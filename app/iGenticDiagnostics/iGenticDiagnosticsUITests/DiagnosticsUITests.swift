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
        // Keep the local status near the top of Agent Home. This avoids
        // depending on a deeply offscreen control after SwiftUI expands the
        // long preview and Shortcuts sections on small iOS 27 simulators.
        guard let status = scrollToControl("igentic-agent-local-status", in: app)
        else { return }
        status.tap()
        let output = app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-status-result").firstMatch
        XCTAssertTrue(output.waitForExistence(timeout: 10))
        XCTAssertTrue(output.label.contains("ChatGPT-Verbindung nicht geprüft"))

        guard let prompt = scrollToControl("igentic-agent-prompt", in: app) else { return }
        prompt.tap()
        prompt.typeText("Offline Textentwurf")
        guard let preview = scrollToControl("igentic-agent-preview", in: app) else { return }
        preview.tap()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-proposal").firstMatch.waitForExistence(timeout: 10))
        // Tapping Preview should dismiss editing focus before the user
        // scrolls through the longer local proposal or Shortcuts guide.
        let keyboard = app.keyboards.firstMatch
        if keyboard.exists {
            let hidden = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"), object: keyboard
            )
            XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
        }
        // iOS 27 currently does not consistently expose the ShareLink's
        // accessibility identifier in XCUITest. Manual share availability
        // is unit-tested by AgentLoopLocalBridgeTests; this UI test confirms
        // the actual local status and proposal without opening another app.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-agent-proposal").firstMatch.exists)
    }

    @MainActor
    func testAgentLoopInboxOpensWithoutCallingExternalModel() {
        // This is a UI-only acceptance. The pure Swift store tests cover the
        // Start → Receive → Review protocol and failures; Apple's customer
        // AppIntentsTesting environment does not run the real ChatGPT model.
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        guard let entry = scrollToControl("igentic-open-agent-home", in: app) else { return }
        entry.tap()
        XCTAssertTrue(app.navigationBars["iGentic Agent"].waitForExistence(timeout: 15))
        guard let inbox = scrollToControl("igentic-loop-open-inbox", in: app) else { return }
        inbox.tap()
        XCTAssertTrue(app.navigationBars["KI-Antwort prüfen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Kein offener KI-Auftrag"].waitForExistence(timeout: 10))
        // No model or OS Shortcuts actions are invoked by this navigation.
    }

    @MainActor
    func testAPIFreeLoopSetupGuideHasSafeNativeLinks() {
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        guard let entry = scrollToControl("igentic-open-agent-home", in: app)
        else { return }
        entry.tap()
        XCTAssertTrue(app.navigationBars["iGentic Agent"]
            .waitForExistence(timeout: 15))
        guard let setup = scrollToControl("igentic-loop-open-setup", in: app)
        else { return }
        setup.tap()
        XCTAssertTrue(app.navigationBars["KI-Loop einrichten"]
            .waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-loop-setup-name")
            .firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["iGentic KI Loop"].exists)
        // Do not tap Create/Run: that would invoke another OS app or model.
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "igentic-loop-setup-local-state")
            .firstMatch.exists)
    }

    @MainActor
    private func scrollToControl(_ identifier: String, in app: XCUIApplication) -> XCUIElement? {
        // Use a stable accessibility identifier, not a SwiftUI-dependent
        // Button/Link element type; a row may be virtualized while off-screen.
        let control = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        for attempt in 0...6 {
            if control.exists && control.isHittable { return control }
            if attempt == 6 { break }
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else if app.collectionViews.firstMatch.exists {
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
