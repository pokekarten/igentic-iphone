public enum CreateReminderDestinationBlockReason: String, Equatable, Sendable {
    case missingDestination
    case unknownDestination
    case localOnlyRequiresDeviceLocalStore
    case restrictedSensitiveDataRequiresDeviceLocalStore
}

public enum CreateReminderDestinationPolicyDecision: Equatable, Sendable {
    case allowed
    case blocked(CreateReminderDestinationBlockReason)
}

public struct CreateReminderDestinationPolicy: Sendable {
    public init() {}

    public func evaluate(
        _ draft: CreateReminderDraft,
        privacyMode: PrivacyMode
    ) -> CreateReminderDestinationPolicyDecision {
        switch draft.actionDataDestination {
        case .none:
            return .blocked(.missingDestination)
        case .unknown:
            return .blocked(.unknownDestination)
        case .deviceLocalStore:
            return .allowed
        case .systemSyncedPersonalStore:
            if privacyMode == .localOnly {
                return .blocked(.localOnlyRequiresDeviceLocalStore)
            }
            if draft.effectiveDataSensitivity == .restrictedSensitiveData {
                return .blocked(.restrictedSensitiveDataRequiresDeviceLocalStore)
            }
            return .allowed
        }
    }
}
