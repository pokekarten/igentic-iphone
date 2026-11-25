import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// Internal wire encoder for the fixed read-only key-holder acknowledgement.
/// HMAC proves key possession, not independently attested device execution.
/// Only the native enrolled review path should use this with protected keys.
#if canImport(CryptoKit)
enum AgentLoopReadOnlyKeyProof {
    private static let domain = "igentic-device-receipt-key-proof-v1\n"
    private static let capability = "igentic.own_app.status.read"
    private static let maxJavaScriptSafeInteger = 9_007_199_254_740_991

    /// Emits exactly Node signReadOnlyDeviceKeyReceipt's JSON representation.
    /// Pure encoding, not authorization. Never accepts an observation value.
    static func encode(
        secret: Data,
        requestID: String,
        receiptNonce: String,
        observedAt: Int
    ) -> Data? {
        guard secret.count == 32, Set(secret).count > 1,
              requestID.count == 36,
              let id = UUID(uuidString: requestID),
              id.uuidString.lowercased() == requestID,
              receiptNonce.count == 36,
              let challenge = UUID(uuidString: receiptNonce),
              challenge.uuidString.lowercased() == receiptNonce,
              observedAt >= 0, observedAt <= maxJavaScriptSafeInteger
        else { return nil }

        let body = """
        {"schema":1,"kind":"read-only-device-key-ack","requestId":"\(requestID)","capability":"\(capability)","nonce":"\(receiptNonce)","observedAt":\(observedAt),"status":"key-holder-reports-read"}
        """
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data((domain + body).utf8),
            using: SymmetricKey(data: secret)
        ).map { String(format: "%02x", $0) }.joined()
        return Data("{\"body\":\(body),\"signature\":\"\(signature)\"}".utf8)
    }
}

#if DEBUG
/// Retain the explicit synthetic interoperability fixture for existing tests.
enum AgentLoopReadOnlyReceiptFixture {
    static func makeTestOnlyProof(secret: Data, requestID: String,
                                  receiptNonce: String, observedAt: Int) -> Data? {
        AgentLoopReadOnlyKeyProof.encode(secret: secret, requestID: requestID,
                                         receiptNonce: receiptNonce, observedAt: observedAt)
    }
}
#endif
#endif
