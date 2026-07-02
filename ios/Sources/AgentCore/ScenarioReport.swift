import Foundation

public enum ScenarioRouteKind: String, Equatable, Sendable {
    case clarification
    case approvalRequired
    case localTool
    case blocked
}

public enum ScenarioDelegationKind: String, Equatable, Sendable {
    case blocked
    case approvalRequired
    case allowedMetadataOnly
}

public struct ScenarioReportEntry: Equatable, Sendable {
    public let scenarioID: String
    public let route: ScenarioRouteKind
    public let policyAllowed: Bool
    public let policyRequiresApproval: Bool
    public let approvalStatus: ApprovalStatus
    public let delegation: ScenarioDelegationKind

    public init(
        scenarioID: String,
        route: ScenarioRouteKind,
        policyAllowed: Bool,
        policyRequiresApproval: Bool,
        approvalStatus: ApprovalStatus,
        delegation: ScenarioDelegationKind
    ) {
        self.scenarioID = scenarioID
        self.route = route
        self.policyAllowed = policyAllowed
        self.policyRequiresApproval = policyRequiresApproval
        self.approvalStatus = approvalStatus
        self.delegation = delegation
    }
}

public struct ScenarioReport: Equatable, Sendable {
    public let entries: [ScenarioReportEntry]

    public init(results: [DiagnosticScenarioResult]) {
        self.entries = results.map { ScenarioReportEntry(result: $0) }
    }

    public var textSummary: String {
        // This is a derived, display-only summary built from the structured
        // scenario result fields above. It is intentionally not a separate source
        // of truth.
        entries
            .map {
                "\($0.scenarioID): route=\($0.route.rawValue), policyAllowed=\($0.policyAllowed), policyApproval=\($0.policyRequiresApproval), approval=\($0.approvalStatus.rawValue), delegation=\($0.delegation.rawValue)"
            }
            .joined(separator: "\n")
    }
}

public extension ScenarioReportEntry {
    init(result: DiagnosticScenarioResult) {
        self.init(
            scenarioID: result.scenarioID,
            route: Self.routeKind(for: result.route),
            policyAllowed: result.policyDecision.isAllowed,
            policyRequiresApproval: result.policyDecision.requiresApproval,
            approvalStatus: result.approvalStatus,
            delegation: Self.delegationKind(for: result.delegationDecision)
        )
    }

    private static func routeKind(for route: TaskRoute) -> ScenarioRouteKind {
        switch route {
        case .askClarification:
            return .clarification
        case .approvalRequired:
            return .approvalRequired
        case .localTool:
            return .localTool
        case .blocked:
            return .blocked
        }
    }

    private static func delegationKind(for decision: DelegationDecision) -> ScenarioDelegationKind {
        switch decision {
        case .blocked:
            return .blocked
        case .requiresApproval:
            return .approvalRequired
        case .allowedMetadataOnly:
            return .allowedMetadataOnly
        }
    }
}
