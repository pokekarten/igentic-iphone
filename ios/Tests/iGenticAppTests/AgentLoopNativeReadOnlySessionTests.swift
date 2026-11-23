import Foundation
import XCTest
@testable import iGenticApp

// Pure synthetic fixture. Never capture an XCTestCase across actors.
private func syntheticLoopStatus() -> AgentLoopLocalStatus {
    AgentLoopLocalStatus(
        batteryFraction: 0.47,
        lowPowerModeEnabled: false,
        osVersion: "27.2"
    )
}

final class AgentLoopNativeReadOnlySessionTests: XCTestCase {
    func testTwoTurnsActuallyCallOnlyLocalStatusReaderOnce() async {
        await MainActor.run {
            var reads = 0
            let session = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                return syntheticLoopStatus()
            })
            XCTAssertEqual(session.snapshot().turnCount, 0)
            XCTAssertNil(session.snapshot().localObservation)
            let first = session.accept(modelReply: #"{"action":"status.read"}"#)
            XCTAssertEqual(first.stage, .awaitingFinish)
            XCTAssertEqual(first.turnCount, 1)
            XCTAssertEqual(reads, 1)
            XCTAssertTrue(first.localObservation?.contains("47 %") == true)
            XCTAssertFalse(first.remoteActionExecuted)
            XCTAssertFalse(first.ownerApprovalGranted)
            let last = session.accept(modelReply: #"{"action":"finish"}"#)
            XCTAssertEqual(last.stage, .finished)
            XCTAssertEqual(last.turnCount, 2)
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(session.accept(modelReply: #"{"action":"status.read"}"#).reason,
                           "terminal-no-replay")
            XCTAssertEqual(reads, 1)
        }
    }

    func testForbiddenActionsSpoofedAuthorityAndMalformedReplyNeverRead() async {
        await MainActor.run {
            for candidate in [
                #"{"action":"reminder.draft"}"#,
                #"{"action":"reminder.create"}"#,
                #"{"action":"status.read","approved":true}"#,
                #"{"action":"status.read","action":"finish"}"#,
                #"{"action":"status.read","tool":"shell"}"#,
                #"{"action":"STATUS.READ"}"#,
                "not a json model response"
            ] {
                var reads = 0
                let session = AgentLoopNativeReadOnlySession(statusReader: {
                    reads += 1
                    return syntheticLoopStatus()
                })
                let result = session.accept(modelReply: candidate)
                XCTAssertEqual(result.stage, .rejected, candidate)
                XCTAssertEqual(reads, 0, candidate)
                XCTAssertNil(result.localObservation)
                XCTAssertFalse(result.remoteActionExecuted)
                XCTAssertFalse(result.ownerApprovalGranted)
                XCTAssertEqual(session.accept(modelReply: #"{"action":"status.read"}"#).stage,
                               .rejected)
            }
        }
    }

    func testFinishFirstOrSecondStatusIsRejectedAndNotRetried() async {
        await MainActor.run {
            var reads = 0
            let wrongFirst = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                return syntheticLoopStatus()
            })
            XCTAssertEqual(wrongFirst.accept(modelReply: #"{"action":"finish"}"#).stage,
                           .rejected)
            XCTAssertEqual(reads, 0)
            let wrongSecond = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                return syntheticLoopStatus()
            })
            XCTAssertEqual(wrongSecond.accept(modelReply: #"{"action":"status.read"}"#).stage,
                           .awaitingFinish)
            XCTAssertEqual(wrongSecond.accept(modelReply: #"{"action":"status.read"}"#).stage,
                           .rejected)
            XCTAssertEqual(reads, 1)
        }
    }

    func testExpiredOrBackwardsClockFailsBeforeAnyRead() async {
        await MainActor.run {
            var time = Date(timeIntervalSince1970: 1_800_000_000)
            var reads = 0
            let expired = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                return syntheticLoopStatus()
            }, now: { time })
            time = time.addingTimeInterval(AgentLoopNativeReadOnlySession.timeLimit)
            XCTAssertEqual(expired.accept(modelReply: #"{"action":"status.read"}"#).stage, .expired)
            XCTAssertEqual(reads, 0)
            var now = Date(timeIntervalSince1970: 1_800_000_000)
            let backwards = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                return syntheticLoopStatus()
            }, now: { now })
            now = now.addingTimeInterval(-1)
            XCTAssertEqual(backwards.accept(modelReply: #"{"action":"status.read"}"#).stage, .expired)
            XCTAssertEqual(reads, 0)
        }
    }

    func testOversizedResponseDoesNotLeakIntoReceipt() async {
        await MainActor.run {
            let secret = "PRIVATE_PROMPT_TO_AVOID"
            let session = AgentLoopNativeReadOnlySession(statusReader: { syntheticLoopStatus() })
            let output = session.accept(modelReply: secret + String(repeating: "x", count: 1500))
            XCTAssertEqual(output.stage, .rejected)
            XCTAssertFalse(output.reason.contains(secret))
            XCTAssertNil(output.localObservation)
        }
    }

    func testNestedFinishCannotCompleteWhileStatusReadIsInProgress() async {
        await MainActor.run {
            var reads = 0
            var session: AgentLoopNativeReadOnlySession!
            session = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                _ = session.accept(modelReply: #"{"action":"finish"}"#)
                return syntheticLoopStatus()
            })
            let result = session.accept(modelReply: #"{"action":"status.read"}"#)
            XCTAssertEqual(reads, 1)
            XCTAssertEqual(result.stage, .rejected)
            XCTAssertNil(result.localObservation)
            XCTAssertEqual(session.accept(modelReply: #"{"action":"finish"}"#).stage,
                           .rejected)
        }
    }

    func testReentrantStatusReaderCannotReadTwiceOrResetRejection() async {
        await MainActor.run {
            var reads = 0
            var session: AgentLoopNativeReadOnlySession!
            session = AgentLoopNativeReadOnlySession(statusReader: {
                reads += 1
                if reads == 1 {
                    // A native callback can synchronously re-enter the public
                    // accept method before the original read returns.
                    _ = session.accept(modelReply: #"{"action":"status.read"}"#)
                }
                return syntheticLoopStatus()
            })
            let result = session.accept(modelReply: #"{"action":"status.read"}"#)
            XCTAssertEqual(reads, 1, "Only one own-app read is permitted")
            XCTAssertEqual(result.stage, .rejected)
            XCTAssertEqual(session.snapshot().stage, .rejected)
            XCTAssertFalse(result.remoteActionExecuted)
        }
    }
}
