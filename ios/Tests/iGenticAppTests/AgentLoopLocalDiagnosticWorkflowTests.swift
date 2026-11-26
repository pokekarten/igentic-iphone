import XCTest
@testable import iGenticApp

final class AgentLoopLocalDiagnosticWorkflowTests: XCTestCase {
    @MainActor
    func testModelChoosesOrderAndReceivesObservations() async {
        var seen: [AgentLoopDiagnosticProgress] = []
        var reads = 0, checks = 0
        let report = await AgentLoopLocalDiagnosticWorkflow.run(propose: { p in
            seen.append(p)
            switch p.completed.count {
            case 0: return "model.readiness"
            case 1: return "status.read"
            default: return "finish"
            }
        }, readStatus: {
            reads += 1
            return .init(batteryFraction: 0.4, lowPowerModeEnabled: false, osVersion: "27.2")
        }, checkModel: { checks += 1; return true }, elapsed: { 1 })
        XCTAssertEqual(report.outcome,.completed)
        XCTAssertEqual(report.steps,[.checkModel,.readStatus,.finish])
        XCTAssertEqual(report.modelTurns,3)
        XCTAssertEqual(reads,1)
        XCTAssertEqual(checks,1)
        XCTAssertEqual(seen[1].localModelAvailable,true)
        XCTAssertTrue(seen[2].statusAvailable)
        XCTAssertTrue(report.localReport?.contains("40 %") == true)
    }

    @MainActor
    func testUnknownDuplicateAndPrematureFinishFailClosed() async {
        for proposals in [["finish"],["delete.contacts"],["status.read","status.read"]] {
            var n = 0, reads = 0
            let report = await AgentLoopLocalDiagnosticWorkflow.run(propose: { _ in
                defer { n += 1 }; return proposals[n]
            }, readStatus: {
                reads += 1
                return .init(batteryFraction: 0.4, lowPowerModeEnabled: false, osVersion: "27")
            }, checkModel: { XCTFail("Unexpected tool"); return true }, elapsed: { 1 })
            XCTAssertEqual(report.outcome,.rejectedProposal)
            XCTAssertNil(report.localReport)
            XCTAssertEqual(reads, proposals.count == 2 ? 1 : 0)
        }
    }

    @MainActor
    func testCancelledProposalCannotExecuteTool() async {
        let task = Task { @MainActor in
            await AgentLoopLocalDiagnosticWorkflow.run(propose: { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                return "status.read"
            }, readStatus: {
                XCTFail("Cancelled proposal executed")
                return .init(batteryFraction: 0, lowPowerModeEnabled: false, osVersion: "27")
            }, checkModel: { false }, elapsed: { 1 })
        }
        let report = await task.value
        XCTAssertEqual(report.outcome, .cancelled)
        XCTAssertTrue(report.steps.isEmpty)
        XCTAssertNil(report.localReport)
    }

    @MainActor
    func testExpiredThrowIsNotMisclassifiedAsProviderFailure() async {
        var time: TimeInterval = 0
        let report = await AgentLoopLocalDiagnosticWorkflow.run(propose: { _ in
            time = 60
            throw CancellationError()
        }, readStatus: {
            XCTFail("Expired proposal executed")
            return .init(batteryFraction: 0, lowPowerModeEnabled: false, osVersion: "27")
        }, checkModel: { false }, elapsed: { time })
        XCTAssertEqual(report.outcome, .expired)
        XCTAssertNil(report.localReport)
    }

    @MainActor
    func testExpiredModelResultCannotExecuteTool() async {
        var time: TimeInterval = 0
        let report = await AgentLoopLocalDiagnosticWorkflow.run(propose: { _ in
            time = 60; return "status.read"
        }, readStatus: {
            XCTFail("Expired tool executed")
            return .init(batteryFraction: 0, lowPowerModeEnabled: false, osVersion: "27")
        }, checkModel: { false }, elapsed: { time })
        XCTAssertEqual(report.outcome,.expired)
        XCTAssertEqual(report.steps,[])
        XCTAssertNil(report.localReport)
    }
}

extension AgentLoopLocalDiagnosticWorkflowTests {
    @MainActor
    func testExtendedGoalUsesRegisteredCapabilitiesAndFeedsEvidenceBack() async {
        let choices = ["capabilities.read","status.read","model.readiness","finish"]
        var seen: [AgentLoopDiagnosticProgress] = []
        var inventoryReads = 0
        let report = await AgentLoopLocalDiagnosticWorkflow.run(goal: .extended, propose: { p in
            defer { seen.append(p) }
            return choices[seen.count]
        }, readStatus: {
            .init(batteryFraction: 0.5, lowPowerModeEnabled: false, osVersion: "27")
        }, checkModel: { true }, inspectCapabilities: {
            inventoryReads += 1
            return 4
        }, elapsed: { 1 })
        XCTAssertEqual(report.outcome,.completed)
        XCTAssertEqual(report.modelTurns,4)
        XCTAssertEqual(inventoryReads,1)
        XCTAssertEqual(seen[1].capabilityCount,4)
        XCTAssertEqual(seen[1].remainingReads,[.readStatus,.checkModel])
        XCTAssertTrue(seen[3].remainingReads.isEmpty)
        XCTAssertTrue(report.localReport?.contains("Navigationsmöglichkeiten: 4") == true)
    }

    @MainActor
    func testBasicGoalCannotDispatchExtendedReader() async {
        let report = await AgentLoopLocalDiagnosticWorkflow.run(propose: { _ in
            "capabilities.read"
        }, readStatus: {
            XCTFail("Unexpected read")
            return .init(batteryFraction: 0, lowPowerModeEnabled: false, osVersion: "27")
        }, checkModel: { XCTFail("Unexpected readiness"); return false },
        inspectCapabilities: { XCTFail("Out-of-goal capability"); return 4 }, elapsed: { 1 })
        XCTAssertEqual(report.outcome,.rejectedProposal)
        XCTAssertNil(report.localReport)
    }
}

// The result can be consumed by an external Shortcut; local report text must
// never be serialized into this boundary.
extension AgentLoopLocalDiagnosticWorkflowTests {
    func testShortcutReceiptContainsOnlyExecutionMetadata() {
        let report = AgentLoopDiagnosticReport(outcome: .completed,
            steps: [.readStatus, .checkModel, .inspectCapabilities, .finish],
            modelTurns: 4, localReport: "PRIVATE FIXTURE status observation")
        XCTAssertEqual(report.shortcutReceipt,
            "outcome=completed; modelTurns=4; steps=status.read,model.readiness,capabilities.read,finish; reportPrepared=true")
        XCTAssertFalse(report.shortcutReceipt.contains("PRIVATE FIXTURE"))
        let blocked = AgentLoopDiagnosticReport(outcome: .modelUnavailable, steps: [],
            modelTurns: 0, localReport: nil)
        XCTAssertEqual(blocked.shortcutReceipt,
            "outcome=modelUnavailable; modelTurns=0; steps=; reportPrepared=false")
    }
}
