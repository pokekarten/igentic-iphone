import Foundation

/// An untrusted, user-opened link from a ChatGPT tool response. This is
/// navigation into our own app, never a permission or remote action receipt.
public enum ChatGPTHandoffRoute: String, CaseIterable, Identifiable {
    case diagnostics
    case discovery
    case reminderDraft = "reminder-draft"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .diagnostics: return "iGentic Diagnostics"
        case .discovery: return "Lokale Entdeckungen"
        case .reminderDraft: return "Erinnerungsentwurf"
        }
    }

    public static func parse(_ url: URL) -> Self? {
        // Exact string matching deliberately rejects credentials, arbitrary
        // URL parameters, external hosts, fragments and encoded path tricks.
        let prefix = "igentic://handoff/v1/"
        let raw = url.absoluteString
        guard raw.hasPrefix(prefix), let route = Self(rawValue: String(raw.dropFirst(prefix.count))),
              raw == prefix + route.rawValue else { return nil }
        return route
    }
}
