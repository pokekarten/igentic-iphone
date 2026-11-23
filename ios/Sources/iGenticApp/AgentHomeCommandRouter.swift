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

    public var canOpenOwnedScreen: Bool {
        AgentHomeCapabilityCatalog.canNavigate(to: destination)
    }
}

/// One immutable, non-executing UI preview of the *entire* entered command.
/// A rejected oversized request never becomes a seemingly valid truncated
/// instruction in the chat-shaped interface.
public struct AgentHomeDisplayPreview: Equatable, Sendable {
    public let displayText: String
    public let proposal: AgentHomeProposal
}

/// A deterministic, offline-first demo router. This never invokes a model,
/// App Intent, system permission, device adapter, or external service.
///
/// Deliberately conservative: ambiguous or mixed instructions never acquire
/// an action-looking navigation suggestion. This is *not* an authorization
/// mechanism; actual work remains gated in the destination screens.
public enum AgentHomeCommandRouter {
    public static let maximumInputCharacters = 512
    public static let maximumInputBytes = 2048

    /// Match display and routing semantics. Do not trim a request before the
    /// complete instruction has been checked for unsupported operations.
    public static func previewForDisplay(_ input: String) -> AgentHomeDisplayPreview {
        let proposal = preview(input)
        let overLimit = input.count > maximumInputCharacters
            || input.utf8.count > maximumInputBytes
        return AgentHomeDisplayPreview(
            displayText: overLimit
                ? "Eingabe zu lang – nicht verarbeitet."
                : input,
            proposal: proposal
        )
    }

    private static let unsupportedActionTerms = [
        "losch", "entfern", "delete", "remove", "schick", "sende", "send ",
        "versend", "verschick", "weiterleit", "forward", "share ",
        "teile ", "teil mit", "post", "publiz", "veroffentlich",
        "anruf", "call ", "telefonier", "install", "deinstall",
        "systemeinstellung", "settings", "whatsapp", "sms", "mail",
        "e-mail", "email", "zahl", "uberweis", "bestell", "kauf",
        "sperr", "entsperr", "ander", "modifizier"
    ]

    public static func preview(_ input: String) -> AgentHomeProposal {
        // Do not silently preview only a harmless prefix of an overlong
        // command while hiding a later unsupported/unsafe instruction.
        guard !input.isEmpty, input.count <= maximumInputCharacters,
              input.utf8.count <= maximumInputBytes,
              !input.unicodeScalars.contains(where: { $0.value == 0 }) else {
            return unsupported()
        }
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive],
                     locale: Locale(identifier: "de_DE"))
            .lowercased()

        guard !normalized.isEmpty,
              !matches(normalized, unsupportedActionTerms) else {
            return unsupported()
        }

        // A single local destination is required. A request spanning multiple
        // categories is not silently narrowed to one apparently successful
        // capability.
        let reminder = matches(normalized, ["erinner", "remind", "reminder"])
        let offline = matches(normalized, ["offline", "notiz", "textentwurf",
                                           "vorlesen", "sprich", "ocr", "bildtext",
                                           "photo text"])
        let discovery = matches(normalized, ["entdecken", "explore", "discovery"])
        let diagnostics = matches(normalized, ["diagnos", "status", "verbindung",
                                               "connection"])
        let categories = [reminder, offline, discovery, diagnostics]
        guard categories.filter({ $0 }).count == 1 else { return unsupported() }

        if reminder {
            return .init(destination: .reminderDraft,
                         title: "Erinnerung vorbereiten",
                         explanation: "Öffnet den vorhandenen manuellen Entwurf. Text und Datum musst du dort prüfen bzw. eingeben; gespeichert wird erst nach separater Freigabe.")
        }
        if offline {
            return .init(destination: .offlineTools,
                         title: "Offline-Werkzeuge öffnen",
                         explanation: "Textentwurf, lokale Sprachausgabe und OCR eines von dir ausgewählten Bildes. Kein Cloud- oder Mac-Zwang.")
        }
        if discovery {
            return .init(destination: .discovery,
                         title: "Lokale Inhalte entdecken",
                         explanation: "Öffnet die mitgelieferte lokale Wissens- und Funktionsübersicht.")
        }
        return .init(destination: .diagnostics,
                     title: "Diagnose ansehen",
                     explanation: "Führt zum bestehenden Diagnosebildschirm. Eine Geräteverbindung oder erfolgreiche Aktion wird dabei nicht behauptet.")
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
