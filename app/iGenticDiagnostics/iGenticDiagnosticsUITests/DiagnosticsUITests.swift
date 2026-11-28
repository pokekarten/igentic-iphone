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
    func testChatGPTHandoffOpensPreviewWithoutAutomaticNavigation() {
        let app = XCUIApplication()
        app.launch()
        // Initial setup still needs the owner's local confirmation.
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].waitForExistence(timeout: 15))

        // Apple XCUIApplication.open exercises the real custom URL dispatch
        // and SwiftUI onOpenURL rather than only calling the Swift URL parser.
        let url = URL(string: "igentic://handoff/v1/discovery")!
        app.open(url)
        let preview = app.staticTexts[
            "Du hast diesen Link auf dem iPhone geöffnet. Es wurde keine Aktion ausgeführt oder freigegeben."
        ]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        // No discovery screen until the owner makes a second local choice.
        XCTAssertFalse(app.navigationBars["Explore"].exists)
        // A native Button with a fixed identifier is exposed in the
        // preview. Avoid traversing the entire accessibility hierarchy.
        let openDiscovery = app.buttons["igentic-handoff-open-discovery"]
        guard openDiscovery.waitForExistence(timeout: 10) else {
            XCTFail("Expected the manual handoff discovery control")
            return
        }
        openDiscovery.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
    }


    @MainActor
    func testChatGPTColdStartURLPreservesNavigationOnlyAfterSetup() {
        let app = XCUIApplication()
        // XCUIApplication.open launches the app from the real URL scheme,
        // instead of passing synthetic SwiftUI state to DiagnosticView.
        app.open(URL(string: "igentic://handoff/v1/diagnostics")!)
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }

        let preview = app.staticTexts[
            "Du hast diesen Link auf dem iPhone geöffnet. Es wurde keine Aktion ausgeführt oder freigegeben."
        ]
        XCTAssertTrue(preview.waitForExistence(timeout: 15))
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].exists)
        // The incoming link did not approve anything or open another app.
        XCTAssertFalse(app.navigationBars["Explore"].exists)
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
        // A multi-line field can leave the preview covered by the software
        // keyboard on a compact iOS 27 simulator. Use the same visible,
        // owner-controlled dismissal action available in the real app.
        if app.keyboards.firstMatch.exists {
            let closeKeyboard = app.buttons["igentic-agent-dismiss-keyboard"]
            XCTAssertTrue(closeKeyboard.waitForExistence(timeout: 10))
            closeKeyboard.tap()
            let keyboardGone = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "exists == false"),
                object: app.keyboards.firstMatch
            )
            XCTAssertEqual(XCTWaiter.wait(for: [keyboardGone], timeout: 10), .completed)
        }
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
        // Restrict lookups to visible text in the guide's scroll view. A
        // whole-app .any query on this long SwiftUI screen timed out in
        // iOS 27.1 XCTest after navigation had already succeeded.
        let guide = app.scrollViews.firstMatch
        guard guide.waitForExistence(timeout: 10) else {
            XCTFail("Expected the scrollable KI-Loop setup guide")
            return
        }
        guard let name = scrollToSetupText("igentic-loop-setup-name", in: guide)
        else { return }
        XCTAssertEqual(name.label, "iGentic KI Loop")
        // Do not tap Create/Run: that would invoke another OS app or model.
        guard let state = scrollToSetupText("igentic-loop-setup-local-state", in: guide)
        else { return }
        XCTAssertFalse(state.label.isEmpty)
    }

    @MainActor
    private func scrollToSetupText(_ identifier: String, in guide: XCUIElement) -> XCUIElement? {
        let target = guide.staticTexts.matching(identifier: identifier).firstMatch
        // The name precedes the state in the guide. Search forward with a
        // finite gesture budget instead of querying the entire offscreen tree.
        for attempt in 0...8 {
            if target.exists && target.isHittable { return target }
            if attempt < 8 { guide.swipeUp() }
        }
        XCTFail("Expected visible setup text: \(identifier)")
        return nil
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
        // The SwiftUI scroll position can shift past a control when focus or
        // keyboard safe-area insets change. Search back towards the top as
        // well; never silently skip a missing required UI control.
        for _ in 0..<6 {
            if control.exists && control.isHittable { return control }
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeDown()
            } else if app.collectionViews.firstMatch.exists {
                app.collectionViews.firstMatch.swipeDown()
            } else if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeDown()
            } else {
                app.swipeDown()
            }
        }
        XCTFail("Expected a visible bundled diagnostic control: \(identifier)")
        return nil
    }
}
