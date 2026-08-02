import SwiftUI
import AgentCore
import iGenticApp

@main
struct iGenticDiagnosticsApp: App {
    private let approvalPolicyStore: AppActionApprovalPolicyStore
    private let initialApprovalPolicy: AppActionApprovalPolicy

    init() {
        let store = AppActionApprovalPolicyStore(
            fileURL: AppActionApprovalPolicyStore.defaultFileURL()
        )
        self.approvalPolicyStore = store
        self.initialApprovalPolicy = (try? store.loadOrInstallDefault()) ?? .default
    }

    var body: some Scene {
        WindowGroup {
            DiagnosticView(
                approvalPolicy: initialApprovalPolicy,
                approvalPolicyStore: approvalPolicyStore
            )
        }
    }
}
