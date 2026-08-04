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
    public let approvalPolicyFields: [DiagnosticSnapshotField]
    public let modelSelectionFields: [DiagnosticSnapshotField]
    public let auditEventsDescription: String
    public let rows: [DiagnosticStatusRow]

    public init(report: ScenarioReport = ScenarioRunner().report()) {
        self.init(
            report: report,
            snapshot: Self.syntheticScenarioSnapshot(),
            policy: .default
        )
    }

    public init(
        report: ScenarioReport = ScenarioRunner().report(),
        snapshot: DiagnosticSnapshot?,
        policy: AppActionApprovalPolicy = .default
    ) {
        self.operatingMode = "Local and trusted-device dry runs"
        self.runtimeStatus = snapshot == nil
            ? "No live diagnostic snapshot available"
            : "Synthetic preview snapshot loaded"
        self.auditStatus = "Synthetic metadata only"
        self.validationStatus = "Use current GitHub Actions evidence"
        self.privacyNotice = "No private content"
        self.snapshotSource = snapshot == nil ? "Not available" : "Synthetic preview result (critical-reminder)"
        self.snapshotFields = Self.makeSnapshotFields(snapshot)
        self.approvalPolicyFields = Self.makeApprovalPolicyFields(policy: policy)
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
                DiagnosticSnapshotField(label: "Policy allow gate", value: "—"),
                DiagnosticSnapshotField(label: "Approval gate", value: "—"),
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
            DiagnosticSnapshotField(label: "Policy allow gate", value: Self.boolText(snapshot.policy.isAllowed)),
            DiagnosticSnapshotField(label: "Approval gate", value: Self.boolText(snapshot.policy.requiresApproval)),
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

    private static func makeApprovalPolicyFields(policy: AppActionApprovalPolicy) -> [DiagnosticSnapshotField] {
        return [
            DiagnosticSnapshotField(label: "Policy schema", value: "v\(policy.schemaVersion)"),
            DiagnosticSnapshotField(label: "Send message approval required", value: approvalPolicyText(for: .sendMessage, policy: policy)),
            DiagnosticSnapshotField(label: "Delete record approval required", value: approvalPolicyText(for: .deleteRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Update record approval required", value: approvalPolicyText(for: .updateRecord, policy: policy)),
            DiagnosticSnapshotField(label: "Export data approval required", value: approvalPolicyText(for: .exportData, policy: policy)),
        ]
    }

    private static func approvalPolicyText(for actionKind: AppActionDraft.ActionKind, policy: AppActionApprovalPolicy) -> String {
        guard let requiresApproval = policy.requiresApproval(for: actionKind) else {
            return "Not configured"
        }
        return boolText(requiresApproval)
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
            ModelCandidate(
                modelID: "model-delta",
                evaluationScore: 0.65,
                latencyScore: 0.85,
                capabilityMatch: 0.10,
                latencyMS: 30,
                contextSize: 2048,
                maxContextTokens: 1024,
                latencyBudgetClass: .medium,
                toolUsageSupported: false
            ),
        ]

        let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
            candidates: candidates,
            request: request,
            policy: .v1
        )

        return modelSelectionFields(for: trace)
    }

    /// Pure diagnostic formatting seam. This does not select a model or execute work.
    static func modelSelectionFields(for trace: ModelSelectionDecisionTrace) -> [DiagnosticSnapshotField] {
        var fields: [DiagnosticSnapshotField] = [
            DiagnosticSnapshotField(label: "Trace schema", value: trace.schemaVersion),
            DiagnosticSnapshotField(label: "Selection request", value: Self.selectionRequestText(trace.request)),
            DiagnosticSnapshotField(label: "Selected model id", value: trace.selectedModelID),
            DiagnosticSnapshotField(label: "Selection reason", value: displayText(Self.selectionReasonText(trace.selectionReason))),
            DiagnosticSnapshotField(label: "Selected score", value: trace.selectedScore.map { Self.scoreText($0) } ?? "—"),
            DiagnosticSnapshotField(label: "Fallback reason", value: trace.fallbackReason.map { displayText(Self.fallbackReasonText($0)) } ?? "None"),
        ]

        fields.append(contentsOf: trace.candidates.map { candidate in
            DiagnosticSnapshotField(
                label: "Candidate: \(candidate.modelID)",
                value: Self.candidateText(candidate)
            )
        })

        return fields
    }

    private static func selectionRequestText(_ request: ModelSelectionRequest) -> String {
        "latencyBudget=\(displayText(request.latencyBudget.rawValue)), contextSize=\(request.contextSize), toolUsageRequired=\(boolText(request.toolUsageRequired))"
    }

    private static func candidateText(_ candidate: ModelSelectionTraceCandidate) -> String {
        var parts: [String] = [candidate.eligible ? "Eligible" : "Rejected"]

        if candidate.eligible {
            if let weightedScore = candidate.weightedScore {
                parts.append("Score \(scoreText(weightedScore))")
            }
            if let scoreComponents = candidate.scoreComponents {
                parts.append("Components: eval \(scoreText(scoreComponents.evaluation)), latency \(scoreText(scoreComponents.latency)), capability \(scoreText(scoreComponents.capability))")
            }
        } else if !candidate.rejectionReasons.isEmpty {
            let reasons = candidate.rejectionReasons.map { displayText($0.rawValue) }.joined(separator: ", ")
            parts.append("Reasons: \(reasons)")
        }

        parts.append("Latency \(candidate.latencyMS) ms")
        return parts.joined(separator: " · ")
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

    private static func fallbackReasonText(_ reason: ModelSelectionTraceFallbackReason) -> String {
        switch reason {
        case .noEligibleCandidates:
            return "noEligibleCandidates"
        case .unresolvedScoreAndLatencyTie:
            return "unresolvedScoreAndLatencyTie"
        }
    }

    private static func scoreText(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
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
