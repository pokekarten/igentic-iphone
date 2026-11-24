import Foundation
#if canImport(Security) && canImport(Darwin)
import AgentCore

/// One explicit foreground claim attempt, bound to the current local
/// enrollment. No automatic enrollment, polling, execution or receipt send.
/// The transport is still loopback-only; this is not a remote device service.
@MainActor
final class AgentLoopEnrolledClaimSession {
    enum Failure: Error, Equatable {
        case privacyDenied, alreadyAttempted, enrollmentChanged
    }

    private let vault: AgentLoopDeviceEnrollmentVault
    private let currentPrivacyMode: @MainActor () -> PrivacyMode
    private let transport: @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?
    private var attempted = false

    init(vault: AgentLoopDeviceEnrollmentVault,
         currentPrivacyMode: @escaping @MainActor () -> PrivacyMode,
         transport: @escaping @Sendable (Int, Data, Data) async throws -> AgentLoopRelayClaim?) {
        self.vault = vault
        self.currentPrivacyMode = currentPrivacyMode
        self.transport = transport
    }

    convenience init(vault: AgentLoopDeviceEnrollmentVault,
                     currentPrivacyMode: @escaping @MainActor () -> PrivacyMode) {
        let client = AgentLoopRelayClaimClient()
        self.init(vault: vault, currentPrivacyMode: currentPrivacyMode) { port, device, proposal in
            try await client.claim(port: port, deviceAccessKey: device, proposalKey: proposal)
        }
    }

    /// Called only after an explicit native owner action. The policy and
    /// enrollment are checked both before and after the asynchronous I/O.
    /// An ambiguous transport attempt consumes this session even on failure.
    func claimAfterLocalAction(port: Int) async throws -> AgentLoopRelayClaim? {
        guard !attempted else { throw Failure.alreadyAttempted }
        guard currentPrivacyMode() == .externalAI else { throw Failure.privacyDenied }
        let enrollment = try vault.loadExisting()
        guard (1...65535).contains(port) else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        attempted = true
        try Task.checkCancellation()
        let result = try await transport(port, enrollment.deviceAccessKey, enrollment.proposalKey)
        try Task.checkCancellation()
        guard currentPrivacyMode() == .externalAI else { throw Failure.privacyDenied }
        guard let current = try? vault.loadExisting(), current == enrollment else {
            throw Failure.enrollmentChanged
        }
        // Only the signed claim preview is returned. The existing native
        // owner gate must separately check policy and reserve replay state.
        return result
    }
}
#endif
