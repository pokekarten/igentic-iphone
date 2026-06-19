import Foundation

public struct DiagnosticScenario: Identifiable, Equatable, Sendable {
    public let id: String
    public let task: TaskRequest
    public let privacyMode: PrivacyMode
    public let delegationTarget: DelegationTarget
    public let defaultApprovalStatus: ApprovalStatus

    public init(
        id: String,
        task: TaskRequest,
        privacyMode: PrivacyMode,
        delegationTarget: DelegationTarget,
        defaultApprovalStatus: ApprovalStatus = .pending
    ) {
        self.id = id
        self.task = task
        self.privacyMode = privacyMode
        self.delegationTarget = delegationTarget
        self.defaultApprovalStatus = defaultApprovalStatus
    }
}

public struct DiagnosticScenarioResult: Equatable, Sendable {
    public let scenarioID: String
    public let route: TaskRoute
    public let policyDecision: PolicyDecision
    public let approvalStatus: ApprovalStatus
    public let delegationDecision: DelegationDecision

    public init(
        scenarioID: String,
        route: TaskRoute,
        policyDecision: PolicyDecision,
        approvalStatus: ApprovalStatus,
        delegationDecision: DelegationDecision
    ) {
        self.scenarioID = scenarioID
        self.route = route
        self.policyDecision = policyDecision
        self.approvalStatus = approvalStatus
        self.delegationDecision = delegationDecision
    }
}

public struct ScenarioRunner: Sendable {
    private let delegationBroker: DelegationBroker

    public init(delegationBroker: DelegationBroker = DelegationBroker()) {
        self.delegationBroker = delegationBroker
    }

    public static let defaultScenarios = SyntheticScenarioCatalog.baseline

    public func run(_ scenario: DiagnosticScenario) -> DiagnosticScenarioResult {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: scenario.defaultApprovalStatus)
        )
        let response = kernel.handle(scenario.task, privacyMode: scenario.privacyMode)
        let delegationDecision = delegationBroker.decide(
            DelegationRequest(
                privacyMode: scenario.privacyMode,
                target: scenario.delegationTarget,
                dataClassification: scenario.task.dataClassification,
                actionRisk: scenario.task.actionRisk,
                reason: scenario.id
            )
        )

        return DiagnosticScenarioResult(
            scenarioID: scenario.id,
            route: response.route,
            policyDecision: response.policyDecision,
            approvalStatus: response.approvalStatus,
            delegationDecision: delegationDecision
        )
    }

    public func runAll(_ scenarios: [DiagnosticScenario] = ScenarioRunner.defaultScenarios) -> [DiagnosticScenarioResult] {
        scenarios.map(run)
    }

    public func report(_ scenarios: [DiagnosticScenario] = ScenarioRunner.defaultScenarios) -> ScenarioReport {
        ScenarioReport(results: runAll(scenarios))
    }
}
