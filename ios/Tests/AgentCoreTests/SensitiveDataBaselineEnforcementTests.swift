import XCTest
@testable import AgentCore

final class SensitiveDataBaselineEnforcementTests: XCTestCase {
    private struct EmptySensitiveDataDetector: SensitiveDataDetecting {
        func detect(in text: String) -> SensitiveDataDetectionResult {
            SensitiveDataDetectionResult(findings: [])
        }
    }

    private func restrictedExternalTask() -> TaskRequest {
        let iban = ["DE", "89", "3704", "0044", "0532", "0130", "00"].joined()
        return TaskRequest(
            userText: "Please send account \(iban) to the external provider.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .externalProvider
        )
    }

    func testInjectedEmptyDetectorCannotDowngradeKernelBaseline() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved),
            sensitiveDataDetector: EmptySensitiveDataDetector()
        )

        let response = kernel.handle(
            restrictedExternalTask(),
            privacyMode: .trustedDevices
        )

        XCTAssertFalse(response.policyDecision.isAllowed)
        if case .blocked = response.route {
            // Expected: built-in IBAN detection still blocks external delegation.
        } else {
            XCTFail("An injected empty detector must not suppress the built-in sensitive-data baseline.")
        }
        XCTAssertEqual(
            kernel.auditEvents().first { $0.type == .taskReceived }?.dataSensitivity,
            .restrictedSensitiveData
        )
    }

    func testEmptyPrecomputedDetectionCannotDowngradeKernelBaseline() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )

        let response = kernel.handle(
            restrictedExternalTask(),
            privacyMode: .trustedDevices,
            precomputedDetection: SensitiveDataDetectionResult(findings: [])
        )

        XCTAssertFalse(response.policyDecision.isAllowed)
        if case .blocked = response.route {
            // Expected: precomputed results are supplemental, not authoritative.
        } else {
            XCTFail("An empty precomputed result must not suppress the built-in sensitive-data baseline.")
        }
    }

    func testInjectedEmptyDetectorCannotDowngradeAppActionBaseline() {
        let coordinator = AppActionCoordinator(
            approvalManager: ApprovalManager(defaultStatus: .approved),
            sensitiveDataDetector: EmptySensitiveDataDetector()
        )
        let action = AppActionDraft(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            actionKind: .sendMessage,
            targetDescription: "external provider",
            payloadSummary: "Please use IBAN DE89 3704 0044 0532 0130 00",
            dataClassification: .publicDefault,
            actionRisk: .read
        )

        switch coordinator.approvalEvaluation(for: action, privacyMode: .trustedDevices) {
        case .blocked:
            break
        case .notRequired, .required:
            XCTFail("An injected empty detector must not suppress AppAction sensitive-data blocking.")
        }

        XCTAssertEqual(
            coordinator.perform(action, privacyMode: .trustedDevices),
            .rejected
        )
        XCTAssertTrue(
            coordinator.auditEvents().contains {
                $0.type == .blocked && $0.dataSensitivity == .restrictedSensitiveData
            }
        )
    }
}
