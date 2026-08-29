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
/// This type intentionally provides no persistence, retry, reset, or
/// `consuming -> issued` transition.
final class SafeActionExecutionCapabilityLedger: @unchecked Sendable {
    private let states = LockedBox<[UUID: SafeActionExecutionCapabilityState]>([:])

    init() {}

    @discardableResult
    func issue(_ capabilityID: UUID) -> Bool {
        states.withValue { states in
            guard states[capabilityID] == nil else {
                return false
            }
            states[capabilityID] = .issued
            return true
        }
    }

    func state(for capabilityID: UUID) -> SafeActionExecutionCapabilityState? {
        states.withValue { $0[capabilityID] }
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
        states.withValue { states in
            guard let state = states[capabilityID] else {
                return .unknownCapability
            }

            switch state {
            case .issued:
                states[capabilityID] = .consuming
                return nil
            case .consuming:
                return .alreadyConsuming
            case .consumed:
                return .alreadyConsumed
            }
        }
    }

    private func terminalizeConsumption(_ capabilityID: UUID) {
        states.withValue { states in
            guard states[capabilityID] == .consuming else {
                return
            }
            states[capabilityID] = .consumed
        }
    }
}
