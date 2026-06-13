import XCTest
@testable import AgentCore

final class SmokeTests: XCTestCase {
    func testPolicyAllowsLocalRead() {
        let engine = PolicyEngine()
        let decision = engine.decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )

        XCTAssertTrue(decision.isAllowed)
    }

    func testPolicyIncludesRiskMetadataForSafeLocalRead() {
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
        XCTAssertEqual(decision.riskScore.value, 1)
        XCTAssertFalse(decision.riskScore.requiresExplicitApproval)
        XCTAssertFalse(decision.riskScore.reasons.isEmpty)
    }

    func testPolicyKeepsLocalOnlyExternalDelegationBlockedWithRiskMetadata() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .prepare,
                requestedDelegationTarget: .trustedMac
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.reason, "Local Only blocks non-local delegation.")
        XCTAssertEqual(decision.riskScore.value, 5)
        XCTAssertFalse(decision.riskScore.reasons.isEmpty)
    }

    func testPolicyKeepsRestrictedExternalDelegationBlockedAndApprovalRequired() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .restrictedSensitiveData, reason: "Test restricted metadata."),
                actionRisk: .prepare,
                requestedDelegationTarget: .externalProvider
            )
        )

        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.reason, "Restricted sensitive data cannot be delegated automatically.")
        XCTAssertTrue(decision.riskScore.requiresExplicitApproval)
    }

    func testPolicyKeepsCriticalActionsApprovalRequired() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: .publicDefault,
                actionRisk: .critical,
                requestedDelegationTarget: .trustedMac
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertTrue(decision.requiresApproval)
        XCTAssertEqual(decision.riskScore.value, 7)
        XCTAssertTrue(decision.riskScore.requiresExplicitApproval)
    }

    func testPolicyRiskScoreDoesNotAddApprovalByItself() {
        let decision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .contextualPrivateData, reason: "Test contextual metadata."),
                actionRisk: .prepare,
                requestedDelegationTarget: .externalProvider
            )
        )

        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresApproval)
        XCTAssertEqual(decision.riskScore.value, 7)
        XCTAssertTrue(decision.riskScore.requiresExplicitApproval)
    }

    func testDiagnosticSnapshotUsesMetadataOnlySummaries() {
        let rawPrivateValue = "DE44500105175407324931"
        let policyDecision = PolicyEngine().decide(
            PolicyRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                requestedDelegationTarget: .localDevice
            )
        )
        let approvalReceipt = ApprovalManager(defaultStatus: .approved).approvalReceipt(
            for: ApprovalRequest(
                taskSummary: "Synthetic diagnostic task",
                dataClassification: .publicDefault,
                actionRisk: .read,
                reason: "synthetic-diagnostic-check"
            )
        )
        let auditLog = AuditLog()
        auditLog.record(
            AuditEvent(
                type: .policyDecision,
                message: "Synthetic event with raw value that must not leave audit events: \(rawPrivateValue)",
                dataSensitivity: .restrictedSensitiveData
            )
        )
        let delegationDecision = DelegationBroker().decide(
            DelegationRequest(
                privacyMode: .trustedDevices,
                target: .localDevice,
                dataClassification: .publicDefault,
                actionRisk: .read,
                reason: "synthetic local diagnostic"
            )
        )

        let snapshot = DiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            privacyMode: .localOnly,
            policy: PolicyDecisionSummary(policyDecision),
            approval: ApprovalStatusSummary(approvalReceipt),
            audit: AuditSummary(events: auditLog.allEvents()),
            delegation: DelegationDecisionSummary(delegationDecision),
            risk: RiskScoreSummary(policyDecision.riskScore)
        )

        XCTAssertEqual(snapshot.policy.isAllowed, true)
        XCTAssertEqual(snapshot.approval.status, .approved)
        XCTAssertEqual(snapshot.audit.eventCount, 1)
        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(snapshot.risk.value, 1)
        XCTAssertFalse(snapshot.metadataLines.joined(separator: "\n").contains(rawPrivateValue))
    }

    func testAuditLogRecordsEvents() {
        let log = AuditLog()
        let event = AuditEvent(
            type: .taskReceived,
            message: "test event",
            dataSensitivity: .publicData
        )

        log.record(event)

        XCTAssertEqual(log.allEvents(), [event])
    }

    func testAuditLogReturnsSnapshot() {
        let log = AuditLog()
        log.record(
            AuditEvent(
                type: .taskReceived,
                message: "first",
                dataSensitivity: .publicData
            )
        )

        let snapshot = log.allEvents()
        log.record(
            AuditEvent(
                type: .routeSelected,
                message: "second",
                dataSensitivity: .publicData
            )
        )

        XCTAssertEqual(snapshot.count, 1)
        XCTAssertEqual(log.allEvents().count, 2)
    }

    func testAgentKernelStopsWhenApprovalIsPending() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .pending)
        )
        let task = TaskRequest(
            userText: "Prepare reviewed task",
            intent: .createReminder,
            actionRisk: .execute
        )

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertEqual(response.approvalStatus, .pending)
        XCTAssertEqual(response.route, .approvalRequired(reason: "Approval is required before routing."))
    }

    func testAgentKernelRoutesWhenApprovalIsApproved() {
        let kernel = AgentKernel(
            approvalManager: ApprovalManager(defaultStatus: .approved)
        )
        let task = TaskRequest(
            userText: "Prepare reviewed task",
            intent: .createReminder,
            actionRisk: .execute
        )

        let response = kernel.handle(task, privacyMode: .localOnly)

        XCTAssertEqual(response.approvalStatus, .approved)
        XCTAssertEqual(response.route, .localTool(name: "createReminder", reason: "Reminder creation is a typed local action."))
    }

    func testToolRegistryStoresToolMetadataOnly() {
        let registry = ToolRegistry()
        let tool = ToolDefinition(
            name: "createReminder",
            requiredDataLevel: .contextualPrivateData,
            actionRisk: .prepare,
            description: "Prepare a local reminder action."
        )

        registry.register(tool)

        XCTAssertEqual(registry.tool(named: "createReminder"), tool)
        XCTAssertNil(registry.tool(named: "sendMessage"))
    }

    func testToolRegistryReturnsSortedSnapshot() {
        let registry = ToolRegistry()
        registry.register(
            ToolDefinition(
                name: "summarizeNote",
                requiredDataLevel: .contextualPrivateData,
                actionRisk: .prepare,
                description: "Prepare a local note summary."
            )
        )
        registry.register(
            ToolDefinition(
                name: "createReminder",
                requiredDataLevel: .contextualPrivateData,
                actionRisk: .prepare,
                description: "Prepare a local reminder action."
            )
        )

        XCTAssertEqual(registry.allTools().map(\.name), ["createReminder", "summarizeNote"])
    }

    func testMemoryStoreSavesAndListsEntriesByScope() {
        let store = MemoryStore()

        store.save(key: "session-summary", value: "metadata-only", scope: .session)
        store.save(key: "task-state", value: "pending", scope: .task)

        let sessionEntries = store.entries(in: .session)
        let taskEntries = store.entries(in: .task)

        XCTAssertEqual(sessionEntries.map(\.key), ["session-summary"])
        XCTAssertEqual(sessionEntries.map(\.value), ["metadata-only"])
        XCTAssertEqual(taskEntries.map(\.key), ["task-state"])
        XCTAssertEqual(taskEntries.map(\.value), ["pending"])
    }

    func testMemoryStoreOverwritesWithinSameScope() {
        let store = MemoryStore()

        let firstEntry = store.save(key: "task-state", value: "pending", scope: .task)
        let updatedEntry = store.save(key: "task-state", value: "approved", scope: .task)

        XCTAssertEqual(firstEntry.id, updatedEntry.id)
        XCTAssertEqual(store.entries(in: .task).count, 1)
        XCTAssertEqual(store.entries(in: .task).first?.value, "approved")
    }

    func testMemoryStoreDeletesOnlyRequestedScope() {
        let store = MemoryStore()

        store.save(key: "session-summary", value: "metadata-only", scope: .session)
        store.save(key: "task-state", value: "pending", scope: .task)

        store.delete(scope: .session)

        XCTAssertTrue(store.entries(in: .session).isEmpty)
        XCTAssertEqual(store.entries(in: .task).map(\.key), ["task-state"])
    }

    func testSensitiveDataDetectorFlagsIBANWithoutRetainingRawValue() {
        let result = SensitiveDataDetector().detect(
            in: "Bitte pruefe DE44500105175407324931 fuer die lokale Risikoanalyse."
        )

        XCTAssertEqual(result.findings.map(\.category), [.iban])
        XCTAssertEqual(result.suggestedDataClassification.level, .restrictedSensitiveData)
        XCTAssertFalse(result.findings.contains { $0.reason.contains("DE44500105175407324931") })
    }

    func testSensitiveDataDetectorFlagsEmailAndPhoneAsMetadataCategories() {
        let result = SensitiveDataDetector().detect(
            in: "Kontakt: test@example.com oder +49 151 12345678."
        )

        XCTAssertEqual(result.findings.map(\.category), [.emailAddress, .phoneNumber])
        XCTAssertEqual(result.suggestedDataClassification.level, .contextualPrivateData)
    }

    func testRiskScorerKeepsLocalPublicReadLow() {
        let score = RiskScorer().score(
            RiskScoringRequest(
                privacyMode: .localOnly,
                dataClassification: .publicDefault,
                actionRisk: .read,
                delegationTarget: .localDevice
            )
        )

        XCTAssertEqual(score.value, 1)
        XCTAssertFalse(score.requiresExplicitApproval)
    }

    func testRiskScorerRaisesExternalProviderRisk() {
        let scorer = RiskScorer()
        let localScore = scorer.score(
            RiskScoringRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .contextualPrivateData, reason: "Test metadata."),
                actionRisk: .prepare,
                delegationTarget: .localDevice
            )
        )
        let externalScore = scorer.score(
            RiskScoringRequest(
                privacyMode: .trustedDevices,
                dataClassification: DataClassification(level: .contextualPrivateData, reason: "Test metadata."),
                actionRisk: .prepare,
                delegationTarget: .externalProvider
            )
        )

        XCTAssertGreaterThan(externalScore.value, localScore.value)
        XCTAssertEqual(externalScore.value, 7)
        XCTAssertTrue(externalScore.requiresExplicitApproval)
    }

    func testRiskScorerTreatsCriticalActionsAsHighRisk() {
        let score = RiskScorer().score(
            RiskScoringRequest(
                privacyMode: .trustedDevices,
                dataClassification: .publicDefault,
                actionRisk: .critical,
                delegationTarget: .trustedMac
            )
        )

        XCTAssertEqual(score.value, 7)
        XCTAssertTrue(score.requiresExplicitApproval)
    }

    func testRiskScorerTreatsIBANLikeDataAsHighRisk() {
        let detection = SensitiveDataDetector().detect(
            in: "IBAN fuer Test: DE44500105175407324931"
        )
        let score = RiskScorer().score(
            RiskScoringRequest(
                privacyMode: .localOnly,
                dataClassification: detection.suggestedDataClassification,
                actionRisk: .read,
                delegationTarget: .localDevice,
                sensitiveDataFindings: detection.findings
            )
        )

        XCTAssertEqual(score.value, 8)
        XCTAssertTrue(score.requiresExplicitApproval)
    }

    func testDelegationBrokerBlocksLocalOnlyMode() {
        let broker = DelegationBroker()
        let decision = broker.decide(
            DelegationRequest(
                privacyMode: .localOnly,
                target: .trustedMac,
                actionRisk: .prepare
            )
        )

        XCTAssertEqual(decision, .blocked(reason: "Local Only prevents delegation."))
        XCTAssertFalse(decision.isAllowed)
        XCTAssertFalse(decision.requiresExplicitApproval)
    }

    func testDelegationBrokerRequiresApprovalForExternalProvider() {
        let broker = DelegationBroker()
        let decision = broker.decide(
            DelegationRequest(
                privacyMode: .trustedDevices,
                target: .externalProvider,
                actionRisk: .prepare
            )
        )

        XCTAssertEqual(decision, .requiresApproval(reason: "External provider delegation requires explicit approval."))
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.requiresExplicitApproval)
    }

    func testDelegationBrokerRequiresApprovalForCriticalAction() {
        let broker = DelegationBroker()
        let decision = broker.decide(
            DelegationRequest(
                privacyMode: .trustedDevices,
                target: .trustedMac,
                actionRisk: .critical
            )
        )

        XCTAssertEqual(decision, .requiresApproval(reason: "Critical actions require explicit approval."))
        XCTAssertFalse(decision.isAllowed)
        XCTAssertTrue(decision.requiresExplicitApproval)
    }

    func testDelegationBrokerAllowsSafeTrustedDeviceMetadataDecision() {
        let broker = DelegationBroker()
        let decision = broker.decide(
            DelegationRequest(
                privacyMode: .trustedDevices,
                target: .trustedMac,
                actionRisk: .prepare
            )
        )

        XCTAssertEqual(decision, .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision."))
        XCTAssertTrue(decision.isAllowed)
        XCTAssertFalse(decision.requiresExplicitApproval)
    }

    func testScenarioRunnerProvidesDefaultDryRunScenarios() {
        let results = ScenarioRunner().runAll()

        XCTAssertEqual(
            results.map(\.scenarioID),
            ["local-only-summary", "critical-reminder", "external-provider-check", "trusted-device-metadata"]
        )
        XCTAssertEqual(results.count, 4)
    }

    func testScenarioRunnerKeepsLocalOnlyDelegationBlocked() {
        let result = ScenarioRunner().runAll().first { $0.scenarioID == "local-only-summary" }

        XCTAssertEqual(result?.route, .localTool(name: "summarizeNote", reason: "Note summarization must stay local unless policy allows delegation."))
        XCTAssertEqual(result?.delegationDecision, .blocked(reason: "Local Only prevents delegation."))
    }

    func testScenarioRunnerReportsCriticalApprovalPath() {
        let result = ScenarioRunner().runAll().first { $0.scenarioID == "critical-reminder" }

        XCTAssertEqual(result?.route, .approvalRequired(reason: "Approval is required before routing."))
        XCTAssertEqual(result?.approvalStatus, .pending)
        XCTAssertEqual(result?.delegationDecision, .requiresApproval(reason: "Critical actions require explicit approval."))
    }

    func testScenarioRunnerReportsTrustedDeviceMetadataPath() {
        let result = ScenarioRunner().runAll().first { $0.scenarioID == "trusted-device-metadata" }

        XCTAssertEqual(result?.route, .localTool(name: "findFile", reason: "File search starts with local metadata and permissions."))
        XCTAssertEqual(result?.delegationDecision, .allowedMetadataOnly(reason: "Allowed as metadata-only delegation decision."))
    }
}
