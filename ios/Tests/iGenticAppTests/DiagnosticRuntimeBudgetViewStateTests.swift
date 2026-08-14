import AgentCore
import Foundation
import XCTest
@testable import iGenticApp

final class DiagnosticRuntimeBudgetViewStateTests: XCTestCase {
    func testRendersRuntimeBudgetAsAdvisoryPlanningMetadata() {
        let snapshot = DiagnosticSnapshot(
            generatedAt: Date(timeIntervalSince1970: 400),
            privacyMode: .localOnly,
            policy: PolicyDecisionSummary(isAllowed: true, requiresApproval: false),
            approval: ApprovalStatusSummary(status: .notRequired, mayContinueRouting: true),
            audit: AuditSummary(eventCount: 4, highestDataSensitivity: .publicData),
            delegation: DelegationDecisionSummary(outcome: .allowedMetadataOnly),
            risk: RiskScoreSummary(value: 1, requiresExplicitApproval: false, reasonCount: 1),
            runtimeBudget: RuntimeBudgetSummary(
                executionClass: .tiny,
                expectedLocality: .localOnly,
                estimatedMemoryClass: .low,
                reasonCount: 1
            )
        )

        let state = DiagnosticViewState(
            report: ScenarioRunner().report(),
            snapshot: snapshot
        )
        let fields = Dictionary(uniqueKeysWithValues: state.snapshotFields.map { ($0.label, $0.value) })

        XCTAssertEqual(fields["Runtime budget stage"], "Advisory planning only")
        XCTAssertEqual(fields["Runtime execution class"], "Tiny")
        XCTAssertEqual(fields["Runtime expected locality"], "Local Only")
        XCTAssertEqual(fields["Runtime estimated memory class"], "Low")
        XCTAssertEqual(fields["Runtime reason count"], "1")

        let visibleRuntimeMetadata = state.snapshotFields
            .filter { $0.label.hasPrefix("Runtime") }
            .map(\.value)
            .joined(separator: " ")
        XCTAssertFalse(visibleRuntimeMetadata.contains("Intent family:"))
        XCTAssertFalse(visibleRuntimeMetadata.contains("Synthetic private"))
    }

    func testDefaultApprovalPendingPreviewReportsRuntimeBudgetNotReached() {
        let state = DiagnosticViewState()
        let fields = Dictionary(uniqueKeysWithValues: state.snapshotFields.map { ($0.label, $0.value) })

        XCTAssertEqual(fields["Approval status"], "Pending")
        XCTAssertEqual(fields["Runtime budget stage"], "Not reached")
        XCTAssertEqual(fields["Runtime execution class"], "—")
        XCTAssertEqual(fields["Runtime expected locality"], "—")
        XCTAssertEqual(fields["Runtime estimated memory class"], "—")
        XCTAssertEqual(fields["Runtime reason count"], "—")
    }

    func testMissingSnapshotDoesNotInventRuntimePlanningValues() {
        let state = DiagnosticViewState(
            report: ScenarioRunner().report(),
            snapshot: nil
        )
        let fields = Dictionary(uniqueKeysWithValues: state.snapshotFields.map { ($0.label, $0.value) })

        XCTAssertEqual(fields["Runtime budget stage"], "—")
        XCTAssertEqual(fields["Runtime execution class"], "—")
        XCTAssertEqual(fields["Runtime expected locality"], "—")
        XCTAssertEqual(fields["Runtime estimated memory class"], "—")
        XCTAssertEqual(fields["Runtime reason count"], "—")
    }
}
