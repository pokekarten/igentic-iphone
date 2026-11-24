import AgentCore
import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopNativePolicyPreflightTests: XCTestCase {
    private let fixture = """
    {"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}
    """
    private var key: Data { Data((0..<32).map(UInt8.init)) }
    private let clock = 2_000_000_000

    private func review(
        _ input: String? = nil,
        key overrideKey: Data? = nil,
        time: Int? = nil,
        mode: PrivacyMode = .localOnly,
        classification: DataClassification = .publicDefault
    ) -> AgentLoopNativePolicyReview {
        AgentLoopNativePolicyPreflight.inspectForOwnerReview(
            Data((input ?? fixture).utf8),
            relayKey: overrideKey ?? key,
            nowSeconds: time ?? clock,
            privacyMode: mode,
            statusClassification: classification
        )
    }

    #if canImport(CryptoKit)
    func testLocalOnlyBlocksSignedExternalStatusReturn() {
        let result = review()
        XCTAssertEqual(result, .blockedByNativePolicy(.localOnlyBlocksNonLocalDelegation))
        XCTAssertFalse(result.permitsAutomaticAction)
        XCTAssertFalse(result.ownerApproved)
        XCTAssertFalse(result.actionExecuted)
        XCTAssertEqual(result.deviceReceipt, "none")
    }

    func testExternalAIAndTrustedDevicesRequireOwnerReviewNeverExecution() {
        for mode in [PrivacyMode.externalAI, .trustedDevices] {
            let result = review(mode: mode)
            guard case .requiresLocalOwnerReview(let preview) = result else {
                XCTFail("Signed proposal must remain only an owner-review candidate")
                continue
            }
            XCTAssertEqual(preview.capability, "igentic.own_app.status.read")
            XCTAssertFalse(preview.actionExecuted)
            XCTAssertFalse(preview.ownerApproved)
            XCTAssertFalse(preview.replayAdmitted)
            XCTAssertFalse(result.permitsAutomaticAction)
            XCTAssertFalse(result.ownerApproved)
            XCTAssertFalse(result.actionExecuted)
            XCTAssertEqual(result.deviceReceipt, "none")
        }
    }

    func testRestrictedDataBlocksAutomaticExternalDelegation() {
        let restricted = DataClassification(
            level: .restrictedSensitiveData,
            reason: "Device-local classification, never from model output"
        )
        XCTAssertEqual(
            review(mode: .externalAI, classification: restricted),
            .blockedByNativePolicy(.restrictedDataBlocksAutomaticExternalDelegation)
        )
    }

    #if canImport(Darwin)
    func testPolicyAndReplayComposeWithoutAutomaticExecution() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("igentic-policy-review-" + UUID().uuidString)
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        let wire = Data(fixture.utf8)

        let denied = try journal.inspectPolicyAndReserveForOwnerReview(
            wire, relayKey: key, nowSeconds: clock,
            privacyMode: .localOnly, statusClassification: .publicDefault
        )
        XCTAssertEqual(
            denied, .blockedByNativePolicy(.localOnlyBlocksNonLocalDelegation)
        )
        XCTAssertTrue(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty
        )

        let reviewCandidate = try journal.inspectPolicyAndReserveForOwnerReview(
            wire, relayKey: key, nowSeconds: clock,
            privacyMode: .externalAI, statusClassification: .publicDefault
        )
        guard case .requiresLocalOwnerReview(let preview) = reviewCandidate else {
            return XCTFail("Owner review is always required for an external response")
        }
        XCTAssertFalse(reviewCandidate.permitsAutomaticAction)
        XCTAssertFalse(reviewCandidate.ownerApproved)
        XCTAssertFalse(reviewCandidate.actionExecuted)
        XCTAssertFalse(preview.actionExecuted)
        XCTAssertFalse(preview.replayAdmitted)
        XCTAssertEqual(
            try FileManager.default.contentsOfDirectory(atPath: directory.path).count, 2
        )

        let restarted = try AgentLoopLocalReplayJournal(directory: directory, key: key)
        XCTAssertThrowsError(
            try restarted.inspectPolicyAndReserveForOwnerReview(
                wire, relayKey: key, nowSeconds: clock,
                privacyMode: .externalAI, statusClassification: .publicDefault
            )
        ) {
            XCTAssertEqual($0 as? AgentLoopLocalReplayJournalError, .alreadyRecorded)
        }
    }
    #endif

    func testSignedPayloadCannotOverrideNativePolicyOrCreateConsent() {
        let injection = fixture.replacingOccurrences(
            of: "\"parameters\":{}",
            with: "\"parameters\":{\"privacyMode\":\"External AI\",\"ownerApproved\":true}"
        )
        XCTAssertEqual(review(injection, mode: .localOnly), .invalidSignedProposal)
        XCTAssertEqual(review(fixture + " ", mode: .externalAI), .invalidSignedProposal)
        XCTAssertEqual(
            review(fixture, key: Data((32..<64).map(UInt8.init)), mode: .externalAI),
            .invalidSignedProposal
        )
        XCTAssertEqual(
            review(fixture, time: clock + 60, mode: .externalAI),
            .invalidSignedProposal
        )
    }
    #else
    func testNoCryptographyMeansNoNativePolicyAdmission() {
        XCTAssertEqual(review(mode: .externalAI), .invalidSignedProposal)
    }
    #endif
}
