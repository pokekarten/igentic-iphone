import Foundation
import XCTest
@testable import AgentCore

final class AppActionApprovalPolicyStoreTests: XCTestCase {
    private func makeStore() throws -> (store: AppActionApprovalPolicyStore, directoryURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppActionApprovalPolicyStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        return (AppActionApprovalPolicyStore(fileURL: directoryURL.appendingPathComponent("policy.json")), directoryURL)
    }

    private func writeRawPolicy(_ json: String, to store: AppActionApprovalPolicyStore) throws {
        try Data(json.utf8).write(to: store.fileURL, options: [.atomic])
    }

    override func tearDown() {
        super.tearDown()
    }

    func testSaveAndLoadRoundTripPreservesPolicy() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let policy = AppActionApprovalPolicy(
            schemaVersion: 2,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: true, note: "Review outbound messages."),
                .init(actionKind: .deleteRecord, requiresApproval: false, enabled: true, note: "Allow local cleanup."),
                .init(actionKind: .updateRecord, requiresApproval: true),
                .init(actionKind: .exportData, requiresApproval: true)
            ]
        )

        try store.save(policy)

        XCTAssertEqual(store.load(), policy)
    }

    func testLoadOrDefaultFallsBackToDefaultForCorruptedFile() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try Data("not-json".utf8).write(to: store.fileURL, options: [.atomic])

        XCTAssertNil(store.load())
        XCTAssertEqual(store.loadOrDefault(), .default)
    }

    func testLoadRejectsPolicyMissingRequiredActionKind() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let missingRuleJSON = """
        {
          "schemaVersion": 7,
          "rules": [
            {"actionKindRawValue":"sendMessage","requiresApproval":false,"enabled":true},
            {"actionKindRawValue":"deleteRecord","requiresApproval":true,"enabled":true},
            {"actionKindRawValue":"updateRecord","requiresApproval":true,"enabled":true}
          ]
        }
        """
        try writeRawPolicy(missingRuleJSON, to: store)

        XCTAssertNil(store.load())
        XCTAssertEqual(store.loadOrDefault(), .default)
    }

    func testLoadRejectsDuplicateActionKindRules() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let duplicateRuleJSON = """
        {
          "schemaVersion": 3,
          "rules": [
            {"actionKindRawValue":"sendMessage","requiresApproval":false,"enabled":true},
            {"actionKindRawValue":"deleteRecord","requiresApproval":true,"enabled":true},
            {"actionKindRawValue":"updateRecord","requiresApproval":true,"enabled":true},
            {"actionKindRawValue":"updateRecord","requiresApproval":false,"enabled":true}
          ]
        }
        """
        try writeRawPolicy(duplicateRuleJSON, to: store)

        XCTAssertNil(store.load())
        XCTAssertEqual(store.loadOrDefault(), .default)
    }

    func testLoadRejectsUnknownActionKindRule() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let unknownRuleJSON = """
        {
          "schemaVersion": 4,
          "rules": [
            {"actionKindRawValue":"sendMessage","requiresApproval":false,"enabled":true},
            {"actionKindRawValue":"deleteRecord","requiresApproval":true,"enabled":true},
            {"actionKindRawValue":"updateRecord","requiresApproval":true,"enabled":true},
            {"actionKindRawValue":"futureAction","requiresApproval":false,"enabled":true}
          ]
        }
        """
        try writeRawPolicy(unknownRuleJSON, to: store)

        XCTAssertNil(store.load())
        XCTAssertEqual(store.loadOrDefault(), .default)
    }

    func testSaveRejectsIncompletePolicyWithoutWritingFile() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let incompletePolicy = AppActionApprovalPolicy(
            schemaVersion: 8,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: true),
                .init(actionKind: .deleteRecord, requiresApproval: true),
                .init(actionKind: .updateRecord, requiresApproval: true)
            ]
        )

        XCTAssertThrowsError(try store.save(incompletePolicy))
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testLoadOrInstallDefaultCreatesDefaultPolicyWhenFileIsMissing() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))

        let installed = try store.loadOrInstallDefault()

        XCTAssertEqual(installed, .default)
        XCTAssertEqual(store.load(), .default)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
    }

    func testLoadOrInstallDefaultKeepsExistingPolicyUntouched() throws {
        let (store, directoryURL) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let customPolicy = AppActionApprovalPolicy(
            schemaVersion: 9,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: true),
                .init(actionKind: .deleteRecord, requiresApproval: true),
                .init(actionKind: .updateRecord, requiresApproval: false),
                .init(actionKind: .exportData, requiresApproval: false)
            ]
        )

        try store.save(customPolicy)

        let loaded = try store.loadOrInstallDefault()

        XCTAssertEqual(loaded, customPolicy)
        XCTAssertEqual(store.load(), customPolicy)
    }
}
