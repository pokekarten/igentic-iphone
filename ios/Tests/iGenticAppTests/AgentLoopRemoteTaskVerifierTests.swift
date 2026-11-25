import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopRemoteTaskVerifierTests: XCTestCase {
    // Generated independently using the existing Node
    // prepareSignedReadOnlyProposal implementation, not a Swift signer.
    private let nodeFixture = """
    {"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}
    """
    private var testKey: Data { Data((0..<32).map(UInt8.init)) }

    private func review(
        _ json: String,
        key: Data? = nil,
        now: Int = 2_000_000_000
    ) -> AgentLoopRemoteTaskPreview? {
        AgentLoopRemoteTaskVerifier.inspectCanonicalProposal(
            Data(json.utf8), relayKey: key ?? testKey, nowSeconds: now
        )
    }

    #if canImport(CryptoKit)
    func testNodeProposalIsCryptographicallyVerifiableButNeverExecutable() {
        let result = review(nodeFixture)
        XCTAssertEqual(result?.requestID, "11111111-2222-4333-8444-555555555555")
        XCTAssertEqual(result?.expiresAt, 2_000_000_060)
        XCTAssertEqual(result?.capability, "igentic.own_app.status.read")
        XCTAssertEqual(result?.status, "cryptographically-verified-preview-only")
        XCTAssertEqual(result?.actionExecuted, false)
        XCTAssertEqual(result?.ownerApproved, false)
        XCTAssertEqual(result?.replayAdmitted, false)
        XCTAssertEqual(result?.iPhoneConnected, "not-checked")
        XCTAssertEqual(result?.deviceReceipt, "none")
    }

    func testTamperingReplayAndClockBoundariesFailClosed() {
        XCTAssertNotNil(review(nodeFixture, now: 2_000_000_059))
        XCTAssertNil(review(nodeFixture, now: 2_000_000_060))
        XCTAssertNil(review(nodeFixture, now: 1_999_999_994))
        XCTAssertNil(review(nodeFixture, key: Data((1...32).map(UInt8.init))))
        XCTAssertNil(review(nodeFixture, key: Data(repeating: 0, count: 32)))
        XCTAssertNil(review(nodeFixture, key: Data(repeating: 1, count: 16)))
        XCTAssertNil(review(nodeFixture, now: -1))
    }

    func testMalformedOrPrivilegedJSONIsNeverAccepted() {
        let canonical = nodeFixture
        let variants = [
            canonical.replacingOccurrences(
                of: "\"capability\":\"igentic.own_app.status.read\"",
                with: "\"capability\":\"reminder.create\""
            ),
            canonical.replacingOccurrences(
                of: "\"parameters\":{}", with: "\"parameters\":{\"text\":\"private\"}"
            ),
            canonical.replacingOccurrences(
                of: "\"parameters\":{}", with: "\"parameters\":{},\"ownerApproved\":true"
            ),
            canonical.replacingOccurrences(
                of: "\"issuedAt\":2000000000",
                with: "\"issuedAt\":2000000000,\"issuedAt\":2000000000"
            ),
            canonical.replacingOccurrences(
                of: "\"schema\":1", with: "\"schema\":true"
            ),
            canonical.replacingOccurrences(
                of: "\"issuedAt\":2000000000", with: "\"issuedAt\":2e9"
            ),
            canonical.replacingOccurrences(
                of: "\"signature\":\"", with: "\"signature\":\"0"
            ),
            canonical.replacingOccurrences(
                of: "\"signature\":\"", with: "\"signature\":\"garbage\",\"extra\":\""
            ),
            canonical.replacingOccurrences(
                of: "\"requestId\":\"11111111", with: "\"requestId\":\"AAAAAAAA"
            ),
            canonical.uppercased(),
            " " + canonical,
            canonical + "\n",
            canonical + " trailing-text",
            String(repeating: "x", count: 1025)
        ]
        for input in variants {
            XCTAssertNil(review(input), "Malformed proposal must never be accepted")
        }
    }

    func testInvalidTimeToLiveAndSwappedKeysAreRejected() {
        XCTAssertNil(review(nodeFixture.replacingOccurrences(
            of: "\"expiresAt\":2000000060", with: "\"expiresAt\":2000000061"
        )))
        XCTAssertNil(review(nodeFixture.replacingOccurrences(
            of: "\"expiresAt\":2000000060", with: "\"expiresAt\":2000000000"
        )))
        XCTAssertNil(review(nodeFixture.replacingOccurrences(
            of: "\"issuedAt\":2000000000", with: "\"issuedAt\":-1"
        )))
    }
    #else
    func testCryptoUnavailableCannotReturnTrustedPreview() {
        XCTAssertNil(review(nodeFixture))
    }
    #endif
}
