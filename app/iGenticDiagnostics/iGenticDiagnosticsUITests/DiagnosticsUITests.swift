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
        let openDiscovery = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Lokale Entdeckungen öffnen"))
            .firstMatch
        XCTAssertTrue(openDiscovery.waitForExistence(timeout: 10))
        openDiscovery.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
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
