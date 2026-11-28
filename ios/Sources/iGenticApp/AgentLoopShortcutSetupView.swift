#if os(iOS) && canImport(SwiftUI)
import SwiftUI
import AppIntents

/// Human-approved setup instructions. No access to the Shortcuts library,
/// Siri conversations, ChatGPT tokens or automated iOS UI control.
public struct AgentLoopShortcutSetupView: View {
    @State private var localStage: AgentLoopShortcutSetup.LocalStage = .noTask
    @State private var storageError = false
    @State private var statusLoopStageText = "Noch nicht geprüft"
    private let store = AgentLoopShortcutExchangeStore()

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label("ChatGPT ohne API einrichten", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.title3).bold()
                Text("iGentic → Kurzbefehle → ChatGPT oder lokales Modell → iGentic. Kein eigener OpenAI-API-Schlüssel erforderlich.")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Automatisch mit iGentic verfügbar").font(.headline)
                    Text("Öffne die App-Kurzbefehle und wähle „ChatGPT-Beispielaufgabe“. Weitere Aktionen lesen den iPhone-Status, prüfen die Diagnose oder bereiten einen lokalen Auftrag vor.")
                    if let url = AgentLoopShortcutSetup.chatGPTExampleURL {
                        Link("Beispielaufgabe direkt in ChatGPT öffnen", destination: url)
                            .accessibilityIdentifier("igentic-chatgpt-example")
                    }
                    ShortcutsLink()
                        .accessibilityIdentifier("igentic-native-app-shortcuts")
                    Text("Diese nativen Aktionen benötigen keinen Import. Die weiteren iGentic-Schritte für den KI-Loop findest du als einzelne Aktionen im Kurzbefehle-Editor. Die Beispielaufgabe öffnet ChatGPT mit einer festen Frage zu einer leeren Testliste.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("igentic-auto-shortcuts-guide")

                VStack(alignment: .leading, spacing: 6) {
                    Text("1. ChatGPT-Kurzbefehl einmalig verbinden").font(.headline)
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
                    Text("2. Diese fünf Schritte verbinden").font(.headline)
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
                    Text("Lokaler Status-Loop").font(.headline)
                    Text("Unter App-Kurzbefehle → iGentic Diagnostics startet „iGentic Status-Loop“ eine einzelne lokale Statusabfrage mit Abschluss. Der App-Kurzbefehl gehört zum Build und braucht keinen Import und kein KI-Modell.")
                        .font(.subheadline)
                    Text("Optional: eigener Kurzbefehl mit Modellvorschlag").font(.headline)
                    Text("Dieser unabhängige Test verarbeitet einen Modellvorschlag, liest danach auf dem iPhone nur Akku, Stromsparmodus und iOS-Version und akzeptiert anschließend ausschließlich den Abschluss. Der Zustand bleibt über getrennte Kurzbefehle-Aufrufe erhalten.")
                        .font(.subheadline)
                    ForEach(AgentLoopShortcutSetup.statusLoopActions.indices, id: \.self) { index in
                        Text(AgentLoopShortcutSetup.statusLoopActions[index])
                            .font(.subheadline)
                    }
                    Text(statusLoopStageText)
                        .font(.caption)
                        .accessibilityIdentifier("igentic-shortcuts-status-loop-state")
                    Button("Status-Loop-Zustand lokal prüfen") { refreshStatusLoop() }
                        .accessibilityIdentifier("igentic-shortcuts-status-loop-refresh")
                    Text("Die erste Statusbeobachtung erscheint nur in der Ausgabe deiner eigenen iGentic-Aktion. Erst dein selbst eingerichteter Kurzbefehl könnte sie an ein externes KI-Modell schicken. Eine solche Weitergabe findet nicht automatisch in iGentic statt.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("igentic-shortcuts-status-loop-guide")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Separat: ChatGPT-Projektchat öffnen").font(.headline)
                    Text("Erstelle in Kurzbefehle einen zweiten Ablauf namens:")
                    Text(AgentLoopShortcutSetup.projectChatShortcutName)
                        .font(.headline.monospaced())
                        .textSelection(.enabled)
                        .accessibilityIdentifier("igentic-project-chat-shortcut-name")
                    Text("Diese Einrichtung ist unabhängig vom KI-Loop oben. Das ChatGPT-Projekt wird im Apple-Kurzbefehle-Editor gewählt, nicht über einen iGentic-Link.")
                        .font(.subheadline)
                    ForEach(AgentLoopShortcutSetup.projectChatActions.indices, id: \.self) { index in
                        Text(AgentLoopShortcutSetup.projectChatActions[index])
                            .font(.subheadline)
                    }
                    Link(destination: AgentLoopShortcutSetup.createURL) {
                        Label("Projektchat-Kurzbefehl anlegen", systemImage: "plus.square")
                    }
                    .accessibilityIdentifier("igentic-project-chat-create")
                    Link(destination: AgentLoopShortcutSetup.projectChatRunURL) {
                        Label("iGentic-Projektchat über Kurzbefehle öffnen",
                              systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityIdentifier("igentic-project-chat-launch")
                    Text("Der Startlink enthält nur den festen Kurzbefehlnamen. Er prüft weder Installation noch Projektwahl und schickt keine KI-Antwort an iGentic. Es entsteht ein NEUER Chat im Projekt, nicht die exakte Fortsetzung eines alten Threads. Um dieselbe Unterhaltung fortzusetzen, öffne den bestehenden Chat direkt in ChatGPT. Für einen lokalen Rückkanal dient der getrennte iGentic KI Loop.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("igentic-project-chat-guide")

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

                Text("Die vier eingebauten App Shortcuts installiert iOS automatisch mit der App. Den zusätzlichen mehrstufigen ChatGPT-Kurzbefehl kann iGentic nicht still in deine private Kurzbefehle-Sammlung schreiben. Ebenso kann die App die ChatGPT-Aktivierung nicht zuverlässig erkennen. Wenn das Erweiterungsmodell fehlt, verwende ein verfügbares lokales Modell.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("KI-Loop einrichten")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refresh()
            refreshStatusLoop()
        }
    }

    private func refreshStatusLoop() {
        do {
            if let snapshot = try AgentLoopStatusShortcutStore().snapshotForOwner() {
                statusLoopStageText = "Lokaler Status-Loop: " + snapshot.stage.ownerStatusText
                    + "\nAuftrags-ID: " + snapshot.taskID
            } else {
                statusLoopStageText = "Lokaler Status-Loop: kein Auftrag"
            }
        } catch {
            statusLoopStageText = "Lokaler Status-Loop nicht lesbar oder gesperrt. Keine Wiederholung starten."
        }
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
