import XCTest

final class DiagnosticsUITests: XCTestCase {
    @MainActor
    func testLaunchExploreAndSyntheticApprovalCancel() {
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        XCTAssertTrue(app.staticTexts["iGentic Diagnostics"].waitForExistence(timeout: 15))
        // SwiftUI List materializes off-screen rows lazily. On smaller or
        // dual-display devices the Explore section starts below the fold.
        guard let explore = scrollToControl("igentic-open-local-discovery", in: app) else { return }
        explore.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
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
