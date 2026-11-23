import AgentCore
import Foundation
import XCTest
@testable import iGenticApp

#if canImport(CryptoKit) && canImport(Darwin)
/// Existing synthetic Node fixture only. No production owner key, iPhone or
/// device identity is involved in these regression tests.
private let signedTaskFixture = """
{"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}
"""
private func signedTaskKey() -> Data {
    Data((0..<32).map(UInt8.init))
}
private func syntheticSignedStatus() -> AgentLoopLocalStatus {
    AgentLoopLocalStatus(batteryFraction: 0.64, lowPowerModeEnabled: true, osVersion: "27.2")
}
private func newPrivateReplayDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("igentic-owner-status-\(UUID().uuidString)")
    try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    return url
}

final class AgentLoopSignedOwnerStatusGateTests: XCTestCase {
    func testVerifiedAndReservedTaskCannotReadUntilSeparateLocalReviewAction() async throws {
        try await MainActor.run {
            let dir = try newPrivateReplayDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let journal = try AgentLoopLocalReplayJournal(directory: dir, key: signedTaskKey())
            var reads = 0
            let gate = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { 2_000_000_000 },
                statusReader: { reads += 1; return syntheticSignedStatus() }
            )
            XCTAssertEqual(gate.readAfterLocalReviewAction().stage, .empty)
            let preview = gate.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            )
            XCTAssertEqual(preview.stage, .awaitingOwnerReview)
            XCTAssertEqual(preview.requestID, "11111111-2222-4333-8444-555555555555")
            XCTAssertEqual(reads, 0)
            XCTAssertFalse(preview.localReadCompleted)
            XCTAssertFalse(preview.externalDataShared)
            XCTAssertFalse(preview.ownerConsentAttested)
            XCTAssertFalse(preview.remoteActionExecuted)
            XCTAssertEqual(preview.independentDeviceReceipt, "none")
            XCTAssertNil(preview.ownerAppObservation)

            let read = gate.readAfterLocalReviewAction()
            XCTAssertEqual(read.stage, .locallyRead)
            XCTAssertEqual(read.requestID, "11111111-2222-4333-8444-555555555555")
            XCTAssertTrue(read.localReadCompleted)
            XCTAssertTrue(read.ownerAppObservation?.contains("64 %") == true)
            XCTAssertFalse(read.externalDataShared)
            XCTAssertFalse(read.ownerConsentAttested)
            XCTAssertFalse(read.remoteActionExecuted)
            XCTAssertEqual(read.independentDeviceReceipt, "none")
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(gate.readAfterLocalReviewAction(), read)
            XCTAssertEqual(reads, 1)

            // Fresh processes cannot re-admit the same signed task/ID after
            // this local reservation; even with a valid HMAC.
            let replayGate = AgentLoopSignedOwnerStatusGate(
                replayJournal: try AgentLoopLocalReplayJournal(
                    directory: dir, key: signedTaskKey()
                ), clockSeconds: { 2_000_000_001 },
                statusReader: { reads += 1; return syntheticSignedStatus() }
            )
            XCTAssertEqual(replayGate.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            ).stage, .denied)
            XCTAssertEqual(replayGate.readAfterLocalReviewAction().stage, .denied)
            XCTAssertEqual(reads, 1)
        }
    }

    func testLocalOnlyPolicyDeniedWithoutConsumingReplayMarker() async throws {
        try await MainActor.run {
            let dir = try newPrivateReplayDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let journal = try AgentLoopLocalReplayJournal(directory: dir, key: signedTaskKey())
            var reads = 0
            let denied = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { 2_000_000_000 },
                statusReader: { reads += 1; return syntheticSignedStatus() }
            )
            let first = denied.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .localOnly, statusClassification: .publicDefault
            )
            XCTAssertEqual(first.stage, .denied)
            XCTAssertEqual(reads, 0)
            XCTAssertNil(first.ownerAppObservation)
            XCTAssertEqual(
                try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 0
            )
            let permittedReview = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { 2_000_000_000 },
                statusReader: { reads += 1; return syntheticSignedStatus() }
            )
            XCTAssertEqual(permittedReview.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            ).stage, .awaitingOwnerReview)
            XCTAssertEqual(reads, 0)
        }
    }

    func testTamperedOrUnknownToolCannotReserveOrRead() async throws {
        try await MainActor.run {
            for input in [
                signedTaskFixture.replacingOccurrences(
                    of: "igentic.own_app.status.read", with: "reminder.create"
                ),
                signedTaskFixture.replacingOccurrences(
                    of: "\"parameters\":{}", with: "\"parameters\":{\"text\":\"secret\"}"
                ),
                signedTaskFixture.replacingOccurrences(
                    of: "\"signature\":\"", with: "\"signature\":\"0"
                ),
                signedTaskFixture + " trailing"
            ] {
                let dir = try newPrivateReplayDirectory()
                defer { try? FileManager.default.removeItem(at: dir) }
                let journal = try AgentLoopLocalReplayJournal(
                    directory: dir, key: signedTaskKey()
                )
                var reads = 0
                let gate = AgentLoopSignedOwnerStatusGate(
                    replayJournal: journal, clockSeconds: { 2_000_000_000 },
                    statusReader: { reads += 1; return syntheticSignedStatus() }
                )
                XCTAssertEqual(gate.stageSignedTaskForOwnerReview(
                    Data(input.utf8), relayKey: signedTaskKey(),
                    privacyMode: .externalAI, statusClassification: .publicDefault
                ).stage, .denied)
                XCTAssertEqual(gate.readAfterLocalReviewAction().stage, .denied)
                XCTAssertEqual(reads, 0)
                XCTAssertNil(gate.snapshot().ownerAppObservation)
            }
        }
    }

    func testDeadlineBeforeLocalReadExpiresWithoutReading() async throws {
        try await MainActor.run {
            let dir = try newPrivateReplayDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let journal = try AgentLoopLocalReplayJournal(directory: dir, key: signedTaskKey())
            var time = 2_000_000_000
            var reads = 0
            let gate = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { time },
                statusReader: { reads += 1; return syntheticSignedStatus() }
            )
            XCTAssertEqual(gate.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            ).stage, .awaitingOwnerReview)
            time = 2_000_000_060
            XCTAssertEqual(gate.snapshot().stage, .expired)
            XCTAssertEqual(gate.snapshot().requestID, "11111111-2222-4333-8444-555555555555")
            XCTAssertEqual(gate.readAfterLocalReviewAction().stage, .expired)
            XCTAssertEqual(reads, 0)
        }
    }

    func testSlowReadExpiredAfterCallbackNeverReleasesStaleObservation() async throws {
        try await MainActor.run {
            let dir = try newPrivateReplayDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let journal = try AgentLoopLocalReplayJournal(directory: dir, key: signedTaskKey())
            var time = 2_000_000_000
            var reads = 0
            let gate = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { time },
                statusReader: {
                    reads += 1
                    time += 61
                    return syntheticSignedStatus()
                }
            )
            XCTAssertEqual(gate.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            ).stage, .awaitingOwnerReview)
            let result = gate.readAfterLocalReviewAction()
            XCTAssertEqual(result.stage, .expired)
            XCTAssertEqual(reads, 1)
            XCTAssertNil(result.ownerAppObservation)
            XCTAssertFalse(result.localReadCompleted)
            XCTAssertFalse(result.externalDataShared)
        }
    }

    func testSynchronousReaderReentrancyCannotCauseSecondRead() async throws {
        try await MainActor.run {
            let dir = try newPrivateReplayDirectory()
            defer { try? FileManager.default.removeItem(at: dir) }
            let journal = try AgentLoopLocalReplayJournal(directory: dir, key: signedTaskKey())
            var reads = 0
            var nestedStage: AgentLoopSignedStatusGateStage?
            var instance: AgentLoopSignedOwnerStatusGate?
            let gate = AgentLoopSignedOwnerStatusGate(
                replayJournal: journal, clockSeconds: { 2_000_000_000 },
                statusReader: {
                    reads += 1
                    nestedStage = instance?.readAfterLocalReviewAction().stage
                    return syntheticSignedStatus()
                }
            )
            instance = gate
            XCTAssertEqual(gate.stageSignedTaskForOwnerReview(
                Data(signedTaskFixture.utf8), relayKey: signedTaskKey(),
                privacyMode: .externalAI, statusClassification: .publicDefault
            ).stage, .awaitingOwnerReview)
            let result = gate.readAfterLocalReviewAction()
            // A nested action is an attempted second invocation. Fail the
            // entire first read rather than returning a success receipt.
            XCTAssertEqual(result.stage, .denied)
            XCTAssertEqual(nestedStage, .denied)
            XCTAssertNil(result.ownerAppObservation)
            XCTAssertFalse(result.localReadCompleted)
            XCTAssertFalse(result.remoteActionExecuted)
            XCTAssertFalse(result.ownerConsentAttested)
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(gate.readAfterLocalReviewAction().stage, .denied)
            XCTAssertEqual(reads, 1)
        }
    }
}
#endif
