import Foundation

public struct DelegationRequest: Equatable, Sendable {
    public let privacyMode: PrivacyMode
    public let target: DelegationTarget
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk
    public let reason: String

    public init(
        privacyMode: PrivacyMode,
        target: DelegationTarget,
        dataClassification: DataClassification = .publicDefault,
        actionRisk: ActionRisk = .prepare,
        reason: String = "metadata-only delegation decision"
    ) {
        self.privacyMode = privacyMode
        self.target = target
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
        self.reason = reason
    }
}

public enum DelegationDecision: Equatable, Sendable {
    case blocked(reason: String)
    case requiresApproval(reason: String)
    case allowedMetadataOnly(reason: String)

    public var isAllowed: Bool {
        switch self {
        case .allowedMetadataOnly:
            return true
        case .blocked, .requiresApproval:
            return false
        }
    }

    public var requiresExplicitApproval: Bool {
        switch self {
        case .requiresApproval:
            return true
        case .blocked, .allowedMetadataOnly:
            return false
        }
    }
}

/// Diagnostics/scenario-only delegation broker.
///
/// `ScenarioRunner` uses this to surface a metadata-only delegation decision
/// alongside live kernel behavior for smoke tests and reports.
/// It is intentionally not part of the live authorization path; `AgentKernel`
/// continues to route through `PolicyEngine` and `ApprovalManager`.
public struct DelegationBroker: Sendable {
    public init() {}

    public func decide(_ request: DelegationRequest) -> DelegationDecision {
        // Keep the same precedence as PolicyEngine so diagnostics and live
        // policy report the same blocking reason for the same request.
        if request.dataClassification.level.blocksAutomaticExternalDelegation,
           request.target != .none,
           request.target != .localDevice {
            return .blocked(reason: "Restricted sensitive data cannot be delegated automatically.")
        }

        if request.privacyMode == .localOnly,
           request.target != .none,
           request.target != .localDevice {
            return .blocked(reason: "Local Only blocks non-local delegation.")
        }

        if request.target == .externalProvider {
            return .requiresApproval(reason: "External provider delegation requires explicit approval.")
        }

        if request.dataClassification.level.requiresExplicitApproval {
            return .requiresApproval(reason: "Highly private data requires explicit approval.")
        }

        if request.actionRisk.requiresApproval {
            return .requiresApproval(reason: "Action risk requires explicit approval.")
        }

        return .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision.")
    }
}