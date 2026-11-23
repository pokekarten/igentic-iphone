import XCTest

final class DiagnosticsUITests: XCTestCase {
    @MainActor
    func testLaunchExploreAndSyntheticApprovalCancel() {
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        XCTAssertTrue(app.staticTexts["iGentic Diagnostics"].waitForExistence(timeout: 15))
        // SwiftUI List rows can be virtualized on different device sizes;
        // this bounded accessibility lookup also works for link-type rows.
        guard let explore = scrollToControl("igentic-open-local-discovery", in: app) else { return }
        explore.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        // iOS 27.1 can expose the native NavigationStack back item as
        // .other instead of .button. Use the native edge-back gesture rather
        // than depending on the framework's accessibility element type.
        let backGestureStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.45))
        let backGestureEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        backGestureStart.press(forDuration: 0.1, thenDragTo: backGestureEnd)
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].waitForExistence(timeout: 10))
        guard let reminder = scrollToControl("igentic-review-synthetic-reminder", in: app) else { return }
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Review reminder"].waitForExistence(timeout: 10))
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Review reminder"].exists)
    }

    @MainActor
    func testAgentHomeLocalStatusAndPreview() {
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        guard let entry = scrollToControl("igentic-open-agent-home", in: app) else { return }
        entry.tap()

        XCTAssertTrue(app.navigationBars["iGentic Agent"].waitForExistence(timeout: 15))
        let status = app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-local-status").firstMatch
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        status.tap()
        let output = app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-status-result").firstMatch
        XCTAssertTrue(output.waitForExistence(timeout: 10))
        XCTAssertTrue(output.label.contains("ChatGPT-Verbindung nicht geprüft"))

        let prompt = app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-prompt").firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 10))
        prompt.tap()
        prompt.typeText("Offline Textentwurf")
        let preview = app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-preview").firstMatch
        preview.tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-proposal").firstMatch.waitForExistence(timeout: 10))
        // iOS 27 currently does not consistently expose the ShareLink's
        // accessibility identifier in XCUITest. Manual share availability
        // is unit-tested by AgentLoopLocalBridgeTests; this UI test confirms
        // the actual local status and proposal without opening another app.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-proposal").firstMatch.exists)
    }

    @MainActor
    private func scrollToControl(_ identifier: String, in app: XCUIApplication) -> XCUIElement? {
        // Use a stable accessibility identifier, not a SwiftUI-dependent
        // Button/Link element type; a row may be virtualized while off-screen.
        let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        for attempt in 0...6 {
            if control.exists && control.isHittable { return control }
            if attempt == 6 { break }
            if app.collectionViews.firstMatch.exists {
                app.collectionViews.firstMatch.swipeUp()
            } else if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        XCTFail("Expected a visible bundled diagnostic control: \(identifier)")
        return nil
    }
}
