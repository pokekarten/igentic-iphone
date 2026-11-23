import XCTest
@testable import iGenticApp

final class CellularHeartbeatProtocolTests: XCTestCase {
    func testOnlyHTTPSFixedPathNoCredentialOrQueryIsAccepted() {
        XCTAssertNotNil(CellularHeartbeatProtocol.validEndpoint(
            "https://example.org/v1/companion/readiness"))
        for input in [
            "http://example.org/v1/companion/readiness",
            "https://example.org/unbounded",
            "https://user:password@example.org/v1/companion/readiness",
            "https://example.org/v1/companion/readiness?secret=1",
            "https://example.org/v1/companion/readiness#fragment",
            "https://localhost/v1/companion/readiness",
            "https://127.0.0.1/v1/companion/readiness",
            "file:///etc/passwd"
        ] {
            XCTAssertNil(CellularHeartbeatProtocol.validEndpoint(input))
        }
    }

    func testTaskMetricsMayArriveAfterHTTPCompletion() async {
        let observation = CellularTransportObservation()
        let delayed = Task {
            try? await Task.sleep(for: .milliseconds(30))
            observation.record([true, true])
        }
        let result = await observation.waitForEvidence(
            attempts: 12, pollDelay: .milliseconds(10)
        )
        await delayed.value
        XCTAssertEqual(result, "cellular-transport-observed")
    }

    func testMissingTaskMetricsNeverClaimCellular() async {
        let observation = CellularTransportObservation()
        let missing = await observation.waitForEvidence(
            attempts: 2, pollDelay: .milliseconds(1)
        )
        XCTAssertEqual(missing, "transport-not-verified")
        observation.record([false])
        let firstObserved = await observation.waitForEvidence(attempts: 1)
        XCTAssertEqual(firstObserved, "other-transport-observed")
        // Later duplicates must not mutate the first task observation.
        observation.record([true])
        let secondObserved = await observation.waitForEvidence(attempts: 1)
        XCTAssertEqual(secondObserved, "other-transport-observed")
    }

    func testActualTransactionMetricsFailClosedOnMissingOrMixedNetworkRoutes() {
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: []),
            "transport-not-verified")
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: [true]),
            "cellular-transport-observed")
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: [true, true]),
            "cellular-transport-observed")
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: [false]),
            "other-transport-observed")
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: [false, false]),
            "other-transport-observed")
        XCTAssertEqual(
            CellularHeartbeatProtocol.classifyTransport(transactionCellularFlags: [true, false]),
            "mixed-transport-not-verified")
    }

    func testFixedBodyMatchesHostProtocolAndRejectsWeakKeys() {
        XCTAssertEqual(
            String(data: CellularHeartbeatProtocol.body, encoding: .utf8),
            "{\"schema\":1,\"kind\":\"readiness\"}"
        )
        XCTAssertNil(CellularHeartbeatProtocol.decodedSecret("short-key"))
        XCTAssertNil(CellularHeartbeatProtocol.decodedSecret(
            Data(repeating: 0, count: 16).base64EncodedString()))
        XCTAssertEqual(CellularHeartbeatProtocol.decodedSecret(
            Data(repeating: 1, count: 32).base64EncodedString())?.count, 32)
    }

    #if canImport(CryptoKit)
    func testSwiftAndNodeHaveExactSameHMACSignature() {
        let secret = Data(repeating: 1, count: 32)
        let nonce = "11111111-2222-3333-4444-555555555555"
        XCTAssertEqual(
            CellularHeartbeatProtocol.signature(
                secret: secret, timestamp: 1795393200, nonce: nonce),
            "5dedf955ffd065e6440260208c033d98fd3901608c317f7c2bb6c6fc36ab64d9"
        )
        XCTAssertNil(CellularHeartbeatProtocol.signature(
            secret: Data(repeating: 1, count: 12),
            timestamp: 1795393200, nonce: nonce))
        XCTAssertNil(CellularHeartbeatProtocol.signature(
            secret: secret, timestamp: 1795393200, nonce: "bad"))
    }
    #endif
}
