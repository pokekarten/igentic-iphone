import SwiftUI
import AgentCore
import iGenticApp

@main
struct iGenticDiagnosticsApp: App {
    @State private var physicalProbeStatus = ""
    private let approvalPolicyStore: AppActionApprovalPolicyStore
    private let setupConfirmationStore: AppActionApprovalPolicySetupConfirmationStore
    private let initialApprovalPolicy: AppActionApprovalPolicy
    private let requiresInitialSetupConfirmation: Bool

    init() {
        let policyStore = AppActionApprovalPolicyStore(
            fileURL: AppActionApprovalPolicyStore.defaultFileURL()
        )
        let confirmationStore = AppActionApprovalPolicySetupConfirmationStore(
            fileURL: AppActionApprovalPolicySetupConfirmationStore.defaultFileURL()
        )
        let bootstrapState = try? AppActionApprovalPolicyBootstrap(
            store: policyStore
        ).prepare()

        self.approvalPolicyStore = policyStore
        self.setupConfirmationStore = confirmationStore
        self.initialApprovalPolicy = bootstrapState?.policy ?? .default
        self.requiresInitialSetupConfirmation = (bootstrapState?.requiresSetupConfirmation ?? true)
            || !confirmationStore.isConfirmed()
    }

    var body: some Scene {
        WindowGroup {
            DiagnosticView(
                approvalPolicy: initialApprovalPolicy,
                approvalPolicyStore: approvalPolicyStore,
                setupConfirmationStore: setupConfirmationStore,
                requiresInitialSetupConfirmation: requiresInitialSetupConfirmation
            )
            .overlay(alignment: .top) {
                if !physicalProbeStatus.isEmpty {
                    Text(physicalProbeStatus).padding().background(.regularMaterial)
                        .accessibilityIdentifier("physical-model-probe-result")
                }
            }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("--synthetic-local-model-probe") else { return }
                let fixtures = [
                    "reminder-en": "Remind me tomorrow at 18:00 to water the demo plant.",
                    "reminder-de": "Erinnere mich morgen um 18 Uhr daran, die Demo-Pflanze zu gießen.",
                    "ambiguous-de": "Erinnere mich irgendwann an die Demo-Pflanze.",
                    "unsupported-en": "Change the wallpaper to blue."
                ]
                let selected = ProcessInfo.processInfo.arguments.first(where: {
                    $0.hasPrefix("--synthetic-local-model-case=")
                }).map { String($0.dropFirst("--synthetic-local-model-case=".count)) } ?? "reminder-en"
                guard let prompt = fixtures[selected] else {
                    physicalProbeStatus = "PHYSICAL_MODEL_PROBE=invalidFixture"
                    return
                }
                physicalProbeStatus = "PHYSICAL_MODEL_PROBE=running"
                let result = await ReminderDraftProposalService().propose(
                    instruction: prompt,
                    trustedDataClassification: DataClassification(
                        level: .contextualPrivateData,
                        reason: "Fixed synthetic physical-device model fixture."
                    )
                )
                switch result {
                case .proposed(let proposal):
                    let zone = TimeZone.current.identifier
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: zone) ?? .gmt
                    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                    let parts = calendar.dateComponents([.year, .month, .day], from: tomorrow)
                    let expectedDue = try? ReminderDueDate.resolve(
                        year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0,
                        hour: 18, minute: 0, timeZoneIdentifier: zone
                    )
                    let tokens = Set(proposal.title.value.lowercased().split { !$0.isLetter }.map(String.init))
                    let expectedObjectTokens = selected == "reminder-de" ? ["demo", "pflanze"] : ["demo", "plant"]
                    let expectedActionTokens = selected == "reminder-de" ? ["gießen", "wässern"] : ["water", "watering"]
                    let titleMatch = expectedObjectTokens.allSatisfy { tokens.contains($0) }
                        && expectedActionTokens.contains { tokens.contains($0) }
                    let dueMatch = expectedDue.map { proposal.due == $0 } ?? false
                    physicalProbeStatus = "PHYSICAL_MODEL_PROBE=proposalCreated; titleTermsMatch=\(titleMatch); dueMatch=\(dueMatch); writeAttempted=false"
                case .inputRejected: physicalProbeStatus = "PHYSICAL_MODEL_PROBE=inputRejected; writeAttempted=false"
                case .modelUnavailable: physicalProbeStatus = "PHYSICAL_MODEL_PROBE=modelUnavailable; writeAttempted=false"
                case .generationFailed: physicalProbeStatus = "PHYSICAL_MODEL_PROBE=generationFailed; writeAttempted=false"
                case .unsupportedAction: physicalProbeStatus = "PHYSICAL_MODEL_PROBE=unsupportedAction; writeAttempted=false"
                case .invalidProposal: physicalProbeStatus = "PHYSICAL_MODEL_PROBE=invalidProposal; writeAttempted=false"
                }
                #if DEBUG
                // Explicit fixed-fixture probe only: no prompt, generated text,
                // identifiers or user content. Observable via devicectl --console.
                print(physicalProbeStatus)
                #endif
            }
        }
    }
}
