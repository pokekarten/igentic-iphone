import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// A *cryptographic preview* of one owner-relay proposal, not an admission,
/// device action or iOS authorization. The replay ledger, device enrollment,
/// native policy, transport and independent receipt all remain separate.
public struct AgentLoopRemoteTaskPreview: Equatable, Sendable {
    public let requestID: String
    public let expiresAt: Int
    public let capability: String

    public var status: String { "cryptographically-verified-preview-only" }
    public var actionExecuted: Bool { false }
    public var ownerApproved: Bool { false }
    public var iPhoneConnected: String { "not-checked" }
    public var deviceReceipt: String { "none" }
    public var replayAdmitted: Bool { false }
}

/// Exact counterpart of the Node owner relay's bounded, canonical proposal
/// format. No HTTP, storage, Shortcuts or action dispatch is performed here.
public enum AgentLoopRemoteTaskVerifier {
    private static let capability = "igentic.own_app.status.read"
    private static let domain = "igentic-owner-task-proposal-v0\n"
    private static let maxBytes = 1024
    private static let maxTTL = 60
    private static let clockSkew = 5

    private struct EmptyParameters: Decodable {}
    private struct TaskBody: Decodable {
        let schema: Int
        let kind: String
        let requestId: String
        let issuedAt: Int
        let expiresAt: Int
        let capability: String
        let parameters: EmptyParameters
    }
    private struct Envelope: Decodable {
        let body: TaskBody
        let signature: String
    }

    /// Returns nil on malformed, ambiguous, expired, unsupported or unsigned
    /// input. A successful result is still *not* permission to act on iOS.
    public static func inspectCanonicalProposal(
        _ bytes: Data,
        relayKey: Data,
        nowSeconds: Int
    ) -> AgentLoopRemoteTaskPreview? {
        #if canImport(CryptoKit)
        guard bytes.count > 0, bytes.count <= maxBytes,
              relayKey.count == 32, Set(relayKey).count > 1,
              nowSeconds >= 0, nowSeconds <= Int.max - clockSkew,
              let original = String(data: bytes, encoding: .utf8),
              let decoded = try? JSONDecoder().decode(Envelope.self, from: bytes)
        else { return nil }

        let body = decoded.body
        guard body.schema == 1,
              body.kind == "read-only-task-proposal",
              body.capability == capability,
              body.issuedAt >= 0,
              body.issuedAt <= nowSeconds + clockSkew,
              body.expiresAt > body.issuedAt,
              body.expiresAt > nowSeconds,
              body.expiresAt - body.issuedAt <= maxTTL,
              body.requestId.count == 36,
              let id = UUID(uuidString: body.requestId),
              id.uuidString.lowercased() == body.requestId,
              decoded.signature.utf8.count == 64,
              decoded.signature.utf8.allSatisfy({
                  (48...57).contains($0) || (97...102).contains($0)
              })
        else { return nil }

        // JSONDecoder accepts unknown or duplicate object fields. Require
        // byte-exact Node JSON.stringify output to exclude both as well as
        // alternate field order, escaped names, ambiguous numeric formats,
        // booleans, redirects, URLs, private text and approval claims.
        let signedBody = """
        {"schema":1,"kind":"read-only-task-proposal","requestId":"\(body.requestId)","issuedAt":\(body.issuedAt),"expiresAt":\(body.expiresAt),"capability":"igentic.own_app.status.read","parameters":{}}
        """
        let canonicalWire = """
        {"body":\(signedBody),"signature":"\(decoded.signature)"}
        """
        guard original == canonicalWire else { return nil }

        let expected = HMAC<SHA256>.authenticationCode(
            for: Data((domain + signedBody).utf8),
            using: SymmetricKey(data: relayKey)
        )
        let expectedHex = expected.map { String(format: "%02x", $0) }.joined()
        // Fixed-size, constant-work comparison after the length and alphabet
        // checks. No private key or supplied content ever enters an error.
        var difference: UInt8 = 0
        for (a, b) in zip(expectedHex.utf8, decoded.signature.utf8) {
            difference |= a ^ b
        }
        guard difference == 0 else { return nil }

        return AgentLoopRemoteTaskPreview(
            requestID: body.requestId,
            expiresAt: body.expiresAt,
            capability: capability
        )
        #else
        // Unsupported CryptoKit platforms never claim cryptographic trust.
        return nil
        #endif
    }
}
