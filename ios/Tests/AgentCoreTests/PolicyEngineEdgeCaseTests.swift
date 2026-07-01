import XCTest
@testable import AgentCore

final class PolicyEngineEdgeCaseTests: XCTestCase {
    func testKernelPreservesLocalDeviceDefaultDelegationTarget() {
        let response = AgentKernel().handle(
            TaskRequest(userText: "Remind me", intent: .createReminder),
            privacyMode: .localOnly
        )

        XCTAssertTrue(response.policyDecision.isAllowed)
        XCTAssertEqual(response.policyDecision.reasonCode, .allowedWithCurrentSafeguards)
        XCTAssertEqual(
            response.route,
            .localTool(name: "createReminder", reason: "Reminder creation is a typed local action.")
        )
    }

    func testKernelBlocksExternalProviderDelegationUnderLocalOnlyPrivacyMode() {
        let response = AgentKernel().handle(
            TaskRequest(
                userText: "Delegate this",
                intent: .requestApproval,
                requestedDelegationTarget: .externalProvider
            ),
            privacyMode: .localOnly
        )

        XCTAssertFalse(response.policyDecision.isAllowed)
        XCTAssertEqual(response.policyDecision.reasonCode, .localOnlyBlocksNonLocalDelegation)
        XCTAssertEqual(response.route, .blocked(reason: "Local Only blocks non-local delegation."))
    }

    func testLocalOnlyBlocksExternalProviderBeforeApprovalEscalation() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(level: .restrictedSensitiveData, reason: "Synthetic restricted metadata."),
                actionRisk: .critical,
                requestedDelegationTarget: .externalProvider
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .localOnlyBlocksNonLocalDelegation)
        XCTAssertEqual(decision.reason, "Local Only blocks non-local delegation.")
    }

    func testRestrictedDataBlocksAutomaticTrustedDeviceDelegation() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .restrictedSensitiveData, reason: "Synthetic restricted metadata."),
                actionRisk: .prepare,
                requestedDelegationTarget: .trustedMac
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .restrictedDataBlocksAutomaticExternalDelegation)
        XCTAssertEqual(decision.reason, "Restricted sensitive data cannot be delegated automatically.")
    }

    func testSensitiveLocalCriticalActionRequiresApprovalWithoutDelegation() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(level: .restrictedSensitiveData, reason: "Synthetic restricted metadata."),
                actionRisk: .critical,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .dataAndActionRequireApproval)
        XCTAssertEqual(decision.reason, "Policy allows task with current safeguards.")
    }
}