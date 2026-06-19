import XCTest
@testable import AgentCore

final class ToolRegistryValidationTests: XCTestCase {
    func testValidToolMetadataRegistersDeterministically() {
        let registry = ToolRegistry()
        let tool = ToolDefinition(
            name: "createReminder",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "Prepare a local reminder action."
        )

        XCTAssertTrue(tool.isValid)
        XCTAssertEqual(tool.validationIssues, [])
        XCTAssertEqual(registry.register(tool), .registered)
        XCTAssertEqual(registry.tool(named: "createReminder"), tool)
    }

    func testRegistrationNormalizesOuterNameWhitespace() {
        let registry = ToolRegistry()
        let tool = ToolDefinition(
            name: "  summarizeNote\n",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "Prepare a local note summary."
        )

        XCTAssertEqual(registry.register(tool), .registered)
        XCTAssertEqual(registry.tool(named: "summarizeNote")?.name, "summarizeNote")
        XCTAssertEqual(registry.tool(named: "  summarizeNote  ")?.name, "summarizeNote")
    }

    func testEmptyAndWhitespaceOnlyNamesAreRejected() {
        let registry = ToolRegistry()
        let emptyName = ToolDefinition(
            name: "",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Synthetic empty-name tool."
        )
        let whitespaceName = ToolDefinition(
            name: " \n\t ",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Synthetic whitespace-name tool."
        )

        XCTAssertEqual(emptyName.validationIssues, [.emptyName])
        XCTAssertEqual(whitespaceName.validationIssues, [.emptyName])
        XCTAssertEqual(registry.register(emptyName), .rejectedInvalid([.emptyName]))
        XCTAssertEqual(registry.register(whitespaceName), .rejectedInvalid([.emptyName]))
        XCTAssertEqual(registry.allTools(), [])
        XCTAssertNil(registry.tool(named: ""))
        XCTAssertNil(registry.tool(named: "   "))
    }

    func testDuplicateNameIsRejectedWithoutReplacingFirstDefinition() {
        let registry = ToolRegistry()
        let first = ToolDefinition(
            name: "createReminder",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "First safe definition."
        )
        let duplicate = ToolDefinition(
            name: " createReminder ",
            requiredDataLevel: .restrictedSensitiveData,
            actionRisk: .critical,
            description: "Duplicate definition that must not replace the first."
        )

        XCTAssertEqual(registry.register(first), .registered)
        XCTAssertEqual(registry.register(duplicate), .rejectedDuplicateName)
        XCTAssertEqual(registry.tool(named: "createReminder"), first)
        XCTAssertEqual(registry.allTools(), [first])
    }

    func testInitializerUsesFirstValidDefinitionAndKeepsSortedSnapshot() {
        let createReminder = ToolDefinition(
            name: "createReminder",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "First valid reminder definition."
        )
        let duplicateReminder = ToolDefinition(
            name: "createReminder",
            requiredDataLevel: .restrictedSensitiveData,
            actionRisk: .critical,
            description: "Duplicate reminder definition."
        )
        let summarizeNote = ToolDefinition(
            name: "summarizeNote",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "Prepare a local note summary."
        )
        let invalid = ToolDefinition(
            name: " ",
            requiredDataLevel: .publicData,
            actionRisk: .read,
            description: "Invalid synthetic definition."
        )

        let registry = ToolRegistry(
            tools: [summarizeNote, invalid, createReminder, duplicateReminder]
        )

        XCTAssertEqual(registry.allTools().map(\.name), ["createReminder", "summarizeNote"])
        XCTAssertEqual(registry.tool(named: "createReminder"), createReminder)
        XCTAssertEqual(registry.tool(named: "summarizeNote"), summarizeNote)
    }
}
