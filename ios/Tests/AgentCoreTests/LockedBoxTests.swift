import Dispatch
import XCTest
@testable import AgentCore

final class LockedBoxTests: XCTestCase {
    func testWithValueReturnsBodyResult() {
        let box = LockedBox<Int>(1)

        let result = box.withValue { value in
            value += 1
            return value
        }

        XCTAssertEqual(result, 2)
    }

    func testWithValuePersistsMutationAcrossCalls() {
        let box = LockedBox<[String]>([])

        box.withValue { $0.append("a") }
        box.withValue { $0.append("b") }

        let snapshot = box.withValue { $0 }
        XCTAssertEqual(snapshot, ["a", "b"])
    }

    func testConcurrentMutationsAreSerializedWithoutLostUpdates() {
        let box = LockedBox<Int>(0)
        let iterationsPerQueue = 1000
        let queueCount = 8
        let group = DispatchGroup()

        for _ in 0..<queueCount {
            group.enter()
            DispatchQueue.global().async {
                for _ in 0..<iterationsPerQueue {
                    box.withValue { $0 += 1 }
                }
                group.leave()
            }
        }

        group.wait()

        let finalValue = box.withValue { $0 }
        XCTAssertEqual(finalValue, queueCount * iterationsPerQueue)
    }
}
