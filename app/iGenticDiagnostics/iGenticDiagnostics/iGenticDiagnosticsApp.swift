import SwiftUI
import AgentCore
import iGenticApp

@main
struct iGenticDiagnosticsApp: App {
    init() {
        let store = AppActionApprovalPolicyStore(fileURL: AppActionApprovalPolicyStore.defaultFileURL())
        _ = try? store.loadOrInstallDefault()
    }

    var body: some Scene {
        WindowGroup {
            DiagnosticView()
        }
    }
}
