#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// An honest chat-shaped entry point for existing, owner-controlled tools.
/// No LLM calls, cross-app automation, background control or fake receipts.
public struct AgentHomePrototypeView: View {
    @State private var input = ""
    @State private var submitted = ""
    @State private var proposal: AgentHomeProposal?
    @State private var statusText: String?
    @State private var loopMessage: String?
    @State private var loopReady = false
    private let loopStore = AgentLoopShortcutExchangeStore()
    // Fixed own workflow name, no task, user ID, secrets, or result in the URL.
    private let loopShortcutURL = URL(string: "shortcuts://run-shortcut?name=iGentic%20KI%20Loop")!
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Lokal · Prototyp", systemImage: "iphone")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Was möchtest du auf deinem iPhone tun?")
                        .font(.title2).bold()
                    Text("Ein gemeinsamer Einstieg für unsere eigenen Werkzeuge. Vorschläge sind noch keine Ausführung.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Zum Beispiel: Erinnere mich morgen an die Pflanze", text: $input, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("igentic-agent-prompt")
                    Button("Lokalen Vorschlag prüfen") {
                        submitted = input
                        proposal = AgentLoopTaskBridge.preview(input)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("igentic-agent-preview")
                    Text("Nur regelbasierte Vorschau. Kein Sprachmodell, kein Netzwerk, kein App Intent und keine Systemaktion werden durch diesen Knopf ausgeführt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                if let proposal {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(submitted)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("igentic-agent-user-message")
                        Text(proposal.title).font(.headline)
                        Text(proposal.explanation).font(.subheadline)
                        if proposal.canOpenOwnedScreen {
                            destinationLink(for: proposal.destination)
                        } else {
                            Label("Keine freigegebene iPhone-Aktion", systemImage: "lock.shield")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        // Any bounded question may be *manually* shared for AI advice.
                        // Unsupported device commands remain unsupported and cannot run.
                        if let share = AgentLoopTaskBridge.shareText(submitted) {
                            ShareLink(item: share) {
                                Label("An ChatGPT oder andere KI-App weitergeben",
                                      systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("igentic-agent-share")
                            Text("Nur durch deine Auswahl im Teilen-Menü wird der angezeigte Auftrag weitergegeben. Keine automatische Cloud-Übertragung.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("igentic-agent-proposal")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("ChatGPT-Loop ohne API").font(.headline)
                    Text("Auftrag lokal vorbereiten → eigener Kurzbefehl → „Modell verwenden“ (ChatGPT) → KI-Antwort lokal empfangen.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("KI-Auftrag lokal vorbereiten") {
                        do {
                            _ = try loopStore.begin(task: input)
                            loopReady = true
                            loopMessage = "Auftrag lokal bereit. Der Kurzbefehl muss auf deinem iPhone eingerichtet sein."
                        } catch {
                            loopReady = false
                            loopMessage = "Nicht vorbereitet: Bitte einen gültigen Auftrag eingeben, sensible Angaben entfernen oder den vorherigen Auftrag in der KI-Antwort-Ansicht löschen."
                        }
                    }
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("igentic-loop-prepare")
                    if loopReady {
                        Link(destination: loopShortcutURL) {
                            Label("iGentic KI Loop in Kurzbefehle starten",
                                  systemImage: "play.circle")
                        }
                        .accessibilityIdentifier("igentic-loop-launch-shortcut")
                    }
                    Text(loopMessage ?? "Noch kein KI-Auftrag vorbereitet.")
                        .font(.footnote)
                        .accessibilityIdentifier("igentic-loop-prepare-result")
                    NavigationLink("KI-Antwort prüfen") { AgentLoopInboxView() }
                        .accessibilityIdentifier("igentic-loop-open-inbox")
                    Text("Vor dem Aufruf des ChatGPT-Erweiterungsmodells entscheidet deine Kurzbefehle-Konfiguration über das Senden. iGentic verschickt nichts selbst.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Button("iPhone-Status lokal lesen") {
                        statusText = AgentLoopDeviceStatusReader.read().shortcutSummary
                    }
                    .accessibilityIdentifier("igentic-agent-local-status")
                    if let statusText {
                        Text(statusText).font(.footnote)
                            .accessibilityIdentifier("igentic-agent-status-result")
                    }
                    Text("Akku, Stromsparmodus und iOS-Version werden nur auf diesem Gerät gelesen.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("Direkt öffnen").font(.headline)
                VStack(alignment: .leading, spacing: 12) {
                    NavigationLink("Offline-Werkzeuge") { OfflineToolsView() }
                    #if canImport(EventKit)
                    NavigationLink("Erinnerungsentwurf") { CreateReminderTaskView() }
                    #endif
                    NavigationLink("Entdecken") { ExploreView() }
                    Button("Diagnose") { dismiss() }
                }
                .buttonStyle(.bordered)
                Text("iGentic führt Aktionen ausschließlich über die bestehenden App- und Policy-Grenzen aus. Freigaben, Berechtigungen und Erfolgsnachweise bleiben an den jeweiligen Funktionen.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("iGentic Agent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let state = try? loopStore.snapshot() {
                let age = Date().timeIntervalSince(state.createdAt)
                loopReady = !state.isAnswered
                    && age >= 0 && age <= AgentLoopShortcutExchangeStore.expiration
            } else {
                loopReady = false
            }
        }
    }

    @ViewBuilder
    private func destinationLink(for destination: AgentHomeDestination) -> some View {
        switch destination {
        case .offlineTools:
            NavigationLink("Werkzeug öffnen") { OfflineToolsView() }
        case .reminderDraft:
            #if canImport(EventKit)
            NavigationLink("Entwurf öffnen") { CreateReminderTaskView() }
            #else
            Text("Erinnerungen sind hier nicht verfügbar.")
            #endif
        case .discovery:
            NavigationLink("Entdecken öffnen") { ExploreView() }
        case .diagnostics:
            Button("Zur Diagnose") { dismiss() }
        case .unsupported:
            EmptyView()
        }
    }
}
#endif
