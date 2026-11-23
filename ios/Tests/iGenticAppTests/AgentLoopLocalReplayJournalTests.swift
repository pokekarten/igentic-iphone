import Foundation
import XCTest
@testable import iGenticApp

#if canImport(CryptoKit) && canImport(Darwin)
import Darwin

final class AgentLoopLocalReplayJournalTests: XCTestCase {
    private let fixture = """
    {"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}
    """
    private var key: Data { Data((0..<32).map(UInt8.init)) }
    private let now = 2_000_000_000

    private func createDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("igentic-replay-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return url
    }

    private func preview() throws -> AgentLoopRemoteTaskPreview {
        try XCTUnwrap(AgentLoopRemoteTaskVerifier.inspectCanonicalProposal(
            Data(fixture.utf8), relayKey: key, nowSeconds: now
        ))
    }

    func testVerifiedTaskCanOnlyBeReservedOnceEvenAfterRestart() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        let signed = try preview()
        try first.reserveVerifiedPreview(signed, nowSeconds: now)
        let restarted = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        XCTAssertThrowsError(try restarted.reserveVerifiedPreview(signed, nowSeconds: now)) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .alreadyRecorded)
        }
        XCTAssertFalse(signed.replayAdmitted)
        XCTAssertFalse(signed.actionExecuted)
        XCTAssertFalse(signed.ownerApproved)
    }

    func testMarkerIsEmptyAndNameDoesNotExposeRequestID() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        let signed = try preview()
        try journal.reserveVerifiedPreview(signed, nowSeconds: now)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertEqual(names.count, 2)
        let name = try XCTUnwrap(names.first { $0.hasSuffix(".attempt") })
        XCTAssertEqual(names.filter { $0.hasPrefix(".key.") }.count, 1)
        XCTAssertEqual(name.count, 72)
        XCTAssertTrue(name.hasSuffix(".attempt"))
        XCTAssertFalse(name.contains(signed.requestID))
        let content = try Data(contentsOf: directory.appendingPathComponent(name))
        XCTAssertTrue(content.isEmpty)
    }

    func testExpiredTasksCannotReserveMarker() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        XCTAssertThrowsError(try journal.reserveVerifiedPreview(
            try preview(), nowSeconds: 2_000_000_060
        )) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .invalidPreview)
        }
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 0
        )
    }

    func testUnsafeDirectoryAndChangedPermissionsFailClosed() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        XCTAssertEqual(chmod(directory.path, 0o755), 0)
        XCTAssertThrowsError(try journal.reserveVerifiedPreview(
            try preview(), nowSeconds: now
        )) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .unavailable)
        }
        XCTAssertThrowsError(try AgentLoopLocalReplayJournal(
            directory: directory, key: key
        ))
    }

    func testKeyRotationCannotReopenAlreadyRecordedTask() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let verified = try preview()
        let original = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        try original.reserveVerifiedPreview(verified, nowSeconds: now)
        // A second 32-byte local key must not silently start a new ledger.
        let rotated = try AgentLoopLocalReplayJournal(
            directory: directory,
            key: Data((32..<64).map(UInt8.init))
        )
        XCTAssertThrowsError(
            try rotated.reserveVerifiedPreview(verified, nowSeconds: now)
        ) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .unavailable)
        }
    }

    func testMissingBindingCannotReopenEarlierTask() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        let signed = try preview()
        try journal.reserveVerifiedPreview(signed, nowSeconds: now)
        let names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        let bound = try XCTUnwrap(names.first { $0.hasPrefix(".key.") })
        try FileManager.default.removeItem(
            at: directory.appendingPathComponent(bound)
        )
        XCTAssertThrowsError(
            try journal.reserveVerifiedPreview(signed, nowSeconds: now)
        ) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .unavailable)
        }
    }

    func testInvalidKeyAndSymlinkDirectoryAreRejected() throws {
        let directory = try createDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try AgentLoopLocalReplayJournal(
            directory: directory, key: Data(repeating: 0, count: 32)
        ))
        let link = directory.deletingLastPathComponent()
            .appendingPathComponent("igentic-link-" + UUID().uuidString)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: directory)
        defer { try? FileManager.default.removeItem(at: link) }
        XCTAssertThrowsError(try AgentLoopLocalReplayJournal(directory: link, key: key))
    }
}
#endif
