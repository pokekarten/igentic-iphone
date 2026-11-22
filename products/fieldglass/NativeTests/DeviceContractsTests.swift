import XCTest
import AppIntents
import UniformTypeIdentifiers
@testable import Fieldglass

final class DeviceContractsTests: XCTestCase {
    func testOneReservationPerReminderAcrossCalls() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let id = UUID()
        XCTAssertTrue(try ReminderAttempt.reserve(id, in: folder))
        XCTAssertFalse(try ReminderAttempt.reserve(id, in: folder))
        XCTAssertTrue(try ReminderAttempt.reserve(UUID(), in: folder))
    }

    func testInvalidLinksHaveNoAction() {
        let id = UUID().uuidString
        let link = "fieldglass://experiment/v1?id=\(id)&term=Test&region=top"
        XCTAssertNotNil(Experiment(link: URL(string: link)!))
        XCTAssertNil(Experiment(link: URL(string: link + "&region=all")!))
        XCTAssertNil(WorkspaceJob(link: URL(string: "fieldglass://workspace/v1?id=\(id)&action=reminder&text=")!))
        XCTAssertNil(WorkspaceJob(link: URL(string: "fieldglass://workspace/v1?id=\(id)&action=shell&text=demo")!))
    }

    @available(iOS 18.0, *)
    func testNativeShortcutPerformsOCRAndReturnsMinimalReceipt() async throws {
        let id = UUID()
        var intent = CheckImageIntent()
        intent.link = "fieldglass://experiment/v1?id=\(id.uuidString)&term=ORBIT&region=top"
        let data = await MainActor.run { Reader.sample() }
        intent.image = IntentFile(data: data, filename: "example.png", type: .png)
        let result = try await intent.perform()
        let json = try XCTUnwrap(result.value)
        let receipt = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        XCTAssertEqual(receipt["experimentId"] as? String, id.uuidString)
        XCTAssertEqual(receipt["outcome"] as? String, "match")
        XCTAssertEqual(Set(receipt.keys), ["version","experimentId","readingId","region","source","runtime","outcome"])
    }
}
