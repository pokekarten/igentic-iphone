import XCTest
@testable import AgentCore

final class AppActionApprovalPolicySetupConfirmationStoreTests: XCTestCase {
    private func makeTemporaryStore() throws -> (store: AppActionApprovalPolicySetupConfirmationStore, directoryURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppActionApprovalPolicySetupConfirmationStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        let store = AppActionApprovalPolicySetupConfirmationStore(
            fileURL: directoryURL.appendingPathComponent("confirmation")
        )
        return (store, directoryURL)
    }

    func testMissingConfirmationIsNotConfirmed() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(store.isConfirmed())
    }

    func testConfirmationPersistsRoundTrip() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try store.confirm()

        XCTAssertTrue(store.isConfirmed())
    }

    func testUnexpectedMarkerDoesNotCountAsConfirmation() throws {
        let (store, directoryURL) = try makeTemporaryStore()
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        try Data("unexpected".utf8).write(to: store.fileURL, options: [.atomic])

        XCTAssertFalse(store.isConfirmed())
    }
}
