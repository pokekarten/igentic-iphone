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
        case privacyDenied, alreadyAttempted, enrollmentChanged, reviewUnavailable, proofUnavailable
    }

    private let vault: AgentLoopDeviceEnrollmentVault
    private let currentPrivacyMode: @MainActor () -> PrivacyMode
    private let transport: @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?
    private var attempted = false
    private typealias Review = (gate: AgentLoopSignedOwnerStatusGate,
                                enrollment: AgentLoopDeviceEnrollment, port: Int, requestID: String)
    private let upload: @Sendable (Int, Data, Data, String) async throws -> Void
    private var pendingReview: Review?
    private var completedReview: Review?

    init(vault: AgentLoopDeviceEnrollmentVault,
         currentPrivacyMode: @escaping @MainActor () -> PrivacyMode,
         upload: @escaping @Sendable (Int, Data, Data, String) async throws -> Void = { _, _, _, _ in
             throw AgentLoopRelayClaimError.invalidConfiguration
         },
         transport: @escaping @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?) {
        self.upload = upload
        self.vault = vault
        self.currentPrivacyMode = currentPrivacyMode
        self.transport = transport
    }

    convenience init(vault: AgentLoopDeviceEnrollmentVault,
                     currentPrivacyMode: @escaping @MainActor () -> PrivacyMode) {
        let client = AgentLoopRelayClaimClient()
        self.init(vault: vault, currentPrivacyMode: currentPrivacyMode, upload: { port, device, proof, id in
            try await client.submitReceipt(port: port, deviceAccessKey: device, proof: proof, requestID: id)
        }) { port, device, proposal in
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
            pendingReview = (gate, claimed.enrollment, port, claim.requestID)
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
        guard pending.gate.snapshot().stage == .awaitingOwnerReview else {
            throw Failure.reviewUnavailable
        }
        let result = pending.gate.readAfterLocalReviewAction()
        try checkEnrollment(pending.enrollment)
        if result.stage == .locallyRead {
            completedReview = pending
        }
        return result
    }

    /// A third, separate native owner action prepares the fixed key-holder
    /// acknowledgement. Never returns status text and never sends it here.
    /// Consume this opportunity even if policy, enrollment or signing fails.
    func prepareProofAfterSeparateLocalShareAction() throws -> Data {
        try consumeReviewedProof().proof
    }

    /// The explicit sharing action consumes signing and sending together.
    /// An ambiguous HTTP outcome is never a reason to resend or reread.
    /// Return only the request correlation, not the raw proof or status.
    func submitProofAfterSeparateLocalShareAction() async throws -> String {
        let prepared = try consumeReviewedProof()
        try checkEnrollment(prepared.review.enrollment)
        try await upload(prepared.review.port, prepared.review.enrollment.deviceAccessKey,
                         prepared.proof, prepared.review.requestID)
        try checkEnrollment(prepared.review.enrollment)
        return prepared.review.requestID
    }

    private func consumeReviewedProof() throws -> (proof: Data, review: Review) {
        guard let completed = completedReview else { throw Failure.proofUnavailable }
        completedReview = nil
        try checkEnrollment(completed.enrollment)
        guard let proof = completed.gate.prepareReadOnlyKeyProofAfterSeparateLocalReview(
            receiptKey: completed.enrollment.receiptKey, currentPrivacyMode: currentPrivacyMode()
        ) else { throw Failure.proofUnavailable }
        try checkEnrollment(completed.enrollment)
        return (proof, completed)
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
