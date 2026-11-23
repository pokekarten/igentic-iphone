import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

/// The small, public-only envelope shared by the iGentic iPhone companion
/// and the first-party Node HTTPS readiness gateway. Not a control channel.
public enum CellularHeartbeatProtocol {
    public static let path = "/v1/companion/readiness"
    public static let body = Data("{\"schema\":1,\"kind\":\"readiness\"}".utf8)

    public static func validEndpoint(_ text: String) -> URL? {
        guard let parts = URLComponents(string: text),
              parts.scheme?.lowercased() == "https",
              let host = parts.host, host.contains("."),
              host != "localhost" && host != "127.0.0.1",
              parts.user == nil, parts.password == nil,
              parts.path == path,
              parts.query == nil, parts.fragment == nil,
              parts.port == nil || (parts.port! > 0 && parts.port! <= 65535),
              let url = parts.url else { return nil }
        return url
    }

    /// Classifies ONLY URLSession's observed transaction-level isCellular
    /// flags, not network reachability or the available radio. Empty or
    /// mixed metrics never constitute cellular evidence.
    public static func classifyTransport(transactionCellularFlags flags: [Bool]) -> String {
        guard !flags.isEmpty else { return "transport-not-verified" }
        if flags.allSatisfy({ $0 }) { return "cellular-transport-observed" }
        if flags.allSatisfy({ !$0 }) { return "other-transport-observed" }
        return "mixed-transport-not-verified"
    }

    public static func decodedSecret(_ encoded: String) -> Data? {
        let normalized = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count == 44,
              let data = Data(base64Encoded: normalized),
              data.count == 32, data.base64EncodedString() == normalized
        else { return nil }
        return data
    }

    #if canImport(CryptoKit)
    public static func signature(
        secret: Data, timestamp: Int, nonce: String
    ) -> String? {
        guard secret.count == 32,
              timestamp > 0,
              timestamp < 1_000_000_000_000,
              UUID(uuidString: nonce) != nil,
              nonce == nonce.lowercased()
        else { return nil }
        let digest = SHA256.hash(data: body)
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let message = [
            "igentic-cellular-v1", "POST", path,
            String(timestamp), nonce, hex
        ].joined(separator: "\n")
        let signed = HMAC<SHA256>.authenticationCode(
            for: Data(message.utf8), using: SymmetricKey(data: secret)
        )
        return signed.map { String(format: "%02x", $0) }.joined()
    }
    #endif
}

/// Per-request synchronization between URLSession's task completion and its
/// potentially later didFinishCollecting metrics callback. Never infer a radio
/// from a URLSession success. Only a bounded wait is allowed: no metrics must
/// remain "not verified" rather than a guessed cellular success.
final class CellularTransportObservation: @unchecked Sendable {
    private let lock = NSLock()
    private var capturedFlags: [Bool]?

    func record(_ flags: [Bool]) {
        lock.lock()
        if capturedFlags == nil { capturedFlags = flags }
        lock.unlock()
    }

    func snapshot() -> [Bool]? {
        lock.lock()
        defer { lock.unlock() }
        return capturedFlags
    }

    func waitForEvidence(
        attempts: Int = 12, pollDelay: Duration = .milliseconds(100)
    ) async -> String {
        guard attempts > 0 else { return "transport-not-verified" }
        for attempt in 0..<attempts {
            if let flags = snapshot() {
                return CellularHeartbeatProtocol.classifyTransport(
                    transactionCellularFlags: flags
                )
            }
            if attempt + 1 < attempts {
                try? await Task.sleep(for: pollDelay)
            }
        }
        return "transport-not-verified"
    }
}
