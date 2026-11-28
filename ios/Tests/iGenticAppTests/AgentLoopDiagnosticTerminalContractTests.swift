import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopDiagnosticTerminalContractTests: XCTestCase {
    @MainActor private func fixture() throws -> (URL, AgentLoopDiagnosticJournal) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return (dir, AgentLoopDiagnosticJournal(url: dir.appendingPathComponent("journal.json")))
    }

    @MainActor func testCompletedReportRequiresPreparedLocalResult() async throws {
        for payload: String? in [nil, ""] {
            let (dir, journal) = try fixture()
            defer { try? FileManager.default.removeItem(at: dir) }
            let ticket = try journal.enqueue(goal: .basic)
            let next = try journal.enqueue(goal: .extended)
            do {
                _ = try await journal.run(goal: .basic, queuedID: ticket) { checkpoint in
                    do {
                        try checkpoint([.readStatus])
                        try checkpoint([.readStatus, .checkModel])
                        try checkpoint([.readStatus, .checkModel, .finish])
                    } catch { XCTFail("Unexpected checkpoint failure") }
                    return .init(outcome: .completed, steps: [.readStatus, .checkModel, .finish], modelTurns: 0, localReport: payload)
                }
                XCTFail("Completion without a local report was accepted")
            } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
            XCTAssertEqual(try journal.snapshot()?.stage, .running)
            XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id), [next])
        }
    }

    @MainActor func testFailedReportCannotCarryPayloadOrFinish() async throws {
        for withFinish in [false, true] {
            let (dir, journal) = try fixture()
            defer { try? FileManager.default.removeItem(at: dir) }
            let steps: [AgentLoopDiagnosticStep] = withFinish ? [.readStatus, .checkModel, .finish] : [.readStatus]
            do {
                _ = try await journal.run(goal: .basic) { checkpoint in
                    for i in 1...steps.count {
                        do { try checkpoint(Array(steps.prefix(i))) } catch { XCTFail("Unexpected checkpoint failure") }
                    }
                    return .init(outcome: .failed, steps: steps, modelTurns: 0, localReport: withFinish ? nil : "synthetic partial report")
                }
                XCTFail("Contradictory failure report was accepted")
            } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
            XCTAssertEqual(try journal.snapshot()?.stage, .running)
        }
    }

    @MainActor func testInvalidModelTurnCountCannotBecomeCompletedReceipt() async throws {
        for turns in [-1, 1, 4, Int.max] {
            let (dir, journal) = try fixture()
            defer { try? FileManager.default.removeItem(at: dir) }
            do {
                _ = try await journal.run(goal: .basic) { checkpoint in
                    do {
                        try checkpoint([.readStatus])
                        try checkpoint([.readStatus, .checkModel])
                        try checkpoint([.readStatus, .checkModel, .finish])
                    } catch { XCTFail("Unexpected checkpoint failure") }
                    return .init(outcome: .completed, steps: [.readStatus, .checkModel, .finish], modelTurns: turns, localReport: "synthetic complete report")
                }
                XCTFail("Impossible model turn count was accepted")
            } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
            XCTAssertEqual(try journal.snapshot()?.stage, .running)
        }
    }

    @MainActor func testValidDeterministicAndModelCompletionsRemainAccepted() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        var previousID: UUID?
        for turns in [0, 3] {
            let result = try await journal.run(goal: .basic) { checkpoint in
                do {
                    try checkpoint([.readStatus])
                    try checkpoint([.readStatus, .checkModel])
                    try checkpoint([.readStatus, .checkModel, .finish])
                } catch { XCTFail("Unexpected checkpoint failure") }
                return .init(outcome: .completed, steps: [.readStatus, .checkModel, .finish], modelTurns: turns, localReport: "synthetic complete report")
            }
            XCTAssertEqual(result.outcome, .completed)
            let saved = try XCTUnwrap(journal.snapshot())
            XCTAssertEqual(saved.stage, .completed)
            XCTAssertEqual(result.attemptID, saved.id)
            XCTAssertNotEqual(previousID, saved.id)
            XCTAssertTrue(result.shortcutReceipt.hasSuffix("; attemptID=" + saved.id.uuidString.lowercased()))
            XCTAssertFalse(result.shortcutReceipt.contains("synthetic complete report"))
            previousID = saved.id
        }
    }

    @MainActor func testOperationCannotSupplyItsOwnAttemptIdentity() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let suppliedID = UUID()
        do {
            _ = try await journal.run(goal: .basic) { _ in
                .init(outcome: .failed, steps: [], modelTurns: 0,
                      localReport: nil, attemptID: suppliedID)
            }
            XCTFail("Operation-supplied identity was accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
        let saved = try XCTUnwrap(journal.snapshot())
        XCTAssertEqual(saved.stage, .running)
        XCTAssertNotEqual(saved.id, suppliedID)
    }

    @MainActor func testStoppedReportCarriesPersistedAttemptIdentity() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let result = try await journal.run(goal: .basic) { _ in
            .init(outcome: .modelUnavailable, steps: [], modelTurns: 0, localReport: nil)
        }
        let saved = try XCTUnwrap(journal.snapshot())
        XCTAssertEqual(saved.stage, .stopped)
        XCTAssertEqual(result.attemptID, saved.id)
        XCTAssertTrue(result.shortcutReceipt.hasSuffix("; attemptID=" + saved.id.uuidString.lowercased()))
        XCTAssertNil(result.localReport)
    }

    @MainActor func testVisibleReportMatchesOnlyCurrentTerminalCheckpoint() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let steps: [AgentLoopDiagnosticStep] = [.readStatus, .checkModel, .finish]
        let result = try await journal.run(goal: .basic) { checkpoint in
            do {
                for i in 1...steps.count { try checkpoint(Array(steps.prefix(i))) }
            } catch { XCTFail("Unexpected checkpoint failure") }
            return .init(outcome: .completed, steps: steps, modelTurns: 0,
                         localReport: "synthetic complete report")
        }
        let saved = try XCTUnwrap(journal.snapshot())
        XCTAssertTrue(saved.matchesTerminalReport(result))
        let ticket = try journal.enqueue(goal: .extended)
        let queued = try XCTUnwrap(journal.snapshot())
        XCTAssertEqual(queued.id, ticket)
        XCTAssertEqual(queued.stage, .queued)
        XCTAssertFalse(queued.matchesTerminalReport(result))
        let next = try await journal.run(goal: .extended, queuedID: ticket) { _ in
            .init(outcome: .modelUnavailable, steps: [], modelTurns: 0, localReport: nil)
        }
        let stopped = try XCTUnwrap(journal.snapshot())
        XCTAssertTrue(stopped.matchesTerminalReport(next))
        XCTAssertFalse(stopped.matchesTerminalReport(result))
    }

    func testVisibleReportRejectsUnboundOrContradictoryEvidence() {
        let id = UUID()
        let steps: [AgentLoopDiagnosticStep] = [.readStatus, .checkModel, .finish]
        let completed = AgentLoopDiagnosticCheckpoint(schema: 1, id: id, goal: .basic,
                                                      steps: steps, stage: .completed)
        for attemptID in [nil, UUID()] as [UUID?] {
            XCTAssertFalse(completed.matchesTerminalReport(.init(
                outcome: .completed, steps: steps, modelTurns: 0,
                localReport: "synthetic", attemptID: attemptID)))
        }
        for payload in [nil, ""] as [String?] {
            XCTAssertFalse(completed.matchesTerminalReport(.init(
                outcome: .completed, steps: steps, modelTurns: 0,
                localReport: payload, attemptID: id)))
        }
        XCTAssertFalse(completed.matchesTerminalReport(.init(
            outcome: .completed, steps: [.readStatus], modelTurns: 0,
            localReport: "synthetic", attemptID: id)))
        XCTAssertFalse(completed.matchesTerminalReport(.init(
            outcome: .failed, steps: steps, modelTurns: 0, localReport: nil, attemptID: id)))
        var running = completed
        running.stage = .running
        XCTAssertFalse(running.matchesTerminalReport(.init(
            outcome: .completed, steps: steps, modelTurns: 0,
            localReport: "synthetic", attemptID: id)))
        var stopped = completed
        stopped.stage = .stopped
        // A finish checkpoint alone cannot substantiate a terminal report.
        XCTAssertFalse(stopped.matchesTerminalReport(.init(
            outcome: .failed, steps: steps, modelTurns: 0, localReport: nil, attemptID: id)))
        stopped.steps = [.readStatus]
        XCTAssertFalse(stopped.matchesTerminalReport(.init(
            outcome: .failed, steps: stopped.steps, modelTurns: 0,
            localReport: "synthetic", attemptID: id)))
    }

    @MainActor func testInterruptedAttemptRequiresFreshIdentityAndPreservesQueue() async throws {
        let (dir, journal) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = try journal.enqueue(goal: .basic)
        let second = try journal.enqueue(goal: .extended)
        do {
            _ = try await journal.run(goal: .basic, queuedID: first) { checkpoint in
                do { try checkpoint([.readStatus]) }
                catch { XCTFail("Unexpected checkpoint failure") }
                return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
            }
            XCTFail("Contradictory terminal report accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .invalid) }
        let reopened = AgentLoopDiagnosticJournal(url: dir.appendingPathComponent("journal.json"))
        let interrupted = try XCTUnwrap(reopened.snapshot())
        XCTAssertEqual(interrupted.id, first)
        XCTAssertEqual(interrupted.stage, .running)
        XCTAssertEqual(interrupted.queuedTickets.map(\.id), [second])
        let staleReport = AgentLoopDiagnosticReport(outcome: .failed, steps: [.readStatus],
            modelTurns: 0, localReport: nil, attemptID: first)
        XCTAssertFalse(interrupted.matchesTerminalReport(staleReport))
        do {
            _ = try await reopened.run(goal: .extended, queuedID: second) { _ in
                XCTFail("Later ticket executed before explicit recovery")
                return .init(outcome: .failed, steps: [], modelTurns: 0, localReport: nil)
            }
            XCTFail("Interrupted attempt bypassed")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure, .staleTicket) }
        let fresh = try await reopened.run(goal: .basic, restartID: first) { checkpoint in
            do { try checkpoint([.readStatus]) }
            catch { XCTFail("Unexpected checkpoint failure") }
            return .init(outcome: .cancelled, steps: [.readStatus], modelTurns: 0, localReport: nil)
        }
        let stopped = try XCTUnwrap(reopened.snapshot())
        XCTAssertNotEqual(stopped.id, first)
        XCTAssertEqual(stopped.stage, .stopped)
        XCTAssertEqual(stopped.queuedTickets.map(\.id), [second])
        XCTAssertEqual(fresh.attemptID, stopped.id)
        XCTAssertTrue(stopped.matchesTerminalReport(fresh))
        XCTAssertFalse(stopped.matchesTerminalReport(staleReport))
    }
}
