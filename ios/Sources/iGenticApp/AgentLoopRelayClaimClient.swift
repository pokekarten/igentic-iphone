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
        guard (1...65535).contains(port), deviceAccessKey.count == 32,
              Set(deviceAccessKey).count > 1,
              let url = URL(string: "https://127.0.0.1:\(port)/v1/device/claim") else {
            throw AgentLoopRelayClaimError.invalidConfiguration
        }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 5)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + deviceAccessKey.map { String(format: "%02x", $0) }.joined(),
                         forHTTPHeaderField: "Authorization")
        return request
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
    func claim(port: Int, deviceAccessKey: Data, proposalKey: Data,
               clock: @Sendable () -> Int = { Int(Date().timeIntervalSince1970) }) async throws -> AgentLoopRelayClaim? {
        guard !attempted else { throw AgentLoopRelayClaimError.attemptAlreadyConsumed }
        guard proposalKey.count == 32, Set(proposalKey).count > 1,
              proposalKey != deviceAccessKey else { throw AgentLoopRelayClaimError.invalidConfiguration }
        let request = try AgentLoopRelayClaimProtocol.request(port: port, deviceAccessKey: deviceAccessKey)
        attempted = true
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
        do {
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
            return try AgentLoopRelayClaimProtocol.decode(data, proposalKey: proposalKey, nowSeconds: clock())
        } catch {
            // A failed response may follow successful server-side preparation.
            // Never pass through credentials, transport details or raw wire.
            throw AgentLoopRelayClaimError.transportUncertain
        }
    }
}
#endif
