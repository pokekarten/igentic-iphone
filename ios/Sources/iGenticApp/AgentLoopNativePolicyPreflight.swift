import AgentCore
import Foundation

/// Offline policy verdict for a signed read-only relay proposal.
/// A cryptographic signature establishes origin, not consent to disclose data.
public enum AgentLoopNativePolicyReview: Equatable, Sendable {
    case invalidSignedProposal
    case blockedByNativePolicy(PolicyDecisionReason)
    case requiresLocalOwnerReview(AgentLoopRemoteTaskPreview)

    public var permitsAutomaticAction: Bool { false }
    public var ownerApproved: Bool { false }
    public var actionExecuted: Bool { false }
    public var deviceReceipt: String { "none" }
}

/// Pure preflight, with no network, file I/O or device operations.
/// privacyMode and statusClassification must come from native owner-controlled
/// device state, NEVER from task contents, remote JSON or a model response.
/// It does not consume a replay marker if the owner subsequently denies it.
public enum AgentLoopNativePolicyPreflight {
    public static func inspectForOwnerReview(
        _ canonicalWire: Data,
        relayKey: Data,
        nowSeconds: Int,
        privacyMode: PrivacyMode,
        statusClassification: DataClassification
    ) -> AgentLoopNativePolicyReview {
        guard let preview = AgentLoopRemoteTaskVerifier.inspectCanonicalProposal(
            canonicalWire, relayKey: relayKey, nowSeconds: nowSeconds
        ) else {
            return .invalidSignedProposal
        }

        // A response to a remote task shares local iGentic status externally;
        // do not grant the reply using only local read permission.
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: statusClassification,
                actionRisk: .externalShare,
                requestedDelegationTarget: .externalProvider
            )
        )
        guard decision.isAllowed else {
            return .blockedByNativePolicy(decision.reasonCode)
        }
        // Any future policy relaxation is a block, not auto-consent.
        guard decision.requiresApproval else {
            return .blockedByNativePolicy(.unspecified)
        }
        return .requiresLocalOwnerReview(preview)
    }
}
