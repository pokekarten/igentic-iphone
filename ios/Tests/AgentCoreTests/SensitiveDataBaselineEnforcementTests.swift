import XCTest
@testable import AgentCore

final class SensitiveDataBaselineEnforcementTests: XCTestCase {
    private struct EmptySensitiveDataDetector: SensitiveDataDetecting {
        func detect(in text: String) -> SensitiveDataDetectionResult {
            SensitiveDataDetectionResult(findings: [])
        }
    }

    private func compatibilityFullWidth(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x21...0x7E).contains(value), let mapped = UnicodeScalar(value + 0xFEE0) {
                result.unicodeScalars.append(mapped)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
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

    func testCompatibilityEquivalentIBANStillBlocksExternalDelegation() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let syntheticIBAN = ["DE", "89", "3704", "0044", "0532", "0130", "00"].joined()
        let compatibilityIBAN = compatibilityFullWidth(syntheticIBAN)
        let task = TaskRequest(
            userText: "Please send account \(compatibilityIBAN) to the external provider.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .externalProvider
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)

        XCTAssertFalse(response.policyDecision.isAllowed)
        if case .blocked = response.route {
            // Expected: Unicode compatibility forms cannot bypass the privacy floor.
        } else {
            XCTFail("Compatibility-equivalent IBAN text must remain restricted-sensitive.")
        }
        XCTAssertEqual(
            kernel.auditEvents().first { $0.type == .taskReceived }?.dataSensitivity,
            .restrictedSensitiveData
        )
    }

    func testDefaultIgnorableIBANStillBlocksExternalDelegation() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let syntheticIBAN = ["DE89", "\u{200B}", "370400440532013000"].joined()
        let task = TaskRequest(
            userText: "Please send account \(syntheticIBAN) to the external provider.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .externalProvider
        )

        let response = kernel.handle(task, privacyMode: .trustedDevices)

        XCTAssertFalse(response.policyDecision.isAllowed)
        if case .blocked = response.route {
            // Expected: invisible Unicode separators cannot bypass the privacy floor.
        } else {
            XCTFail("A default-ignorable split IBAN must remain restricted-sensitive.")
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
