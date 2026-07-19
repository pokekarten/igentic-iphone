import Foundation

public struct AppActionDraft: Identifiable, Equatable, Sendable {
    public enum ActionKind: String, Equatable, Sendable {
        case sendMessage
        case deleteRecord
        case updateRecord
        case exportData
    }

    public let id: UUID
    public let actionKind: ActionKind
    public let targetDescription: String
    public let payloadSummary: String
    public let dataClassification: DataClassification
    public let actionRisk: ActionRisk

    public init(
        id: UUID = UUID(),
        actionKind: ActionKind,
        targetDescription: String,
        payloadSummary: String,
        dataClassification: DataClassification,
        actionRisk: ActionRisk
    ) {
        self.id = id
        self.actionKind = actionKind
        self.targetDescription = targetDescription
        self.payloadSummary = payloadSummary
        self.dataClassification = dataClassification
        self.actionRisk = actionRisk
    }
}
