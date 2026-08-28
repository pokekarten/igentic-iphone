#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelsAvailabilitySnapshot: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedPlatform
    case unknownSystemCondition
}

public struct AppleFoundationModelsRuntime: LocalModelRuntime {
    private let availabilityOverride: AppleFoundationModelsAvailabilitySnapshot?

    public init() {
        availabilityOverride = nil
    }

    init(availabilityOverride: AppleFoundationModelsAvailabilitySnapshot) {
        self.availabilityOverride = availabilityOverride
    }

    public var descriptor: LocalModelRuntimeDescriptor {
        LocalModelRuntimeDescriptor(
            identifier: "apple-foundation-models-system",
            modelFamily: "apple-system-language-model",
            executionKind: .system,
            supportedCapabilities: [
                .textGeneration,
                .structuredProposal,
                .summarization,
                .classification,
            ],
            maximumDataSensitivity: .contextualPrivateData,
            contextBudgetClass: .standard,
            memoryBudgetClass: .moderate
        )
    }

    public var availability: LocalModelRuntimeAvailability {
        Self.mapAvailability(availabilityOverride ?? Self.currentAvailabilitySnapshot())
    }

    static func mapAvailability(
        _ snapshot: AppleFoundationModelsAvailabilitySnapshot
    ) -> LocalModelRuntimeAvailability {
        switch snapshot {
        case .available:
            return .available
        case .deviceNotEligible:
            return .unavailable(.deviceNotEligible)
        case .appleIntelligenceNotEnabled:
            return .unavailable(.appleIntelligenceNotEnabled)
        case .modelNotReady:
            return .unavailable(.modelNotReady)
        case .unsupportedPlatform:
            return .unavailable(.unsupportedPlatform)
        case .unknownSystemCondition:
            return .unavailable(.unknownSystemCondition)
        }
    }

    private static func currentAvailabilitySnapshot() -> AppleFoundationModelsAvailabilitySnapshot {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            return foundationModelsAvailabilitySnapshot(
                SystemLanguageModel.default.availability
            )
        }
        #endif

        return .unsupportedPlatform
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func foundationModelsAvailabilitySnapshot(
        _ availability: SystemLanguageModel.Availability
    ) -> AppleFoundationModelsAvailabilitySnapshot {
        switch availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:
                return .deviceNotEligible
            case .appleIntelligenceNotEnabled:
                return .appleIntelligenceNotEnabled
            case .modelNotReady:
                return .modelNotReady
            @unknown default:
                return .unknownSystemCondition
            }
        @unknown default:
            return .unknownSystemCondition
        }
    }
    #endif
}
