public struct RuntimeBudgetAssessor: Sendable {
    public init() {}

    public func assess(_ task: TaskRequest, privacyMode: PrivacyMode) -> RuntimeBudget {
        let family = Self.intentFamily(for: task.intent)

        var executionClass = family.executionClass
        var expectedLocality = family.expectedLocality
        var estimatedMemoryClass = family.estimatedMemoryClass
        var reasons = [family.reason]

        if let escalatedMemoryClass = Self.escalatedMemoryClass(
            from: estimatedMemoryClass,
            for: task.dataClassification.level
        ), escalatedMemoryClass != estimatedMemoryClass {
            estimatedMemoryClass = escalatedMemoryClass
            reasons.append("Data classification escalates memory to \(escalatedMemoryClass.rawValue).")
        }

        if let escalatedExecutionClass = Self.escalatedExecutionClass(
            from: executionClass,
            for: task.actionRisk
        ), escalatedExecutionClass != executionClass {
            executionClass = escalatedExecutionClass
            reasons.append("Action risk escalates execution class to \(escalatedExecutionClass.rawValue).")
        }

        let targetLocality = Self.expectedLocality(
            for: task.requestedDelegationTarget,
            privacyMode: privacyMode
        )
        if targetLocality != expectedLocality {
            expectedLocality = targetLocality
            reasons.append("Requested delegation target maps locality to \(targetLocality.rawValue).")
        }

        let cappedLocality = Self.cappedLocality(expectedLocality, privacyMode: privacyMode)
        if cappedLocality != expectedLocality {
            expectedLocality = cappedLocality
            reasons.append("Privacy mode constrains locality to \(cappedLocality.rawValue).")
        }

        if expectedLocality == .externalRequired {
            reasons.append("Policy result requires an external runtime.")
        }

        return RuntimeBudget(
            executionClass: executionClass,
            expectedLocality: expectedLocality,
            estimatedMemoryClass: estimatedMemoryClass,
            reasons: reasons
        )
    }

    private struct IntentFamily {
        let executionClass: RuntimeExecutionClass
        let expectedLocality: RuntimeLocality
        let estimatedMemoryClass: RuntimeMemoryClass
        let reason: String
    }

    private static func intentFamily(for intent: TaskIntent) -> IntentFamily {
        switch intent {
        case .findFile:
            return IntentFamily(
                executionClass: .tiny,
                expectedLocality: .localOnly,
                estimatedMemoryClass: .low,
                reason: "Intent family: lookup -> tiny."
            )
        case .summarizeNote, .createReminder:
            return IntentFamily(
                executionClass: .small,
                expectedLocality: .localOnly,
                estimatedMemoryClass: .moderate,
                reason: "Intent family: bounded synthesis -> small."
            )
        case .requestApproval, .unknown:
            return IntentFamily(
                executionClass: .large,
                expectedLocality: .trustedDevice,
                estimatedMemoryClass: .high,
                reason: "Intent family: broad synthesis -> large."
            )
        }
    }

    private static func escalatedMemoryClass(
        from base: RuntimeMemoryClass,
        for level: DataSensitivityLevel
    ) -> RuntimeMemoryClass? {
        guard level != .publicData else {
            return nil
        }

        switch base {
        case .low:
            return .moderate
        case .moderate:
            return .high
        case .high:
            return nil
        }
    }

    private static func escalatedExecutionClass(
        from base: RuntimeExecutionClass,
        for actionRisk: ActionRisk
    ) -> RuntimeExecutionClass? {
        guard actionRisk.requiresApproval else {
            return nil
        }

        switch base {
        case .tiny:
            return .small
        case .small:
            return .large
        case .large:
            return nil
        }
    }

    private static func expectedLocality(
        for requestedDelegationTarget: DelegationTarget,
        privacyMode: PrivacyMode
    ) -> RuntimeLocality {
        switch requestedDelegationTarget {
        case .none, .localDevice:
            return .localOnly
        case .trustedMac, .homeServer, .privateCloudCompute:
            return .trustedDevice
        case .externalProvider:
            return privacyMode == .externalAI ? .externalRequired : .trustedDevice
        }
    }

    private static func cappedLocality(
        _ locality: RuntimeLocality,
        privacyMode: PrivacyMode
    ) -> RuntimeLocality {
        switch privacyMode {
        case .localOnly:
            return .localOnly
        case .trustedDevices:
            return locality == .externalRequired ? .trustedDevice : locality
        case .externalAI:
            return locality
        }
    }
}
