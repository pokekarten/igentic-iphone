import XCTest
@testable import AgentCore

final class OnDeviceModelReadinessTests: XCTestCase {
    func testAllAvailabilityReasonsProduceBoundedSafeSummary() {
        let cases: [(LocalModelRuntimeAvailability, String)] = [
            (.available, "available"),
            (.unavailable(.notConfigured), "notConfigured"),
            (.unavailable(.disabledByPolicy), "disabledByPolicy"),
            (.unavailable(.unsupportedPlatform), "unsupportedPlatform"),
            (.unavailable(.deviceNotEligible), "deviceNotEligible"),
            (.unavailable(.appleIntelligenceNotEnabled), "appleIntelligenceNotEnabled"),
            (.unavailable(.modelNotReady), "modelNotReady"),
            (.unavailable(.unsupportedLocale), "unsupportedLocale"),
            (.unavailable(.unknownSystemCondition), "unknownSystemCondition")
        ]
        for (availability, code) in cases {
            let summary = OnDeviceModelReadiness.summary(for: availability)
            XCTAssertEqual(OnDeviceModelReadiness.code(for: availability), code)
            XCTAssertEqual(
                summary,
                "iGentic local AI readiness: \(code). No prompt was processed or sent. This is not a device health check."
            )
            XCTAssertLessThan(summary.count, 180)
            XCTAssertFalse(summary.contains("@"))
        }
    }
}
