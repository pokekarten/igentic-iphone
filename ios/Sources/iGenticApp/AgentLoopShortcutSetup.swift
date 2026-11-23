import Foundation

/// Authoritative, user-facing configuration for the real API-free Shortcuts
/// round trip. Neither URL creates a Shortcut silently or transports user text.
public enum AgentLoopShortcutSetup {
    public static let primaryShortcutName = "iGentic KI Loop"
    public static let researchShortcutName = "iGentic ChatGPT Loop Test"
    public static let createURL = URL(string: "shortcuts://create-shortcut")!

    public static var runURL: URL {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: primaryShortcutName)
        ]
        return components.url!
    }

    // These are names/actions the owner can find in the system Shortcuts editor.
    // We cannot query or silently populate a user's private Shortcut library.
    public static let actions = [
        "1. iGentic KI-Auftrags-ID lesen → Ergebnis als Variable „Auftrags-ID“ merken",
        "2. iGentic KI-Prompt lesen",
        "3. Modell verwenden: Erweiterungsmodell → ChatGPT; Eingabe: KI-Prompt; Nachfragen deaktivieren",
        "4. iGentic KI-Antwort übernehmen: Modellantwort aus Schritt 3, Auftrags-ID aus Schritt 1",
        "5. App öffnen → iGentic Diagnostics; dann „KI-Antwort prüfen“"
    ]

    public enum LocalStage: Equatable {
        case noTask
        case waitingForAnswer
        case answerAvailable
        case expired
        case invalidTimestamp

        public var explanation: String {
            switch self {
            case .noTask: return "Kein iGentic-KI-Auftrag vorbereitet."
            case .waitingForAnswer: return "Ein lokaler Auftrag wartet auf eine Modellantwort."
            case .answerAvailable: return "Eine Modellantwort liegt lokal zur manuellen Prüfung bereit."
            case .expired: return "Der offene Auftrag ist abgelaufen und muss manuell gelöscht werden."
            case .invalidTimestamp: return "Lokaler Auftragszeitpunkt ungültig; keine Ausführung."
            }
        }
    }

    @MainActor
    public static func localStage(
        _ exchange: AgentLoopExchange?, now: Date
    ) -> LocalStage {
        guard let exchange else { return .noTask }
        guard now.timeIntervalSince(exchange.createdAt) >= 0 else {
            return .invalidTimestamp
        }
        if exchange.isAnswered { return .answerAvailable }
        if now.timeIntervalSince(exchange.createdAt)
            > AgentLoopShortcutExchangeStore.expiration {
            return .expired
        }
        return .waitingForAnswer
    }
}
