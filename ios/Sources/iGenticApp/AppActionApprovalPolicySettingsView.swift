#if canImport(SwiftUI)
import AgentCore
import SwiftUI

public struct AppActionApprovalPolicySettingsView: View {
    @Binding private var policy: AppActionApprovalPolicy
    private let store: AppActionApprovalPolicyStore
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
        store: AppActionApprovalPolicyStore
    ) {
        self._policy = policy
        self.store = store
        self._draftPolicy = State(initialValue: policy.wrappedValue)
    }

    public var body: some View {
        Form {
            Section {
                ForEach(Self.actionKinds, id: \.rawValue) { actionKind in
                    Toggle(
                        Self.title(for: actionKind),
                        isOn: requiresApprovalBinding(for: actionKind)
                    )
                }
            } header: {
                Text("Approval required")
            } footer: {
                Text("Blocked actions remain blocked. These settings only control approval after the deterministic policy gate allows an action.")
            }

            Section {
                Button("Save locally") {
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
            policy = policyToSave
            statusMessage = "Saved on this device."
        } catch {
            statusMessage = "The policy could not be saved."
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
            DiagnosticSnapshotField(label: "Send message approval required", value: approvalText(for: .sendMessage, policy: policy)),
            DiagnosticSnapshotField(label: "Delete record approval required", value: approvalText(for: .deleteRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Update record approval required", value: approvalText(for: .updateRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Export data approval required", value: approvalText(for: .exportData, policy: policy)),
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
