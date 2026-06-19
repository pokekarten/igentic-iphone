import Foundation

public enum SyntheticScenarioCatalog {
    public static let all: [DiagnosticScenario] = [
        DiagnosticScenario(
            id: "local-only-summary",
            task: TaskRequest(
                userText: "Synthetic local summary dry run",
                intent: .summarizeNote,
                actionRisk: .read
            ),
            privacyMode: .localOnly,
            delegationTarget: .trustedMac
        ),
        DiagnosticScenario(
            id: "critical-reminder",
            task: TaskRequest(
                userText: "Synthetic critical reminder dry run",
                intent: .createReminder,
                actionRisk: .critical
            ),
            privacyMode: .trustedDevices,
            delegationTarget: .trustedMac
        ),
        DiagnosticScenario(
            id: "external-provider-check",
            task: TaskRequest(
                userText: "Synthetic external provider dry run",
                intent: .summarizeNote,
                actionRisk: .prepare
            ),
            privacyMode: .trustedDevices,
            delegationTarget: .externalProvider
        ),
        DiagnosticScenario(
            id: "trusted-device-metadata",
            task: TaskRequest(
                userText: "Synthetic trusted-device metadata dry run",
                intent: .findFile,
                actionRisk: .prepare
            ),
            privacyMode: .trustedDevices,
            delegationTarget: .trustedMac
        ),
    ]
}
