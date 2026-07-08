import XCTest
@testable import AgentCore

final class RiskScorerTests: XCTestCase {

    private let scorer = RiskScorer()

    // MARK: - Baseline

    func testBaselineMinimumRiskProducesLowestScoreAndNoApproval() {
        let request = RiskScoringRequest(
            privacyMode: .localOnly,
            dataClassification: DataClassification(level: .publicData, reason: "test"),
            actionRisk: .read,
            delegationTarget: .none
        )

        let score = scorer.score(request)

        XCTAssertEqual(score.value, 1)
        XCTAssertFalse(score.requiresExplicitApproval)
        // Only the data-classification reason is added when every other
        // contribution is zero.
        XCTAssertEqual(score.reasons.count, 1)
    }

    // MARK: - actionRisk contribution table
    // Isolated by holding delegation = .none and privacy = .trustedDevices,
    // which only contributes when delegationTarget == .externalProvider
    // (not the case here), so the action contribution is observed alone.

    func testActionRiskContributions() {
        let expected: [(ActionRisk, Int)] = [
            (.read, 0),
            (.prepare, 0),
            (.execute, 2),
            (.destructive, 3),
            (.externalShare, 3),
            (.critical, 5),
        ]

        for (actionRisk, contribution) in expected {
            let request = RiskScoringRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .publicData, reason: "test"),
                actionRisk: actionRisk,
                delegationTarget: .none
            )
            let score = scorer.score(request)
            XCTAssertEqual(
                score.value,
                1 + contribution,
                "actionRisk \(actionRisk) expected contribution \(contribution)"
            )
        }
    }

    // MARK: - delegationTarget contribution table
    // NOTE: privacyMode = .trustedDevices adds its own +1 specifically when
    // delegationTarget == .externalProvider (see contribution(for:privacyMode:)
    // in RiskScorer.swift). That coupling is real, not a test artifact, so the
    // expected totals below fold it in explicitly rather than assuming the
    // two dimensions are independent.

    func testDelegationTargetContributions() {
        let expected: [(DelegationTarget, Int /* delegation */, Int /* privacy coupling */)] = [
            (.none, 0, 0),
            (.localDevice, 0, 0),
            (.trustedMac, 1, 0),
            (.homeServer, 1, 0),
            (.privateCloudCompute, 2, 0),
            (.externalProvider, 3, 1), // trustedDevices + externalProvider => +1 extra
        ]

        for (delegationTarget, delegationContribution, privacyCoupling) in expected {
            let request = RiskScoringRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .publicData, reason: "test"),
                actionRisk: .read,
                delegationTarget: delegationTarget
            )
            let score = scorer.score(request)
            XCTAssertEqual(
                score.value,
                1 + delegationContribution + privacyCoupling,
                "delegationTarget \(delegationTarget) expected total mismatch"
            )
        }
    }

    // MARK: - privacyMode contribution (explicit, per documented coupling)

    func testPrivacyModeContributions() {
        struct Case {
            let privacyMode: PrivacyMode
            let delegationTarget: DelegationTarget
            let expectedTotal: Int
        }

        let cases: [Case] = [
            // localOnly contributes 0 only for none/localDevice, else 3
            Case(privacyMode: .localOnly, delegationTarget: .none, expectedTotal: 1),
            Case(privacyMode: .localOnly, delegationTarget: .localDevice, expectedTotal: 1),
            Case(privacyMode: .localOnly, delegationTarget: .trustedMac, expectedTotal: 1 + 1 /* delegation */ + 3 /* privacy */),

            // trustedDevices contributes 1 only for externalProvider, else 0
            Case(privacyMode: .trustedDevices, delegationTarget: .homeServer, expectedTotal: 1 + 1 /* delegation */ + 0),
            Case(privacyMode: .trustedDevices, delegationTarget: .externalProvider, expectedTotal: 1 + 3 /* delegation */ + 1 /* privacy */),

            // externalAI always contributes 2
            Case(privacyMode: .externalAI, delegationTarget: .none, expectedTotal: 1 + 0 + 2),
        ]

        for testCase in cases {
            let request = RiskScoringRequest(
                privacyMode: testCase.privacyMode,
                dataClassification: DataClassification(level: .publicData, reason: "test"),
                actionRisk: .read,
                delegationTarget: testCase.delegationTarget
            )
            let score = scorer.score(request)
            XCTAssertEqual(
                score.value,
                testCase.expectedTotal,
                "privacyMode \(testCase.privacyMode) / delegation \(testCase.delegationTarget) mismatch"
            )
        }
    }

    // MARK: - sensitiveDataFindings contribution

    func testSensitiveDataFindingContributions() {
        func makeRequest(findings: [SensitiveDataFinding]) -> RiskScoringRequest {
            RiskScoringRequest(
                privacyMode: .localOnly,
                dataClassification: DataClassification(level: .publicData, reason: "test"),
                actionRisk: .read,
                delegationTarget: .none,
                sensitiveDataFindings: findings
            )
        }

        let ibanScore = scorer.score(makeRequest(findings: [
            SensitiveDataFinding(category: .iban, reason: "test"),
        ]))
        XCTAssertEqual(ibanScore.value, 1 + 3)

        let emailScore = scorer.score(makeRequest(findings: [
            SensitiveDataFinding(category: .emailAddress, reason: "test"),
        ]))
        XCTAssertEqual(emailScore.value, 1 + 1)

        let phoneScore = scorer.score(makeRequest(findings: [
            SensitiveDataFinding(category: .phoneNumber, reason: "test"),
        ]))
        XCTAssertEqual(phoneScore.value, 1 + 1)

        // Findings accumulate additively, and each finding adds its own
        // reason line regardless of individual contribution size.
        let combinedFindings = [
            SensitiveDataFinding(category: .iban, reason: "test"),
            SensitiveDataFinding(category: .emailAddress, reason: "test"),
            SensitiveDataFinding(category: .phoneNumber, reason: "test"),
        ]
        let combinedScore = scorer.score(makeRequest(findings: combinedFindings))
        XCTAssertEqual(combinedScore.value, 1 + 3 + 1 + 1)
        XCTAssertEqual(combinedScore.reasons.count, 1 + combinedFindings.count)
    }

    // MARK: - Clamping

    func testScoreIsClampedToTenWhenContributionsExceedIt() {
        let request = RiskScoringRequest(
            privacyMode: .externalAI,
            dataClassification: DataClassification(level: .restrictedSensitiveData, reason: "test"),
            actionRisk: .critical,
            delegationTarget: .externalProvider,
            sensitiveDataFindings: [SensitiveDataFinding(category: .iban, reason: "test")]
        )
        // Raw sum would be 5 (base) + 5 (critical) + 3 (externalProvider)
        // + 2 (externalAI) + 3 (iban) = 18, clamped to 10.
        let score = scorer.score(request)
        XCTAssertEqual(score.value, 10)
        XCTAssertTrue(score.requiresExplicitApproval)
    }

    // NOTE ON LOWER-BOUND CLAMP: `RiskScore.init` also clamps to a minimum
    // of 1, but every contribution function in RiskScorer.swift returns a
    // non-negative value and the base term is `level.rawValue + 1` (minimum
    // 1 for .publicData). There is no combination reachable through the
    // public API that produces a raw value below 1, so the lower clamp
    // is defensive/unreachable code as far as this component's public
    // surface is concerned. Not asserted here as a discrepancy — flagging
    // it in the handoff report rather than fabricating a test for it.

    // MARK: - Approval threshold boundary

    func testApprovalThresholdBoundary() {
        let justBelowRequest = RiskScoringRequest(
            privacyMode: .localOnly,
            dataClassification: DataClassification(level: .publicData, reason: "test"),
            actionRisk: .critical,
            delegationTarget: .none
        )
        // 1 (base) + 5 (critical) = 6
        let justBelow = scorer.score(justBelowRequest)
        XCTAssertEqual(justBelow.value, 6)
        XCTAssertFalse(justBelow.requiresExplicitApproval)

        let atThresholdRequest = RiskScoringRequest(
            privacyMode: .localOnly,
            dataClassification: DataClassification(level: .publicData, reason: "test"),
            actionRisk: .critical,
            delegationTarget: .none,
            sensitiveDataFindings: [SensitiveDataFinding(category: .phoneNumber, reason: "test")]
        )
        // 6 + 1 (phoneNumber) = 7
        let atThreshold = scorer.score(atThresholdRequest)
        XCTAssertEqual(atThreshold.value, 7)
        XCTAssertTrue(atThreshold.requiresExplicitApproval)
    }
}