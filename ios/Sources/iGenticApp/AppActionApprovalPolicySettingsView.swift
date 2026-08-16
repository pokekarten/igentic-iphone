#if canImport(SwiftUI)
import AgentCore
import SwiftUI

public struct AppActionApprovalPolicySettingsView: View {
    @Binding private var policy: AppActionApprovalPolicy
    private let store: AppActionApprovalPolicyStore
    private let guidance: String?
    private let saveButtonTitle: String
    private let onSuccessfulSave: () throws -> Void
    @State private var draftPolicy: AppActionApprovalPolicy
    @State private var statusMessage: String?

    private static let actionKinds: [AppActionDraft.ActionKind] = [
        .sendMessage,
        .deleteRecord,
        .updateRecord,
        .exportData,
    ]

    public init(
        policy: Binding<AppActionApprovalPolicy>,
        store: AppActionApprovalPolicyStore,
        guidance: String? = nil,
        saveButtonTitle: String = "Save locally",
        onSuccessfulSave: @escaping () throws -> Void = {}
    ) {
        self._policy = policy
        self.store = store
        self.guidance = guidance
        self.saveButtonTitle = saveButtonTitle
        self.onSuccessfulSave = onSuccessfulSave
        self._draftPolicy = State(initialValue: policy.wrappedValue)
    }

    public var body: some View {
        Form {
            if let guidance {
                Section("Setup") {
                    Text(guidance)
                }
            }

            Section {
                ForEach(Self.actionKinds, id: \.rawValue) { actionKind in
                    Toggle(
                        Self.title(for: actionKind),
                        isOn: requiresApprovalBinding(for: actionKind)
                    )
                }
            } header: {
                Text("Additional approval")
            } footer: {
                Text("Blocked actions remain blocked. Core policy approval requirements cannot be turned off here. These settings can only add approval after the deterministic policy gate allows an action.")
            }

            Section {
                Button(saveButtonTitle) {
                    save(draftPolicy)
                }

                Button("Restore setup defaults", role: .destructive) {
                    let defaultPolicy = AppActionApprovalPolicy.default
                    draftPolicy = defaultPolicy
                    save(defaultPolicy)
                }
            }

            if let statusMessage {
                Section("Status") {
                    Text(statusMessage)
                }
            }
        }
        .navigationTitle("Approval policy")
    }

    private func requiresApprovalBinding(for actionKind: AppActionDraft.ActionKind) -> Binding<Bool> {
        Binding(
            get: {
                draftPolicy.requiresApproval(for: actionKind) ?? true
            },
            set: { requiresApproval in
                draftPolicy = draftPolicy.replacingRule(
                    for: actionKind,
                    requiresApproval: requiresApproval,
                    enabled: true
                )
                statusMessage = "Unsaved local changes."
            }
        )
    }

    private func save(_ policyToSave: AppActionApprovalPolicy) {
        do {
            try store.save(policyToSave)
            try onSuccessfulSave()
            policy = policyToSave
            statusMessage = "Saved on this device."
        } catch {
            statusMessage = "The policy or confirmation could not be saved."
        }
    }

    private static func title(for actionKind: AppActionDraft.ActionKind) -> String {
        switch actionKind {
        case .sendMessage:
            return "Send message"
        case .deleteRecord:
            return "Delete record"
        case .updateRecord:
            return "Update record"
        case .exportData:
            return "Export data"
        }
    }
}

extension DiagnosticViewState {
    static func effectiveApprovalPolicyFields(
        for policy: AppActionApprovalPolicy
    ) -> [DiagnosticSnapshotField] {
        [
            DiagnosticSnapshotField(label: "Policy schema", value: "v\(policy.schemaVersion)"),
            DiagnosticSnapshotField(label: "Send message additional approval", value: approvalText(for: .sendMessage, policy: policy)),
            DiagnosticSnapshotField(label: "Delete record additional approval", value: approvalText(for: .deleteRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Update record additional approval", value: approvalText(for: .updateRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Export data additional approval", value: approvalText(for: .exportData, policy: policy)),
        ]
    }

    private static func approvalText(
        for actionKind: AppActionDraft.ActionKind,
        policy: AppActionApprovalPolicy
    ) -> String {
        guard let requiresApproval = policy.requiresApproval(for: actionKind) else {
            return "Not configured"
        }
        return requiresApproval ? "Yes" : "No"
    }
}
#endif
