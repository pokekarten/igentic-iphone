import XCTest
@testable import AgentCore

final class TaskRouterTests: XCTestCase {
    private let router = TaskRouter()

    func testCreateReminderRoutesToLocalTool() {
        let task = TaskRequest(userText: "Remind me", intent: .createReminder)

        XCTAssertEqual(
            router.route(task),
            .localTool(name: "createReminder", reason: "Reminder creation is a typed local action.")
        )
    }

    func testSummarizeNoteRoutesToLocalTool() {
        let task = TaskRequest(userText: "Summarize this", intent: .summarizeNote)

        XCTAssertEqual(
            router.route(task),
            .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation.")
        )
    }

    func testFindFileRoutesToLocalTool() {
        let task = TaskRequest(userText: "Find my file", intent: .findFile)

        XCTAssertEqual(
            router.route(task),
            .localTool(name: "findFile", reason: "File search starts with local metadata and permissions.")
        )
    }

    func testRequestApprovalRoutesToLocalTool() {
        let task = TaskRequest(userText: "Approve this", intent: .requestApproval)

        XCTAssertEqual(
            router.route(task),
            .localTool(name: "requestApproval", reason: "Approval is a first-class local action.")
        )
    }

    func testUnknownIntentAsksForClarification() {
        let task = TaskRequest(userText: "???", intent: .unknown)

        XCTAssertEqual(
            router.route(task),
            .askClarification(reason: "Intent is unclear.")
        )
    }

    func testRouteDependsOnlyOnIntentNotOnDataClassificationOrActionRisk() {
        let lowRisk = TaskRequest(
            userText: "Find my file",
            intent: .findFile,
            dataClassification: .publicDefault,
            actionRisk: .read
        )
        let highRisk = TaskRequest(
            userText: "Find my file",
            intent: .findFile,
            dataClassification: DataClassification(
                level: .restrictedSensitiveData,
                reason: "Test restricted metadata."
            ),
            actionRisk: .critical
        )

        XCTAssertEqual(router.route(lowRisk), router.route(highRisk))
    }
}
