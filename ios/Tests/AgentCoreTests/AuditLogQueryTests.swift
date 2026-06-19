import Dispatch
import Foundation
import XCTest
@testable import AgentCore

final class AuditLogQueryTests: XCTestCase {
    func testMetadataSnapshotPreservesOrderWithoutMessagesOrIdentifiers() {
        let privateValues = [
            "synthetic-private-value-001",
            "synthetic-private-value-002",
            "synthetic-private-value-003",
        ]
        let events = [
            AuditEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                timestamp: Date(timeIntervalSince1970: 1),
                type: .taskReceived,
                message: privateValues[0],
                dataSensitivity: .publicData
            ),
            AuditEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                timestamp: Date(timeIntervalSince1970: 2),
                type: .policyDecision,
                message: privateValues[1],
                dataSensitivity: .contextualPrivateData
            ),
            AuditEvent(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
                timestamp: Date(timeIntervalSince1970: 3),
                type: .blocked,
                message: privateValues[2],
                dataSensitivity: .restrictedSensitiveData
            ),
        ]
        let log = AuditLog()
        events.forEach(log.record)

        let snapshot = log.metadataSnapshot()

        XCTAssertEqual(
            snapshot,
            [
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 1),
                    type: .taskReceived,
                    dataSensitivity: .publicData
                ),
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 2),
                    type: .policyDecision,
                    dataSensitivity: .contextualPrivateData
                ),
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 3),
                    type: .blocked,
                    dataSensitivity: .restrictedSensitiveData
                ),
            ]
        )

        let renderedSnapshot = String(describing: snapshot)
        privateValues.forEach { XCTAssertFalse(renderedSnapshot.contains($0)) }
        events.forEach { XCTAssertFalse(renderedSnapshot.contains($0.id.uuidString)) }
    }

    func testTypeFiltersAndCountsReturnOnlyMatchingMetadata() {
        let log = makePopulatedLog()

        XCTAssertEqual(log.count(ofType: .policyDecision), 2)
        XCTAssertEqual(log.count(ofType: .blocked), 1)
        XCTAssertEqual(log.count(ofType: .routeSelected), 0)
        XCTAssertEqual(
            log.metadataSnapshot(ofType: .policyDecision),
            [
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 2),
                    type: .policyDecision,
                    dataSensitivity: .contextualPrivateData
                ),
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 4),
                    type: .policyDecision,
                    dataSensitivity: .highlyPrivateData
                ),
            ]
        )
    }

    func testSensitivityFiltersAndCountsUseStableOrdering() {
        let log = makePopulatedLog()

        XCTAssertEqual(log.count(atOrAbove: .highlyPrivateData), 2)
        XCTAssertEqual(log.count(atOrAbove: .restrictedSensitiveData), 1)
        XCTAssertEqual(
            log.metadataSnapshot(atOrAbove: .highlyPrivateData),
            [
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 3),
                    type: .blocked,
                    dataSensitivity: .restrictedSensitiveData
                ),
                AuditEventMetadata(
                    timestamp: Date(timeIntervalSince1970: 4),
                    type: .policyDecision,
                    dataSensitivity: .highlyPrivateData
                ),
            ]
        )
    }

    func testExistingAllEventsBehaviorRemainsUnchanged() {
        let original = AuditEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            timestamp: Date(timeIntervalSince1970: 10),
            type: .approvalRequired,
            message: "synthetic-original-message",
            dataSensitivity: .highlyPrivateData
        )
        let log = AuditLog()
        log.record(original)

        XCTAssertEqual(log.allEvents(), [original])
        XCTAssertEqual(log.allEvents().first?.message, "synthetic-original-message")
    }

    func testConcurrentRecordingRemainsCompleteAndQueryable() {
        let log = AuditLog()
        let iterations = 100

        DispatchQueue.concurrentPerform(iterations: iterations) { index in
            log.record(
                AuditEvent(
                    timestamp: Date(timeIntervalSince1970: TimeInterval(index)),
                    type: index.isMultiple(of: 2) ? .policyDecision : .blocked,
                    message: "synthetic-concurrent-\(index)",
                    dataSensitivity: index.isMultiple(of: 4)
                        ? .restrictedSensitiveData
                        : .lowRiskAppData
                )
            )
        }

        XCTAssertEqual(log.allEvents().count, iterations)
        XCTAssertEqual(log.metadataSnapshot().count, iterations)
        XCTAssertEqual(log.count(ofType: .policyDecision), 50)
        XCTAssertEqual(log.count(ofType: .blocked), 50)
        XCTAssertEqual(log.count(atOrAbove: .restrictedSensitiveData), 25)
    }

    private func makePopulatedLog() -> AuditLog {
        let log = AuditLog()
        [
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 1),
                type: .taskReceived,
                message: "synthetic-one",
                dataSensitivity: .publicData
            ),
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 2),
                type: .policyDecision,
                message: "synthetic-two",
                dataSensitivity: .contextualPrivateData
            ),
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 3),
                type: .blocked,
                message: "synthetic-three",
                dataSensitivity: .restrictedSensitiveData
            ),
            AuditEvent(
                timestamp: Date(timeIntervalSince1970: 4),
                type: .policyDecision,
                message: "synthetic-four",
                dataSensitivity: .highlyPrivateData
            ),
        ].forEach(log.record)
        return log
    }
}
