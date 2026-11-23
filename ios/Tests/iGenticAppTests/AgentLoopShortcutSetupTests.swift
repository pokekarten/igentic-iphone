import XCTest
import Foundation
@testable import iGenticApp

final class AgentLoopShortcutSetupTests: XCTestCase {
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

    func testStepsRequireActualModelAndNativeReturn() {
        XCTAssertEqual(AgentLoopShortcutSetup.actions.count, 4)
        XCTAssertTrue(AgentLoopShortcutSetup.actions[0].contains("KI-Prompt lesen"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[1].contains("ChatGPT"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[2].contains("KI-Antwort übernehmen"))
        XCTAssertTrue(AgentLoopShortcutSetup.actions[3].contains("App öffnen"))
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
