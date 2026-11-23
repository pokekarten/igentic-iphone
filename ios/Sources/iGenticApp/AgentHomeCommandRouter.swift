import Foundation

/// Navigation-only routes for the first agent home. They are not executable tools.
public enum AgentHomeDestination: String, Sendable, Equatable {
    case offlineTools
    case reminderDraft
    case discovery
    case diagnostics
    case unsupported
}

public struct AgentHomeProposal: Sendable, Equatable {
    public let destination: AgentHomeDestination
    public let title: String
    public let explanation: String

    public var canOpenOwnedScreen: Bool { destination != .unsupported }
}

/// A deterministic, offline-first demo router. This never invokes a model,
/// App Intent, system permission, device adapter, or external service.
public enum AgentHomeCommandRouter {
    public static func preview(_ input: String) -> AgentHomeProposal {
        let normalized = String(input.prefix(512))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "de_DE"))
            .lowercased()

        guard !normalized.isEmpty else { return unsupported() }

        // Do not make a command about system changes, sending, deleting or
        // third-party apps look like an executable on-device capability.
        if matches(normalized, ["losch", "delete", "send", "sende", "versend",
                                "anruf", "call ", "install", "systemeinstellung",
                                "settings", "whatsapp", "sms", "mail verschick"]) {
            return unsupported()
        }
        if matches(normalized, ["erinner", "remind", "reminder"]) {
            return .init(destination: .reminderDraft,
                         title: "Erinnerung vorbereiten",
                         explanation: "Öffnet den vorhandenen manuellen Entwurf. Text und Datum musst du dort prüfen bzw. eingeben; gespeichert wird erst nach separater Freigabe.")
        }
        if matches(normalized, ["offline", "notiz", "textentwurf", "vorlesen",
                                "sprich", "ocr", "bildtext", "photo text"]) {
            return .init(destination: .offlineTools,
                         title: "Offline-Werkzeuge öffnen",
                         explanation: "Textentwurf, lokale Sprachausgabe und OCR eines von dir ausgewählten Bildes. Kein Cloud- oder Mac-Zwang.")
        }
        if matches(normalized, ["entdecken", "explore", "discovery"]) {
            return .init(destination: .discovery,
                         title: "Lokale Inhalte entdecken",
                         explanation: "Öffnet die mitgelieferte lokale Wissens- und Funktionsübersicht.")
        }
        if matches(normalized, ["diagnos", "status", "verbindung", "connection"]) {
            return .init(destination: .diagnostics,
                         title: "Diagnose ansehen",
                         explanation: "Führt zum bestehenden Diagnosebildschirm. Eine Geräteverbindung oder erfolgreiche Aktion wird dabei nicht behauptet.")
        }
        return unsupported()
    }

    private static func matches(_ value: String, _ tokens: [String]) -> Bool {
        tokens.contains(where: value.contains)
    }

    private static func unsupported() -> AgentHomeProposal {
        .init(destination: .unsupported,
              title: "Noch kein sicherer Aktionsweg",
              explanation: "Für diesen Auftrag ist im Prototyp keine freigegebene Funktion hinterlegt. Es wurde nichts ausgeführt oder gesendet.")
    }
}
