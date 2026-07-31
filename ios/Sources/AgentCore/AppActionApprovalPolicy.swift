import Foundation

public struct AppActionApprovalPolicy: Codable, Equatable, Sendable {
    public struct Rule: Codable, Equatable, Sendable {
        public let actionKindRawValue: String
        public let requiresApproval: Bool
        public let enabled: Bool
        public let note: String?

        public init(
            actionKind: AppActionDraft.ActionKind,
            requiresApproval: Bool,
            enabled: Bool = true,
            note: String? = nil
        ) {
            self.actionKindRawValue = actionKind.rawValue
            self.requiresApproval = requiresApproval
            self.enabled = enabled
            self.note = note
        }

        public var actionKind: AppActionDraft.ActionKind? {
            AppActionDraft.ActionKind(rawValue: actionKindRawValue)
        }
    }

    public let schemaVersion: Int
    public let rules: [Rule]

    public init(schemaVersion: Int = 1, rules: [Rule]) {
        self.schemaVersion = schemaVersion
        self.rules = rules
    }

    public static let setupDefault = AppActionApprovalPolicy(rules: [
        .init(actionKind: .sendMessage, requiresApproval: false, note: "Default setup allows direct messaging."),
        .init(actionKind: .deleteRecord, requiresApproval: true, note: "Default setup requires approval for deletions."),
        .init(actionKind: .updateRecord, requiresApproval: true, note: "Default setup requires approval for edits."),
        .init(actionKind: .exportData, requiresApproval: true, note: "Default setup requires approval for exports.")
    ])

    public static var `default`: AppActionApprovalPolicy { setupDefault }

    public func rule(for actionKind: AppActionDraft.ActionKind) -> Rule? {
        rules.first { $0.actionKindRawValue == actionKind.rawValue }
    }

    public func requiresApproval(for actionKind: AppActionDraft.ActionKind) -> Bool? {
        guard let rule = rule(for: actionKind), rule.enabled else { return nil }
        return rule.requiresApproval
    }
}

public struct AppActionApprovalPolicyStore {
    public let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func load() -> AppActionApprovalPolicy? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder.agentKernelPolicy.decode(AppActionApprovalPolicy.self, from: data)
    }

    public func loadOrDefault() -> AppActionApprovalPolicy {
        load() ?? .default
    }

    public func loadOrInstallDefault(fileManager: FileManager = .default) throws -> AppActionApprovalPolicy {
        if let policy = load() {
            return policy
        }

        guard !fileManager.fileExists(atPath: fileURL.path) else {
            return .default
        }

        try save(.default, fileManager: fileManager)
        return .default
    }

    public func save(_ policy: AppActionApprovalPolicy, fileManager: FileManager = .default) throws {
        let data = try JSONEncoder.agentKernelPolicy.encode(policy)
        let directoryURL = fileURL.deletingLastPathComponent()
        if directoryURL.path != "/" && directoryURL.path != "." {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        try data.write(to: fileURL, options: [.atomic])
    }
}

private extension JSONEncoder {
    static var agentKernelPolicy: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var agentKernelPolicy: JSONDecoder {
        JSONDecoder()
    }
}
