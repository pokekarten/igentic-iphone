import XCTest
@testable import iGenticApp

@MainActor
private final class BoundaryDevice: StandaloneDeviceBackend {
    var state: StandaloneTorchState = .off
    var afterStart: StandaloneTorchState = .active
    var afterStop: StandaloneTorchState = .off
    var startResult: StandaloneTorchStart = .started
    var stopResult = true
    var startCalls = 0
    var stopCalls = 0
    var waitCalls = 0
    func status() -> AgentLoopLocalStatus {
        .init(batteryFraction: .nan, lowPowerModeEnabled: false, osVersion: "synthetic private label")
    }
    func availableStorage() -> Int64? { -1 }
    func torchState() -> StandaloneTorchState { state }
    func startPulseIfOff() -> StandaloneTorchStart {
        startCalls += 1
        if case .started = startResult { state = afterStart }
        return startResult
    }
    func stopOwnedPulse() -> Bool {
        stopCalls += 1
        state = afterStop
        return stopResult
    }
}

final class StandaloneDeviceToolsOfflineBoundaryTests: XCTestCase {
    @MainActor func testAlreadyCancelledDoesNotStart() async {
        let b = BoundaryDevice()
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            return await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { b.waitCalls += 1 })
        }
        let result = await task.value
        XCTAssertEqual(result, .blocked)
        XCTAssertEqual(b.startCalls, 0)
        XCTAssertEqual(b.stopCalls, 0)
        XCTAssertEqual(b.waitCalls, 0)
    }
    @MainActor func testForegroundLossCleansUp() async {
        let b = BoundaryDevice()
        var foreground = true
        let result = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { foreground }, wait: { foreground = false; b.waitCalls += 1 })
        XCTAssertEqual(result, .cancelledAndOff)
        XCTAssertEqual(b.state, .off)
        XCTAssertEqual(b.startCalls, 1)
        XCTAssertEqual(b.stopCalls, 1)
        XCTAssertEqual(b.waitCalls, 1)
    }
    @MainActor func testUncertainStartDoesNotReplayOrClaimOwnership() async {
        let b = BoundaryDevice(); b.startResult = .uncertain
        let result = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { b.waitCalls += 1 })
        XCTAssertEqual(result, .uncertain)
        XCTAssertEqual(b.startCalls, 1)
        XCTAssertEqual(b.stopCalls, 0)
        XCTAssertEqual(b.waitCalls, 0)
    }
    @MainActor func testUnobservedStartIsNotVerifiedEvenAfterCleanup() async {
        let b = BoundaryDevice(); b.afterStart = .unknown
        let result = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: {})
        XCTAssertEqual(result, .notObservedAndOff)
        XCTAssertEqual(b.stopCalls, 1)
    }
    @MainActor func testSuccessfulStopWithoutOffReadbackIsUncertain() async {
        let b = BoundaryDevice(); b.afterStop = .unknown
        let result = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: {})
        XCTAssertEqual(result, .uncertain)
        XCTAssertEqual(b.stopCalls, 1)
    }
    @MainActor func testCancellationCannotMaskUnverifiedCleanup() async {
        let b = BoundaryDevice(); b.stopResult = false
        let result = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { throw CancellationError() })
        XCTAssertEqual(result, .uncertain)
        XCTAssertEqual(b.stopCalls, 1)
    }
    @MainActor func testInvalidStatusValuesStayUnknown() async {
        let b = BoundaryDevice()
        let report = StandaloneDeviceTools.readReport(backend: b)
        XCTAssertNotNil(report)
        XCTAssertTrue(report?.contains("Akku: unbekannt") == true)
        XCTAssertTrue(report?.contains("iOS: unbekannt") == true)
        XCTAssertTrue(report?.contains("Speicher (Schätzung): unbekannt") == true)
        XCTAssertFalse(report?.contains("synthetic private label") == true)
        XCTAssertEqual(b.startCalls, 0)
        XCTAssertEqual(b.stopCalls, 0)
    }
}
