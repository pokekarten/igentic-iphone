import XCTest
@testable import iGenticApp

final class AgentLoopLocalBridgeTests: XCTestCase {
    func testActualStatusFormattingDoesNotClaimChatGPTConnectivity() {
        let status = AgentLoopLocalStatus(batteryFraction: 0.625,
                                          lowPowerModeEnabled: true, osVersion: "27.2.1")
        XCTAssertEqual(status.batteryPercent, 63)
        XCTAssertTrue(status.shortcutSummary.contains("63 %"))
        XCTAssertTrue(status.shortcutSummary.contains("Stromsparmodus aktiv"))
        XCTAssertTrue(status.shortcutSummary.contains("iOS 27.2.1"))
        XCTAssertTrue(status.shortcutSummary.contains("ChatGPT-Verbindung nicht geprüft"))
    }

    func testUnavailableBatteryAndInvalidOSFailClosed() {
        for level: Float in [-1, 1.01, .infinity, .nan] {
            let status = AgentLoopLocalStatus(batteryFraction: level,
                                              lowPowerModeEnabled: false, osVersion: "My iPhone")
            XCTAssertNil(status.batteryPercent)
            XCTAssertTrue(status.shortcutSummary.contains("nicht verfügbar"))
            XCTAssertTrue(status.shortcutSummary.contains("iOS unbekannt"))
        }
        XCTAssertEqual(AgentLoopLocalStatus(batteryFraction: 0, lowPowerModeEnabled: false,
                                            osVersion: "27").batteryPercent, 0)
        XCTAssertEqual(AgentLoopLocalStatus(batteryFraction: 1, lowPowerModeEnabled: false,
                                            osVersion: "27").batteryPercent, 100)
    }

    func testTaskPreviewRoutesOnlyToOwnAppAndReturnsNoPrivateRequestText() {
        let instruction = "Erinnere mich morgen an meine Pflanze"
        let proposal = AgentLoopTaskBridge.preview(instruction)
        XCTAssertEqual(proposal.destination, .reminderDraft)
        let summary = AgentLoopTaskBridge.shortcutSummary(instruction)
        XCTAssertTrue(summary.contains("Keine Aktion ausgeführt"))
        XCTAssertFalse(summary.contains("meine Pflanze"))
        XCTAssertFalse(summary.contains("extern"))
    }

    func testLongOrDangerousTasksCannotBecomeDeviceCommands() {
        for instruction in ["", String(repeating: "a", count: 513)] {
            XCTAssertEqual(AgentLoopTaskBridge.preview(instruction).destination, .unsupported)
            XCTAssertNil(AgentLoopTaskBridge.shareText(instruction))
        }
        for instruction in ["Lösche alle Erinnerungen", "Öffne WhatsApp"] {
            XCTAssertEqual(AgentLoopTaskBridge.preview(instruction).destination, .unsupported)
            // User-controlled external advice is allowed, device execution is not.
            XCTAssertNotNil(AgentLoopTaskBridge.shareText(instruction))
        }
    }

    func testShareTextRequiresExplicitSupportedPreviewAndContainsNoLinksOrSecrets() {
        let message = AgentLoopTaskBridge.shareText("Offline Textentwurf")
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("manuell geteilter Auftrag") == true)
        XCTAssertTrue(message?.contains("keine iPhone-Aktion ohne separate Freigabe") == true)
        XCTAssertFalse(message?.contains("igentic://") == true)
    }
}
