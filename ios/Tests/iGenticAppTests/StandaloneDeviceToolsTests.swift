import XCTest
@testable import iGenticApp

@MainActor
private final class FakeDevice: StandaloneDeviceBackend {
    var state: StandaloneTorchState = .off
    var started = 0
    var stopped = 0
    var stopWorks = true
    var result: StandaloneTorchStart = .started
    func status() -> AgentLoopLocalStatus {
        .init(batteryFraction: 0.5, lowPowerModeEnabled: false, osVersion: "27.2")
    }
    func availableStorage() -> Int64? { 1_000_000 }
    func torchState() -> StandaloneTorchState { state }
    func startPulseIfOff() -> StandaloneTorchStart {
        started += 1
        if state != .off { return .blocked }
        if case .started = result { state = .active }
        return result
    }
    func stopOwnedPulse() -> Bool {
        stopped += 1
        if stopWorks { state = .off }
        return stopWorks
    }
}

final class StandaloneDeviceToolsTests: XCTestCase {
    @MainActor func testReadsAreLocalAndDoNotWrite() {
        let b = FakeDevice()
        XCTAssertTrue(StandaloneDeviceTools.readReport(backend: b)?.contains("50 %") == true)
        XCTAssertEqual(b.started, 0)
        XCTAssertEqual(b.stopped, 0)
        XCTAssertFalse(StandaloneDeviceTools.permitted(.torchPulse))
    }

    @MainActor func testRequiresConfirmationAndForeground() async {
        let b = FakeDevice()
        for (approved, active) in [(false, true), (true, false)] {
            let r = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: approved, foreground: { active }, wait: { XCTFail("No wait expected") })
            XCTAssertEqual(r, .blocked)
        }
        XCTAssertEqual(b.started, 0)
    }

    @MainActor func testConfirmedPulseAndCleanup() async {
        let b = FakeDevice()
        let r = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { XCTAssertEqual(b.state, .active) })
        XCTAssertEqual(r, .verified)
        XCTAssertEqual(b.state, .off)
        XCTAssertEqual(b.started, 1)
        XCTAssertEqual(b.stopped, 1)
    }

    @MainActor func testCancellationCleansUp() async {
        let b = FakeDevice()
        let r = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { throw CancellationError() })
        XCTAssertEqual(r, .cancelledAndOff)
        XCTAssertEqual(b.state, .off)
        XCTAssertEqual(b.stopped, 1)
    }

    @MainActor func testAlreadyActiveNeverChangesExistingLight() async {
        let b = FakeDevice(); b.state = .active
        let r = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: { XCTFail("No wait expected") })
        XCTAssertEqual(r, .blocked)
        XCTAssertEqual(b.stopped, 0)
        XCTAssertEqual(b.state, .active)
    }

    @MainActor func testUncertainCleanupNeverClaimsSuccess() async {
        let b = FakeDevice(); b.stopWorks = false
        let r = await StandaloneDeviceTools.pulse(backend: b, ownerConfirmed: true, foreground: { true }, wait: {})
        XCTAssertEqual(r, .uncertain)
        XCTAssertEqual(b.started, 1)
        XCTAssertEqual(b.stopped, 1)
    }
}
