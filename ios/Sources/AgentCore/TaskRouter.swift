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
    case approvalRequired(reason: String)
    case localTool(name: String, reason: String)
    case blocked(reason: String)
}

/// Maps an already policy-approved task intent to a concrete local route.
///
/// `TaskRouter` intentionally does not compute or re-check policy or
/// approval decisions. The caller (`AgentKernel.handle`) must obtain a
/// `PolicyDecision` from `PolicyEngine`, confirm `isAllowed`, and resolve
/// any required approval before calling `route`. Keeping that check in a
/// single place avoids two independent code paths disagreeing about
/// whether a task may proceed.
public struct TaskRouter: Sendable {
    public init() {}

    func route(_ task: TaskRequest) -> TaskRoute {
        guard task.intent != .unknown else {
            return .askClarification(reason: "Intent is unclear.")
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
