import XCTest
@testable import AgentCore

final class LocalModelRuntimeTests: XCTestCase {
    func testDescriptorStoresMetadataOnlyRuntimeContract() {
        let runtime = FakeLocalModelRuntime()

        XCTAssertEqual(runtime.descriptor.identifier, "synthetic-local-runtime")
        XCTAssertEqual(runtime.descriptor.modelFamily, "synthetic-qwen-class")
        XCTAssertEqual(runtime.descriptor.executionKind, .local)
        XCTAssertEqual(runtime.descriptor.supportedCapabilities, [.summarization, .classification])
        XCTAssertEqual(runtime.descriptor.maximumDataSensitivity, .contextualPrivateData)
        XCTAssertEqual(runtime.descriptor.contextBudgetClass, .standard)
        XCTAssertEqual(runtime.descriptor.memoryBudgetClass, .moderate)
    }

    func testSupportedRequestWithinDataCeilingIsAccepted() {
        let decision = FakeLocalModelRuntime().assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .contextualPrivateData
            )
        )

        XCTAssertEqual(decision, .accepted)
        XCTAssertTrue(decision.isAccepted)
    }

    func testDelegatedRuntimeIsRejectedByDefaultLocalBoundary() {
        let decision = FakeLocalModelRuntime(executionKind: .delegated).assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .publicData
            )
        )

        XCTAssertEqual(
            decision,
            .rejected(.executionKindNotAllowed(actual: .delegated))
        )
        XCTAssertFalse(decision.isAccepted)
    }

    func testDelegatedRuntimeCanBeExplicitlyAssessedByDelegationPath() {
        let decision = FakeLocalModelRuntime(executionKind: .delegated).assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .publicData,
                allowedExecutionKinds: [.delegated]
            )
        )

        XCTAssertEqual(decision, .accepted)
        XCTAssertTrue(decision.isAccepted)
    }

    func testUnsupportedCapabilityIsRejectedBeforeInvocation() {
        let decision = FakeLocalModelRuntime().assess(
            LocalModelRequest(
                capability: .structuredProposal,
                dataSensitivity: .publicData
            )
        )

        XCTAssertEqual(decision, .rejected(.unsupportedCapability(.structuredProposal)))
        XCTAssertFalse(decision.isAccepted)
    }

    func testDataSensitivityAboveCeilingIsRejectedBeforeInvocation() {
        let decision = FakeLocalModelRuntime().assess(
            LocalModelRequest(
                capability: .summarization,
                dataSensitivity: .highlyPrivateData
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

    func testUnavailableRuntimeIsRejectedBeforeExecutionKindAndCapabilityChecks() {
        let runtime = FakeLocalModelRuntime(
            availability: .unavailable(.disabledByPolicy),
            executionKind: .delegated
        )

        let decision = runtime.assess(
            LocalModelRequest(
                capability: .textGeneration,
                dataSensitivity: .restrictedSensitiveData
            )
        )

        XCTAssertEqual(decision, .rejected(.runtimeUnavailable(.disabledByPolicy)))
    }
}

private struct FakeLocalModelRuntime: LocalModelRuntime {
    let descriptor: LocalModelRuntimeDescriptor
    let availability: LocalModelRuntimeAvailability

    init(
        availability: LocalModelRuntimeAvailability = .available,
        executionKind: LocalModelExecutionKind = .local
    ) {
        self.availability = availability
        self.descriptor = LocalModelRuntimeDescriptor(
            identifier: "synthetic-local-runtime",
            modelFamily: "synthetic-qwen-class",
            executionKind: executionKind,
            supportedCapabilities: [.summarization, .classification],
            maximumDataSensitivity: .contextualPrivateData,
            contextBudgetClass: .standard,
            memoryBudgetClass: .moderate
        )
    }
}
