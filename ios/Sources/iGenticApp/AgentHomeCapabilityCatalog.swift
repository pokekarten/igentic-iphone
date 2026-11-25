import AgentCore
import Foundation

/// The only first-party screens the prototype is currently allowed to
/// *navigate* to. These are metadata-only tools, not action executors.
///
/// This catalog deliberately uses AgentCore's existing ToolRegistry and
/// PolicyEngine so a future App Intents/MCP agent can build on one typed
/// capability boundary. A navigation decision grants NO permission to write
/// reminders, read private data, call Siri, control apps or execute remotely.
public enum AgentHomeCapabilityCatalog {
    private static let registry = ToolRegistry(tools: [
        ToolDefinition(
            name: "igentic.own_app.navigate.offline_tools",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Open the owner-controlled local text, speech and OCR screen; no tool is run."
        ),
        ToolDefinition(
            name: "igentic.own_app.navigate.reminder_draft",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Open the manual reminder editor; EventKit writes need independent owner approval."
        ),
        ToolDefinition(
            name: "igentic.own_app.navigate.discovery",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Open the bundled feature and local discovery screen."
        ),
        ToolDefinition(
            name: "igentic.own_app.navigate.diagnostics",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Return to the existing diagnostic screen; no device status is collected."
        )
    ])

    /// Read-only snapshot for feature discovery and tests. The descriptions
    /// represent navigation destinations, never remote execution authority.
    public static func navigationTools() -> [ToolDefinition] {
        registry.allTools()
    }

    public static func definition(for destination: AgentHomeDestination) -> ToolDefinition? {
        guard let name = toolName(for: destination) else { return nil }
        return registry.tool(named: name)
    }

    public static func canNavigate(to destination: AgentHomeDestination) -> Bool {
        guard let tool = definition(for: destination),
              tool.actionRisk == .read,
              tool.requiredDataLevel == .publicData else { return false }

        // The policy applies only to opening an already-owned screen.
        // The prompt's data is not delegated or executed by this function.
        let decision = PolicyEngine().decide(PolicyRequest(
            privacyMode: .localOnly,
            dataClassification: .publicDefault,
            actionRisk: tool.actionRisk,
            requestedDelegationTarget: .localDevice
        ))
        return decision.isAllowed && !decision.requiresApproval
    }

    private static func toolName(for destination: AgentHomeDestination) -> String? {
        switch destination {
        case .offlineTools: "igentic.own_app.navigate.offline_tools"
        case .reminderDraft: "igentic.own_app.navigate.reminder_draft"
        case .discovery: "igentic.own_app.navigate.discovery"
        case .diagnostics: "igentic.own_app.navigate.diagnostics"
        case .unsupported: nil
        }
    }
}
