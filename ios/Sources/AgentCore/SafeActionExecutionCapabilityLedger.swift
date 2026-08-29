import Foundation

enum SafeActionExecutionCapabilityState: String, Equatable, Sendable {
    case issued
    case consuming
    case consumed
}

enum SafeActionExecutionCapabilityRejection: Equatable, Sendable {
    case unknownCapability
    case alreadyConsuming
    case alreadyConsumed
}

enum SafeActionExecutionCapabilityIssueRejection: Equatable, Sendable {
    case duplicateCapabilityID
    case duplicateAuthorityID
}

enum SafeActionExecutionCapabilityIssueResult: Equatable, Sendable {
    case issued
    case rejected(SafeActionExecutionCapabilityIssueRejection)
}

enum SafeActionExecutionCapabilityConsumption<Output: Sendable>: Sendable {
    case rejected(SafeActionExecutionCapabilityRejection)
    case completed(Output)
}

/// Process-local one-shot capability ledger for Safe Action execution.
///
/// The first caller that atomically transitions an issued capability to
/// `consuming` owns the execution attempt. Every normal return or thrown error
/// after that transition terminalizes the capability as `consumed`.
///
/// Authority-bound issuance can additionally claim one authority identity at
/// the same atomic boundary as the capability ID. Reusing that authority
/// identity cannot mint another capability during the process lifetime.
///
/// This type intentionally provides no persistence, retry, reset, or
/// `consuming -> issued` transition.
final class SafeActionExecutionCapabilityLedger: @unchecked Sendable {
    private struct Storage {
        var capabilityStates: [UUID: SafeActionExecutionCapabilityState] = [:]
        var authorityIDs: Set<String> = []
    }

    private let storage = LockedBox(Storage())

    init() {}

    @discardableResult
    func issue(_ capabilityID: UUID) -> Bool {
        storage.withValue { storage in
            guard storage.capabilityStates[capabilityID] == nil else {
                return false
            }
            storage.capabilityStates[capabilityID] = .issued
            return true
        }
    }

    func issue(
        _ capabilityID: UUID,
        authorityID: String
    ) -> SafeActionExecutionCapabilityIssueResult {
        storage.withValue { storage in
            guard storage.capabilityStates[capabilityID] == nil else {
                return .rejected(.duplicateCapabilityID)
            }
            guard !storage.authorityIDs.contains(authorityID) else {
                return .rejected(.duplicateAuthorityID)
            }

            storage.capabilityStates[capabilityID] = .issued
            storage.authorityIDs.insert(authorityID)
            return .issued
        }
    }

    func state(for capabilityID: UUID) -> SafeActionExecutionCapabilityState? {
        storage.withValue { $0.capabilityStates[capabilityID] }
    }

    func consume<Output: Sendable>(
        _ capabilityID: UUID,
        operation: @Sendable () async throws -> Output
    ) async rethrows -> SafeActionExecutionCapabilityConsumption<Output> {
        if let rejection = beginConsumption(capabilityID) {
            return .rejected(rejection)
        }

        defer {
            terminalizeConsumption(capabilityID)
        }

        return .completed(try await operation())
    }

    private func beginConsumption(_ capabilityID: UUID) -> SafeActionExecutionCapabilityRejection? {
        storage.withValue { storage in
            guard let state = storage.capabilityStates[capabilityID] else {
                return .unknownCapability
            }

            switch state {
            case .issued:
                storage.capabilityStates[capabilityID] = .consuming
                return nil
            case .consuming:
                return .alreadyConsuming
            case .consumed:
                return .alreadyConsumed
            }
        }
    }

    private func terminalizeConsumption(_ capabilityID: UUID) {
        storage.withValue { storage in
            guard storage.capabilityStates[capabilityID] == .consuming else {
                return
            }
            storage.capabilityStates[capabilityID] = .consumed
        }
    }
}
