import Foundation
import Security

// Test-process-only trust for one generated loopback certificate.
private final class FixtureTrust: NSObject, URLSessionTaskDelegate {
    let certificate: Data
    init(certificate: Data) { self.certificate = certificate }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping @Sendable (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.host == "127.0.0.1",
              challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let anchor = SecCertificateCreateWithData(nil, certificate as CFData),
              SecTrustSetAnchorCertificates(trust, [anchor] as CFArray) == errSecSuccess,
              SecTrustSetAnchorCertificatesOnly(trust, true) == errSecSuccess,
              SecTrustEvaluateWithError(trust, nil) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@main
private enum NativeRelayClaimSmoke {
    struct Fixture: Decodable {
        let port: Int
        let certificate, deviceKey, proposalKey: Data
        let requestID: String
        let now: Int
    }

    enum Failure: Error { case unexpectedTrust, retried, invalidClaim }

    static func main() async {
        do {
            try await run()
        } catch {
            // Keep the failure actionable without printing Foundation request details.
            let code = (error as NSError).code
            FileHandle.standardError.write(Data("Native claim smoke failed (code \(code))\n".utf8))
            exit(1)
        }
    }

    static func run() async throws {
        let fixture = try JSONDecoder().decode(Fixture.self, from: FileHandle.standardInput.readDataToEndOfFile())
        let client = AgentLoopRelayClaimClient()
        do {
            _ = try await client.claim(port: fixture.port, deviceAccessKey: fixture.deviceKey,
                                       proposalKey: fixture.proposalKey)
            throw Failure.unexpectedTrust
        } catch AgentLoopRelayClaimError.transportUncertain {}
        do {
            _ = try await client.claim(port: fixture.port, deviceAccessKey: fixture.deviceKey,
                                       proposalKey: fixture.proposalKey)
            throw Failure.retried
        } catch AgentLoopRelayClaimError.attemptAlreadyConsumed {}

        let config = URLSessionConfiguration.ephemeral
        config.connectionProxyDictionary = [:]
        config.timeoutIntervalForResource = 8
        let delegate = FixtureTrust(certificate: fixture.certificate)
        let session = URLSession(configuration: config, delegate: delegate,
                                 delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let request = try AgentLoopRelayClaimProtocol.request(port: fixture.port, deviceAccessKey: fixture.deviceKey)
        let (stream, response) = try await session.bytes(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == request.url,
              http.value(forHTTPHeaderField: "Cache-Control") == "no-store",
              http.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8" else {
            throw Failure.invalidClaim
        }
        var data = Data()
        for try await byte in stream {
            guard data.count < AgentLoopRelayClaimProtocol.maxResponseBytes else { throw Failure.invalidClaim }
            data.append(byte)
        }
        guard let claim = try AgentLoopRelayClaimProtocol.decode(data, proposalKey: fixture.proposalKey,
                                                                 nowSeconds: fixture.now),
              claim.requestID == fixture.requestID else { throw Failure.invalidClaim }
    }
}
