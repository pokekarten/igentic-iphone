import XCTest
@testable import AgentCore

final class DiagnosticSnapshotProducerTests: XCTestCase {
    func testProducesSnapshotForLiveApprovalRequiredTask() {
        let producer = DiagnosticSnapshotProducer()
        let task = TaskRequest(
            userText: "Please email alice@example.com to the external provider.",
            intent: .requestApproval,
            dataClassification: .publicDefault,
            actionRisk: .execute,
            requestedDelegationTarget: .externalProvider
        )

        let snapshot = producer.produceSnapshot(
            for: task,
            privacyMode: .trustedDevices,
            generatedAt: Date(timeIntervalSince1970: 100)
        )

        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 100))
        XCTAssertEqual(snapshot.privacyMode, .trustedDevices)
        XCTAssertTrue(snapshot.policy.isAllowed)
        XCTAssertTrue(snapshot.policy.requiresApproval)
        XCTAssertEqual(snapshot.approval.status, .pending)
        XCTAssertFalse(snapshot.approval.mayContinueRouting)
        XCTAssertEqual(snapshot.audit.eventCount, 3)
        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .contextualPrivateData)
        XCTAssertEqual(snapshot.delegation.outcome, .requiresApproval)
        XCTAssertEqual(snapshot.risk.value, 10)
        XCTAssertTrue(snapshot.risk.requiresExplicitApproval)
        XCTAssertEqual(snapshot.risk.reasonCount, 5)
    }

    func testProducesBlockedSnapshotForLocalOnlyExternalDelegation() {
        let producer = DiagnosticSnapshotProducer()
        let task = TaskRequest(
            userText: "Handle this locally and delegate externally.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare,
            requestedDelegationTarget: .externalProvider
        )

        let snapshot = producer.produceSnapshot(
            for: task,
            privacyMode: .localOnly,
            generatedAt: Date(timeIntervalSince1970: 200)
        )

        XCTAssertEqual(snapshot.generatedAt, Date(timeIntervalSince1970: 200))
        XCTAssertEqual(snapshot.privacyMode, .localOnly)
        XCTAssertFalse(snapshot.policy.isAllowed)
        XCTAssertFalse(snapshot.policy.requiresApproval)
        XCTAssertEqual(snapshot.approval.status, .notRequired)
        XCTAssertTrue(snapshot.approval.mayContinueRouting)
        XCTAssertEqual(snapshot.audit.eventCount, 2)
        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .publicData)
        XCTAssertEqual(snapshot.delegation.outcome, .blocked)
        XCTAssertEqual(snapshot.risk.value, 7)
        XCTAssertTrue(snapshot.risk.requiresExplicitApproval)
        XCTAssertEqual(snapshot.risk.reasonCount, 3)
    }
}
