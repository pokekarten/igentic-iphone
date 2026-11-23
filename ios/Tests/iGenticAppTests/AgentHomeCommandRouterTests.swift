import XCTest
@testable import iGenticApp

final class AgentHomeCommandRouterTests: XCTestCase {
    func testReminderIsOnlyNavigationProposal() {
        let p = AgentHomeCommandRouter.preview("Erinnere mich morgen an die Pflanze")
        XCTAssertEqual(p.destination, .reminderDraft)
        XCTAssertTrue(p.canOpenOwnedScreen)
        XCTAssertTrue(p.explanation.contains("Freigabe"))
    }

    func testExistingOfflineFunctionsAreDiscoverable() {
        XCTAssertEqual(AgentHomeCommandRouter.preview("Offline Textentwurf").destination, .offlineTools)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Bildtext OCR").destination, .offlineTools)
    }

    func testDiscoveryAndDiagnosticRoutes() {
        XCTAssertEqual(AgentHomeCommandRouter.preview("Explore").destination, .discovery)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Status").destination, .diagnostics)
    }

    func testUnknownAndBlankCommandsNeverBecomeActions() {
        XCTAssertEqual(AgentHomeCommandRouter.preview(" ").destination, .unsupported)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Ändere meinen Hintergrund").destination, .unsupported)
        XCTAssertFalse(AgentHomeCommandRouter.preview("Öffne WhatsApp").canOpenOwnedScreen)
    }

    func testNoSilentPrefixTruncationOrEmbeddedNull() {
        let long = "Erinnere mich morgen an die Pflanze "
            + String(repeating: "x", count: 510)
            + " und schicke eine Nachricht"
        XCTAssertEqual(AgentHomeCommandRouter.preview(long).destination, .unsupported)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Status" + String(UnicodeScalar(0)!) + " lesen").destination, .unsupported)
    }

    func testMixedLocalDestinationsAreNotGuessed() {
        let examples = [
            "Erinnerung und Status",
            "Erinnere mich und öffne offline Text",
            "Offline Text und Diagnose",
            "Status und Explore"
        ]
        for example in examples {
            XCTAssertEqual(AgentHomeCommandRouter.preview(example).destination, .unsupported,
                           "unexpected routing")
        }
    }

    func testUnsupportedMessagingAndSystemActionsTakePrecedence() {
        let examples = [
            "Schicke die Erinnerung an alle Kontakte",
            "Bitte verschicke meinen Status per Nachricht",
            "Teile eine Offline-Notiz",
            "Erinnerung per Mail verschicken",
            "Installiere eine App und prüfe Status",
            "Ändere die iPhone Einstellungen und lies Status"
        ]
        for example in examples {
            XCTAssertEqual(AgentHomeCommandRouter.preview(example).destination, .unsupported,
                           "unexpected routing")
        }
    }

    func testSimpleGermanAndEnglishDestinationsRemainUsable() {
        XCTAssertEqual(AgentHomeCommandRouter.preview("Remind me tomorrow").destination, .reminderDraft)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Vorlesen").destination, .offlineTools)
        XCTAssertEqual(AgentHomeCommandRouter.preview("ENTDECKEN").destination, .discovery)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Verbindung prüfen").destination, .diagnostics)
    }

    func testSensitiveMutationCommandsCannotBeReclassifiedAsReminder() {
        XCTAssertEqual(AgentHomeCommandRouter.preview("Lösche alle Erinnerungen").destination, .unsupported)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Sende meine Erinnerung als SMS").destination, .unsupported)
    }
}
