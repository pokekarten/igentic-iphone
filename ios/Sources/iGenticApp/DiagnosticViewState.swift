import AgentCore
import Foundation

public struct DiagnosticStatusRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let route: String
    public let policy: String
    public let approval: String
    public let delegation: String

    public init(entry: ScenarioReportEntry) {
        self.id = entry.scenarioID
        self.title = Self.displayText(entry.scenarioID)
        self.route = Self.displayText(entry.route.rawValue)
        self.policy = entry.policyAllowed
            ? (entry.policyRequiresApproval ? "Approval required" : "Allowed")
            : "Blocked"
        self.approval = Self.displayText(entry.approvalStatus.rawValue)
        self.delegation = Self.displayText(entry.delegation.rawValue)
    }

    private static func displayText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}

public struct DiagnosticViewState: Equatable, Sendable {
    public let operatingMode: String
    public let auditStatus: String
    public let validationStatus: String
    public let privacyNotice: String
    public let rows: [DiagnosticStatusRow]

    public init(report: ScenarioReport = ScenarioRunner().report()) {
        self.operatingMode = "Local and trusted-device dry runs"
        self.auditStatus = "Synthetic metadata only"
        self.validationStatus = "Use current GitHub Actions evidence"
        self.privacyNotice = "No private content"
        self.rows = report.entries.map(DiagnosticStatusRow.init)
    }
}
