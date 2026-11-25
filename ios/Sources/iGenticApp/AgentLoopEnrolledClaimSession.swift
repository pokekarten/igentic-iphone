import Foundation
#if canImport(Security) && canImport(Darwin)
import AgentCore

/// One explicit foreground claim attempt, bound to the current local
/// enrollment. No automatic enrollment, polling, execution or receipt send.
/// A separate explicit local review action may perform one bounded status read.
/// The transport is still loopback-only; this is not a remote device service.
@MainActor
final class AgentLoopEnrolledClaimSession {
    enum Failure: Error, Equatable {
        case privacyDenied, alreadyAttempted, enrollmentChanged, reviewUnavailable
    }

    private let vault: AgentLoopDeviceEnrollmentVault
    private let currentPrivacyMode: @MainActor () -> PrivacyMode
    private let transport: @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?
    private var attempted = false
    private var pendingReview: (gate: AgentLoopSignedOwnerStatusGate, enrollment: AgentLoopDeviceEnrollment)?

    init(vault: AgentLoopDeviceEnrollmentVault,
         currentPrivacyMode: @escaping @MainActor () -> PrivacyMode,
         transport: @escaping @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?) {
        self.vault = vault
        self.currentPrivacyMode = currentPrivacyMode
        self.transport = transport
    }

    convenience init(vault: AgentLoopDeviceEnrollmentVault,
                     currentPrivacyMode: @escaping @MainActor () -> PrivacyMode) {
        let client = AgentLoopRelayClaimClient()
        self.init(vault: vault, currentPrivacyMode: currentPrivacyMode) { port, device, proposal in
            try await client.claim(port: port, deviceAccessKey: device, proposalKey: proposal)
        }
    }

    /// Called only after an explicit native owner action. The policy and
    /// enrollment are checked both before and after the asynchronous I/O.
    /// An ambiguous transport attempt consumes this session even on failure.
    func claimAfterLocalAction(port: Int) async throws -> AgentLoopRelayClaim? {
        try await claimWithEnrollment(port: port).claim
    }

    private func claimWithEnrollment(port: Int) async throws
        -> (claim: AgentLoopRelayClaim?, enrollment: AgentLoopDeviceEnrollment) {
        guard !attempted else { throw Failure.alreadyAttempted }
        guard currentPrivacyMode() == .externalAI else { throw Failure.privacyDenied }
        let enrollment = try vault.loadExisting()
        guard (1...65535).contains(port) else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        attempted = true
        try Task.checkCancellation()
        let result = try await transport(port, enrollment.deviceAccessKey, enrollment.proposalKey)
        try Task.checkCancellation()
        guard currentPrivacyMode() == .externalAI else { throw Failure.privacyDenied }
        guard let current = try? vault.loadExisting(), current == enrollment else {
            throw Failure.enrollmentChanged
        }
        // Only the signed claim preview is returned. The existing native
        // owner gate must separately check policy and reserve replay state.
        return (result, enrollment)
    }

    /// Claim and stage only; caller must create a fresh gate with a durable
    /// replay journal. No local observation is produced by this transition.
    func stageClaimAfterLocalAction(port: Int, gate: AgentLoopSignedOwnerStatusGate)
        async throws -> AgentLoopSignedStatusGateReceipt? {
        guard gate.snapshot().stage == .empty else { throw Failure.reviewUnavailable }
        let claimed = try await claimWithEnrollment(port: port)
        guard let claim = claimed.claim else { return nil }
        try checkEnrollment(claimed.enrollment)
        guard gate.snapshot().stage == .empty else { throw Failure.reviewUnavailable }
        let review = gate.stageRelayClaimForOwnerReview(claim,
            relayKey: claimed.enrollment.proposalKey, privacyMode: currentPrivacyMode(),
            statusClassification: DataClassification(level: .contextualPrivateData,
                reason: "Bounded owner-app status; no external observation sharing."))
        if review.stage == .awaitingOwnerReview {
            pendingReview = (gate, claimed.enrollment)
        }
        return review
    }

    /// Only a separate native foreground owner action may call this.
    /// Consume the review before any read, and recheck mode/enrollment.
    /// A denied or uncertain action is never retried by this session.
    func readAfterSeparateLocalReviewAction() throws -> AgentLoopSignedStatusGateReceipt {
        guard let pending = pendingReview else { throw Failure.reviewUnavailable }
        pendingReview = nil
        try checkEnrollment(pending.enrollment)
        let result = pending.gate.readAfterLocalReviewAction()
        try checkEnrollment(pending.enrollment)
        return result
    }

    private func checkEnrollment(_ expected: AgentLoopDeviceEnrollment) throws {
        try Task.checkCancellation()
        guard currentPrivacyMode() == .externalAI else { throw Failure.privacyDenied }
        guard let current = try? vault.loadExisting(), current == expected else {
            throw Failure.enrollmentChanged
        }
    }
}
#endif
