import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Verified, bounded proposal preview, not local execution, consent or a receipt.
/// Internal to the native app; never expose this value to a model or App Intent.
struct AgentLoopRelayClaim: Equatable, Sendable {
    let canonicalWire: Data
    let requestID: String
    let receiptNonce: String
    let expiresAt: Int
}

enum AgentLoopRelayClaimError: Error, Equatable {
    case invalidConfiguration
    case invalidResponse
    case attemptAlreadyConsumed
    case transportUncertain
}

/// The exact response contract from the loopback Node HTTPS relay.
/// This does not sign receipts or bypass the separate native owner gate.
enum AgentLoopRelayClaimProtocol {
    static let maxResponseBytes = 2048

    static func request(port: Int, deviceAccessKey: Data) throws -> URLRequest {
        try fixedRequest(port: port, deviceAccessKey: deviceAccessKey, receiptBody: nil)
    }

    /// Only the fixed receipt route is exposed to native code. The proof
    /// is produced by the enrolled review session, not supplied by a model.
    static func receiptRequest(port: Int, deviceAccessKey: Data, proof: Data,
                               expectedClaim: AgentLoopRelayClaim? = nil) throws -> URLRequest {
        // The fixed acknowledgement envelope cannot carry arbitrary text,
        // additional fields or alternative encodings.
        guard proof.count <= maxResponseBytes - 10,
              let text = String(data: proof, encoding: .utf8),
              let decoded = try? JSONDecoder().decode(ReceiptEnvelope.self, from: proof),
              let id = UUID(uuidString: decoded.body.requestId),
              id.uuidString.lowercased() == decoded.body.requestId,
              let nonce = UUID(uuidString: decoded.body.nonce),
              nonce.uuidString.lowercased() == decoded.body.nonce,
              decoded.body.observedAt >= 0, decoded.body.observedAt <= 9_007_199_254_740_991,
              decoded.signature.utf8.count == 64,
              decoded.signature.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        let expected = """
        {"body":{"schema":1,"kind":"read-only-device-key-ack","requestId":"\(decoded.body.requestId)","capability":"igentic.own_app.status.read","nonce":"\(decoded.body.nonce)","observedAt":\(decoded.body.observedAt),"status":"key-holder-reports-read"},"signature":"\(decoded.signature)"}
        """
        guard text == expected, proof == Data(expected.utf8),
              expectedClaim.map({ $0.requestID == decoded.body.requestId &&
                  $0.receiptNonce == decoded.body.nonce &&
                  decoded.body.observedAt < $0.expiresAt }) ?? true else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        var body = Data(#"{"proof":"#.utf8)
        body.append(proof)
        body.append(contentsOf: "}".utf8)
        return try fixedRequest(port: port, deviceAccessKey: deviceAccessKey, receiptBody: body)
    }

    /// Accept only the exact Node acknowledgement for this request.
    /// A 200 alone, unknown outcome or claimed device attestation is not success.
    static func verifyReceiptAcknowledgement(_ bytes: Data, requestID: String) throws {
        guard let id = UUID(uuidString: requestID), id.uuidString.lowercased() == requestID,
              bytes.count <= maxResponseBytes else {
            throw AgentLoopRelayClaimError.invalidResponse
        }
        let expected = """
        {"schema":1,"result":{"schema":1,"requestId":"\(requestID)","capability":"igentic.own_app.status.read","entryPoint":"chatgpt-site","transport":"cellular-foreground","state":"receipt-key-authenticated","deliveryAttempted":true,"attemptCount":1,"receiptKeyAuthenticated":true,"actionExecuted":false,"ownerApproved":false,"iPhoneConnected":"not-checked","deviceReceipt":"key-authenticated-not-device-attested","automaticRetryAllowed":false}}
        """
        guard bytes == Data(expected.utf8) else { throw AgentLoopRelayClaimError.invalidResponse }
    }

    private static func fixedRequest(port: Int, deviceAccessKey: Data, receiptBody: Data?) throws -> URLRequest {
        let path = receiptBody == nil ? "claim" : "receipt"
        guard (1...65535).contains(port), deviceAccessKey.count == 32,
              Set(deviceAccessKey).count > 1,
              let url = URL(string: "https://127.0.0.1:\(port)/v1/device/\(path)") else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 5)
        request.httpMethod = "POST"
        request.httpBody = receiptBody ?? Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + deviceAccessKey.map { String(format: "%02x", $0) }.joined(),
                         forHTTPHeaderField: "Authorization")
        return request
    }

    private struct ReceiptEnvelope: Decodable {
        struct Body: Decodable {
            let requestId: String
            let nonce: String
            let observedAt: Int
        }
        let body: Body
        let signature: String
    }

    private struct Response: Decodable {
        let schema: Int
        let result: Payload?
    }
    private struct Payload: Decodable {
        let canonicalWire: String
        let receiptNonce: String
        let requestId: String
        let expiresAt: Int
    }

    static func decode(_ bytes: Data, proposalKey: Data, nowSeconds: Int) throws -> AgentLoopRelayClaim? {
        guard bytes.count <= maxResponseBytes,
              let response = try? JSONDecoder().decode(Response.self, from: bytes),
              response.schema == 1 else { throw AgentLoopRelayClaimError.invalidResponse }
        guard let payload = response.result else {
            guard bytes == Data(#"{"schema":1,"result":null}"#.utf8) else {
                throw AgentLoopRelayClaimError.invalidResponse
            }
            return nil
        }
        let wire = Data(payload.canonicalWire.utf8)
        guard let nonce = UUID(uuidString: payload.receiptNonce),
              nonce.uuidString.lowercased() == payload.receiptNonce,
              let preview = AgentLoopRemoteTaskVerifier.inspectCanonicalProposal(
                wire, relayKey: proposalKey, nowSeconds: nowSeconds),
              preview.requestID == payload.requestId,
              preview.expiresAt == payload.expiresAt,
              let inner = try? JSONSerialization.jsonObject(with: wire) as? [String: Any],
              let body = inner["body"] as? [String: Any],
              let issuedAt = body["issuedAt"] as? Int,
              nowSeconds >= issuedAt,
              let encodedWire = try? JSONEncoder().encode(payload.canonicalWire),
              let escapedWire = String(data: encodedWire, encoding: .utf8) else {
            throw AgentLoopRelayClaimError.invalidResponse
        }
        // Exact server field order and encoding. Reject duplicate or unknown
        // keys, ambiguous numeric representations, extra metadata and whitespace.
        let expected = """
        {"schema":1,"result":{"canonicalWire":\(escapedWire),"receiptNonce":"\(payload.receiptNonce)","requestId":"\(payload.requestId)","expiresAt":\(payload.expiresAt)}}
        """
        guard bytes == Data(expected.utf8) else { throw AgentLoopRelayClaimError.invalidResponse }
        return AgentLoopRelayClaim(canonicalWire: wire, requestID: preview.requestID,
                                  receiptNonce: payload.receiptNonce, expiresAt: preview.expiresAt)
    }
}

#if canImport(Darwin)
/// No redirects (including same-host redirects), cookies, cache, custom trust
/// overrides, background tasks or retry loop. Normal system TLS trust applies.
private final class AgentLoopRelayNoRedirect: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Host/simulator test client only: 127.0.0.1 on the device itself is not a
/// connection to the owner's Mac. Caller must explicitly create each session.
/// A failed/empty claim is never automatically retried by this instance.
actor AgentLoopRelayClaimClient {
    private var attempted = false
    private var receiptAttempted = false
    private var receiptBinding: (port: Int, key: Data, claim: AgentLoopRelayClaim)?

    /// Separate one-use receipt upload. The enrolled session binds it to
    /// the original claim port, credentials and request ID.
    func submitReceipt(port: Int, deviceAccessKey: Data, proof: Data, requestID: String) async throws {
        guard !receiptAttempted else { throw AgentLoopRelayClaimError.attemptAlreadyConsumed }
        guard let binding = receiptBinding, binding.port == port,
              binding.key == deviceAccessKey, binding.claim.requestID == requestID else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        receiptAttempted = true
        receiptBinding = nil
        let request = try AgentLoopRelayClaimProtocol.receiptRequest(
            port: port, deviceAccessKey: deviceAccessKey, proof: proof, expectedClaim: binding.claim)
        do {
            let bytes = try await send(request)
            try AgentLoopRelayClaimProtocol.verifyReceiptAcknowledgement(bytes, requestID: requestID)
        } catch {
            throw AgentLoopRelayClaimError.transportUncertain
        }
    }

    func claim(port: Int, deviceAccessKey: Data, proposalKey: Data,
               clock: @Sendable () -> Int = { Int(Date().timeIntervalSince1970) }) async throws -> AgentLoopRelayClaim? {
        guard !attempted else { throw AgentLoopRelayClaimError.attemptAlreadyConsumed }
        guard proposalKey.count == 32, Set(proposalKey).count > 1,
              proposalKey != deviceAccessKey else { throw AgentLoopRelayClaimError.invalidConfiguration }
        let request = try AgentLoopRelayClaimProtocol.request(port: port, deviceAccessKey: deviceAccessKey)
        attempted = true
        do {
            let claim = try AgentLoopRelayClaimProtocol.decode(
                try await send(request), proposalKey: proposalKey, nowSeconds: clock())
            if let claim { receiptBinding = (port, deviceAccessKey, claim) }
            return claim
        } catch {
            throw AgentLoopRelayClaimError.transportUncertain
        }
    }

    private func send(_ request: URLRequest) async throws -> Data {
        try Task.checkCancellation()
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.httpShouldSetCookies = false
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config, delegate: AgentLoopRelayNoRedirect(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let (stream, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              http.url == request.url,
              http.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8",
              http.value(forHTTPHeaderField: "Cache-Control") == "no-store" else {
            throw AgentLoopRelayClaimError.invalidResponse
        }
        var data = Data()
        for try await byte in stream {
            guard data.count < AgentLoopRelayClaimProtocol.maxResponseBytes else {
                throw AgentLoopRelayClaimError.invalidResponse
            }
            data.append(byte)
        }
        return data
    }
}
#endif
