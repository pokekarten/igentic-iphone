import Foundation

public struct AppActionApprovalPolicyEditor: Sendable {
    public let store: AppActionApprovalPolicyStore
    public private(set) var policy: AppActionApprovalPolicy

    public init(store: AppActionApprovalPolicyStore = .init(fileURL: AppActionApprovalPolicyStore.defaultFileURL()), fileManager: FileManager = .default) throws {
        self.store = store
        self.policy = try store.loadOrInstallDefault(fileManager: fileManager)
    }

    public mutating func setRequiresApproval(_ requiresApproval: Bool, for actionKind: AppActionDraft.ActionKind) {
        policy = policy.replacingRule(for: actionKind, requiresApproval: requiresApproval)
    }

    public mutating func setEnabled(_ enabled: Bool, for actionKind: AppActionDraft.ActionKind) {
        policy = policy.replacingRule(for: actionKind, enabled: enabled)
    }

    public mutating func setNote(_ note: String?, for actionKind: AppActionDraft.ActionKind) {
        policy = policy.replacingRule(
            for: actionKind,
            note: note,
            shouldReplaceNote: true
        )
    }

    public mutating func resetToDefault() {
        policy = .default
    }

    public func save(fileManager: FileManager = .default) throws {
        try store.save(policy, fileManager: fileManager)
    }
}

public extension AppActionApprovalPolicy {
    func replacingRule(
        for actionKind: AppActionDraft.ActionKind,
        requiresApproval: Bool? = nil,
        enabled: Bool? = nil,
        note: String? = nil,
        shouldReplaceNote: Bool = false
    ) -> AppActionApprovalPolicy {
        let existingRule = rule(for: actionKind)
        let rule = Rule(
            actionKind: actionKind,
            requiresApproval: requiresApproval ?? existingRule?.requiresApproval ?? false,
            enabled: enabled ?? existingRule?.enabled ?? true,
            note: shouldReplaceNote ? note : note ?? existingRule?.note
        )

        var updatedRules = rules.filter { $0.actionKindRawValue != actionKind.rawValue }
        updatedRules.append(rule)
        updatedRules.sort { $0.actionKindRawValue < $1.actionKindRawValue }
        return AppActionApprovalPolicy(schemaVersion: schemaVersion, rules: updatedRules)
    }
}
