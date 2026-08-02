import SwiftUI
import AgentCore
import iGenticApp

@main
struct iGenticDiagnosticsApp: App {
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

        let bootstrapRequiresConfirmation: Bool
        switch bootstrapState {
        case .some(.loadedExisting(_)):
            bootstrapRequiresConfirmation = false
        case .some(.installedDefault(_)), .some(.fellBackToDefault(_)), .none:
            bootstrapRequiresConfirmation = true
        }

        self.approvalPolicyStore = policyStore
        self.setupConfirmationStore = confirmationStore
        self.initialApprovalPolicy = bootstrapState?.policy ?? .default
        self.requiresInitialSetupConfirmation = bootstrapRequiresConfirmation
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
        }
    }
}
