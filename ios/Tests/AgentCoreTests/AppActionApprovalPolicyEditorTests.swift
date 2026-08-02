import XCTest
@testable import AgentCore

final class AppActionApprovalPolicyEditorTests: XCTestCase {
    private func makeTemporaryStore() throws -> (store: AppActionApprovalPolicyStore, directoryURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppActionApprovalPolicyEditorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        let store = AppActionApprovalPolicyStore(fileURL: directoryURL.appendingPathComponent("policy.json"))
        return (store, directoryURL)
    }

    func testEditorInstallsDefaultWhenPolicyFileIsMissing() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))

        let editor = try AppActionApprovalPolicyEditor(store: store)

        XCTAssertEqual(editor.policy, .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertEqual(store.load(), .default)
    }

    func testEditorMutationsPersistRoundTrip() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let initialPolicy = AppActionApprovalPolicy(
            schemaVersion: 3,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: false, note: "Allow messages for trusted-device mode."),
                .init(actionKind: .deleteRecord, requiresApproval: true, note: "Review deletions."),
                .init(actionKind: .updateRecord, requiresApproval: true, note: "Review updates."),
                .init(actionKind: .exportData, requiresApproval: true, note: "Review exports.")
            ]
        )
        try store.save(initialPolicy)

        var editor = try AppActionApprovalPolicyEditor(store: store)
        XCTAssertEqual(editor.policy, initialPolicy)

        editor.setRequiresApproval(false, for: .deleteRecord)
        editor.setEnabled(false, for: .exportData)
        editor.setNote("No approval for local delete cleanup.", for: .deleteRecord)
        try editor.save()

        let loaded = store.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.requiresApproval(for: .deleteRecord), false)
        XCTAssertEqual(loaded?.requiresApproval(for: .exportData), nil)
        XCTAssertEqual(loaded?.rule(for: .deleteRecord)?.note, "No approval for local delete cleanup.")
        XCTAssertEqual(loaded, editor.policy)
    }

    func testEditorCanClearExistingNote() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let initialPolicy = AppActionApprovalPolicy(
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: false, note: "Temporary note."),
                .init(actionKind: .deleteRecord, requiresApproval: true),
                .init(actionKind: .updateRecord, requiresApproval: true),
                .init(actionKind: .exportData, requiresApproval: true)
            ]
        )
        try store.save(initialPolicy)

        var editor = try AppActionApprovalPolicyEditor(store: store)
        editor.setNote(nil, for: .sendMessage)
        try editor.save()

        XCTAssertNil(editor.policy.rule(for: .sendMessage)?.note)
        XCTAssertNil(store.load()?.rule(for: .sendMessage)?.note)
    }

    func testResetToDefaultRestoresSetupPolicy() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let customPolicy = AppActionApprovalPolicy(
            schemaVersion: 9,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: true),
                .init(actionKind: .deleteRecord, requiresApproval: false),
                .init(actionKind: .updateRecord, requiresApproval: false),
                .init(actionKind: .exportData, requiresApproval: false)
            ]
        )
        try store.save(customPolicy)

        var editor = try AppActionApprovalPolicyEditor(store: store)
        XCTAssertEqual(editor.policy, customPolicy)

        editor.resetToDefault()
        try editor.save()

        XCTAssertEqual(store.load(), .default)
    }
}
