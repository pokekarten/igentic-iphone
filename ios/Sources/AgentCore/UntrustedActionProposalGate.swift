import Foundation

/// Model output is untrusted text, never an authorization credential.
/// This contract intentionally has no callable tool, execution or approval APIs.
public struct UntrustedActionProposal: Equatable, Sendable {
    public let actionName: String
    public let proposedText: String

    public init(actionName: String, proposedText: String = "") {
        self.actionName = actionName
        self.proposedText = proposedText
    }
}

public enum UntrustedActionProposalDisposition: Equatable, Sendable {
    case previewOnly
    case approvalRequired
    case blocked
}

public enum UntrustedActionProposalReason: String, Equatable, Sendable {
    case unknownAction
    case malformedPayload
    case sensitivePayload
    case policyDenied
    case policyRequiresApproval
    case safeReadOnlyPreview
}

public struct UntrustedActionProposalReview: Equatable, Sendable {
    public let disposition: UntrustedActionProposalDisposition
    public let reason: UntrustedActionProposalReason

    public init(disposition: UntrustedActionProposalDisposition, reason: UntrustedActionProposalReason) {
        self.disposition = disposition
        self.reason = reason
    }
}

/// Pure, fail-closed review boundary between a future local model and
/// AgentCore's real action/approval system. No proposed text is echoed or logged.
///
/// Do not use `previewOnly` as permission to execute a real read or write.
/// The actual user-triggered operation must still pass the existing AgentKernel
/// and, for writes, an explicit user-bound ApprovalReceipt.
public struct UntrustedActionProposalGate: Sendable {
    private let policyEngine: PolicyEngine

    public init(policyEngine: PolicyEngine = PolicyEngine()) {
        self.policyEngine = policyEngine
    }

    public func review(
        _ proposal: UntrustedActionProposal,
        privacyMode: PrivacyMode,
        trustedDataClassification: DataClassification
    ) -> UntrustedActionProposalReview {
        let action = proposal.actionName
        let text = proposal.proposedText

        // Exact allowlist; never match substrings, aliases or injected prompt text.
        guard action == "diagnostics.read" || action == "reminder.create" else {
            return .init(disposition: .blocked, reason: .unknownAction)
        }

        // Only an empty payload is meaningful for a static diagnostics read.
        // For reminder previews, bound payload size, and reject all whitespace.
        guard text.utf8.count <= 512,
              (action == "diagnostics.read" ? text.isEmpty : !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        else {
            return .init(disposition: .blocked, reason: .malformedPayload)
        }

        let detection = SensitiveDataDetector().detect(in: text)
        // We cannot infer all types of sensitive personal data from model text.
        // Conservative rule: any detected pattern prevents automatic preview.
        guard !detection.hasFindings else {
            return .init(disposition: .blocked, reason: .sensitivePayload)
        }

        let classification = DataClassification.effectiveClassification(
            baseClassification: trustedDataClassification,
            detectorResult: detection
        )
        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: classification,
                actionRisk: action == "diagnostics.read" ? .read : .execute,
                requestedDelegationTarget: .localDevice,
                sensitiveDataFindings: detection.findings
            )
        )
        guard decision.isAllowed else {
            return .init(disposition: .blocked, reason: .policyDenied)
        }

        // All writes remain proposals only. The model cannot supply approval.
        if decision.requiresApproval || action == "reminder.create" {
            return .init(disposition: .approvalRequired, reason: .policyRequiresApproval)
        }

        return .init(disposition: .previewOnly, reason: .safeReadOnlyPreview)
    }
}
