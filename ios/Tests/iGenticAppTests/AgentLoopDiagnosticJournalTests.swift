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
