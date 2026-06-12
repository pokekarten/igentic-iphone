import Foundation

public enum TaskIntent: String, Sendable {
    case unknown
    case createReminder
    case summarizeNote
    case findFile
    case requestApproval
}

public struct TaskRequest: Equatable, Sendable {
    public let userText: String
    public let intent: TaskIntent
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk

    public init(
        userText: String,
        intent: TaskIntent,
        dataClassification: DataClassification = .publicDefault,
        actionRisk: ActionRisk = .prepare
    ) {
        self.userText = userText
        self.intent = intent
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
    }
}

public enum TaskRoute: Equatable, Sendable {
    case askClarification(reason: String)
    case localTool(name: String, reason: String)
    case blocked(reason: String)
}

public struct TaskRouter: Sendable {
    private let policyEngine: PolicyEngine

    public init(policyEngine: PolicyEngine = PolicyEngine()) {
        self.policyEngine = policyEngine
    }

    public func route(_ task: TaskRequest, privacyMode: PrivacyMode) -> TaskRoute {
        guard task.intent != .unknown else {
            return .askClarification(reason: "Intent is unclear.")
        }

        let decision = policyEngine.decide(
            PolicyRequest(
                privacyMode: privacyMode,
                dataClassification: task.dataClassification,
                actionRisk: task.actionRisk,
                requestedDelegationTarget: .localDevice
            )
        )

        guard decision.isAllowed else {
            return .blocked(reason: decision.reason)
        }

        switch task.intent {
        case .createReminder:
            return .localTool(name: "createReminder", reason: "Reminder creation is a typed local action.")
        case .summarizeNote:
            return .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation.")
        case .findFile:
            return .localTool(name: "findFile", reason: "File search starts with local metadata and permissions.")
        case .requestApproval:
            return .localTool(name: "requestApproval", reason: "Approval is a first-class local action.")
        case .unknown:
            return .askClarification(reason: "Intent is unclear.")
        }
    }
}
