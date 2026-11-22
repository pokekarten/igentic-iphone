#if canImport(SwiftUI) && canImport(EventKit)
import AgentCore
import SwiftUI

private struct ReminderReviewItem: Identifiable {
    let subject: CreateReminderApprovalSubject
    var id: UUID { subject.draftID }
}

/// Manual input is the complete first route; no model can fill or approve this form.
public struct CreateReminderTaskView: View {
    @State private var workflow = ReminderCreationWorkflow(backend: EventKitReminderStore())
    @State private var proposalService = ReminderDraftProposalService()
    @State private var instruction = ""
    @State private var title = ""
    @State private var due = Date().addingTimeInterval(24 * 60 * 60)
    @State private var allowSyncedStore = false
    @State private var phase = ReminderCreationState.editing
    @State private var authorization = ReminderTargetAuthorizationState.setupRequired
    @State private var notice = ""
    @State private var review: ReminderReviewItem?
    @State private var executionTask: Task<Void, Never>?
    @State private var requestingPermission = false
    @State private var generatingProposal = false
    @State private var proposalTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase
    private let timeZoneIdentifier = TimeZone.current.identifier

    public init() {}

    private var terminalOrBusy: Bool {
        phase == .executing || phase == .verified || phase == .uncertain || requestingPermission || generatingProposal
    }

    public var body: some View {
        Form {
            Section("Status") {
                Text(statusText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("reminder-task-status")
                if !notice.isEmpty {
                    Text(notice).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section("Erinnerungsentwurf") {
                TextField("Was soll ich dich erinnern?", text: $instruction, axis: .vertical)
                    .accessibilityIdentifier("reminder-instruction-input")
                Button(generatingProposal ? "Vorschlag wird lokal erstellt …" : "Lokal mit Apple-Modell vorschlagen") {
                    proposeLocally()
                }
                .disabled(terminalOrBusy)
                .accessibilityIdentifier("reminder-local-proposal")
                Text("Der Vorschlag füllt nur die bearbeitbaren Felder aus. Er erstellt nichts und ersetzt nicht deine Prüfung.")
                    .font(.footnote)
                TextField("Titel", text: $title, axis: .vertical)
                    .accessibilityIdentifier("reminder-title-input")
                DatePicker("Fällig", selection: $due, displayedComponents: [.date, .hourAndMinute])
                Text("Zeitzone: \(timeZoneIdentifier)").font(.footnote)
                Button("Synthetisches Beispiel einsetzen") {
                    title = "iGentic Test – Pflanze gießen"
                }
            }
            .disabled(terminalOrBusy)
            .disabled(terminalOrBusy)
            Section("Speicherziel") {
                Text("Verwendet die Standardliste von Apple Erinnerungen. Ein Wechsel der Standardliste nach der Freigabe stoppt die Ausführung.")
                Toggle("Synchronisierte Standardliste zulassen", isOn: $allowSyncedStore)
                    .disabled(terminalOrBusy)
                Text("Dein Auftrag wird für den Vorschlag ausschließlich an Apples lokales Systemmodell auf diesem Gerät gegeben. Titel und Zeitpunkt werden erst nach deiner Freigabe in die Standardliste geschrieben; eine synchronisierte Liste kann sie über deinen eingerichteten Account, etwa iCloud, übertragen.")
                    .font(.footnote)
            }
            Section("Zugriff auf Erinnerungen") {
                Text(permissionText)
                if authorization != .fullAccess {
                    Button("Erinnerungszugriff anfragen") {
                        requestingPermission = true
                        Task {
                            let granted = await workflow.requestAccess()
                            authorization = workflow.authorization
                            requestingPermission = false
                            notice = granted ? "Zugriff erteilt. Bitte den Entwurf jetzt prüfen." : "Zugriff nicht erteilt. Es wurde keine Erinnerung erstellt."
                        }
                    }
                    .disabled(terminalOrBusy || authorization != .setupRequired)
                }
                Text("iOS erteilt hierfür vollständigen Lese- und Schreibzugriff. Diese Funktion prüft nur das Standardziel und den von ihr neu angelegten Eintrag.")
                    .font(.footnote)
            }
            Section {
                Button("Entwurf prüfen") { prepare() }
                    .disabled(terminalOrBusy)
                    .accessibilityIdentifier("reminder-review-draft")
                Button("Entwurf verwerfen", role: .cancel) {
                    workflow.cancel()
                    phase = workflow.state
                    review = nil
                }
                .disabled(terminalOrBusy)
            }
            Section("Diese erste Version") {
                Text("Freigaben gelten für diesen Entwurf höchstens fünf Minuten. Beim Verlassen der aktiven App verfällt eine offene Prüfung. Nach einem Neustart wird nichts automatisch ausgeführt. Bei unklarem Ergebnis zuerst in Apple Erinnerungen prüfen; ein neuer Versuch könnte einen zweiten Eintrag erzeugen.")
                    .font(.footnote)
            }
        }
        .navigationTitle("Erinnerung erstellen")
        .onAppear { authorization = workflow.authorization }
        .onChange(of: title) { invalidate() }
        .onChange(of: due) { invalidate() }
        .onChange(of: allowSyncedStore) { invalidate() }
        .onChange(of: scenePhase) {
            if scenePhase != .active {
                proposalTask?.cancel()
                generatingProposal = false
                executionTask?.cancel()
                workflow.cancel()
                phase = workflow.state
                review = nil
            }
        }
        .onDisappear {
            proposalTask?.cancel()
            executionTask?.cancel()
            workflow.cancel()
        }
        .sheet(item: $review) { item in
            CreateReminderApprovalView(subject: item.subject) { decision in
                switch decision {
                case .approved(let receipt):
                    phase = .executing
                    executionTask = Task {
                        await workflow.execute(approval: receipt)
                        phase = workflow.state
                    }
                case .rejected, .cancelled:
                    workflow.cancel()
                    phase = workflow.state
                }
                review = nil
            }
        }
    }

    private func invalidate() {
        workflow.invalidateDraft()
        phase = workflow.state
        notice = ""
        review = nil
    }

    private func proposeLocally() {
        guard !terminalOrBusy else { return }
        notice = ""
        generatingProposal = true
        let text = instruction
        let zone = timeZoneIdentifier
        proposalTask = Task {
            let outcome = await proposalService.propose(
                instruction: text,
                trustedDataClassification: DataClassification(
                    level: .contextualPrivateData,
                    reason: "User-entered reminder instruction, processed by the on-device system model."
                ),
                timeZoneIdentifier: zone
            )
            guard !Task.isCancelled else {
                generatingProposal = false
                return
            }
            generatingProposal = false
            switch outcome {
            case .proposed(let proposal):
                title = proposal.title.value
                due = Date(timeIntervalSince1970: TimeInterval(proposal.due.resolvedUnixSeconds))
                notice = "Vorschlag übernommen. Bitte Titel, Zeitpunkt und Speicherziel prüfen; es wurde nichts gespeichert."
            case .inputRejected:
                notice = "Eingabe nicht geeignet. Bitte eine kurze Erinnerung ohne besonders sensible Angaben eingeben."
            case .modelUnavailable:
                notice = "Das Apple-Modell ist auf diesem Gerät gerade nicht verfügbar. Du kannst den Entwurf manuell ausfüllen."
            case .generationFailed:
                notice = "Es konnte kein Vorschlag erstellt werden. Du kannst den Entwurf manuell ausfüllen."
            case .unsupportedAction:
                notice = "Das Modell hat keine unterstützte Erinnerungsaufgabe vorgeschlagen. Es wurde nichts erstellt."
            case .invalidProposal:
                notice = "Der Modellvorschlag war nicht eindeutig oder nicht gültig. Bitte den Entwurf manuell ausfüllen."
            }
        }
    }

    private func prepare() {
        notice = ""
        var calendar = Calendar(identifier: .gregorian)
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else { return }
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        do {
            let resolved = try ReminderDueDate.resolve(
                year: parts.year!, month: parts.month!, day: parts.day!,
                hour: parts.hour!, minute: parts.minute!, timeZoneIdentifier: timeZoneIdentifier
            )
            workflow.prepare(title: title, due: resolved, allowSyncedStore: allowSyncedStore)
            phase = workflow.state
            authorization = workflow.authorization
            if let subject = workflow.subject { review = .init(subject: subject) }
        } catch {
            workflow.invalidateDraft()
            phase = .invalidInput
            notice = "Der Zeitpunkt muss gültig und auch bei einer Zeitumstellung eindeutig sein."
        }
    }

    private var statusText: String {
        switch phase {
        case .editing: "Entwurf – noch nichts erstellt"
        case .needsPermission: "Erinnerungszugriff erforderlich – nichts erstellt"
        case .invalidInput: "Bitte einen gültigen Titel und Zeitpunkt angeben"
        case .destinationBlocked: "Speicherziel nicht erlaubt – nichts erstellt"
        case .targetUnavailable: "Standardliste nicht verfügbar – nichts erstellt"
        case .needsApproval: "Wartet auf deine Freigabe"
        case .cancelled: "Abgebrochen – nichts erstellt"
        case .expired: "Freigabeprüfung abgelaufen – bitte erneut prüfen"
        case .approvalRejected: "Freigabe ungültig – nichts erstellt"
        case .executing: "Wird erstellt und überprüft"
        case .verified: "Erinnerung erstellt und zurückgelesen"
        case .uncertain: "Ergebnis nicht überprüfbar – vor einem neuen Versuch in Apple Erinnerungen nachsehen"
        case .targetChanged: "Speicherziel verändert oder nicht beschreibbar – nichts erstellt"
        }
    }

    private var permissionText: String {
        switch authorization {
        case .fullAccess: "Zugriff erteilt"
        case .setupRequired: "Zugriff noch nicht angefragt"
        case .denied: "Zugriff in iOS abgelehnt"
        case .restricted: "Zugriff durch iOS eingeschränkt"
        case .unsupported: "Zugriffsstatus nicht unterstützt"
        }
    }
}
#endif
