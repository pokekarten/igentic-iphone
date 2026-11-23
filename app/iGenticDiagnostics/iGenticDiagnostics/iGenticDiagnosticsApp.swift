import SwiftUI
import AppIntents
import UIKit
import AgentCore
import iGenticApp

@main
struct iGenticDiagnosticsApp: App {
    @State private var physicalProbeStatus = ""
    // Only a fixed app-owned diagnostic route, never arbitrary URL, tap or shell.
    private let pluginBridge = iGenticNativeBridgeLaunch.parse(ProcessInfo.processInfo.arguments)
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
                requiresInitialSetupConfirmation: requiresInitialSetupConfirmation,
                nativeBridgeOpenDiscovery: pluginBridge?.action == "open-discovery",
                nativeBridgeScreenObserved: { [pluginBridge] view in
                    pluginBridge?.writeObservedReceipt(view: view)
                }
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
                let assessment = await ReminderDraftProposalService().assess(
                    instruction: prompt,
                    trustedDataClassification: DataClassification(
                        level: .contextualPrivateData,
                        reason: "Fixed synthetic physical-device model fixture."
                    )
                )
                switch assessment.outcome {
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
                if let reason = assessment.rejectionReason {
                    physicalProbeStatus += "; rejectionReason=\(reason.rawValue)"
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


private enum iGenticDiagnosticsIntentError: Error {
    case policyDenied
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
        // A Shortcut is a task entry point, not a bypass for the AgentCore
        // authorization boundary. This fixed response is read-only/local;
        // fail closed if the central policy ever changes its decision.
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )
        guard decision.isAllowed, !decision.requiresApproval else {
            throw iGenticDiagnosticsIntentError.policyDenied
        }
        return .result(value: "iGentic diagnostics shortcut is available. This is a fixed demo response, not a device health check. No personal data was accessed.")
    }
}

// A real, owner-requested on-device status. It returns coarse runtime data to
// Shortcuts, not to a remote plugin. No identifiers, photos, messages or
// cross-app content; no background polling or external provider requests.
@available(iOS 27.0, *)
struct iGenticDeviceStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Read iGentic iPhone Status"
    static let description = IntentDescription(
        "Read the battery, low-power mode and iOS version locally in Shortcuts."
    )
    static let supportedModes: IntentModes = .background

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(
                    level: .contextualPrivateData,
                    reason: "Owner-requested local device runtime status."
                ),
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )
        guard decision.isAllowed, !decision.requiresApproval else {
            throw iGenticDiagnosticsIntentError.policyDenied
        }
        return .result(value: AgentLoopDeviceStatusReader.read().shortcutSummary)
    }
}

// A second Shortcuts entry: classify text on the iPhone, but NEVER execute the
// result or automatically forward the user's input to ChatGPT or other apps.
// The returned summary deliberately excludes the original instruction.
@available(iOS 27.0, *)
struct iGenticPrepareAgentTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Prepare iGentic Agent Task"
    static let description = IntentDescription(
        "Create a read-only local task preview for iGentic; no iPhone command is executed."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Auftrag")
    var instruction: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(
                    level: .contextualPrivateData,
                    reason: "User-entered Shortcuts task, processed locally."
                ),
                actionRisk: .prepare,
                requestedDelegationTarget: .localDevice
            )
        )
        guard decision.isAllowed, !decision.requiresApproval else {
            throw iGenticDiagnosticsIntentError.policyDenied
        }
        return .result(value: AgentLoopTaskBridge.shortcutSummary(instruction))
    }
}

// This is the second half of an API-free Shortcuts model handoff.
// Shortcuts calls ChatGPT's Use Model action; this app-owned Intent validates
// the *returned model text*. It never invokes ChatGPT or performs a phone action.
@available(iOS 27.0, *)
struct iGenticReviewModelReplyIntent: AppIntent {
    static let title: LocalizedStringResource = "Review iGentic Model Reply"
    static let description = IntentDescription(
        "Validate a ChatGPT reply locally and return a non-executing JSON receipt."
    )
    static let supportedModes: IntentModes = .background

    @Parameter(title: "Task ID")
    var taskID: String

    @Parameter(title: "Model Reply")
    var modelReply: String

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(
                    level: .contextualPrivateData,
                    reason: "Explicit Shortcuts model output reviewed on device."
                ),
                actionRisk: .prepare,
                requestedDelegationTarget: .localDevice
            )
        )
        guard decision.isAllowed, !decision.requiresApproval else {
            throw iGenticDiagnosticsIntentError.policyDenied
        }
        return .result(value: AgentLoopModelHandoff.review(
            taskID: taskID, modelReply: modelReply
        ))
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
        AppShortcut(
            intent: iGenticDeviceStatusIntent(),
            phrases: [
                "Check iPhone status with \(.applicationName)",
                "Read my battery with \(.applicationName)"
            ],
            shortTitle: "iPhone Status",
            systemImageName: "battery.100percent"
        )
        AppShortcut(
            intent: iGenticPrepareAgentTaskIntent(),
            phrases: [
                "Prepare a task with \(.applicationName)"
            ],
            shortTitle: "Agent Task Preview",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: iGenticReviewModelReplyIntent(),
            phrases: [
                "Review a model reply with \(.applicationName)"
            ],
            shortTitle: "Review Model Reply",
            systemImageName: "checkmark.shield"
        )
    }
}

// Per-launch, one-purpose, privacy-safe device bridge. The host passes a fresh
// UUID nonce to Apple's CoreDevice launch service. Our own view emits a tiny
// receipt only after SwiftUI's onAppear, never from launch's exit status alone.
// This does not authorize general iOS UI control or write any user data.
private struct iGenticNativeBridgeLaunch {
    let action: String
    let nonce: String

    static func parse(_ args: [String]) -> Self? {
        let actions = args.filter { $0.hasPrefix("--igentic-bridge-action=") }
        let nonces = args.filter { $0.hasPrefix("--igentic-bridge-nonce=") }
        guard actions.count == 1, nonces.count == 1 else { return nil }
        let action = String(actions[0].dropFirst("--igentic-bridge-action=".count))
        let nonce = String(nonces[0].dropFirst("--igentic-bridge-nonce=".count))
        guard ["open-diagnostics", "open-discovery"].contains(action),
              let uuid = UUID(uuidString: nonce),
              uuid.uuidString.lowercased() == nonce.lowercased() else { return nil }
        return Self(action: action, nonce: nonce.lowercased())
    }

    func writeObservedReceipt(view: String) {
        let expected = action == "open-discovery" ? "discovery" : "diagnostics"
        guard view == expected else { return }
        // One fixed file; atomic replace, no private content, no token or network.
        let data: [String: Any] = [
            "schema": 1, "nonce": nonce, "action": action,
            "view": view, "status": "observed"
        ]
        guard let directory = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask
        ).first,
        let bytes = try? JSONSerialization.data(withJSONObject: data, options: [.sortedKeys])
        else { return }
        try? bytes.write(
            to: directory.appendingPathComponent("igentic-plugin-receipt.json"),
            options: [.atomic, .completeFileProtectionUnlessOpen]
        )
    }
}
