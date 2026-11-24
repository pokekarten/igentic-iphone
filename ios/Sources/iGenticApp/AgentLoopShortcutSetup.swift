import Foundation

/// Authoritative, user-facing configuration for the real API-free Shortcuts
/// round trip. No launcher URL creates a Shortcut or transports user text.
public enum AgentLoopShortcutSetup {
    public static let primaryShortcutName = "iGentic KI Loop"
    public static let projectChatShortcutName = "iGentic Projekt-Chat"
    public static let researchShortcutName = "iGentic ChatGPT Loop Test"
    public static let createURL = URL(string: "shortcuts://create-shortcut")!

    public static var runURL: URL { runShortcutURL(named: primaryShortcutName) }

    /// A separately owner-configured ChatGPT project-chat launcher.
    /// Opening it does not return a ChatGPT answer or execute an iPhone task.
    public static var projectChatRunURL: URL {
        runShortcutURL(named: projectChatShortcutName)
    }

    private static func runShortcutURL(named name: String) -> URL {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        return components.url!
    }

    // Owner-configured, project-aware interactive chat. The ChatGPT iOS
    // action owns the project selector; iGentic cannot select a project,
    // send a message, or prove a successful chat using the fixed launcher.
    public static let projectChatActions = [
        "1. ChatGPT-Aktion „Start chat in project“ hinzufügen und das gewünschte vorhandene iGentic-iPhone-Projekt ausdrücklich auswählen.",
        "2. Optional die ChatGPT-Aktion „Voice Mode“ direkt danach hinzufügen, um im neu gestarteten Projektchat zu sprechen.",
        "3. Kurzbefehl exakt „iGentic Projekt-Chat“ nennen. Danach mit Siri oder aus iGentic starten und prüfen, dass das richtige Projekt geöffnet wird."
    ]

    // Independent read-only status experiment. It is NOT the free-form
    // one-answer KI Loop and cannot write reminders or control other apps.
    public static let statusLoopActions = [
        "1. iGentic-Aktion „iGentic Status-Loop starten“ ausführen; die JSON-Antwort als Wörterbuch lesen.",
        "2. taskId als eigene Kurzbefehle-Variable merken. Nur den Feldwert prompt an ein optionales „Modell verwenden“ weitergeben.",
        "3. iGentic-Aktion „iGentic Status-Loop fortsetzen“ aufrufen: taskId und die rohe Modellantwort (z. B. {\"action\":\"status.read\"}). Für nur eine Modellrunde „Nach Statusabfrage lokal abschließen“ aktivieren. Bei finished ist der Auftrag abgeschlossen.",
        "4. Beobachtung lokal anzeigen. Nur wenn du es ausdrücklich willst, darf dein selbst eingerichteter Kurzbefehl sie an ChatGPT oder ein anderes externes Modell weitergeben.",
        "5. Nur bei awaitingFinish: optional zweite Modellrunde mit nextPrompt starten oder direkt lokal den festen Abschluss {\"action\":\"finish\"} benutzen.",
        "6. „iGentic Status-Loop fortsetzen“ erneut mit derselben taskId und dem Abschluss aufrufen; Status finished prüfen.",
        "7. Bei Fehler, Zeitablauf oder ungewisser Lesephase nicht automatisch wiederholen. Nach Ablauf von fünf Minuten einen frischen Auftrag starten."
    ]

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
