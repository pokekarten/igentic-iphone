import XCTest
@testable import AgentCore

/// Pins the exact policy contract used by the system-facing read-only Intent.
/// No simulated approval or agent-provided data can authorize a write.
final class ShortcutPolicyBoundaryTests: XCTestCase {
    func testLocalReadOnlyIntentIsAllowedWithoutApproval() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )
        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .allowedWithCurrentSafeguards)
    }

    func testExternalProviderIsBlockedInLocalOnlyMode() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .externalProvider
            )
        )
        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .localOnlyBlocksNonLocalDelegation)
    }

    func testLocalWriteRequiresApprovalAndCannotUseReadOnlyPath() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .execute,
                requestedDelegationTarget: .localDevice
            )
        )
        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reasonCode, .actionRequiresApproval)
    }
}
