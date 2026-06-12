import Foundation

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
}

public final class ToolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var toolsByName: [String: ToolDefinition] = [:]

    public init(tools: [ToolDefinition] = []) {
        for tool in tools {
            toolsByName[tool.name] = tool
        }
    }

    public func register(_ tool: ToolDefinition) {
        lock.lock()
        defer { lock.unlock() }
        toolsByName[tool.name] = tool
    }

    public func tool(named name: String) -> ToolDefinition? {
        lock.lock()
        defer { lock.unlock() }
        return toolsByName[name]
    }

    public func allTools() -> [ToolDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return toolsByName.values.sorted { $0.name < $1.name }
    }
}
