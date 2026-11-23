import Foundation
import XCTest
@testable import iGenticApp

final class ChatGPTHandoffRouteTests: XCTestCase {
    func testKnownReadOnlyHandoffDestinations() {
        for route in ChatGPTHandoffRoute.allCases {
            let url = URL(string: "igentic://handoff/v1/" + route.rawValue)!
            XCTAssertEqual(ChatGPTHandoffRoute.parse(url), route)
        }
    }

    func testPreviewReceiptContainsOnlyFixedFieldsAndFreshEvent() throws {
        let first = ChatGPTHandoffPreviewReceipt(
            route: .discovery,
            eventID: UUID(uuidString: "C13B1B76-1000-4000-8000-123456789ABC")!
        )
        let second = ChatGPTHandoffPreviewReceipt(
            route: .discovery,
            eventID: UUID(uuidString: "C13B1B76-1000-4000-8000-ABCDEF123456")!
        )
        XCTAssertNotEqual(first.eventID, second.eventID)
        XCTAssertEqual(first.schema, 1)
        XCTAssertEqual(first.route, "discovery")
        XCTAssertEqual(first.view, "handoff-preview")
        XCTAssertEqual(first.status, "observed")
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(first)
        ) as! [String: Any]
        XCTAssertEqual(Set(json.keys),
                       Set(["schema", "eventID", "route", "view", "status"]))
        XCTAssertEqual(json["eventID"] as? String, first.eventID)
        XCTAssertNil(json["approved"])
        XCTAssertNil(json["title"])
    }

    func testArbitraryActionsQueriesAndRemotePermissionsFailClosed() {
        let invalid = [
            "igentic://handoff/v1/delete-contacts",
            "igentic://handoff/v1/reminder-draft?title=private",
            "igentic://handoff/v1/discovery#auto-execute",
            "igentic://other/v1/diagnostics",
            "igentic://handoff/v1/diagnostics/extra",
            "igentic://handoff/v1/diagnostics%2Fextra",
            "https://example.org/v1/diagnostics",
            "igentic://user@handoff/v1/discovery",
            "igentic://handoff/v1/discovery?approved=true",
            "igentic://handoff/v1/diagnostics?tool=shell",
            "shortcuts://run-shortcut?name=Anything"
        ]
        for candidate in invalid {
            guard let url = URL(string: candidate) else {
                return XCTFail("Expected valid URL fixture")
            }
            XCTAssertNil(ChatGPTHandoffRoute.parse(url), candidate)
        }
    }
}
