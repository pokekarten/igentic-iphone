import XCTest

final class DiagnosticsUITests: XCTestCase {
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
        if !reminder.isHittable { app.swipeUp() }
        XCTAssertTrue(reminder.waitForExistence(timeout: 10))
        reminder.tap()
        XCTAssertTrue(app.navigationBars["Review reminder"].waitForExistence(timeout: 10))
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        cancel.tap()
        XCTAssertTrue(app.navigationBars["iGentic Diagnostics"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars["Review reminder"].exists)
    }
}
