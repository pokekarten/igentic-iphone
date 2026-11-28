import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopShortcutTicketTests: XCTestCase {
    func testSiriTicketContainsSeparateIDAndModelPrompt() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("igentic-ticket-\(UUID().uuidString)")
            let store = AgentLoopShortcutExchangeStore(
                fileURL: directory.appendingPathComponent("exchange.json"),
                clock: { Date(timeIntervalSince1970: 1_700_000_000) }
            )
            defer { try? FileManager.default.removeItem(at: directory) }
            let encoded = try store.beginTicket(task: "Erkläre mir einen sicheren Kurzbefehl")
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(encoded.utf8)) as? [String: Any]
            )
            XCTAssertEqual(object.count, 3)
            XCTAssertEqual(object["schema"] as? Int, 1)
            let id = try XCTUnwrap(object["taskId"] as? String)
            let prompt = try XCTUnwrap(object["prompt"] as? String)
            XCTAssertEqual(id, try store.pendingTaskID())
            XCTAssertEqual(prompt, try store.pendingPrompt())
            XCTAssertFalse(prompt.contains(id), "Correlation ID must not be sent to the AI model")
            XCTAssertTrue(prompt.contains("Erkläre mir einen sicheren Kurzbefehl"))
            let next = try store.pendingTicket()
            let secondObject = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(next.utf8)) as? [String: Any]
            )
            XCTAssertEqual(secondObject["taskId"] as? String, id)
            _ = try store.receive(answer: "Antwort nur als Text", taskID: id)
            XCTAssertThrowsError(try store.pendingTicket()) {
                XCTAssertEqual($0 as? AgentLoopExchangeError, .alreadyAnswered)
            }
        }
    }

    func testOldStructuredTicketCannotWriteAfterTaskReset() async throws {
        try await MainActor.run {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("igentic-ticket-reset-\(UUID().uuidString)")
            let store = AgentLoopShortcutExchangeStore(
                fileURL: directory.appendingPathComponent("exchange.json"),
                clock: { Date(timeIntervalSince1970: 1_700_000_000) }
            )
            defer { try? FileManager.default.removeItem(at: directory) }
            let old = try store.beginTicket(task: "Auftrag eins")
            let ticket = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(old.utf8)) as? [String: Any]
            )
            let oldID = try XCTUnwrap(ticket["taskId"] as? String)
            try store.clear()
            _ = try store.beginTicket(task: "Auftrag zwei")
            let currentID = try store.pendingTaskID()
            XCTAssertNotEqual(oldID, currentID)
            XCTAssertThrowsError(try store.receive(answer: "Veraltet", taskID: oldID)) {
                XCTAssertEqual($0 as? AgentLoopExchangeError, .mismatchedTaskID)
            }
            XCTAssertNil(try store.snapshot()?.answer)
        }
    }
}
