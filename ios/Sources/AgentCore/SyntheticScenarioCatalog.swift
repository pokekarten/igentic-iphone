import Foundation

public enum SyntheticScenarioCatalog {
    private static let syntheticSensitiveText = "Synthetic contact: scenario@example.com"

    private static var syntheticSensitiveClassification: DataClassification {
        SensitiveDataDetector()
            .detect(in: syntheticSensitiveText)
            .suggestedDataClassification
    }

    public static let baseline: [DiagnosticScenario] = [
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

    public static let all: [DiagnosticScenario] = baseline + [
        DiagnosticScenario(
            id: "restricted-external-delegation",
            task: TaskRequest(
                userText: "Synthetic restricted metadata delegation dry run",
                intent: .summarizeNote,
                dataClassification: DataClassification(
                    level: .restrictedSensitiveData,
                    reason: "Synthetic restricted classification for delegation smoke testing."
                ),
                actionRisk: .prepare
            ),
            privacyMode: .trustedDevices,
            delegationTarget: .externalProvider
        ),
        DiagnosticScenario(
            id: "sensitive-data-detection",
            task: TaskRequest(
                userText: syntheticSensitiveText,
                intent: .summarizeNote,
                dataClassification: syntheticSensitiveClassification,
                actionRisk: .read
            ),
            privacyMode: .trustedDevices,
            delegationTarget: .trustedMac
        ),
    ]
}
