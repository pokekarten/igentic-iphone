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


// App-owned *observation* only: a fresh, fixed-schema receipt after the
// handoff sheet appears. This is never an approval or control capability.
public struct ChatGPTHandoffPreviewReceipt: Codable, Equatable {
    public let schema: Int
    public let eventID: String
    public let route: String
    public let view: String
    public let status: String

    public init(route: ChatGPTHandoffRoute, eventID: UUID = UUID()) {
        self.schema = 1
        self.eventID = eventID.uuidString.lowercased()
        self.route = route.rawValue
        self.view = "handoff-preview"
        self.status = "observed"
    }
}
