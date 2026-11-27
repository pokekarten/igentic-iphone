import Foundation
import AgentCore

/// Selection is made before an attempt. Never retry a partially executed goal
/// with another provider. No delegated or hosted provider is representable.
public enum DiagnosticModelRouter {
    public enum Preference: String, Sendable { case automatic, apple, qwen }
    public enum Selection: String, Sendable { case apple, qwen, unavailable }

    public static func select(preference: Preference, appleReady: Bool,
                              qwenOptIn: Bool, qwenArtifactAdmitted: Bool) -> Selection {
        let qwenEligible = qwenOptIn && qwenArtifactAdmitted
        switch preference {
        case .apple: return appleReady ? .apple : .unavailable
        case .qwen: return qwenEligible ? .qwen : .unavailable
        case .automatic:
            if appleReady { return .apple }
            return qwenEligible ? .qwen : .unavailable
        }
    }

    /// Calls at most one trusted local provider, even if it throws. A failed
    /// attempt remains a failed attempt, not a reason to replay native reads.
    @MainActor
    public static func dispatch<T>(
        _ selection: Selection,
        apple: @MainActor () async throws -> T,
        qwen: @MainActor () async throws -> T
    ) async throws -> T? {
        // Do not start a provider (which may load weights or open a journal)
        // for an attempt that was cancelled before dispatch. Never turn
        // cancellation into unavailability or try another provider.
        try Task.checkCancellation()
        switch selection {
        case .apple: return try await apple()
        case .qwen: return try await qwen()
        case .unavailable: return nil
        }
    }

    #if os(iOS) && canImport(UIKit)
    /// Same journal and policy enforcement as the existing system workflow.
    @MainActor
    public static func runSystem(goal: AgentLoopDiagnosticGoal = .extended) async throws -> AgentLoopDiagnosticReport {
        try await AgentLoopDiagnosticJournal().run(goal: goal) { checkpoint in
            await AgentLoopLocalDiagnosticWorkflow.runOnDevice(goal: goal, checkpoint: checkpoint)
        }
    }
    #endif
}
