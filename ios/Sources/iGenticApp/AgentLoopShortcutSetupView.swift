#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// Human-approved setup instructions. No access to the Shortcuts library,
/// Siri conversations, ChatGPT tokens or automated iOS UI control.
public struct AgentLoopShortcutSetupView: View {
    @State private var localStage: AgentLoopShortcutSetup.LocalStage = .noTask
    @State private var storageError = false
    private let store = AgentLoopShortcutExchangeStore()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("ChatGPT ohne API einrichten", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.title3).bold()
                Text("iGentic → Kurzbefehle → ChatGPT oder lokales Modell → iGentic. Kein eigener OpenAI-API-Schlüssel erforderlich.")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Kurzbefehl anlegen").font(.headline)
                    Text("Erstelle einen eigenen Kurzbefehl mit exakt diesem Namen:")
                    Text(AgentLoopShortcutSetup.primaryShortcutName)
                        .font(.headline.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("igentic-loop-setup-name")
                    Link(destination: AgentLoopShortcutSetup.createURL) {
                        Label("Neuen Kurzbefehl öffnen", systemImage: "plus.square")
                    }
                    .accessibilityIdentifier("igentic-loop-setup-create")
                    Text("Apple öffnet nur den Editor. Die Aktionen musst du selbst hinzufügen und für ChatGPT gegebenenfalls zustimmen.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("2. Diese vier Aktionen verbinden").font(.headline)
                    ForEach(AgentLoopShortcutSetup.actions.indices, id: \.self) { index in
                        Text(AgentLoopShortcutSetup.actions[index])
                            .font(.subheadline)
                    }
                }
                .accessibilityIdentifier("igentic-loop-setup-steps")

                VStack(alignment: .leading, spacing: 8) {
                    Text("3. Lokal prüfen und starten").font(.headline)
                    Text(localStage.explanation)
                        .accessibilityIdentifier("igentic-loop-setup-local-state")
                    if storageError {
                        Text("Lokaler Auftrag konnte nicht gelesen werden. Kein Start bestätigt.")
                            .foregroundStyle(.red).font(.caption)
                    }
                    Button("Lokalen Zustand aktualisieren") { refresh() }
                    Link(destination: AgentLoopShortcutSetup.runURL) {
                        Label("Vorhandenen KI-Kurzbefehl starten", systemImage: "play.circle")
                    }
                    .accessibilityIdentifier("igentic-loop-setup-run")
                    Text("Ein Klick öffnet Kurzbefehle. Das ist kein Nachweis, dass der Kurzbefehl existiert, ChatGPT aufgerufen wurde oder eine Aktion ausgeführt wurde.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("4. Ergebnis prüfen").font(.headline)
                    NavigationLink("Lokale KI-Antwort öffnen") { AgentLoopInboxView() }
                    Text("Modellantworten sind nicht vertrauenswürdig und lösen keine iPhone-Befehle aus. Lösche einen fertigen oder abgelaufenen Auftrag in der Antwortansicht.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Optionaler Entwicklertest").font(.headline)
                    if let url = AgentLoopShortcutLaunch.url {
                        Link(destination: url) {
                            Label("Separaten 2-Turn-Werkzeugtest öffnen",
                                  systemImage: "wrench.and.screwdriver")
                        }
                    }
                    Text("Dieser andere Kurzbefehl prüft nur sichere Vorschläge. Er ist nicht der normale iGentic KI Loop.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Text("iGentic kann weder erkennen, ob ChatGPT in Apples Einstellungen aktiviert ist, noch einen privaten Kurzbefehl automatisch installieren. Nutze bei fehlendem ChatGPT-Erweiterungsmodell ersatzweise das lokale Modell, sofern es auf deinem iPhone verfügbar ist.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("KI-Loop einrichten")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refresh() }
    }

    private func refresh() {
        do {
            localStage = AgentLoopShortcutSetup.localStage(
                try store.snapshot(), now: Date()
            )
            storageError = false
        } catch {
            localStage = .noTask
            storageError = true
        }
    }
}
#endif
