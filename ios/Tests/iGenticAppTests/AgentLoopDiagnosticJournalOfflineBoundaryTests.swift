import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopDiagnosticJournalOfflineBoundaryTests: XCTestCase {
    @MainActor private func fixture() throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return (dir, dir.appendingPathComponent("journal.json"))
    }

    @MainActor func testQueueReplacementIsPrivateAndLeavesNoStaging() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let a = try journal.enqueue(goal: .basic)
        let b = try journal.enqueue(goal: .extended)
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [a,b])
        try journal.removeQueued(id: a)
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [b])
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: dir.path)), ["journal.json", "journal.json.lock"])
    }

    @MainActor func testCancelledQueuedTaskDoesNotConsumeTicket() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let a = try journal.enqueue(goal: .basic)
        let b = try journal.enqueue(goal: .extended)
        let before = try Data(contentsOf: url)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return try await journal.run(goal: .basic, queuedID: a) { _ in
                XCTFail("Cancelled task executed")
                return .init(outcome: .cancelled, steps: [], modelTurns: 0, localReport: nil)
            }
        }
        do { _ = try await task.value; XCTFail("Cancellation ignored") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(try Data(contentsOf: url), before)
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [a,b])
    }

    @MainActor func testRejectedCheckpointPreservesPreviouslyCommittedProgress() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let report = try await journal.run(goal: .basic) { checkpoint in
            do {
                try checkpoint([.readStatus])
                let before = try Data(contentsOf: url)
                do { try checkpoint([.readStatus,.finish]); XCTFail("Premature finish accepted") }
                catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
                XCTAssertEqual(try Data(contentsOf: url), before)
            } catch { XCTFail("Unexpected checkpoint error: \(error)") }
            return .init(outcome: .failed, steps: [.readStatus], modelTurns: 0, localReport: nil)
        }
        XCTAssertEqual(report.outcome, .failed)
        XCTAssertEqual(try journal.snapshot()?.steps, [.readStatus])
        XCTAssertEqual(try journal.snapshot()?.stage, .stopped)
    }

    @MainActor func testAbandonedHeadCannotConsumeLaterQueueAndRecoveryGetsNewID() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let a = try journal.enqueue(goal: .basic)
        let b = try journal.enqueue(goal: .extended)
        do {
            _ = try await journal.run(goal: .basic, queuedID: a) { checkpoint in
                do { try checkpoint([.readStatus]) } catch { XCTFail("Checkpoint failed") }
                return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
            }
            XCTFail("Contradictory terminal accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
        let reopened = AgentLoopDiagnosticJournal(url: url)
        XCTAssertEqual(try reopened.snapshot()?.stage, .running)
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets.map(\.id), [b])
        do {
            _ = try await reopened.run(goal: .extended, queuedID: b) { _ in
                XCTFail("Bypassed interrupted head")
                return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
            }
            XCTFail("Later task accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .staleTicket) }
        _ = try await reopened.run(goal: .basic, restartID: a) { checkpoint in
            do { try checkpoint([.readStatus]); try checkpoint([.readStatus,.checkModel]); try checkpoint([.readStatus,.checkModel,.finish]) }
            catch { XCTFail("Fresh progress failed: \(error)") }
            return .init(outcome: .completed, steps: [.readStatus,.checkModel,.finish], modelTurns: 0, localReport: "synthetic private report")
        }
        XCTAssertNotEqual(try reopened.snapshot()?.id, a)
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets.map(\.id), [b])
        XCTAssertFalse(try String(contentsOf: url, encoding: .utf8).contains("synthetic private report"))
    }

    @MainActor func testCompetingLeaseCannotChangeQueue() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = AgentLoopDiagnosticJournal(url: url)
        let second = AgentLoopDiagnosticJournal(url: url)
        let a = try first.enqueue(goal: .basic)
        let b = try first.enqueue(goal: .extended)
        _ = try await first.run(goal: .basic, queuedID: a) { _ in
            do { _ = try second.enqueue(goal: .basic); XCTFail("Competing enqueue succeeded") }
            catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .busy) }
            do { try second.removeQueued(id: b); XCTFail("Competing removal succeeded") }
            catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .busy) }
            return .init(outcome: .cancelled, steps: [], modelTurns: 0, localReport: nil)
        }
        XCTAssertEqual(try second.snapshot()?.queuedTickets.map(\.id), [b])
    }
}
