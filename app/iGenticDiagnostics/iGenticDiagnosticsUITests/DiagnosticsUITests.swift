import XCTest

final class DiagnosticsUITests: XCTestCase {
    @MainActor
    func testLaunchExploreAndSyntheticApprovalCancel() {
        let app = XCUIApplication()
        app.launch()
        let confirm = app.buttons["Confirm and continue"]
        if confirm.waitForExistence(timeout: 10) { confirm.tap() }
        XCTAssertTrue(app.staticTexts["iGentic Diagnostics"].waitForExistence(timeout: 15))
        let explore = app.buttons["Open local discovery"]
        XCTAssertTrue(explore.waitForExistence(timeout: 10))
        explore.tap()
        XCTAssertTrue(app.navigationBars["Explore"].waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()
        let reminder = app.buttons["Review synthetic reminder"]
        // The diagnostics list is lazy: this safe preview can be below the
        // fold after adding another first-screen task. Scroll only this app,
        // with a strict bound; never tap an unobserved target.
        for _ in 0..<6 {
            if reminder.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(reminder.isHittable, "Synthetic reminder entry was not visible")
        guard reminder.isHittable else { return }
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Review reminder"].waitForExistence(timeout: 10))
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Review reminder"].exists)
    }
}
