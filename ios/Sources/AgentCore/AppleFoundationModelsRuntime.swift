import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum AppleFoundationModelsAvailabilitySnapshot: Equatable, Sendable {
    case available
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case unsupportedLocale
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
        case .unsupportedLocale:
            return .unavailable(.unsupportedLocale)
        case .unsupportedPlatform:
            return .unavailable(.unsupportedPlatform)
        case .unknownSystemCondition:
            return .unavailable(.unknownSystemCondition)
        }
    }

    private static func currentAvailabilitySnapshot() -> AppleFoundationModelsAvailabilitySnapshot {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            let systemModel = SystemLanguageModel.default
            let snapshot = foundationModelsAvailabilitySnapshot(systemModel.availability)
            guard snapshot == .available else {
                return snapshot
            }
            // OS availability alone does not imply that the user's preferred
            // language is supported by the installed on-device model.
            // Keep this local: do not silently fall back to a hosted provider.
            let preferredLocale = Locale.preferredLanguages.first.map {
                Locale(identifier: $0)
            } ?? Locale.current
            return systemModel.supportsLocale(preferredLocale)
                ? .available
                : .unsupportedLocale
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
