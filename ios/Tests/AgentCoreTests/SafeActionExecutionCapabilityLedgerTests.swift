import Foundation
import XCTest
@testable import AgentCore

final class SafeActionExecutionCapabilityLedgerTests: XCTestCase {
    private enum TestError: Error {
        case failed
    }

    actor InvocationCounter {
        private(set) var count = 0

        func increment() {
            count += 1
        }

        func snapshot() -> Int {
            count
        }
    }

    actor StartSignal {
        private var started = false

        func markStarted() {
            started = true
        }

        func hasStarted() -> Bool {
            started
        }
    }

    func testIssueCreatesIssuedCapabilityAndRejectsDuplicateIdentity() {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()

        XCTAssertTrue(ledger.issue(id))
        XCTAssertEqual(ledger.state(for: id), .issued)
        XCTAssertFalse(ledger.issue(id))
        XCTAssertEqual(ledger.state(for: id), .issued)
    }

    func testUnknownCapabilityFailsClosedWithoutRunningOperation() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let counter = InvocationCounter()

        let result = await ledger.consume(UUID()) {
            await counter.increment()
            return "unexpected"
        }

        guard case .rejected(.unknownCapability) = result else {
            return XCTFail("Expected unknown-capability rejection.")
        }
        let count = await counter.snapshot()
        XCTAssertEqual(count, 0)
    }

    func testSuccessfulOperationTerminalizesCapability() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        ledger.issue(id)

        let result = await ledger.consume(id) { "success" }

        guard case .completed(let value) = result else {
            return XCTFail("Expected completed consumption.")
        }
        XCTAssertEqual(value, "success")
        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testCancelledOutcomeBeforeExecutorStillTerminalizesCapability() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        let executorCounter = InvocationCounter()
        ledger.issue(id)

        let cancellationObservedAfterAcquisition = true
        let result = await ledger.consume(id) {
            if cancellationObservedAfterAcquisition {
                return "cancelled"
            }
            await executorCounter.increment()
            return "executed"
        }

        guard case .completed(let value) = result else {
            return XCTFail("Expected the winning consumption attempt to complete.")
        }
        XCTAssertEqual(value, "cancelled")
        let executorCount = await executorCounter.snapshot()
        XCTAssertEqual(executorCount, 0)
        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testTaskCancellationAfterAcquisitionThrowsAndTerminalizesCapability() async {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        let signal = StartSignal()
        ledger.issue(id)

        let task = Task {
            try await ledger.consume(id) {
                await signal.markStarted()
                try await Task.sleep(for: .seconds(10))
                return "unexpected"
            }
        }

        while !(await signal.hasStarted()) {
            await Task.yield()
        }
        XCTAssertEqual(ledger.state(for: id), .consuming)

        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate from the operation.")
        } catch is CancellationError {
            // Expected. The ledger defer must still terminalize the capability.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testExecutorFailureOutcomeStillTerminalizesCapability() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        ledger.issue(id)

        let result = await ledger.consume(id) { "platformFailure" }

        guard case .completed(let value) = result else {
            return XCTFail("Expected completed consumption.")
        }
        XCTAssertEqual(value, "platformFailure")
        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testThrownOperationStillTerminalizesCapability() async {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        ledger.issue(id)

        do {
            _ = try await ledger.consume(id) { () async throws -> String in
                throw TestError.failed
            }
            XCTFail("Expected operation to throw.")
        } catch TestError.failed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testSecondAttemptAfterConsumptionIsRejectedWithoutOperation() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        let counter = InvocationCounter()
        ledger.issue(id)

        _ = await ledger.consume(id) {
            await counter.increment()
            return "first"
        }
        let second = await ledger.consume(id) {
            await counter.increment()
            return "second"
        }

        guard case .rejected(.alreadyConsumed) = second else {
            return XCTFail("Expected consumed-capability rejection.")
        }
        let count = await counter.snapshot()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(ledger.state(for: id), .consumed)
    }

    func testConcurrentConsumersHaveExactlyOneWinnerAndOneOperationCall() async throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let id = UUID()
        let counter = InvocationCounter()
        ledger.issue(id)

        async let first = ledger.consume(id) {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(40))
            return "first"
        }
        async let second = ledger.consume(id) {
            await counter.increment()
            try await Task.sleep(for: .milliseconds(40))
            return "second"
        }

        let results = try await [first, second]
        let completedCount = results.reduce(into: 0) { count, result in
            if case .completed = result {
                count += 1
            }
        }
        let rejectedCount = results.reduce(into: 0) { count, result in
            if case .rejected(let reason) = result {
                XCTAssertEqual(reason, .alreadyConsuming)
                count += 1
            }
        }

        XCTAssertEqual(completedCount, 1)
        XCTAssertEqual(rejectedCount, 1)
        let count = await counter.snapshot()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(ledger.state(for: id), .consumed)
    }
}
