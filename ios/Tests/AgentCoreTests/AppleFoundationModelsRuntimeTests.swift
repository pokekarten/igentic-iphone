import XCTest
@testable import AgentCore

final class AppleFoundationModelsRuntimeTests: XCTestCase {
    func testDescriptorKeepsSystemBackendMetadataConservative() {
        let descriptor = AppleFoundationModelsRuntime(
            availabilityOverride: .available
        ).descriptor

        XCTAssertEqual(descriptor.identifier, "apple-foundation-models-system")
        XCTAssertEqual(descriptor.modelFamily, "apple-system-language-model")
        XCTAssertEqual(descriptor.executionKind, .system)
        XCTAssertEqual(
            descriptor.supportedCapabilities,
            [.textGeneration, .structuredProposal, .summarization, .classification]
        )
        XCTAssertEqual(descriptor.maximumDataSensitivity, .contextualPrivateData)
        XCTAssertEqual(descriptor.contextBudgetClass, .standard)
        XCTAssertEqual(descriptor.memoryBudgetClass, .moderate)
    }

    func testAvailabilityMappingsAreStableAndFailClosed() {
        let cases: [(AppleFoundationModelsAvailabilitySnapshot, LocalModelRuntimeAvailability)] = [
            (.available, .available),
            (.deviceNotEligible, .unavailable(.deviceNotEligible)),
            (.appleIntelligenceNotEnabled, .unavailable(.appleIntelligenceNotEnabled)),
            (.modelNotReady, .unavailable(.modelNotReady)),
            (.unsupportedPlatform, .unavailable(.unsupportedPlatform)),
            (.unknownSystemCondition, .unavailable(.unknownSystemCondition)),
        ]

        for (snapshot, expected) in cases {
            XCTAssertEqual(
                AppleFoundationModelsRuntime(availabilityOverride: snapshot).availability,
                expected
            )
        }
    }

    func testHighlyPrivateDataRemainsAboveSystemBackendCeiling() {
        let runtime = AppleFoundationModelsRuntime(availabilityOverride: .available)

        let decision = runtime.assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .highlyPrivateData,
                allowedExecutionKinds: [.system]
            )
        )

        XCTAssertEqual(
            decision,
            .rejected(
                .dataSensitivityExceedsCeiling(
                    requested: .highlyPrivateData,
                    maximum: .contextualPrivateData
                )
            )
        )
    }

    func testUnavailableSystemBackendRejectsBeforeCapabilityAssessment() {
        let runtime = AppleFoundationModelsRuntime(
            availabilityOverride: .appleIntelligenceNotEnabled
        )

        let decision = runtime.assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .publicData,
                allowedExecutionKinds: [.system]
            )
        )

        XCTAssertEqual(
            decision,
            .rejected(.runtimeUnavailable(.appleIntelligenceNotEnabled))
        )
    }
}
