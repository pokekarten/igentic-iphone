import Foundation
import XCTest
@testable import iGenticApp

final class AgentLoopRelayClaimClientTests: XCTestCase {
    private let wire = #"{"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}"#
    private var proposalKey: Data { Data((0..<32).map(UInt8.init)) }
    private var deviceKey: Data { Data((32..<64).map(UInt8.init)) }
    private let nonce = "aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
    // Exact Node JSON.stringify output; independently generated, synthetic key only.
    private let response = #"{"schema":1,"result":{"canonicalWire":"{\"body\":{\"schema\":1,\"kind\":\"read-only-task-proposal\",\"requestId\":\"11111111-2222-4333-8444-555555555555\",\"issuedAt\":2000000000,\"expiresAt\":2000000060,\"capability\":\"igentic.own_app.status.read\",\"parameters\":{}},\"signature\":\"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2\"}","receiptNonce":"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee","requestId":"11111111-2222-4333-8444-555555555555","expiresAt":2000000060}}"#

    func testFixedLoopbackRequestAndNoSecretInURL() throws {
        let request = try AgentLoopRelayClaimProtocol.request(port: 12345, deviceAccessKey: deviceKey)
        XCTAssertEqual(request.url?.absoluteString, "https://127.0.0.1:12345/v1/device/claim")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data("{}".utf8))
        XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Bearer ") == true)
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.request(port: 0, deviceAccessKey: deviceKey))
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.request(port: 65536, deviceAccessKey: deviceKey))
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.request(port: 12345, deviceAccessKey: Data(repeating: 0,count:32)))
    }

    func testReceiptRequestAndStrictAcknowledgement() throws {
        let id = "11111111-2222-4333-8444-555555555555"
        let proof = Data(#"{"body":{"schema":1,"kind":"read-only-device-key-ack","requestId":"11111111-2222-4333-8444-555555555555","capability":"igentic.own_app.status.read","nonce":"22222222-3333-4444-8555-666666666666","observedAt":2000000000,"status":"key-holder-reports-read"},"signature":"27ecb277fcdcf0c6591740d8bb58f9885bdacc54e986748116f77842ddec3a6e"}"#.utf8)
        let request = try AgentLoopRelayClaimProtocol.receiptRequest(port: 12345, deviceAccessKey: deviceKey, proof: proof)
        XCTAssertEqual(request.url?.absoluteString, "https://127.0.0.1:12345/v1/device/receipt")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.httpBody, Data(#"{"proof":"#.utf8) + proof + Data("}".utf8))
        let bound = AgentLoopRelayClaim(canonicalWire: Data(wire.utf8), requestID: id,
            receiptNonce: "22222222-3333-4444-8555-666666666666", expiresAt: 2_000_000_060)
        _ = try AgentLoopRelayClaimProtocol.receiptRequest(port: 12345, deviceAccessKey: deviceKey, proof: proof, expectedClaim: bound)
        let wrong = AgentLoopRelayClaim(canonicalWire: bound.canonicalWire, requestID: id,
            receiptNonce: nonce, expiresAt: bound.expiresAt)
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.receiptRequest(port: 12345, deviceAccessKey: deviceKey, proof: proof, expectedClaim: wrong))
        let text = String(decoding: proof, as: UTF8.self)
        for malformed in [text + " ", #"{"private":"synthetic test text"}"#,
            text.replacingOccurrences(of: #""schema":1,"kind":"#, with: #""schema":1,"schema":1,"kind":"#),
            text.replacingOccurrences(of: #""status":"#, with: #""observation":"synthetic","status":"#)] {
            XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.receiptRequest(port: 12345, deviceAccessKey: deviceKey, proof: Data(malformed.utf8)))
        }
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.receiptRequest(port: 12345, deviceAccessKey: deviceKey, proof: Data(repeating: 1, count: 2049)))
        let ack = #"{"schema":1,"result":{"schema":1,"requestId":"11111111-2222-4333-8444-555555555555","capability":"igentic.own_app.status.read","entryPoint":"chatgpt-site","transport":"cellular-foreground","state":"receipt-key-authenticated","deliveryAttempted":true,"attemptCount":1,"receiptKeyAuthenticated":true,"actionExecuted":false,"ownerApproved":false,"iPhoneConnected":"not-checked","deviceReceipt":"key-authenticated-not-device-attested","automaticRetryAllowed":false}}"#
        try AgentLoopRelayClaimProtocol.verifyReceiptAcknowledgement(Data(ack.utf8), requestID: id)
        for invalid in [ack + " ", ack.replacingOccurrences(of: id, with: nonce),
            ack.replacingOccurrences(of: "receipt-key-authenticated", with: "outcome-unknown"),
            ack.replacingOccurrences(of: #""actionExecuted":false"#, with: #""actionExecuted":true"#),
            ack.replacingOccurrences(of: #""schema":1,"result":"#, with: #""schema":1,"schema":1,"result":"#),
            ack.replacingOccurrences(of: #""ownerApproved":false"#, with: #""ownerApproved":true"#)] {
            XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.verifyReceiptAcknowledgement(Data(invalid.utf8), requestID: id))
        }
    }

    func testEmptyResponseMustBeExact() throws {
        XCTAssertNil(try AgentLoopRelayClaimProtocol.decode(Data(#"{"schema":1,"result":null}"#.utf8),
                      proposalKey: proposalKey, nowSeconds: 2_000_000_000))
        for value in [#"{"schema":1}"#, #"{"schema":1,"result":null,"actionExecuted":true}"#,
                      #"{"schema":1,"schema":1,"result":null}"#] {
            XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.decode(Data(value.utf8),
                                 proposalKey: proposalKey, nowSeconds: 2_000_000_000))
        }
    }

    #if canImport(CryptoKit)
    func testNodeSignedWireAndStrictCorrelation() throws {
        let value = try XCTUnwrap(AgentLoopRelayClaimProtocol.decode(Data(response.utf8),
                                   proposalKey: proposalKey, nowSeconds: 2_000_000_000))
        XCTAssertEqual(value.canonicalWire, Data(wire.utf8))
        XCTAssertEqual(value.receiptNonce, nonce)
        XCTAssertEqual(value.expiresAt, 2_000_000_060)
        for time in [1_999_999_999, 2_000_000_060] {
            XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.decode(Data(response.utf8),
                                 proposalKey: proposalKey, nowSeconds: time))
        }
        XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.decode(Data(response.utf8),
                             proposalKey: deviceKey, nowSeconds: 2_000_000_000))
    }

    func testMalformedClaimNeverReachesOwnerGate() {
        for value in [
            response.replacingOccurrences(of: nonce, with: nonce.uppercased()),
            response.replacingOccurrences(of: #""requestId":"11111111-2222-4333-8444-555555555555""#,
                                           with: #""requestId":"aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee""#),
            response.replacingOccurrences(of: #""expiresAt":2000000060"#, with: #""expiresAt":2000000061"#),
            response.replacingOccurrences(of: #""schema":1,"result":"#, with: #""schema":1,"schema":1,"result":"#),
            response.replacingOccurrences(of: #""receiptNonce":"#, with: #""ownerApproved":true,"receiptNonce":"#),
            response + " ", String(repeating: "x", count: 2049)
        ] {
            XCTAssertThrowsError(try AgentLoopRelayClaimProtocol.decode(Data(value.utf8),
                                 proposalKey: proposalKey, nowSeconds: 2_000_000_000))
        }
    }
    #endif
}
