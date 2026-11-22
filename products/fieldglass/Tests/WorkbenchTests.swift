import XCTest

final class WorkbenchTests: XCTestCase {
    func testReadThenChangeRegion() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["run"].tap()
        XCTAssertTrue(app.staticTexts["Suchtext erkannt."].waitForExistence(timeout: 30))
        app.buttons["Unten"].tap()
        app.buttons["run"].tap()
        XCTAssertTrue(app.staticTexts["Im gewählten Bereich wurde kein Treffer erkannt."].waitForExistence(timeout: 30))
    }

    func testNativeWorkspace() {
        let app = XCUIApplication()
        func open(_ action: String, _ text: String) {
            var c = URLComponents(string: "fieldglass://workspace/v1")!
            c.queryItems = [URLQueryItem(name: "id",value: UUID().uuidString),
                            URLQueryItem(name: "action",value: action),URLQueryItem(name: "text",value: text)]
            app.open(c.url!)
        }
        open("status","")
        app.buttons["Status erfassen"].tap()
        XCTAssertTrue(app.staticTexts["actionStatus"].label.contains("Stromsparmodus"))
        app.buttons["Fertig"].tap()
        open("draft","Eine Probe")
        app.buttons["Entwurf übernehmen"].tap()
        XCTAssertTrue(app.staticTexts["actionStatus"].label.contains("bereit"))
        app.buttons["Fertig"].tap()
        open("reminder","Synthetische Probe")
        app.buttons["Speichern prüfen"].tap()
        XCTAssertTrue(app.alerts.firstMatch.exists)
        app.buttons["Abbrechen"].tap()
        XCTAssertTrue(app.buttons["Speichern prüfen"].isEnabled)
    }

    func testSharedExperiment() throws {
        guard let raw = ProcessInfo.processInfo.environment["FIELDGLASS_LINK"],
              let url = URL(string: raw) else { throw XCTSkip("Run scripts/acceptance.sh for the protocol handoff") }
        let app = XCUIApplication()
        app.open(url)
        XCTAssertTrue(app.staticTexts["Auftrag geladen. Bild auswählen und Prüfung starten."].waitForExistence(timeout: 15))
        for name in ["before", "after"] {
            if name == "after" {
                app.swipeDown()
                app.buttons["Beispiel wechseln"].tap()
            }
            app.buttons["run"].tap()
            let expected = name == "before" ? "Suchtext erkannt." : "Im gewählten Bereich wurde kein Treffer erkannt."
            XCTAssertTrue(app.staticTexts[expected].waitForExistence(timeout: 30))
            let report = app.buttons["Bericht ansehen"].firstMatch
            if !report.isHittable { app.swipeUp() }
            report.tap()
            let text = app.staticTexts["receipt"]
            XCTAssertTrue(text.waitForExistence(timeout: 5))
            let attachment = XCTAttachment(data: Data(text.label.utf8), uniformTypeIdentifier: "public.json")
            attachment.name = "fieldglass-" + name + ".json"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.buttons["Fertig"].tap()
        }
    }
}
