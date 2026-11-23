import XCTest

final class SimulatorSystemTests: XCTestCase {
    override func setUpWithError() throws {
        #if targetEnvironment(simulator)
        try XCTSkipUnless(ProcessInfo.processInfo.environment["FIELDGLASS_SYSTEM_FIXTURES"] == "1",
                          "Run scripts/system-acceptance.sh with its disposable simulator")
        #else
        throw XCTSkip("Isolated simulator fixtures only")
        #endif
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    private let app = XCUIApplication()

    private func open(_ action: String, text: String, id: UUID = UUID()) {
        var url = URLComponents(string: "fieldglass://workspace/v1")!
        url.queryItems = [.init(name: "action", value: action), .init(name: "text", value: text),
                          .init(name: "id", value: id.uuidString)]
        app.open(url.url!)
    }

    private func firstVisible(_ query: XCUIElementQuery, containing phrase: String) -> XCUIElement {
        query.matching(NSPredicate(format: "label CONTAINS[c] %@", phrase)).firstMatch
    }

    func testSelectedPhotoReturnsSelectedImageReceipt() throws {
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        let chooseImage = app.buttons["Bild auswählen"]
        for _ in 0..<4 where !chooseImage.isHittable { app.swipeUp() }
        XCTAssertTrue(chooseImage.waitForExistence(timeout: 6), app.debugDescription)
        chooseImage.tap()
        let photoService = XCUIApplication(bundleIdentifier: "com.apple.PhotosViewService")
        let photosCell = photoService.descendants(matching: .any).matching(NSPredicate(format: "elementType == %d", XCUIElement.ElementType.cell.rawValue)).firstMatch
        XCTAssertTrue(photosCell.waitForExistence(timeout: 12), XCUIApplication(bundleIdentifier: "com.apple.springboard").debugDescription)
        photosCell.tap()
        XCTAssertTrue(app.images["Ausgewähltes Bild"].waitForExistence(timeout: 12), app.debugDescription)
        app.buttons["run"].tap()
        XCTAssertTrue(app.staticTexts["Suchtext erkannt."].waitForExistence(timeout: 15))
        let report = app.buttons["Bericht ansehen"]
        if !report.isHittable { app.swipeUp() }
        report.tap()
        let raw = app.staticTexts["receipt"].label
        let parsed = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String:Any])
        XCTAssertEqual(parsed["source"] as? String, "selected-image")
        XCTAssertEqual(parsed["outcome"] as? String, "match")
    }

    func testDraftShareSheet() {
        app.launch()
        app.buttons["Werkzeuge öffnen"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Werkzeug,'")).firstMatch.tap()
        app.buttons["Fertig"].tap()
        open("draft", text: "Der Komet zieht heute über den Himmel. Am Abend ist er gut zu sehen.")
        app.buttons["Entwurf übernehmen"].tap()
        XCTAssertTrue(app.buttons["Entwurf teilen"].isHittable)
    }

    func testLocalSummaryAvailability() {
        open("draft", text: "Der Komet zieht heute über den Himmel. Am Abend ist er gut zu sehen.")
        let summary = app.buttons["Text zusammenfassen"]
        for _ in 0..<4 where !summary.isHittable { app.swipeUp() }
        XCTAssertTrue(summary.waitForExistence(timeout: 6), app.debugDescription)
        summary.tap()
        let message = app.staticTexts["language-status"]
        XCTAssertTrue(message.waitForExistence(timeout: 6))
        if message.label.contains("nicht verfügbar") {
            print("FIELDGLASS_SUMMARY=unavailable")
        } else {
            let result = app.staticTexts["language-result"]
            if !result.waitForExistence(timeout: 60) {
                XCTAssertTrue(message.label.contains("nicht erstellt"), message.label)
                print("FIELDGLASS_SUMMARY=unavailable-runtime")
                return
            }
            app.buttons["Als Entwurf übernehmen"].tap()
            print("FIELDGLASS_SUMMARY=generated")
        }
    }

    func testImportLocalGermanAudio() {
        open("draft", text: "Simulatorprobe")
        app.buttons["Deutsche Audiodatei transkribieren"].tap()
        let documents = XCUIApplication(bundleIdentifier: "com.apple.DocumentsApp")
        let file = firstVisible(documents.descendants(matching: .any), containing: "Fieldglass-Probe")
        let browse = firstVisible(documents.descendants(matching: .any), containing: "Browse")
        let pickerApp = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        let filePicker = pickerApp.otherElements.firstMatch
        if !file.exists, browse.waitForExistence(timeout: 4) { browse.tap() }
        if !file.exists {
            let local = firstVisible(documents.descendants(matching: .any), containing: "On My iPhone")
            if local.waitForExistence(timeout: 5) { local.tap() }
            let folder = documents.descendants(matching: .any).matching(NSPredicate(format: "label == 'Fieldglass'")).firstMatch
            if folder.waitForExistence(timeout: 4), folder.isHittable { folder.tap() }
        }
        var availableFiles = pickerApp.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Fieldglass-Probe'"))
        if !availableFiles.firstMatch.exists {
            availableFiles = filePicker.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Fieldglass-Probe'"))
        }
        if !availableFiles.firstMatch.exists {
            for _ in 0..<2 { documents.swipeDown() }
        }
        availableFiles = pickerApp.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'Fieldglass-Probe'"))
        XCTAssertTrue(availableFiles.firstMatch.waitForExistence(timeout: 12), pickerApp.debugDescription)
        availableFiles.firstMatch.tap()
        let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) { allow.tap() }
        let status = app.staticTexts["language-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 8))
        let unavailable = "Lokale deutsche Spracherkennung ist derzeit nicht verfügbar."
        if status.label == unavailable { print("FIELDGLASS_ASR=unavailable"); return }
        let result = app.staticTexts["language-result"]
        XCTAssertTrue(result.waitForExistence(timeout: 35), status.label)
        XCTAssertTrue(result.label.localizedCaseInsensitiveContains("Komet"), result.label)
        app.buttons["Als Entwurf übernehmen"].tap()
        print("FIELDGLASS_ASR=transcribed-synthetic-german")
    }

    func testSpeechAndStop() {
        open("speak", text: "Der Komet leuchtet am Himmel.")
        app.buttons["Vorlesen starten"].tap()
        let completion = app.staticTexts["Vorlesen abgeschlossen."]
        let started = app.staticTexts["Text wird vorgelesen."]
        XCTAssertTrue(started.waitForExistence(timeout: 5) || completion.exists, app.debugDescription)
        XCTAssertTrue(completion.waitForExistence(timeout: 20), app.debugDescription)
        app.buttons["Vorlesen starten"].tap()
        app.buttons["Vorlesen stoppen"].tap()
        XCTAssertEqual(app.staticTexts["actionStatus"].label, "Sprachausgabe gestoppt.")
        print("FIELDGLASS_SPEECH=synthesizer-finished")
    }

    func testLayoutAndOCRInLandscape() {
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let run = app.buttons["run"]
        for _ in 0..<5 where !run.isHittable { app.swipeUp() }
        XCTAssertTrue(run.isHittable, app.debugDescription)
        run.tap()
        XCTAssertTrue(app.staticTexts["Suchtext erkannt."].waitForExistence(timeout: 15))
    }

    func testReminderPermissionDenied() {
        open("reminder", text: "Gesperrte Simulatorprobe")
        app.buttons["Speichern prüfen"].tap()
        app.alerts.buttons["Erinnerung speichern"].tap()
        XCTAssertTrue(app.staticTexts["Der Zugriff auf Erinnerungen wurde abgelehnt."].waitForExistence(timeout: 8), app.debugDescription)
    }

    func testReminderWriteReadbackAndRestart() {
        let id = UUID()
        let title = "FG Probe 773"
        open("reminder", text: title, id: id)
        app.buttons["Speichern prüfen"].tap()
        app.alerts.buttons["Erinnerung speichern"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow'" )).firstMatch
        if allow.waitForExistence(timeout: 8) { allow.tap() }
        if !app.staticTexts["In der Standardliste gespeichert und zurückgelesen."].waitForExistence(timeout: 12) {
            let tail = app.debugDescription
            print("FIELDGLASS_REMINDER_UI=" + String(tail.suffix(2500)))
            XCTFail("EventKit write or readback did not complete.")
            return
        }
        print("FIELDGLASS_REMINDER=saved-readback")
        app.terminate()
        open("reminder", text: title, id: id)
        app.buttons["Speichern prüfen"].tap()
        app.alerts.buttons["Erinnerung speichern"].tap()
        XCTAssertTrue(app.staticTexts["Für diesen Auftrag besteht ein Speicherversuch. Bitte in Erinnerungen prüfen."].waitForExistence(timeout: 6))
        print("FIELDGLASS_REMINDER=saved-readback-replay-blocked")
    }
}
