import XCTest
@testable import AgentCore

final class AppActionApprovalPolicyBootstrapTests: XCTestCase {
    private func makeTemporaryPolicyURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return directory.appendingPathComponent("app-action-approval-policy.json")
    }

    func testPrepareInstallsDefaultWhenFileIsMissing() throws {
        let url = try makeTemporaryPolicyURL()
        let bootstrap = AppActionApprovalPolicyBootstrap(store: .init(fileURL: url))

        let state = try bootstrap.prepare()

        switch state {
        case .installedDefault(let policy):
            XCTAssertEqual(policy, .default)
        default:
            XCTFail("Expected installedDefault when the policy file is missing")
        }

        XCTAssertTrue(state.requiresSetupConfirmation)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(AppActionApprovalPolicyStore(fileURL: url).load(), .default)
    }

    func testPrepareLoadsExistingPolicyWithoutOverwritingIt() throws {
        let url = try makeTemporaryPolicyURL()
        let store = AppActionApprovalPolicyStore(fileURL: url)
        let policy = AppActionApprovalPolicy(
            schemaVersion: 2,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: false, note: "Direct messages are allowed."),
                .init(actionKind: .deleteRecord, requiresApproval: true, note: "Deletions need review."),
                .init(actionKind: .updateRecord, requiresApproval: false, note: "Updates are allowed."),
                .init(actionKind: .exportData, requiresApproval: true, enabled: false, note: "Temporarily disabled.")
            ]
        )
        try store.save(policy)

        let bootstrap = AppActionApprovalPolicyBootstrap(store: store)
        let state = try bootstrap.prepare()

        switch state {
        case .loadedExisting(let loadedPolicy):
            XCTAssertEqual(loadedPolicy, policy)
        default:
            XCTFail("Expected loadedExisting when a valid policy file is already present")
        }

        XCTAssertFalse(state.requiresSetupConfirmation)
        XCTAssertEqual(store.load(), policy)
    }

    func testPrepareFallsBackToDefaultForCorruptFile() throws {
        let url = try makeTemporaryPolicyURL()
        try "not-json".data(using: .utf8)!.write(to: url, options: [.atomic])
        let bootstrap = AppActionApprovalPolicyBootstrap(store: .init(fileURL: url))

        let state = try bootstrap.prepare()

        switch state {
        case .fellBackToDefault(let policy):
            XCTAssertEqual(policy, .default)
        default:
            XCTFail("Expected fellBackToDefault when the stored file is corrupt")
        }

        XCTAssertTrue(state.requiresSetupConfirmation)
        XCTAssertNil(AppActionApprovalPolicyStore(fileURL: url).load())
    }
}
