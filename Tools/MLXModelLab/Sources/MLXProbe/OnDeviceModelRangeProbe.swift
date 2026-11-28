import Foundation
import CryptoKit

/// Research-only explicit network test. No private data, auth, model execution,
/// file installation, or implicit fallback. Range digest derived from the
/// complete upstream-verified local artifact; final model admission still
/// requires the full pinned manifest.
public enum OnDeviceModelRangeProbe {
    private static let first = 1_292_921_912
    private static let length = 65_536
    private static let total = 1_722_271_785
    private static let digest = "1c6d52d3d63452c4be16c3e0bdc2ccf2a1d5362c9d5f4b4ef34808b092af8bee"
    private static let source = URL(string: "https://huggingface.co/mlx-community/Qwen3.5-2B-4bit/resolve/674aaa7240b91e8012fcad5d791b7dfe5ba90207/model.safetensors")!

    private static func allowed(_ url: URL?) -> Bool {
        guard let url, url.scheme == "https", url.user == nil, url.password == nil, let host = url.host?.lowercased() else { return false }
        return host == "huggingface.co" || host.hasSuffix(".huggingface.co") || host.hasSuffix(".hf.co")
    }

    private final class RedirectGate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest) async -> URLRequest? {
            guard OnDeviceModelRangeProbe.allowed(request.url) else { return nil }
            var clean = request
            clean.setValue(nil, forHTTPHeaderField: "Authorization")
            clean.setValue(nil, forHTTPHeaderField: "Cookie")
            clean.setValue("bytes=\(OnDeviceModelRangeProbe.first)-\(OnDeviceModelRangeProbe.first + OnDeviceModelRangeProbe.length - 1)", forHTTPHeaderField: "Range")
            clean.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            return clean
        }
    }

    public static func run() async -> String {
        let start = ProcessInfo.processInfo.systemUptime
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieStorage = nil
        config.urlCredentialStorage = nil
        config.urlCache = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        let session = URLSession(configuration: config, delegate: RedirectGate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: source)
        request.setValue("bytes=\(first)-\(first + length - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (stream, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, allowed(http.url), http.statusCode == 206,
                  http.value(forHTTPHeaderField: "Content-Range") == "bytes \(first)-\(first + length - 1)/\(total)",
                  http.expectedContentLength == -1 || http.expectedContentLength == Int64(length) else {
                return "MODEL_RANGE_PROBE=responseRejected; installed=false; inference=false"
            }
            var data = Data()
            data.reserveCapacity(length)
            for try await byte in stream {
                guard data.count < length, !Task.isCancelled else {
                    return "MODEL_RANGE_PROBE=bodyRejected; installed=false; inference=false"
                }
                data.append(byte)
            }
            let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard data.count == length, actual == digest else {
                return "MODEL_RANGE_PROBE=bodyRejected; installed=false; inference=false"
            }
            return "MODEL_RANGE_PROBE=verified; bytes=\(data.count); offset=\(first); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000)); installed=false; inference=false"
        } catch { return "MODEL_RANGE_PROBE=networkFailed; installed=false; inference=false" }
    }
}
