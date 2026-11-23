import Foundation
import AgentCore

/// A bounded, in-memory, first-party read-only loop. A caller can present
/// one untrusted model proposal at a time, but cannot inject a tool, approval
/// or privileged action. Never runs a model or delegates an observation.
public enum AgentLoopNativeReadOnlyStage: String, Equatable, Sendable {
    case awaitingStatusProposal
    case awaitingFinish
    case finished
    case rejected
    case expired
}

public struct AgentLoopNativeReadOnlyReceipt: Equatable, Sendable {
    public let stage: AgentLoopNativeReadOnlyStage
    public let turnCount: Int
    public let reason: String
    /// In-app, in-memory observation only. The caller must not auto-export it.
    public let localObservation: String?
    public let remoteActionExecuted: Bool
    public let ownerApprovalGranted: Bool
}

@MainActor
public final class AgentLoopNativeReadOnlySession {
    public static let timeLimit: TimeInterval = 300
    private let taskID = AgentLoopModelHandoff.newCorrelationID()
    private let createdAt: Date
    private let now: () -> Date
    private let statusReader: () -> AgentLoopLocalStatus
    private var stage: AgentLoopNativeReadOnlyStage = .awaitingStatusProposal
    private var turnCount = 0
    private var observation: String?

    /// The reader is local and deliberately provided by the native app.
    /// The returned receipt is not independent physical-device attestation.
    public init(
        statusReader: @escaping () -> AgentLoopLocalStatus,
        now: @escaping () -> Date = Date.init
    ) {
        self.statusReader = statusReader
        self.now = now
        self.createdAt = now()
    }

    public func snapshot() -> AgentLoopNativeReadOnlyReceipt {
        if expirePendingIfNeeded() || stage == .expired {
            return receipt(reason: "invalid-or-expired-clock")
        }
        return receipt(reason: "read-only-local-state")
    }

    /// Even a read-only status poll must enforce the age limit. Otherwise an
    /// idle UI could display a still-actionable proposal and stale local
    /// observation long after the session expired. This is a terminal state:
    /// setting the clock backwards cannot reopen the task.
    private func expirePendingIfNeeded() -> Bool {
        guard stage == .awaitingStatusProposal || stage == .awaitingFinish else {
            return false
        }
        let elapsed = now().timeIntervalSince(createdAt)
        guard elapsed >= 0, elapsed < Self.timeLimit else {
            stage = .expired
            observation = nil
            return true
        }
        return false
    }

    /// Accept at most two messages: status.read, then finish. The existing
    /// strict model-reply gate rejects duplicate JSON keys, spoofed approval,
    /// unknown actions, unsupported tool names and oversized replies.
    @discardableResult
    public func accept(modelReply: String) -> AgentLoopNativeReadOnlyReceipt {
        guard stage == .awaitingStatusProposal || stage == .awaitingFinish else {
            return receipt(reason: "terminal-no-replay")
        }
        if expirePendingIfNeeded() {
            return receipt(reason: "invalid-or-expired-clock")
        }
        guard turnCount < 2 else {
            stage = .rejected
            return receipt(reason: "turn-budget-exhausted")
        }
        turnCount += 1

        let reviewed = AgentLoopModelHandoff.review(taskID: taskID, modelReply: modelReply)
        guard let data = reviewed.data(using: .utf8),
              let decision = try? JSONDecoder().decode(ReviewedProposal.self, from: data),
              decision.schema == 1,
              decision.taskId == taskID,
              decision.approved == false,
              decision.executed == false else {
            stage = .rejected
            return receipt(reason: "untrusted-proposal-rejected")
        }

        switch stage {
        case .awaitingStatusProposal:
            guard decision.decision == "previewOnly",
                  decision.nextAction == "status.read" else {
                stage = .rejected
                return receipt(reason: "expected-read-only-status")
            }
            let policy = PolicyEngine().decide(
                PolicyRequest(
                    privacyMode: .localOnly,
                    dataClassification: DataClassification(
                        level: .contextualPrivateData,
                        reason: "Fixed coarse status read in the owner app."
                    ),
                    actionRisk: .read,
                    requestedDelegationTarget: .localDevice
                )
            )
            guard policy.isAllowed && !policy.requiresApproval else {
                stage = .rejected
                return receipt(reason: "policy-denied-read")
            }
            observation = statusReader().shortcutSummary
            stage = .awaitingFinish
            return receipt(reason: "local-status-observed-not-exported")

        case .awaitingFinish:
            guard decision.decision == "stopped",
                  decision.nextAction == "none" else {
                stage = .rejected
                return receipt(reason: "expected-explicit-finish")
            }
            stage = .finished
            return receipt(reason: "two-turn-loop-finished")

        case .finished, .rejected, .expired:
            return receipt(reason: "terminal-no-replay")
        }
    }

    private func receipt(reason: String) -> AgentLoopNativeReadOnlyReceipt {
        AgentLoopNativeReadOnlyReceipt(
            stage: stage, turnCount: turnCount,
            reason: reason, localObservation: observation,
            remoteActionExecuted: false, ownerApprovalGranted: false
        )
    }

    private struct ReviewedProposal: Decodable {
        let schema: Int
        let taskId: String?
        let decision: String
        let nextAction: String
        let approved: Bool
        let executed: Bool
    }
}
