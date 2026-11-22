import SwiftUI
import AVFoundation
import EventKit

enum WorkAction: String, CaseIterable {
    case status, draft, speak, reminder
    var title: String {
        switch self {
        case .status: "Gerätestatus"
        case .draft: "Textentwurf"
        case .speak: "Vorlesen"
        case .reminder: "Erinnerung"
        }
    }
}

struct WorkspaceJob: Identifiable {
    let id: UUID
    let action: WorkAction
    let text: String
    init(id: UUID = UUID(), action: WorkAction = .status, text: String = "") {
        self.id = id; self.action = action; self.text = text
    }

    init?(link: URL) {
        guard link.absoluteString.utf8.count <= 2048,
              let c = URLComponents(url: link, resolvingAgainstBaseURL: false),
              c.scheme == "fieldglass", c.host == "workspace", c.path == "/v1",
              c.user == nil, c.password == nil, c.port == nil, c.fragment == nil,
              let items = c.queryItems, Set(items.map(\.name)) == ["id","action","text"], items.count == 3,
              let id = UUID(uuidString: items.first(where: { $0.name == "id" })?.value ?? ""),
              let action = WorkAction(rawValue: items.first(where: { $0.name == "action" })?.value ?? ""),
              let text = items.first(where: { $0.name == "text" })?.value,
              text.utf8.count <= 480, text.rangeOfCharacter(from: .controlCharacters) == nil,
              action == .status ? text.isEmpty : !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        self.init(id: id, action: action, text: text)
    }
}

private final class Speaker: ObservableObject {
    let synth = AVSpeechSynthesizer()
    func speak(_ text: String) {
        synth.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "de-DE")
        synth.speak(utterance)
    }
}

struct WorkspaceActions: View {
    let initial: WorkspaceJob
    @State private var action: WorkAction
    @State private var text: String
    @State private var status: String?
    @State private var statusDraft: String?
    @State private var confirming = false
    @State private var saving = false
    @State private var attempted = false
    @StateObject private var speaker = Speaker()
    @Environment(\.dismiss) private var dismiss

    init(job: WorkspaceJob) {
        initial = job; _action = State(initialValue: job.action); _text = State(initialValue: job.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Werkzeug", selection: $action) {
                        ForEach(WorkAction.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.disabled(saving)
                    if action != .status {
                        TextField("Text", text: $text, axis: .vertical).lineLimit(2...6).disabled(saving)
                    }
                }
                Section {
                    switch action {
                    case .status:
                        Button("Status erfassen") {
                            let info = ProcessInfo.processInfo
                            let heat: String
                            switch info.thermalState {
                            case .nominal: heat = "Normal"
                            case .fair: heat = "Erhöht"
                            case .serious: heat = "Hoch"
                            default: heat = "Kritisch oder unbekannt"
                            }
                            status = "iOS \(UIDevice.current.systemVersion) · Wärme: \(heat) · Stromsparmodus: \(info.isLowPowerModeEnabled ? "Ein" : "Aus")"
                        }
                    case .draft:
                        Button("Entwurf übernehmen") { statusDraft = text; status = "Entwurf bereit zum Teilen." }
                            .disabled(!validText)
                        if let statusDraft { ShareLink("Entwurf teilen", item: statusDraft) }
                    case .speak:
                        Button("Vorlesen starten") { speaker.speak(text); status = "Sprachausgabe angefordert." }.disabled(!validText)
                        Button("Vorlesen stoppen") { speaker.synth.stopSpeaking(at: .immediate); status = "Sprachausgabe gestoppt." }
                    case .reminder:
                        Button("Speichern prüfen") { confirming = true }.disabled(!validText || saving || attempted)
                    }
                    if let status { Text(status).accessibilityIdentifier("actionStatus") }
                }
                if action == .draft { LocalLanguage(text: $text) }
            }
            .navigationTitle("Werkzeuge")
            .toolbar { Button("Fertig") { dismiss() }.disabled(saving) }
            .onChange(of: text) { resetResult() }.onChange(of: action) { resetResult() }
            .onDisappear { speaker.synth.stopSpeaking(at: .immediate) }
            .interactiveDismissDisabled(saving)
            .alert("In der Standardliste speichern?", isPresented: $confirming) {
                Button("Abbrechen", role: .cancel) {}
                Button("Erinnerung speichern") {
                    let title = text
                    saving = true
                    Task { await saveReminder(title); saving = false }
                }
            } message: { Text(text) }
        }
    }

    private var validText: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.utf8.count <= 480 }
    private func resetResult() {
        statusDraft = nil; status = nil; attempted = false; speaker.synth.stopSpeaking(at: .immediate)
    }

    @MainActor private func saveReminder(_ title: String) async {
        let store = EKEventStore()
        do {
            guard try await store.requestFullAccessToReminders() else {
                status = "Der Zugriff auf Erinnerungen wurde abgelehnt."; return
            }
            guard let calendar = store.defaultCalendarForNewReminders() else {
                status = "Keine Standardliste verfügbar."; return
            }
            let entry = EKReminder(eventStore: store)
            entry.title = title; entry.calendar = calendar
            let folder = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("reminder-attempts")
            guard try ReminderAttempt.reserve(initial.id, in: folder) else {
                attempted = true; status = "Für diesen Auftrag besteht ein Speicherversuch. Bitte in Erinnerungen prüfen."; return
            }
            attempted = true
            try store.save(entry, commit: true)
            status = store.calendarItem(withIdentifier: entry.calendarItemIdentifier) is EKReminder
                ? "In der Standardliste gespeichert und zurückgelesen."
                : "Speichern gemeldet. Bitte in Erinnerungen prüfen."
        } catch {
            status = attempted ? "Ergebnis unklar. Bitte in Erinnerungen prüfen." : "Der Zugriff ist fehlgeschlagen."
        }
    }
}
