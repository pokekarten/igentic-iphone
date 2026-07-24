import AgentCore
import Foundation

private func displayText(_ value: String) -> String {
    value
        .replacingOccurrences(of: "-", with: " ")
        .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        .capitalized
}

public struct DiagnosticStatusRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let route: String
    public let policy: String
    public let approval: String
    public let delegation: String

    public init(entry: ScenarioReportEntry) {
        self.id = entry.scenarioID
        // The diagnostic UI mirrors the structured report and keeps user task
        // text out of the visible surface.
        self.title = displayText(entry.scenarioID)
        self.route = displayText(entry.route.rawValue)
        self.policy = entry.policyAllowed
            ? (entry.policyRequiresApproval ? "Approval required" : "Allowed")
            : "Blocked"
        self.approval = displayText(entry.approvalStatus.rawValue)
        self.delegation = displayText(entry.delegation.rawValue)
    }
}

public struct DiagnosticSnapshotField: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.id = label
        self.label = label
        self.value = value
    }
}

public struct DiagnosticViewState: Equatable, Sendable {
    public let operatingMode: String
    public let runtimeStatus: String
    public let auditStatus: String
    public let validationStatus: String
    public let privacyNotice: String
    public let snapshotSource: String
    public let snapshotFields: [DiagnosticSnapshotField]
    public let modelSelectionFields: [DiagnosticSnapshotField]
    public let auditEventsDescription: String
    public let rows: [DiagnosticStatusRow]

    public init(report: ScenarioReport = ScenarioRunner().report()) {
        self.init(
            report: report,
            snapshot: Self.syntheticScenarioSnapshot()
        )
    }

    public init(
        report: ScenarioReport = ScenarioRunner().report(),
        snapshot: DiagnosticSnapshot?
    ) {
        self.operatingMode = "Local and trusted-device dry runs"
        self.runtimeStatus = snapshot == nil
            ? "No live diagnostic snapshot available"
            : "Preview snapshot loaded"
        self.auditStatus = "Synthetic metadata only"
        self.validationStatus = "Use current GitHub Actions evidence"
        self.privacyNotice = "No private content"
        self.snapshotSource = snapshot == nil ? "Not available" : "Synthetic scenario result (critical-reminder)"
        self.snapshotFields = Self.makeSnapshotFields(snapshot)
        // Fixed diagnostic example; this does not come from any live candidate registry.
        self.modelSelectionFields = Self.makeModelSelectionFields()
        self.auditEventsDescription = snapshot == nil
            ? "Not available"
            : "Detailed audit events are not available in this shell"
        self.rows = report.entries.map(DiagnosticStatusRow.init)
    }

    private static func syntheticScenarioSnapshot() -> DiagnosticSnapshot {
        guard let scenario = SyntheticScenarioCatalog.baseline.first(where: { $0.id == "critical-reminder" }) else {
            return DiagnosticPreviewData.sampleSnapshot
        }

        return DiagnosticSnapshotProducer().produceSnapshot(
            for: scenario.task,
            privacyMode: scenario.privacyMode,
            generatedAt: Self.iso8601.date(from: "2026-07-07T08:00:00Z") ?? Date(timeIntervalSince1970: 1_751_877_600)
        )
    }

    private static func makeSnapshotFields(_ snapshot: DiagnosticSnapshot?) -> [DiagnosticSnapshotField] {
        guard let snapshot else {
            return [
                DiagnosticSnapshotField(label: "Generated at", value: "—"),
                DiagnosticSnapshotField(label: "Privacy mode", value: "—"),
                DiagnosticSnapshotField(label: "Policy is allowed", value: "—"),
                DiagnosticSnapshotField(label: "Policy requires approval", value: "—"),
                DiagnosticSnapshotField(label: "Approval status", value: "—"),
                DiagnosticSnapshotField(label: "Approval may continue routing", value: "—"),
                DiagnosticSnapshotField(label: "Audit event count", value: "—"),
                DiagnosticSnapshotField(label: "Audit highest sensitivity", value: "—"),
                DiagnosticSnapshotField(label: "Delegation outcome", value: "—"),
                DiagnosticSnapshotField(label: "Risk value", value: "—"),
                DiagnosticSnapshotField(label: "Risk requires explicit approval", value: "—"),
                DiagnosticSnapshotField(label: "Risk reason count", value: "—"),
            ]
        }

        return [
            DiagnosticSnapshotField(label: "Generated at", value: Self.iso8601.string(from: snapshot.generatedAt)),
            DiagnosticSnapshotField(label: "Privacy mode", value: snapshot.privacyMode.rawValue),
            DiagnosticSnapshotField(label: "Policy is allowed", value: Self.boolText(snapshot.policy.isAllowed)),
            DiagnosticSnapshotField(label: "Policy requires approval", value: Self.boolText(snapshot.policy.requiresApproval)),
            DiagnosticSnapshotField(label: "Approval status", value: displayText(snapshot.approval.status.rawValue)),
            DiagnosticSnapshotField(label: "Approval may continue routing", value: Self.boolText(snapshot.approval.mayContinueRouting)),
            DiagnosticSnapshotField(label: "Audit event count", value: "\(snapshot.audit.eventCount)"),
            DiagnosticSnapshotField(label: "Audit highest sensitivity", value: snapshot.audit.highestDataSensitivity.highestDataSensitivityDescription),
            DiagnosticSnapshotField(label: "Delegation outcome", value: displayText(snapshot.delegation.outcome.rawValue)),
            DiagnosticSnapshotField(label: "Risk value", value: "\(snapshot.risk.value)"),
            DiagnosticSnapshotField(label: "Risk requires explicit approval", value: Self.boolText(snapshot.risk.requiresExplicitApproval)),
            DiagnosticSnapshotField(label: "Risk reason count", value: "\(snapshot.risk.reasonCount)"),
        ]
    }

    private static func makeModelSelectionFields() -> [DiagnosticSnapshotField] {
        let request = ModelSelectionRequest(latencyBudget: .low, contextSize: 2048, toolUsageRequired: true)
        let candidates = [
            ModelCandidate(
                modelID: "model-alpha",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 120,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-beta",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 80,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-gamma",
                evaluationScore: 0.70,
                latencyScore: 0.90,
                capabilityMatch: 0.30,
                latencyMS: 40,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
        ]

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: .v1)
        let reason = displayText(Self.selectionReasonText(result.reason))
        let score = result.score.map { String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), $0) } ?? "—"

        return [
            DiagnosticSnapshotField(label: "Selected model id", value: result.selectedModelID),
            DiagnosticSnapshotField(label: "Selection reason", value: reason),
            DiagnosticSnapshotField(label: "Score", value: score),
        ]
    }

    private static func selectionReasonText(_ reason: ModelSelectionReason) -> String {
        switch reason {
        case .highestWeightedScore:
            return "highestWeightedScore"
        case .lowestLatencyValidModel:
            return "lowestLatencyValidModel"
        case .safeRefusalModel:
            return "safeRefusalModel"
        }
    }

    private static func boolText(_ value: Bool) -> String {
        value ? "Yes" : "No"
    }

    private static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}

private extension DataSensitivityLevel {
    var highestDataSensitivityDescription: String {
        switch self {
        case .publicData:
            return "Public data"
        case .lowRiskAppData:
            return "Low risk app data"
        case .contextualPrivateData:
            return "Contextual private data"
        case .highlyPrivateData:
            return "Highly private data"
        case .restrictedSensitiveData:
            return "Restricted sensitive data"
        }
    }
}
