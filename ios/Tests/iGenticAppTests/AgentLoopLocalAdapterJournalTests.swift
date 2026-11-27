import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopLocalAdapterJournalTests: XCTestCase {
    @MainActor private func fixture() throws -> (URL, AgentLoopDiagnosticJournal) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return (dir, AgentLoopDiagnosticJournal(url: dir.appendingPathComponent("journal.json")))
    }

    @MainActor func testLocalAdapterMenuAndJournalDoNotExposeObservationValues() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        var requests: [AgentLoopLocalDiagnosticWorkflow.LocalDecisionRequest] = []
        var reads = 0, checks = 0, inventories = 0
        let report = try await journal.run(goal: .extended) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.runLocalAdapter(goal: .extended, propose: { request in
                requests.append(request)
                return request.allowedActions.last ?? "abort"
            }, readStatus: { reads += 1; return .init(batteryFraction: 0.73, lowPowerModeEnabled: true, osVersion: "27.2") },
                checkModel: { checks += 1; return false }, inspectCapabilities: { inventories += 1; return 4 },
                elapsed: { 1 }, checkpoint: checkpoint)
        }
        XCTAssertEqual(report.outcome, .completed)
        XCTAssertEqual(report.modelTurns, 4)
        XCTAssertEqual(report.steps, [.inspectCapabilities, .checkModel, .readStatus, .finish])
        XCTAssertTrue(report.localReport?.contains("73 %") == true)
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(inventories, 1)
        XCTAssertEqual(requests.map(\.allowedActions), [["status.read", "model.readiness", "capabilities.read"], ["status.read", "model.readiness"], ["status.read"], ["finish"]])
        XCTAssertEqual(requests.map(\.completedActions), [[], ["capabilities.read"], ["capabilities.read", "model.readiness"], ["capabilities.read", "model.readiness", "status.read"]])
        XCTAssertEqual(try journal.snapshot()?.stage, .completed)
        let data = try String(contentsOf: dir.appendingPathComponent("journal.json"), encoding: .utf8)
        for privateValue in ["73 %", "27.2"] {
            XCTAssertFalse(data.contains(privateValue))
            XCTAssertFalse(report.shortcutReceipt.contains(privateValue))
        }
    }

    @MainActor func testPartialModelFailureDoesNotReplayOrConsumeNextTicket() async throws {
        enum SyntheticFailure: Error { case expected }
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try journal.enqueue(goal: .basic)
        let next = try journal.enqueue(goal: .extended)
        var reads = 0, turns = 0, appleCalls = 0
        let report = try await DiagnosticModelRouter.dispatch(.qwen, apple: {
            appleCalls += 1
            return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
        }, qwen: {
            try await journal.run(goal: .basic, queuedID: first) { checkpoint in
                await AgentLoopLocalDiagnosticWorkflow.runLocalAdapter(goal: .basic, propose: { request in
                    turns += 1
                    if request.completedActions.isEmpty { return "status.read" }
                    throw SyntheticFailure.expected
                }, readStatus: { reads += 1; return .init(batteryFraction: 0.73, lowPowerModeEnabled: false, osVersion: "27.2") },
                checkModel: { XCTFail("Model failure executed remaining read"); return false }, elapsed: { 1 }, checkpoint: checkpoint)
            }
        })
        let failed = try XCTUnwrap(report)
        XCTAssertEqual(failed.outcome, .failed)
        XCTAssertEqual(failed.steps, [.readStatus])
        XCTAssertNil(failed.localReport)
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(turns, 2)
        XCTAssertEqual(appleCalls, 0)
        XCTAssertEqual(try journal.snapshot()?.id, first)
        XCTAssertEqual(try journal.snapshot()?.stage, .stopped)
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [next])
    }

    @MainActor func testUnavailableModelAndQueuedTaskAdmissionNeverExecuteProvider() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ticket = try journal.enqueue(goal: .basic)
        let file = dir.appendingPathComponent("journal.json")
        let before = try Data(contentsOf: file)
        let none: Int? = try await DiagnosticModelRouter.dispatch(.unavailable, apple: {
            XCTFail("Unavailable Apple called"); return 1
        }, qwen: {
            XCTFail("Unavailable Qwen called"); return 2
        })
        XCTAssertNil(none)
        do {
            let _: AgentLoopDiagnosticReport? = try await DiagnosticModelRouter.dispatch(.apple, apple: {
                try await journal.run(goal: .basic) { _ in
                    XCTFail("Unselected queued task bypassed journal admission")
                    return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
                }
            }, qwen: {
                XCTFail("Apple admission failure replayed via Qwen")
                return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
            })
            XCTFail("Direct route bypassed queue")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .queuePending) }
        XCTAssertEqual(try Data(contentsOf: file), before)
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [ticket])
    }

    @MainActor func testExpiredModelProposalAfterReadCannotAdvanceJournal() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let ticket = try journal.enqueue(goal: .basic)
        var elapsed: TimeInterval = 0
        var reads = 0
        let result = try await journal.run(goal: .basic, queuedID: ticket) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.runLocalAdapter(goal: .basic, propose: { request in
                if request.completedActions.isEmpty { return "status.read" }
                elapsed = 60
                return "model.readiness"
            }, readStatus: { reads += 1; return .init(batteryFraction: 0.73, lowPowerModeEnabled: false, osVersion: "27.2") },
            checkModel: { XCTFail("Expired result executed a reader"); return true }, elapsed: { elapsed }, checkpoint: checkpoint)
        }
        XCTAssertEqual(result.outcome, .expired)
        XCTAssertEqual(result.steps, [.readStatus])
        XCTAssertNil(result.localReport)
        XCTAssertEqual(reads, 1)
        XCTAssertEqual(try journal.snapshot()?.steps, [.readStatus])
        XCTAssertEqual(try journal.snapshot()?.stage, .stopped)
    }
}
