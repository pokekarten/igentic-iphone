import AgentCore
import Foundation
import XCTest
@testable import iGenticApp

#if canImport(Security) && canImport(Darwin)
import Darwin

private final class FakeReplayKeyBackend: AgentLoopReplayKeyBackend {
    var secret: Data?
    var reads = 0
    var writes = 0
    var failRead = false
    var failWrite = false

    func load() throws -> Data? {
        reads += 1
        if failRead { throw AgentLoopReplayKeyVaultError.unavailable }
        return secret
    }
    func createOnce(_ key: Data) throws -> Bool {
        writes += 1
        if failWrite { throw AgentLoopReplayKeyVaultError.unavailable }
        guard secret == nil else { return false }
        secret = key
        return true
    }
}

final class AgentLoopReplayKeyVaultTests: XCTestCase {
    private let sample = Data((0..<32).map(UInt8.init))

    private func privateDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("igentic-replay-enroll-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        return url
    }

    func testNoImplicitEnrollmentOrKeyGenerationOnNormalLoad() {
        let backend = FakeReplayKeyBackend()
        XCTAssertThrowsError(try AgentLoopReplayKeyEnrollment.loadExisting(backend: backend)) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .notEnrolled)
        }
        XCTAssertEqual(backend.writes, 0)
    }

    func testExplicitEnrollmentCreatesOnceAndPersistsAcrossInstances() throws {
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = FakeReplayKeyBackend()
        var generations = 0
        let saved = try AgentLoopReplayKeyEnrollment.enrollExplicitly(
            directory: dir, backend: backend
        ) {
            generations += 1
            return self.sample
        }
        XCTAssertEqual(saved, sample)
        XCTAssertEqual(generations, 1)
        XCTAssertEqual(backend.writes, 1)
        XCTAssertEqual(
            try AgentLoopReplayKeyEnrollment.loadExisting(backend: backend),
            sample
        )
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { XCTFail("Do not regenerate"); return self.sample }
        ) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .alreadyEnrolled)
        }
        XCTAssertEqual(backend.writes, 1)
    }

    func testOpenExistingJournalUsesEnrolledKeyAndBlocksReplayOnRestart() throws {
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = FakeReplayKeyBackend()
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.openExistingJournal(
                directory: dir, backend: backend
            )
        ) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .notEnrolled)
        }
        XCTAssertEqual(backend.writes, 0)
        _ = try AgentLoopReplayKeyEnrollment.enrollExplicitly(
            directory: dir, backend: backend
        ) { sample }
        let journal = try AgentLoopReplayKeyEnrollment.openExistingJournal(
            directory: dir, backend: backend
        )
        let wire = Data(#"{"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}"#.utf8)
        let outcome = try journal.inspectPolicyAndReserveForOwnerReview(
            wire,
            relayKey: sample,
            nowSeconds: 2_000_000_000,
            privacyMode: .externalAI,
            statusClassification: .publicDefault
        )
        guard case .requiresLocalOwnerReview = outcome else {
            return XCTFail("A signed read-only task still requires owner review")
        }
        XCTAssertFalse(outcome.actionExecuted)
        XCTAssertFalse(outcome.ownerApproved)
        XCTAssertEqual(backend.writes, 1)
        let restarted = try AgentLoopReplayKeyEnrollment.openExistingJournal(
            directory: dir, backend: backend
        )
        XCTAssertThrowsError(
            try restarted.inspectPolicyAndReserveForOwnerReview(
                wire,
                relayKey: sample,
                nowSeconds: 2_000_000_000,
                privacyMode: .externalAI,
                statusClassification: .publicDefault
            )
        ) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .alreadyRecorded)
        }
        XCTAssertEqual(backend.writes, 1)
    }

    func testLossOfKeyDoesNotReenrollOverExistingReplayMarker() throws {
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data().write(to: dir.appendingPathComponent(".key.prior"))
        let backend = FakeReplayKeyBackend()
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { XCTFail("No replacement key"); return sample }
        ) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .unsafeDirectory)
        }
        XCTAssertEqual(backend.writes, 0)
    }

    func testUnsafePermissionsAndSymlinkDirectoryFailClosed() throws {
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = FakeReplayKeyBackend()
        XCTAssertEqual(chmod(dir.path, 0o755), 0)
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { XCTFail("Must not generate"); return sample }
        )
        XCTAssertEqual(chmod(dir.path, 0o700), 0)
        let link = dir.deletingLastPathComponent()
            .appendingPathComponent("igentic-replay-link-" + UUID().uuidString)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: dir)
        defer { try? FileManager.default.removeItem(at: link) }
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: link, backend: backend
            ) { XCTFail("Must not generate"); return sample }
        )
        XCTAssertEqual(backend.writes, 0)
    }

    func testCorruptExistingKeyAndStorageFailuresCannotFallback() throws {
        let backend = FakeReplayKeyBackend()
        backend.secret = Data(repeating: 0, count: 32)
        XCTAssertThrowsError(try AgentLoopReplayKeyEnrollment.loadExisting(backend: backend)) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .unavailable)
        }
        backend.secret = nil
        backend.failRead = true
        XCTAssertThrowsError(try AgentLoopReplayKeyEnrollment.loadExisting(backend: backend)) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .unavailable)
        }
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { XCTFail("Do not generate when Keychain fails"); return sample }
        )
        backend.failRead = false
        backend.failWrite = true
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { sample }
        ) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .unavailable)
        }
        XCTAssertNil(backend.secret)
    }

    func testInvalidGeneratedKeyAndConcurrentDuplicateDoNotRotate() throws {
        let dir = try privateDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let backend = FakeReplayKeyBackend()
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) { Data(repeating: 0, count: 32) }
        )
        XCTAssertEqual(backend.writes, 0)
        let winning = sample
        XCTAssertThrowsError(
            try AgentLoopReplayKeyEnrollment.enrollExplicitly(
                directory: dir, backend: backend
            ) {
                // Simulate another enrollment winning between initial read
                // and the exclusive atomic create.
                backend.secret = winning
                return Data((32..<64).map(UInt8.init))
            }
        ) {
            XCTAssertEqual($0 as? AgentLoopReplayKeyVaultError, .alreadyEnrolled)
        }
        XCTAssertEqual(backend.secret, winning)
    }
}
#endif
