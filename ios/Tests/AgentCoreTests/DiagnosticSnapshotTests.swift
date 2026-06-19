import XCTest
@testable import AgentCore

final class DiagnosticSnapshotTests: XCTestCase {
    func testSnapshotCanBeConstructedFromSyntheticRuntimeValues() {
        let policyDecision = PolicyDecision(
            isAllowed: true,
            requiresApproval: false,
            reason: "Synthetic policy reason.",
            riskScore: RiskScore(value: 3, reasons: ["Synthetic risk metadata."])
        )
        let approvalReceipt = ApprovalReceipt(
            status: .approved,
            requestID: "synthetic-request",
            reasonCode: "synthetic-approval",
            mayContinueRouting: true
        )
        let auditEvents = [
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 1),
                type: .policyDecision,
                message: "Synthetic low-risk event.",
                dataSensitivity: .lowRiskAppData
            ),
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 2),
                type: .approvalRequired,
                message: "Synthetic restricted event.",
                dataSensitivity: .restrictedSensitiveData
            ),
        ]
        let delegationDecision = DelegationDecision.requiresApproval(
            reason: "Synthetic delegation approval."
        )

        let snapshot = DiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 42),
            privacyMode: .trustedDevices,
            policy: PolicyDecisionSummary(policyDecision),
            approval: ApprovalStatusSummary(approvalReceipt),
            audit: AuditSummary(events: auditEvents),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(policyDecision.riskScore)
        )

        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 42))
        XCTAssertEqual(snapshot.privacyMode, .trustedDevices)
        XCTAssertTrue(snapshot.policy.isAllowed)
        XCTAssertFalse(snapshot.policy.requiresApproval)
        XCTAssertEqual(snapshot.approval.status, .approved)
        XCTAssertTrue(snapshot.approval.mayContinueRouting)
        XCTAssertEqual(snapshot.audit.eventCount, 2)
        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(snapshot.delegation.outcome, .requiresApproval)
        XCTAssertEqual(snapshot.risk.value, 3)
        XCTAssertFalse(snapshot.risk.requiresExplicitApproval)
        XCTAssertEqual(snapshot.risk.reasonCount, 1)
    }

    func testMetadataOutputExcludesRawRuntimeReasonsAndPrivateValues() {
        let rawPrivateValue = "DE44500105175407324931"
        let policyDecision = PolicyDecision(
            isAllowed: false,
            requiresApproval: true,
            reason: rawPrivateValue,
            riskScore: RiskScore(value: 9, reasons: [rawPrivateValue])
        )
        let approvalReceipt = ApprovalReceipt(
            status: .pending,
            requestID: rawPrivateValue,
            reasonCode: rawPrivateValue,
            mayContinueRouting: false
        )
        let auditEvent = AuditEvent(
            timestamp: Date(timeIntervalSince1970: 5),
            type: .blocked,
            message: rawPrivateValue,
            dataSensitivity: .restrictedSensitiveData
        )
        let delegationDecision = DelegationDecision.blocked(reason: rawPrivateValue)

        let snapshot = DiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 7),
            privacyMode: .localOnly,
            policy: PolicyDecisionSummary(policyDecision),
            approval: ApprovalStatusSummary(approvalReceipt),
            audit: AuditSummary(events: [auditEvent]),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(policyDecision.riskScore)
        )
        let output = snapshot.metadataLines.joined(separator: "\n")

        XCTAssertFalse(output.contains(rawPrivateValue))
        XCTAssertFalse(output.contains(policyDecision.reason))
        XCTAssertFalse(output.contains(approvalReceipt.requestID))
        XCTAssertFalse(output.contains(approvalReceipt.reasonCode))
        XCTAssertEqual(snapshot.delegation.outcome, .blocked)
        XCTAssertEqual(snapshot.audit.eventCount, 1)
        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(snapshot.risk.reasonCount, 1)
    }

    func testMetadataLinesAreDeterministicForFixedSnapshot() {
        let snapshot = DiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 10),
            privacyMode: .localOnly,
            policy: PolicyDecisionSummary(isAllowed: true, requiresApproval: false),
            approval: ApprovalStatusSummary(status: .notRequired, mayContinueRouting: true),
            audit: AuditSummary(eventCount: 0, highestDataSensitivity: .publicData),
            delegation: DelegationDecisionSummary(outcome: .allowedMetadataOnly),
            risk: RiskScoreSummary(value: 1, requiresExplicitApproval: false, reasonCount: 0)
        )

        XCTAssertEqual(
            snapshot.metadataLines,
            [
                "generatedAt=10.0",
                "privacyMode=Local Only",
                "policyAllowed=true",
                "policyRequiresApproval=false",
                "approvalStatus=notRequired",
                "approvalMayContinueRouting=true",
                "auditEventCount=0",
                "auditHighestSensitivity=0",
                "delegationOutcome=allowedMetadataOnly",
                "riskValue=1",
                "riskRequiresApproval=false",
                "riskReasonCount=0",
            ]
        )
    }
}
