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
