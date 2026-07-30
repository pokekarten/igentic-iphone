import XCTest
@testable import AgentCore

final class AppActionApprovalPolicyTests: XCTestCase {
    func testSetupDefaultPolicyPinsPerActionKinds() {
        let policy = AppActionApprovalPolicy.setupDefault

        XCTAssertEqual(policy.schemaVersion, 1)
        XCTAssertEqual(policy.requiresApproval(for: .sendMessage), false)
        XCTAssertEqual(policy.requiresApproval(for: .deleteRecord), true)
        XCTAssertEqual(policy.requiresApproval(for: .updateRecord), true)
        XCTAssertEqual(policy.requiresApproval(for: .exportData), true)
        XCTAssertEqual(policy.rule(for: .sendMessage)?.note, "Default setup allows direct messaging.")
    }

    func testPolicyStoreRoundTripsAndFallsBackToDefault() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("app-action-approval-policy.json")
        let store = AppActionApprovalPolicyStore(fileURL: url)

        let customPolicy = AppActionApprovalPolicy(
            schemaVersion: 2,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: false, note: "Direct messages are allowed."),
                .init(actionKind: .deleteRecord, requiresApproval: true, note: "Deletions need review."),
                .init(actionKind: .updateRecord, requiresApproval: false, note: "Updates are allowed."),
                .init(actionKind: .exportData, requiresApproval: true, enabled: false, note: "Temporarily disabled.")
            ]
        )

        try store.save(customPolicy)
        XCTAssertEqual(store.load(), customPolicy)
        XCTAssertEqual(store.loadOrDefault(), customPolicy)

        let invalidURL = directory.appendingPathComponent("invalid-policy.json")
        try "not-json".data(using: .utf8)!.write(to: invalidURL, options: [.atomic])
        let invalidStore = AppActionApprovalPolicyStore(fileURL: invalidURL)
        XCTAssertEqual(invalidStore.load(), nil)
        XCTAssertEqual(invalidStore.loadOrDefault(), .default)
    }
}
