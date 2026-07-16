import XCTest
@testable import AgentCore

final class DiagnosticSnapshotProducerSensitiveDataWiringTests: XCTestCase {
    private final class SpySensitiveDataDetector: SensitiveDataDetecting, @unchecked Sendable {
        private(set) var callCount = 0

        func detect(in text: String) -> SensitiveDataDetectionResult {
            callCount += 1
            return SensitiveDataDetectionResult(
                findings: [
                    SensitiveDataFinding(
                        category: .iban,
                        reason: "Spy detector returned a forced IBAN finding."
                    )
                ]
            )
        }
    }

    func testInjectedDetectorIsPassedThroughToLiveAgentKernelPath() {
        let spy = SpySensitiveDataDetector()
        let producer = DiagnosticSnapshotProducer(sensitiveDataDetector: spy)
        let task = TaskRequest(
            userText: "Nothing sensitive should be detected by the real detector.",
            intent: .createReminder,
            dataClassification: .publicDefault,
            actionRisk: .prepare
        )

        let snapshot = producer.produceSnapshot(
            for: task,
            privacyMode: .trustedDevices,
            generatedAt: Date(timeIntervalSince1970: 123)
        )

        XCTAssertEqual(snapshot.audit.highestDataSensitivity, .restrictedSensitiveData)
        XCTAssertEqual(spy.callCount, 2)
    }
}