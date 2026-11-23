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

    func testSensitiveMutationCommandsCannotBeReclassifiedAsReminder() {
        XCTAssertEqual(AgentHomeCommandRouter.preview("Lösche alle Erinnerungen").destination, .unsupported)
        XCTAssertEqual(AgentHomeCommandRouter.preview("Sende meine Erinnerung als SMS").destination, .unsupported)
    }
}
