import Foundation

public enum ToolDefinitionValidationIssue: String, Equatable, Sendable {
    case emptyName
}

public enum ToolRegistrationResult: Equatable, Sendable {
    case registered
    case rejectedInvalid([ToolDefinitionValidationIssue])
    case rejectedDuplicateName
}

public struct ToolDefinition: Equatable, Sendable {
    public let name: String
    public let requiredDataLevel: DataSensitivityLevel
    public let actionRisk: ActionRisk
    public let description: String

    public init(
        name: String,
        requiredDataLevel: DataSensitivityLevel,
        actionRisk: ActionRisk,
        description: String
    ) {
        self.name = name
        self.requiredDataLevel = requiredDataLevel
        self.actionRisk = actionRisk
        self.description = description
    }

    public var validationIssues: [ToolDefinitionValidationIssue] {
        canonicalName.isEmpty ? [.emptyName] : []
    }

    public var isValid: Bool {
        validationIssues.isEmpty
    }

    fileprivate var canonicalName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate var normalized: ToolDefinition {
        ToolDefinition(
            name: canonicalName,
            requiredDataLevel: requiredDataLevel,
            actionRisk: actionRisk,
            description: description
        )
    }
}

public final class ToolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var toolsByName: [String: ToolDefinition] = [:]

    public init(tools: [ToolDefinition] = []) {
        for tool in tools {
            _ = register(tool)
        }
    }

    @discardableResult
    public func register(_ tool: ToolDefinition) -> ToolRegistrationResult {
        let issues = tool.validationIssues
        guard issues.isEmpty else {
            return .rejectedInvalid(issues)
        }

        let normalizedTool = tool.normalized

        lock.lock()
        defer { lock.unlock() }

        guard toolsByName[normalizedTool.name] == nil else {
            return .rejectedDuplicateName
        }

        toolsByName[normalizedTool.name] = normalizedTool
        return .registered
    }

    public func tool(named name: String) -> ToolDefinition? {
        let canonicalName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !canonicalName.isEmpty else {
            return nil
        }

        lock.lock()
        defer { lock.unlock() }
        return toolsByName[canonicalName]
    }

    public func allTools() -> [ToolDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return toolsByName.values.sorted { $0.name < $1.name }
    }
}
