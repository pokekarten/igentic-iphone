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
            XCTAssertEqual(try journal.snapshot()?.stage, .completed)
        }
    }
}
