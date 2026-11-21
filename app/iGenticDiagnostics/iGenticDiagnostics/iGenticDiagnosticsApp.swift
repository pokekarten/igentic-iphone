import SwiftUI
import AppIntents
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
        }
    }
}


// System-facing, read-only demonstration. No device status, user records, model
// provider, persistence, external transport, or action authorization is exposed.
@available(iOS 16.0, *)
struct iGenticReadOnlyDiagnosticsIntent: AppIntent {
    static let title: LocalizedStringResource = "Check iGentic Diagnostics"
    static let description = IntentDescription(
        "Returns a fixed, privacy-safe demonstration status without accessing personal data."
    )
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: "iGentic diagnostics shortcut is available. This is a fixed demo response, not a device health check. No personal data was accessed.")
    }
}

@available(iOS 16.0, *)
struct iGenticDiagnosticsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
                intent: iGenticReadOnlyDiagnosticsIntent(),
                phrases: [
                    "Check diagnostics in \(.applicationName)",
                    "Show diagnostics in \(.applicationName)"
                ],
                shortTitle: "Check Diagnostics",
            systemImageName: "checkmark.shield"
        )
    }
}
