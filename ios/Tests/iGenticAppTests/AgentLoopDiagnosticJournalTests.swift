import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopDiagnosticJournalTests: XCTestCase {
    @MainActor
    private func fixture() throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false,
                                                attributes: [.posixPermissions: 0o700])
        return (dir, dir.appendingPathComponent("journal.json"))
    }
    @MainActor
    func testPersistsProgressAndNoObservationPayload() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let report = try await journal.run(goal: .basic) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.run(propose: { p in
                ["status.read","model.readiness","finish"][p.completed.count]
            }, readStatus: { .init(batteryFraction: 0.42, lowPowerModeEnabled: false, osVersion: "27.2") },
            checkModel: { true }, elapsed: { 1 }, checkpoint: checkpoint)
        }
        XCTAssertEqual(report.outcome,.completed)
        let saved = try XCTUnwrap(AgentLoopDiagnosticJournal(url: url).snapshot())
        XCTAssertEqual(saved.steps,[.readStatus,.checkModel,.finish])
        XCTAssertEqual(saved.stage,.completed)
        let data = try Data(contentsOf: url)
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String:Any])
        XCTAssertEqual(Set(obj.keys),Set(["schema","id","goal","steps","stage"]))
        XCTAssertFalse(String(decoding:data,as:UTF8.self).contains("27.2"))
    }
    @MainActor
    func testInterruptedRunRequiresExplicitFreshRestart() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        // A mismatched terminal report models an abandoned durable record.
        do {
            _ = try await journal.run(goal: .basic) { checkpoint in
                do { try checkpoint([.readStatus]) } catch { XCTFail("Checkpoint failed: \(error)") }
                return .init(outcome:.failed,steps:[],modelTurns:1,localReport:nil)
            }
            XCTFail("Invalid terminal record accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.invalid) }
        let reopened = AgentLoopDiagnosticJournal(url: url)
        let saved = try XCTUnwrap(reopened.snapshot())
        XCTAssertEqual(saved.stage,.running)
        XCTAssertEqual(saved.steps,[.readStatus])
        do {
            _ = try await reopened.run(goal: .basic) { _ in
                XCTFail("Automatic restart")
                return .init(outcome:.failed,steps:[],modelTurns:0,localReport:nil)
            }
            XCTFail("Abandoned record overwritten")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.recoveryRequired) }
        do {
            _ = try await reopened.run(goal:.extended,restartID:saved.id) { _ in
                XCTFail("Wrong goal recovery")
                return .init(outcome:.failed,steps:[],modelTurns:0,localReport:nil)
            }
            XCTFail("Wrong goal accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.staleRecovery) }
        var reads = 0
        let report = try await reopened.run(goal:.basic,restartID:saved.id) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.run(propose: { p in
                ["status.read","model.readiness","finish"][p.completed.count]
            }, readStatus: {
                reads += 1
                return .init(batteryFraction:0.8,lowPowerModeEnabled:false,osVersion:"27")
            }, checkModel:{true},elapsed:{1},checkpoint:checkpoint)
        }
        XCTAssertEqual(report.outcome,.completed)
        XCTAssertEqual(reads,1)
        XCTAssertNotEqual(try reopened.snapshot()?.id,saved.id)
    }
    @MainActor
    func testCorruptedRecordAndCompetingRunAreRejected() async throws {
        let (dir,url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url:url)
        let other = AgentLoopDiagnosticJournal(url:url)
        _ = try await journal.run(goal:.basic) { _ in
            do {
                _ = try other.snapshot()
                XCTFail("Concurrent snapshot acquired lease")
            } catch {
                XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.busy)
            }
            return .init(outcome:.cancelled,steps:[],modelTurns:0,localReport:nil)
        }
        try Data("{}".utf8).write(to:url)
        XCTAssertThrowsError(try other.snapshot()) {
            XCTAssertEqual($0 as? AgentLoopDiagnosticJournal.Failure,.invalid)
        }
    }
}

extension AgentLoopDiagnosticJournalTests {
    @MainActor
    func testQueuePersistsFIFOAndRejectsOutOfOrderExecution() async throws {
        let (dir,url) = try fixture()
        defer { try? FileManager.default.removeItem(at:dir) }
        let journal = AgentLoopDiagnosticJournal(url:url)
        let first = try journal.enqueue(goal:.basic)
        let second = try journal.enqueue(goal:.extended)
        let reopened = AgentLoopDiagnosticJournal(url:url)
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets.map(\.id),[first,second])
        do {
            _ = try await reopened.run(goal:.extended,queuedID:second) { _ in
                XCTFail("Out-of-order execution")
                return .init(outcome:.failed,steps:[],modelTurns:0,localReport:nil)
            }
            XCTFail("Out-of-order ticket accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.staleTicket) }
        let report = try await reopened.run(goal:.basic,queuedID:first) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.run(propose: { p in
                ["status.read","model.readiness","finish"][p.completed.count]
            }, readStatus: { .init(batteryFraction:0.5,lowPowerModeEnabled:false,osVersion:"27") },
            checkModel:{true},elapsed:{1},checkpoint:checkpoint)
        }
        XCTAssertEqual(report.outcome,.completed)
        let saved = try XCTUnwrap(reopened.snapshot())
        XCTAssertEqual(saved.id,first)
        XCTAssertEqual(saved.queuedTickets.map(\.id),[second])
        _ = try await reopened.run(goal:.extended,queuedID:second) { _ in
            .init(outcome:.failed,steps:[],modelTurns:1,localReport:nil)
        }
        XCTAssertEqual(try reopened.snapshot()?.stage,.stopped)
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets,[])
    }

    @MainActor
    func testQueueBoundRemovalAndDirectRunGate() async throws {
        let (dir,url) = try fixture()
        defer { try? FileManager.default.removeItem(at:dir) }
        let journal = AgentLoopDiagnosticJournal(url:url)
        var ids: [UUID] = []
        for _ in 0..<4 { ids.append(try journal.enqueue(goal:.basic)) }
        XCTAssertThrowsError(try journal.enqueue(goal:.extended)) {
            XCTAssertEqual($0 as? AgentLoopDiagnosticJournal.Failure,.queueFull)
        }
        try journal.removeQueued(id:ids[0])
        try journal.removeQueued(id:ids[2])
        XCTAssertEqual(try journal.snapshot()?.queuedTickets.map(\.id),[ids[1],ids[3]])
        XCTAssertThrowsError(try journal.removeQueued(id:ids[0])) {
            XCTAssertEqual($0 as? AgentLoopDiagnosticJournal.Failure,.staleTicket)
        }
        do {
            _ = try await journal.run(goal:.basic) { _ in
                XCTFail("Queue bypassed")
                return .init(outcome:.failed,steps:[],modelTurns:0,localReport:nil)
            }
            XCTFail("Direct run accepted despite pending queue")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.queuePending) }
    }

    @MainActor
    func testInterruptedHeadDoesNotConsumeLaterTicket() async throws {
        let (dir,url) = try fixture()
        defer { try? FileManager.default.removeItem(at:dir) }
        let journal = AgentLoopDiagnosticJournal(url:url)
        let first = try journal.enqueue(goal:.basic)
        let second = try journal.enqueue(goal:.extended)
        do {
            _ = try await journal.run(goal:.basic,queuedID:first) { checkpoint in
                do { try checkpoint([.readStatus]) } catch { XCTFail("Checkpoint failed") }
                return .init(outcome:.failed,steps:[],modelTurns:1,localReport:nil)
            }
            XCTFail("Invalid terminal report accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.invalid) }
        let reopened = AgentLoopDiagnosticJournal(url:url)
        XCTAssertEqual(try reopened.snapshot()?.stage,.running)
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets.map(\.id),[second])
        do {
            _ = try await reopened.run(goal:.extended,queuedID:second) { _ in
                XCTFail("Interrupted task bypassed")
                return .init(outcome:.failed,steps:[],modelTurns:0,localReport:nil)
            }
            XCTFail("Later ticket accepted")
        } catch { XCTAssertEqual(error as? AgentLoopDiagnosticJournal.Failure,.staleTicket) }
        _ = try await reopened.run(goal:.basic,restartID:first) { _ in
            .init(outcome:.cancelled,steps:[],modelTurns:0,localReport:nil)
        }
        XCTAssertEqual(try reopened.snapshot()?.queuedTickets.map(\.id),[second])
    }
}

extension AgentLoopDiagnosticJournalTests {
    @MainActor
    func testDeterministicQueueCompletesWithoutModelAndPersistsOnlyMetadata() async throws {
        let (dir, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: dir) }
        let journal = AgentLoopDiagnosticJournal(url: url)
        let first = try journal.enqueue(goal: .basic)
        let second = try journal.enqueue(goal: .extended)
        let tickets = try XCTUnwrap(journal.snapshot()).queuedTickets
        XCTAssertEqual(tickets.map(\.id), [first, second])
        for ticket in tickets {
            let report = try await journal.run(goal: ticket.goal, queuedID: ticket.id) { checkpoint in
                await AgentLoopLocalDiagnosticWorkflow.runDeterministic(goal: ticket.goal,
                    readStatus: { .init(batteryFraction: 0.42, lowPowerModeEnabled: false, osVersion: "27.2") },
                    checkModel: { false }, inspectCapabilities: { 4 }, elapsed: { 1 }, checkpoint: checkpoint)
            }
            XCTAssertEqual(report.outcome, .completed)
            XCTAssertEqual(report.modelTurns, 0)
            XCTAssertEqual(try journal.snapshot()?.id, ticket.id)
            XCTAssertEqual(try journal.snapshot()?.stage, .completed)
        }
        let reopened = try XCTUnwrap(AgentLoopDiagnosticJournal(url: url).snapshot())
        XCTAssertTrue(reopened.queuedTickets.isEmpty)
        XCTAssertEqual(reopened.steps, [.readStatus,.checkModel,.inspectCapabilities,.finish])
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.contains("27.2"))
        XCTAssertFalse(content.contains("42 %"))
    }
}
