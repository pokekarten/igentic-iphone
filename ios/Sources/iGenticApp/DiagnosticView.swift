#if canImport(SwiftUI)
import AgentCore
import SwiftUI

public struct DiagnosticView: View {
    private let state: DiagnosticViewState
    private let approvalPolicyStore: AppActionApprovalPolicyStore?
    private let setupConfirmationStore: AppActionApprovalPolicySetupConfirmationStore?
    @State private var approvalPolicy: AppActionApprovalPolicy
    @State private var isInitialSetupPresented: Bool
    @State private var isReminderApprovalPresented: Bool
    @State private var reminderApprovalOutcome: String

    public init(
        state: DiagnosticViewState = DiagnosticViewState(),
        approvalPolicy: AppActionApprovalPolicy = .default,
        approvalPolicyStore: AppActionApprovalPolicyStore? = nil,
        setupConfirmationStore: AppActionApprovalPolicySetupConfirmationStore? = nil,
        requiresInitialSetupConfirmation: Bool = false
    ) {
        self.state = state
        self.approvalPolicyStore = approvalPolicyStore
        self.setupConfirmationStore = setupConfirmationStore
        self._approvalPolicy = State(initialValue: approvalPolicy)
        self._isInitialSetupPresented = State(
            initialValue: requiresInitialSetupConfirmation
                && approvalPolicyStore != nil
                && setupConfirmationStore != nil
        )
        self._isReminderApprovalPresented = State(initialValue: false)
        self._reminderApprovalOutcome = State(initialValue: "Not reviewed")
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Safety") {
                    LabeledContent("Operating mode", value: state.operatingMode)
                    LabeledContent("Runtime status", value: state.runtimeStatus)
                    LabeledContent("Audit", value: state.auditStatus)
                    LabeledContent("Validation", value: state.validationStatus)
                    LabeledContent("Privacy", value: state.privacyNotice)
                }

                Section("Explore") {
                    NavigationLink("Open local discovery") {
                        ExploreView()
                    }

                    Text("Bundled sample content only. No network or model execution.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Safe Action approval (synthetic, no execution)") {
                    Button("Review synthetic reminder") {
                        isReminderApprovalPresented = true
                    }

                    LabeledContent("Last decision", value: reminderApprovalOutcome)

                    Text("This uses one fixed public-safe reminder subject to exercise the real human approval surface. Approval creates only an in-memory bound decision receipt; it does not issue a capability or write a reminder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Sample / preview snapshot") {
                    LabeledContent("Source", value: state.snapshotSource)

                    ForEach(state.snapshotFields) { field in
                        DiagnosticMetric(label: field.label, value: field.value)
                    }

                    DiagnosticMetric(label: "Audit events", value: state.auditEventsDescription)
                }

                Section("App action approval policy (effective local policy)") {
                    ForEach(DiagnosticViewState.effectiveApprovalPolicyFields(for: approvalPolicy)) { field in
                        DiagnosticMetric(label: field.label, value: field.value)
                    }

                    if let approvalPolicyStore {
                        NavigationLink("Edit local approval policy") {
                            AppActionApprovalPolicySettingsView(
                                policy: $approvalPolicy,
                                store: approvalPolicyStore
                            )
                        }
                    }
                }

                Section("Model-selection trace preview (synthetic, diagnostic only - not wired to task execution)") {
                    // Fixed diagnostic example; this does not come from any live candidate registry.
                    ForEach(state.modelSelectionFields) { field in
                        DiagnosticMetric(label: field.label, value: field.value)
                    }
                }

                Section("Synthetic scenarios") {
                    ForEach(state.rows) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.title)
                                .font(.headline)

                            DiagnosticMetric(label: "Route", value: row.route)
                            DiagnosticMetric(label: "Policy", value: row.policy)
                            DiagnosticMetric(label: "Approval", value: row.approval)
                            DiagnosticMetric(label: "Delegation", value: row.delegation)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("iGentic Diagnostics")
        }
        .sheet(isPresented: $isInitialSetupPresented) {
            if let approvalPolicyStore, let setupConfirmationStore {
                NavigationStack {
                    AppActionApprovalPolicySettingsView(
                        policy: $approvalPolicy,
                        store: approvalPolicyStore,
                        guidance: "Review the local defaults before using app actions. You can change them now and later in diagnostics settings.",
                        saveButtonTitle: "Confirm and continue",
                        onSuccessfulSave: {
                            try setupConfirmationStore.confirm()
                            isInitialSetupPresented = false
                        }
                    )
                }
                .interactiveDismissDisabled()
            }
        }
        .sheet(isPresented: $isReminderApprovalPresented) {
            CreateReminderApprovalView(
                subject: CreateReminderApprovalSubject.syntheticDiagnosticPreview()
            ) { decision in
                switch decision {
                case .approved:
                    reminderApprovalOutcome = "Approved (no execution)"
                case .rejected:
                    reminderApprovalOutcome = "Rejected"
                case .cancelled:
                    reminderApprovalOutcome = "Cancelled"
                }
                isReminderApprovalPresented = false
            }
        }
    }
}

private struct DiagnosticMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}
#endif
