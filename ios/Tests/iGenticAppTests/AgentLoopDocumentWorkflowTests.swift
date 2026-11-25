import XCTest
@testable import iGenticApp

final class AgentLoopDocumentWorkflowTests: XCTestCase {
    @MainActor
    func testSourceOrderAndExactExtracts() async {
        let lines = ["Demo heading", "Room Cedar", "Start at 14:30"]
        let r = await AgentLoopDocumentWorkflow.run(recognize: { lines }, select: { input in
            XCTAssertEqual(input, lines)
            return [3, 2]
        }, elapsed: { 1 })
        XCTAssertEqual(r.outcome,.completed)
        XCTAssertEqual(r.excerpts,["Room Cedar","Start at 14:30"])
    }
    @MainActor
    func testInvalidSelectionCannotProduceReport() async {
        for ids in [[], [1,1], [0], [4], [1,2,3,4]] {
            let r = await AgentLoopDocumentWorkflow.run(recognize: { ["One","Two","Three"] },
                select: { _ in ids }, elapsed: { 1 })
            XCTAssertEqual(r.outcome,.selectionRejected)
            XCTAssertTrue(r.excerpts.isEmpty)
        }
    }
    @MainActor
    func testOversizeAndControlInputNeverReachesModel() async {
        for lines in [[String(repeating:"a", count:513)], ["line\u{0}"], Array(repeating:"word",count:33)] {
            let r = await AgentLoopDocumentWorkflow.run(recognize: { lines }, select: { _ in
                XCTFail("Rejected input reached model")
                return [1]
            }, elapsed: { 1 })
            XCTAssertEqual(r.outcome,.inputRejected)
        }
    }
    @MainActor
    func testExpiredSelectionCannotReturnExcerpts() async {
        var time = 1.0
        let r = await AgentLoopDocumentWorkflow.run(recognize: { ["One"] }, select: { _ in
            time = 61; return [1]
        }, elapsed: { time })
        XCTAssertEqual(r.outcome,.expired)
        XCTAssertTrue(r.excerpts.isEmpty)
    }
}
