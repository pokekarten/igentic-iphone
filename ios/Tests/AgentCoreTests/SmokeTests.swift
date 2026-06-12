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
}
