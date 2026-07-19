import Foundation

public struct AppActionDraft: Identifiable, Equatable, Sendable {
    public enum ActionKind: String, Equatable, Sendable { case sendMessage, deleteRecord, updateRecord, exportData }
    public let id: UUID, actionKind: ActionKind, targetDescription: String, payloadSummary: String, dataClassification: DataClassification, actionRisk: ActionRisk
    public init(id: UUID = UUID(), actionKind: ActionKind, targetDescription: String, payloadSummary: String, dataClassification: DataClassification, actionRisk: ActionRisk) {
        self.id = id; self.actionKind = actionKind; self.targetDescription = targetDescription; self.payloadSummary = payloadSummary; self.dataClassification = dataClassification; self.actionRisk = actionRisk
    }
}

extension AppActionDraft {
    var fingerprint: String { [id.uuidString, actionKind.rawValue, targetDescription, payloadSummary, String(dataClassification.level.rawValue), actionRisk.rawValue].joined(separator: "|") }
    var requestedDelegationTarget: DelegationTarget {
        switch actionKind {
        case .sendMessage: .externalProvider
        case .deleteRecord: .none
        case .updateRecord: .localDevice
        case .exportData: .trustedMac
        }
    }
}
