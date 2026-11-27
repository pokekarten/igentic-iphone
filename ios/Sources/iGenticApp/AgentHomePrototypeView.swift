#if os(iOS) && canImport(SwiftUI)
import SwiftUI

/// An honest chat-shaped entry point for existing, owner-controlled tools.
/// Explicit local-model diagnostic workflow; no cross-app automation,
/// background control or fake receipts.
public struct AgentHomePrototypeView: View {
    @State private var input = ""
    @FocusState private var isPromptFocused: Bool
    @State private var submitted = ""
    @State private var proposal: AgentHomeProposal?
    @State private var statusText: String?
    @State private var nativeLoopTestText: String?
    @State private var loopMessage: String?
    @State private var loopReady = false
    @State private var diagnosticRun: Task<Void, Never>?
    @State private var diagnosticReport: AgentLoopDiagnosticReport?
    @State private var diagnosticCheckpoint: AgentLoopDiagnosticCheckpoint?
    @State private var diagnosticJournalBlocked = false
    private let diagnosticJournal = AgentLoopDiagnosticJournal()
    private let loopStore = AgentLoopShortcutExchangeStore()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

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

                // Keep the read-only status reachable without traversing
                // the long Shortcuts and project-chat instructions below.
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

                NavigationLink("Gerätesteuerung – direkt auf dem iPhone") {
                    StandaloneDeviceToolsView()
                }
                .accessibilityIdentifier("igentic-agent-device-tools")
                Text("Eigene Gerätefunktionen bleiben auch ohne externe KI verfügbar.")
                    .font(.caption).foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Zum Beispiel: Erinnere mich morgen an die Pflanze", text: $input, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .focused($isPromptFocused)
                        .accessibilityIdentifier("igentic-agent-prompt")
                    Button("Lokalen Vorschlag prüfen") {
                        isPromptFocused = false
                        let result = AgentHomeCommandRouter.previewForDisplay(input)
                        submitted = result.displayText
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
                        Link(destination: AgentLoopShortcutSetup.runURL) {
                            Label("iGentic KI Loop in Kurzbefehle starten",
                                  systemImage: "play.circle")
                        }
                        .accessibilityIdentifier("igentic-loop-launch-shortcut")
                    }
                    Text(loopMessage ?? "Noch kein KI-Auftrag vorbereitet.")
                        .font(.footnote)
                        .accessibilityIdentifier("igentic-loop-prepare-result")
                    NavigationLink("ChatGPT-Loop einrichten") { AgentLoopShortcutSetupView() }
                        .accessibilityIdentifier("igentic-loop-open-setup")
                    NavigationLink("KI-Antwort prüfen") { AgentLoopInboxView() }
                        .accessibilityIdentifier("igentic-loop-open-inbox")
                    Text("Vor dem Aufruf des ChatGPT-Erweiterungsmodells entscheidet deine Kurzbefehle-Konfiguration über das Senden. iGentic verschickt nichts selbst.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 9) {
                    Text("ChatGPT-Projektchat").font(.headline)
                    Text("Starte einen neuen Chat im zuvor im Kurzbefehl ausgewählten Projekt. Projektanweisungen und verfügbare Projektquellen bleiben dort nutzbar; der bisherige Chatverlauf wird nicht vollständig kopiert.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Link(destination: AgentLoopShortcutSetup.projectChatRunURL) {
                        Label("Neuen iGentic-Projektchat starten", systemImage: "bubble.left.and.text.bubble.right")
                    }
                    .accessibilityIdentifier("igentic-agent-project-chat-launch")
                    NavigationLink("Projekt-Kurzbefehl einmalig einrichten") {
                        AgentLoopShortcutSetupView()
                    }
                    .accessibilityIdentifier("igentic-agent-project-chat-setup")
                    Text("Nur ein fester Shortcutname wird geöffnet. Der Text aus dem Eingabefeld wird nicht mitgesendet, und iGentic kann die ChatGPT-Projektwahl ohne echten iPhone-Test nicht bestätigen.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Eigener Offline-Agenten-Loop").font(.headline)
                    Button("Zwei sichere Schritte lokal testen") {
                        // Fixed, public-safe proposals; no model or external client invoked.
                        let runner = AgentLoopNativeReadOnlySession(
                            statusReader: { AgentLoopDeviceStatusReader.read() }
                        )
                        let observed = runner.accept(modelReply: #"{"action":"status.read"}"#)
                        let finished = runner.accept(modelReply: #"{"action":"finish"}"#)
                        if observed.stage == .awaitingFinish && finished.stage == .finished,
                           let summary = observed.localObservation {
                            nativeLoopTestText = "Lokal geprüft (zwei Schritte): \(summary) Keine KI angerufen, keine Fernaktion und keine Freigabe erteilt."
                        } else {
                            nativeLoopTestText = "Lokaler Test gestoppt. Keine Fernaktion ausgeführt."
                        }
                    }
                    .accessibilityIdentifier("igentic-agent-native-loop-test")
                    if let nativeLoopTestText {
                        Text(nativeLoopTestText).font(.footnote)
                            .accessibilityIdentifier("igentic-agent-native-loop-result")
                    }
                    Text("Nur feste Testvorschläge und eine eigene Statusabfrage. Kein ChatGPT-Aufruf, keine Datenweitergabe und keine anderen iPhone-Apps.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Lokaler Agent: Diagnosebericht").font(.headline)
                    Button("Diagnose ohne Sprachmodell ausführen") {
                        startDiagnostic(.extended, deterministic: true)
                    }
                    .disabled(diagnosticRun != nil || scenePhase != .active || diagnosticJournalBlocked || diagnosticCheckpoint?.stage == .running || !(diagnosticCheckpoint?.queuedTickets.isEmpty ?? true))
                    .accessibilityIdentifier("igentic-agent-deterministic-start")
                    Text("Feste lokale Planung, dieselben geprüften Werkzeuge und dasselbe Journal. Funktioniert auch ohne verfügbare KI; kein automatischer Providerwechsel.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Das Apple-Sprachmodell plant mehrere lokale Schritte. iGentic prüft und führt ausschließlich eigene Status- und KI-Bereitschaftsabfragen aus und erstellt daraus einen Bericht.")
                        .font(.footnote)
                    Button("Lokalen KI-Agenten starten") {
                        startDiagnostic(.basic)
                    }
                    .disabled(diagnosticRun != nil || scenePhase != .active || diagnosticJournalBlocked || diagnosticCheckpoint?.stage == .running || !(diagnosticCheckpoint?.queuedTickets.isEmpty ?? true))
                    .accessibilityIdentifier("igentic-agent-diagnostic-start")
                    Button("Erweiterten Fähigkeitsbericht erstellen") {
                        startDiagnostic(.extended)
                    }
                    .disabled(diagnosticRun != nil || scenePhase != .active || diagnosticJournalBlocked || diagnosticCheckpoint?.stage == .running || !(diagnosticCheckpoint?.queuedTickets.isEmpty ?? true))
                    .accessibilityIdentifier("igentic-agent-diagnostic-extended")
                    Text("Lokale Aufgabenwarteschlange").font(.subheadline).bold()
                    HStack {
                        Button("Basis einreihen") { enqueueDiagnostic(.basic) }
                        Button("Erweitert einreihen") { enqueueDiagnostic(.extended) }
                    }
                    .disabled(diagnosticRun != nil || scenePhase != .active || diagnosticJournalBlocked
                              || diagnosticCheckpoint?.stage == .running || (diagnosticCheckpoint?.queuedTickets.count ?? 0) >= 4)
                    if let tickets = diagnosticCheckpoint?.queuedTickets, !tickets.isEmpty {
                        ForEach(tickets, id: \.id) { ticket in
                            HStack {
                                Text(ticket.goal == .basic ? "Basisdiagnose" : "Fähigkeitsbericht")
                                Spacer()
                                Button("Entfernen") { removeQueuedDiagnostic(ticket.id) }
                                    .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active
                                              || diagnosticCheckpoint?.stage == .running)
                            }
                        }
                        Button("Warteschlange lokal abarbeiten") { runDiagnosticQueue() }
                            .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active
                                      || diagnosticCheckpoint?.stage == .running)
                        Button("Warteschlange ohne Sprachmodell abarbeiten") { runDiagnosticQueue(deterministic: true) }
                            .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active || diagnosticCheckpoint?.stage == .running)
                            .accessibilityIdentifier("igentic-agent-deterministic-queue")
                        Text("Bis zu vier Diagnoseaufträge nacheinander, nur bei aktiver App. Bei Fehler oder Abbruch bleiben weitere Aufträge in der Warteschlange.")
                            .font(.caption)
                    }
                    if diagnosticJournalBlocked {
                        Text("Aufgabenjournal nicht verfügbar. Keine neue Ausführung.").font(.caption)
                    }
                    if let saved = diagnosticCheckpoint {
                        Text("Letzter Auftrag: \(saved.steps.count) bestätigte Schritte · " +
                             (saved.stage == .queued ? "wartet" : saved.stage == .running ? "unterbrochen" : saved.stage == .completed ? "abgeschlossen" : "gestoppt"))
                            .font(.caption)
                        Text("Journal-ID: " + saved.id.uuidString.lowercased())
                            .font(.caption)
                            .accessibilityIdentifier("igentic-agent-journal-id")
                        if saved.stage == .running {
                            Button("Unterbrochene Diagnose neu starten") {
                                startDiagnostic(saved.goal, restartID: saved.id)
                            }
                            .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active)
                            Button("Unterbrochene Diagnose ohne Sprachmodell neu starten") {
                                startDiagnostic(saved.goal, restartID: saved.id, deterministic: true)
                            }
                            .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active)
                            Button("Unterbrochenen Auftrag ohne Wiederholung beenden") {
                                abandonDiagnostic(saved.id)
                            }
                            .disabled(diagnosticRun != nil || diagnosticJournalBlocked || scenePhase != .active)
                            .accessibilityIdentifier("igentic-agent-abandon-interrupted")
                            Text("Beenden führt keine Werkzeuge aus. Bestätigte Schritte und wartende Aufträge bleiben erhalten.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if diagnosticRun != nil {
                        ProgressView("Lokale Planung läuft")
                        Button("Abbrechen") { stopDiagnostic() }
                    }
                    if let result = diagnosticReport {
                        Text(result.localReport ?? "Gestoppt: \(result.outcome.rawValue)")
                            .font(.footnote)
                            .accessibilityIdentifier("igentic-agent-diagnostic-report")
                        if let attemptID = result.attemptID {
                            Text("Ergebnis-ID: " + attemptID.uuidString.lowercased())
                                .font(.caption)
                                .accessibilityIdentifier("igentic-agent-report-id")
                        }
                        Text("Bestätigte Schritte: \(result.steps.count) · Modellaufrufe: \(result.modelTurns) · Keine externe Übertragung")
                            .font(.caption)
                    }
                }
                .onDisappear { stopDiagnostic() }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active { stopDiagnostic() } else if diagnosticRun == nil { refreshDiagnosticJournal() }
                }

                Text("Direkt öffnen").font(.headline)
                VStack(alignment: .leading, spacing: 12) {
                    #if canImport(Vision) && canImport(FoundationModels) && canImport(PhotosUI)
                    NavigationLink("Dokumenten-Agent") { AgentLoopDocumentView() }
                    #endif
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
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Tastatur schließen") {
                    isPromptFocused = false
                }
                .accessibilityIdentifier("igentic-agent-dismiss-keyboard")
            }
        }
        .navigationTitle("iGentic Agent")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshDiagnosticJournal()
            if let state = try? loopStore.snapshot() {
                let age = Date().timeIntervalSince(state.createdAt)
                loopReady = !state.isAnswered
                    && age >= 0 && age <= AgentLoopShortcutExchangeStore.expiration
            } else {
                loopReady = false
            }
        }
    }

    private func stopDiagnostic() {
        diagnosticReport = nil
        // Keep the task occupied until its awaited provider returns.
        diagnosticRun?.cancel()
    }

    private func refreshDiagnosticJournal() {
        do {
            diagnosticCheckpoint = try diagnosticJournal.snapshot()
            diagnosticJournalBlocked = false
        } catch {
            diagnosticJournalBlocked = true
        }
    }

    private func abandonDiagnostic(_ id: UUID) {
        guard diagnosticRun == nil, scenePhase == .active, !diagnosticJournalBlocked else { return }
        diagnosticReport = nil
        do {
            try diagnosticJournal.abandonInterrupted(id: id)
        } catch {
            // A stale selection or competing lease must never affect a newer attempt.
            diagnosticJournalBlocked = true
        }
        refreshDiagnosticJournal()
    }

    private func enqueueDiagnostic(_ goal: AgentLoopDiagnosticGoal) {
        guard diagnosticRun == nil, scenePhase == .active, !diagnosticJournalBlocked else { return }
        do { try diagnosticJournal.enqueue(goal: goal) }
        catch { diagnosticJournalBlocked = true }
        refreshDiagnosticJournal()
    }

    private func removeQueuedDiagnostic(_ id: UUID) {
        guard diagnosticRun == nil, scenePhase == .active, !diagnosticJournalBlocked else { return }
        do { try diagnosticJournal.removeQueued(id: id) }
        catch { diagnosticJournalBlocked = true }
        refreshDiagnosticJournal()
    }

    private func runDiagnosticQueue(deterministic: Bool = false) {
        guard diagnosticRun == nil, scenePhase == .active, !diagnosticJournalBlocked else { return }
        // Capture the owner-selected batch, never silently consume later additions.
        let tickets = diagnosticCheckpoint?.queuedTickets ?? []
        guard !tickets.isEmpty else { return }
        diagnosticReport = nil
        diagnosticRun = Task { @MainActor in
            defer { diagnosticRun = nil; refreshDiagnosticJournal() }
            for ticket in tickets {
                guard !Task.isCancelled, scenePhase == .active else { return }
                do {
                    let report = try await diagnosticJournal.run(goal: ticket.goal, queuedID: ticket.id) { checkpoint in
                        if deterministic {
                            return await AgentLoopLocalDiagnosticWorkflow.runDeterministicOnDevice(goal: ticket.goal, checkpoint: checkpoint)
                        }
                        return await AgentLoopLocalDiagnosticWorkflow.runOnDevice(goal: ticket.goal, checkpoint: checkpoint)
                    }
                    guard !Task.isCancelled, scenePhase == .active else { return }
                    diagnosticReport = report
                    guard report.outcome == .completed else { return }
                } catch { return }
            }
        }
    }

    private func startDiagnostic(_ goal: AgentLoopDiagnosticGoal, restartID: UUID? = nil, deterministic: Bool = false) {
        guard diagnosticRun == nil, scenePhase == .active, !diagnosticJournalBlocked else { return }
        diagnosticReport = nil
        diagnosticRun = Task { @MainActor in
            defer { diagnosticRun = nil; refreshDiagnosticJournal() }
            do {
                let report = try await diagnosticJournal.run(goal: goal, restartID: restartID) { checkpoint in
                    if deterministic {
                            return await AgentLoopLocalDiagnosticWorkflow.runDeterministicOnDevice(goal: goal, checkpoint: checkpoint)
                        }
                        return await AgentLoopLocalDiagnosticWorkflow.runOnDevice(goal: goal, checkpoint: checkpoint)
                }
                guard !Task.isCancelled, scenePhase == .active else { return }
                diagnosticReport = report
            } catch {
                diagnosticReport = nil
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
