import AgentCore
import Foundation

#if canImport(CryptoKit) && canImport(Darwin)
/// The review boundary between a signed remote status *proposal* and a
/// first-party local read. This type has no transport, model, Keychain,
/// notification, App Intent, or background entry point.
public enum AgentLoopSignedStatusGateStage: String, Equatable, Sendable {
    case empty
    case awaitingOwnerReview
    case localReadInProgress
    case locallyRead
    /// Historical local read, but its battery/OS snapshot is now stale.
    case locallyReadExpired
    case denied
    case expired
}

public struct AgentLoopSignedStatusGateReceipt: Equatable, Sendable {
    public let stage: AgentLoopSignedStatusGateStage
    public let requestID: String?
    /// Available only inside the owner app. NEVER sent to the relay.
    public let ownerAppObservation: String?
    public let localReadCompleted: Bool
    public let externalDataShared: Bool
    public let ownerConsentAttested: Bool
    public let remoteActionExecuted: Bool
    public let independentDeviceReceipt: String
}

/// A one-request coordinator for two already implemented protections:
/// (1) exact canonical HMAC verification + native external-sharing preflight,
/// and (2) durable one-shot replay admission BEFORE presenting a request.
///
/// The readAfterLocalReviewAction method must only be wired to a native owner
/// UI action, not to a relay, model output, App Intent or plugin endpoint.
/// This module cannot attest that a human tapped; it therefore never asserts
/// ownerConsentAttested or emits a remotely verifiable execution receipt.
@MainActor
public final class AgentLoopSignedOwnerStatusGate {
    private let replayJournal: AgentLoopLocalReplayJournal
    private let clockSeconds: () -> Int
    private let statusReader: () -> AgentLoopLocalStatus
    private var stage: AgentLoopSignedStatusGateStage = .empty
    private var pending: AgentLoopRemoteTaskPreview?
    private var trackedRequestID: String?
    private var admittedAtSeconds: Int?
    private var lastReadExpiresAt: Int?
    private var observed: String?

    public init(
        replayJournal: AgentLoopLocalReplayJournal,
        clockSeconds: @escaping () -> Int,
        statusReader: @escaping () -> AgentLoopLocalStatus
    ) {
        self.replayJournal = replayJournal
        self.clockSeconds = clockSeconds
        self.statusReader = statusReader
    }

    /// Never accepts a remotely supplied approval flag or direct preview.
    /// Invalid, replayed, policy-blocked or expired requests cannot progress
    /// to owner review and cannot reach the local status reader.
    @discardableResult
    public func stageSignedTaskForOwnerReview(
        _ canonicalWire: Data,
        relayKey: Data,
        privacyMode: PrivacyMode,
        statusClassification: DataClassification
    ) -> AgentLoopSignedStatusGateReceipt {
        guard stage == .empty else { return receipt() }
        do {
            let admittedAt = clockSeconds()
            let review = try replayJournal.inspectPolicyAndReserveForOwnerReview(
                canonicalWire,
                relayKey: relayKey,
                nowSeconds: admittedAt,
                privacyMode: privacyMode,
                statusClassification: statusClassification
            )
            switch review {
            case .requiresLocalOwnerReview(let verified):
                pending = verified
                trackedRequestID = verified.requestID
                admittedAtSeconds = admittedAt
                stage = .awaitingOwnerReview
            case .invalidSignedProposal, .blockedByNativePolicy:
                stage = .denied
            }
        } catch {
            // Do not return the untrusted input or leak crypto/ledger state.
            stage = .denied
        }
        return receipt()
    }

    /// Reserved for a future owner-tapped SwiftUI button (NOT a model tool).
    /// The status stays local; sharing it externally requires another
    /// explicitly approved path and device receipt protocol.
    // Only the native iGenticApp review screen should wire this transition.
    // Keeping it module-internal reduces accidental App Intents/relay use;
    // it does not attest a real owner tap.
    @discardableResult
    func readAfterLocalReviewAction() -> AgentLoopSignedStatusGateReceipt {
        guard stage == .awaitingOwnerReview, let task = pending else {
            // A synchronous statusReader may re-enter this method while the
            // first read is still executing. Reject the *whole* operation:
            // blocking only the nested call would let the outer call falsely
            // report a clean locally-completed read.
            if stage == .localReadInProgress {
                stage = .denied
                pending = nil
                observed = nil
            }
            return receipt()
        }
        let beforeRead = clockSeconds()
        guard beforeRead >= 0, let admittedAtSeconds,
              beforeRead >= admittedAtSeconds,
              beforeRead < task.expiresAt else {
            stage = .expired
            pending = nil
            return receipt()
        }

        let policy = PolicyEngine().decide(PolicyRequest(
            privacyMode: .localOnly,
            dataClassification: DataClassification(
                level: .contextualPrivateData,
                reason: "Bounded local owner-app status read after signed task preview."
            ),
            actionRisk: .read,
            requestedDelegationTarget: .localDevice
        ))
        guard policy.isAllowed && !policy.requiresApproval else {
            stage = .denied
            pending = nil
            return receipt()
        }

        // Durable journal reservation happened before owner review.
        // A nested callback cannot re-enter a read, and a crash cannot
        // re-use this signed request in a newly constructed session.
        stage = .localReadInProgress
        let coarseStatus = statusReader().shortcutSummary
        guard stage == .localReadInProgress else {
            observed = nil
            stage = .denied
            pending = nil
            return receipt()
        }
        let afterRead = clockSeconds()
        guard afterRead >= beforeRead, afterRead < task.expiresAt else {
            observed = nil
            stage = .expired
            pending = nil
            return receipt()
        }
        observed = coarseStatus
        lastReadExpiresAt = task.expiresAt
        pending = nil
        stage = .locallyRead
        return receipt()
    }

    public func snapshot() -> AgentLoopSignedStatusGateReceipt {
        if stage == .awaitingOwnerReview, let task = pending {
            let now = clockSeconds()
            if now < (admittedAtSeconds ?? Int.max) || now >= task.expiresAt {
                pending = nil
                stage = .expired
            }
        } else if stage == .locallyRead, let deadline = lastReadExpiresAt {
            // Battery/OS data is a moment-in-time local observation.
            // A snapshot after the signed request TTL (or a rollback)
            // must not expose it as current telemetry. The read still
            // happened; preserve that fact without retaining its value.
            let now = clockSeconds()
            if now < (admittedAtSeconds ?? Int.max) || now >= deadline {
                observed = nil
                stage = .locallyReadExpired
            }
        }
        return receipt()
    }

    private func receipt() -> AgentLoopSignedStatusGateReceipt {
        AgentLoopSignedStatusGateReceipt(
            stage: stage,
            requestID: trackedRequestID,
            ownerAppObservation: observed,
            // Expiring a displayed observation must not erase an actual
            // past local read or misstate it as a verified device receipt.
            localReadCompleted: stage == .locallyRead || stage == .locallyReadExpired,
            externalDataShared: false,
            ownerConsentAttested: false,
            remoteActionExecuted: false,
            independentDeviceReceipt: "none"
        )
    }
}
#endif
