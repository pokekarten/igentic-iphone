import Foundation

/// Locally measured, strictly limited status. Never a claim that a remote
/// ChatGPT connection or a background execution channel is available.
public struct AgentLoopLocalStatus: Equatable, Sendable {
    public let batteryPercent: Int?
    public let lowPowerModeEnabled: Bool
    public let osVersion: String

    public init(batteryFraction: Float, lowPowerModeEnabled: Bool, osVersion: String) {
        if batteryFraction.isFinite && (0...1).contains(batteryFraction) {
            batteryPercent = Int((batteryFraction * 100).rounded())
        } else {
            batteryPercent = nil
        }
        self.lowPowerModeEnabled = lowPowerModeEnabled
        // The displayed OS version is a bounded system-supplied numeric string,
        // never an arbitrary device name, serial number or attached user data.
        let safe = osVersion.unicodeScalars.allSatisfy {
            CharacterSet.decimalDigits.contains($0) || $0 == "."
        }
        self.osVersion = safe && !osVersion.isEmpty && osVersion.count <= 16
            ? osVersion : "unbekannt"
    }

    public var shortcutSummary: String {
        let battery = batteryPercent.map { "\($0) %" } ?? "nicht verfügbar"
        let lowPower = lowPowerModeEnabled ? "aktiv" : "aus"
        return "iGentic iPhone: Akku \(battery); Stromsparmodus \(lowPower); iOS \(osVersion). " +
            "Lokal gelesen. ChatGPT-Verbindung nicht geprüft. Keine anderen Apps oder persönlichen Daten ausgelesen."
    }
}

/// A Shortcuts-ready planning step. Never turns model text or a Shortcut
/// parameter into automatic iPhone action execution.
public enum AgentLoopTaskBridge {
    public static func preview(_ instruction: String) -> AgentHomeProposal {
        guard !instruction.isEmpty && instruction.count <= 512 else {
            return .init(destination: .unsupported,
                         title: "Auftrag nicht übernommen",
                         explanation: "Der Auftrag ist leer oder zu lang. Keine Ausführung und keine Netzwerkübertragung.")
        }
        return AgentHomeCommandRouter.preview(instruction)
    }

    public static func shortcutSummary(_ instruction: String) -> String {
        let proposal = preview(instruction)
        return "iGentic Vorschau: \(proposal.title). Ziel: \(proposal.destination.rawValue). " +
            "Keine Aktion ausgeführt. \(proposal.explanation)"
    }

    /// Only shown by an explicit ShareLink; the operating system then lets
    /// the owner choose ChatGPT or another destination and review the text.
    public static func shareText(_ instruction: String) -> String? {
        let cleaned = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty && cleaned.count <= 512 else { return nil }
        let proposal = preview(cleaned)
        return "iGentic – manuell geteilter Auftrag:\n\(cleaned)\n\n" +
            "Vorschlag: \(proposal.title). Bitte nur beraten; keine iPhone-Aktion ohne separate Freigabe."
    }
}

#if os(iOS) && canImport(UIKit)
import UIKit

@MainActor
public enum AgentLoopDeviceStatusReader {
    public static func read() -> AgentLoopLocalStatus {
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        return AgentLoopLocalStatus(
            batteryFraction: device.batteryLevel,
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            osVersion: device.systemVersion
        )
    }
}
#endif
