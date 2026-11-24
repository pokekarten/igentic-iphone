import XCTest
import Foundation
@testable import iGenticApp

final class AgentLoopShortcutSetupTests: XCTestCase {
    func testChatGPTExampleUsesOnlyTheFixedPublicPrompt() throws {
        let url = try XCTUnwrap(AgentLoopShortcutSetup.chatGPTExampleURL)
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        XCTAssertEqual(parts.scheme, "https")
        XCTAssertEqual(parts.host, "chatgpt.com")
        XCTAssertEqual(parts.queryItems, [URLQueryItem(
            name: "q", value: "Erstelle eine kurze Folgeaufgabe zur Prüfung einer leeren Testliste."
        )])
    }

    func testOfficialURLSchemasCarryNoUserData() {
        let setup = AgentLoopShortcutSetup.self
        XCTAssertEqual(setup.primaryShortcutName, "iGentic KI Loop")
        XCTAssertEqual(setup.createURL.absoluteString, "shortcuts://create-shortcut")
        let parsed = try? XCTUnwrap(
            URLComponents(url: setup.runURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(parsed?.scheme, "shortcuts")
        XCTAssertEqual(parsed?.host, "run-shortcut")
        XCTAssertEqual(parsed?.queryItems?.count, 1)
        XCTAssertEqual(parsed?.queryItems?.first?.name, "name")
        XCTAssertEqual(parsed?.queryItems?.first?.value, setup.primaryShortcutName)
        XCTAssertFalse(setup.runURL.absoluteString.contains("prompt="))
        XCTAssertFalse(setup.runURL.absoluteString.contains("text="))
        XCTAssertFalse(setup.runURL.absoluteString.contains("x-success"))
    }

    func testProjectChatLauncherIsIndependentAndDataFree() throws {
        let setup = AgentLoopShortcutSetup.self
        XCTAssertEqual(setup.projectChatShortcutName, "iGentic Projekt-Chat")
        XCTAssertNotEqual(setup.projectChatShortcutName, setup.primaryShortcutName)
        XCTAssertNotEqual(setup.projectChatRunURL, setup.runURL)

        let parsed = try XCTUnwrap(
            URLComponents(url: setup.projectChatRunURL, resolvingAgainstBaseURL: false)
        )
        XCTAssertEqual(parsed.scheme, "shortcuts")
        XCTAssertEqual(parsed.host, "run-shortcut")
        XCTAssertEqual(parsed.queryItems?.count, 1)
        XCTAssertEqual(parsed.queryItems?.first?.name, "name")
        XCTAssertEqual(parsed.queryItems?.first?.value, setup.projectChatShortcutName)
        XCTAssertTrue(parsed.path.isEmpty)
        XCTAssertFalse(setup.projectChatRunURL.absoluteString.contains("prompt="))
        XCTAssertFalse(setup.projectChatRunURL.absoluteString.contains("text="))
        XCTAssertFalse(setup.projectChatRunURL.absoluteString.contains("projectId="))
        XCTAssertFalse(setup.projectChatRunURL.absoluteString.contains("x-success"))
    }

    func testProjectChatSetupKeepsInteractiveChatSeparateFromModelReplyLoop() {
        let projectSteps = AgentLoopShortcutSetup.projectChatActions
        XCTAssertEqual(projectSteps.count, 3)
        XCTAssertTrue(projectSteps[0].contains("Start chat in project"))
        XCTAssertTrue(projectSteps[0].contains("auswählen"))
        XCTAssertTrue(projectSteps[1].contains("Optional"))
        XCTAssertTrue(projectSteps[1].contains("Voice Mode"))
        XCTAssertTrue(projectSteps[2].contains(AgentLoopShortcutSetup.projectChatShortcutName))
        // A new ChatGPT project conversation cannot be mistaken for an
        // authenticated model reply or an executed phone command.
        XCTAssertFalse(projectSteps.joined().contains("KI-Antwort übernehmen"))
        XCTAssertFalse(projectSteps.joined().contains("actionExecuted=true"))
    }

    func testStepsRequireActualModelAndNativeReturn() {
        XCTAssertEqual(AgentLoopShortcutSetup.actions.count, 5)
        XCTAssertTrue(AgentLoopShortcutSetup.actions[0].contains("Auftrags-ID lesen"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[1].contains("KI-Prompt lesen"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[2].contains("ChatGPT"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[3].contains("KI-Antwort übernehmen"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[3].contains("Auftrags-ID"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[4].contains("App öffnen"))
    }

    @MainActor
    func testLocalStageDoesNotClaimModelConnected() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let waiting = AgentLoopExchange(
            id: UUID(), createdAt: now, task: "Demo", answer: nil, answeredAt: nil
        )
        XCTAssertEqual(AgentLoopShortcutSetup.localStage(nil, now: now), .noTask)
        XCTAssertEqual(AgentLoopShortcutSetup.localStage(waiting, now: now), .waitingForAnswer)
        XCTAssertEqual(
            AgentLoopShortcutSetup.localStage(
                waiting, now: now.addingTimeInterval(31 * 60)
            ), .expired
        )
        XCTAssertEqual(
            AgentLoopShortcutSetup.localStage(
                waiting, now: now.addingTimeInterval(-1)
            ), .invalidTimestamp
        )
        let answered = AgentLoopExchange(
            id: waiting.id, createdAt: now, task: waiting.task,
            answer: "Modelltext", answeredAt: now.addingTimeInterval(1)
        )
        XCTAssertEqual(
            AgentLoopShortcutSetup.localStage(
                answered, now: now.addingTimeInterval(1)
            ), .answerAvailable
        )
    }
}
