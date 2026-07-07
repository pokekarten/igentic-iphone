import AgentCore
import Foundation

enum DiagnosticPreviewData {
    static let sampleSnapshot = DiagnosticSnapshot(
        generatedAt: ISO8601DateFormatter().date(from: "2026-07-07T08:00:00Z") ?? Date(timeIntervalSince1970: 1_751_877_600),
        privacyMode: .trustedDevices,
        policy: PolicyDecisionSummary(isAllowed: true, requiresApproval: true),
        approval: ApprovalStatusSummary(status: .pending, mayContinueRouting: false),
        audit: AuditSummary(eventCount: 3, highestDataSensitivity: .contextualPrivateData),
        delegation: DelegationDecisionSummary(outcome: .requiresApproval),
        risk: RiskScoreSummary(value: 7, requiresExplicitApproval: true, reasonCount: 2)
    )
}
