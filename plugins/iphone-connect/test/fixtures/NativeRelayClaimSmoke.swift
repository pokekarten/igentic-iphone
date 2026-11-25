import Foundation
import Security
import CryptoKit
@testable import iGenticApp

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
        let certificate, deviceKey, proposalKey, receiptKey: Data
        let requestID: String
        let now: Int
    }

    enum Failure: Error { case unexpectedTrust, retried, invalidClaim, invalidReview, invalidResponse }

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
        let data = try await send(request, session: session, delegate: delegate)
        guard let claim = try AgentLoopRelayClaimProtocol.decode(data, proposalKey: fixture.proposalKey,
                                                                 nowSeconds: fixture.now),
              claim.requestID == fixture.requestID else { throw Failure.invalidClaim }

        let proof = try await reviewedFixtureProof(for: claim, fixture: fixture)
        let receiptRequest = try AgentLoopRelayClaimProtocol.receiptRequest(
            port: fixture.port, deviceAccessKey: fixture.deviceKey,
            proof: proof, expectedClaim: claim)
        let ack = try await send(receiptRequest, session: session, delegate: delegate)
        try AgentLoopRelayClaimProtocol.verifyReceiptAcknowledgement(ack, requestID: claim.requestID)
        // The owner independently reads the result using the original request ID.
    }

    @MainActor
    private static func reviewedFixtureProof(for claim: AgentLoopRelayClaim, fixture: Fixture) throws -> Data {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let journalKey = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let journal = try AgentLoopLocalReplayJournal(directory: directory, key: journalKey)
        var reads = 0
        let gate = AgentLoopSignedOwnerStatusGate(replayJournal: journal, clockSeconds: { fixture.now }) {
            reads += 1
            return AgentLoopLocalStatus(batteryFraction: 0.64, lowPowerModeEnabled: true, osVersion: "fixture")
        }
        let staged = gate.stageRelayClaimFixture(claim, relayKey: fixture.proposalKey,
                                                privacyMode: .externalAI, statusClassification: .publicDefault)
        guard staged.stage == .awaitingOwnerReview, reads == 0 else { throw Failure.invalidReview }

        func externalProof() -> Data? {
            gate.prepareTestOnlyProofAfterSeparateLocalReview(receiptKey: fixture.receiptKey,
                                                             currentPrivacyMode: .externalAI)
        }
        guard externalProof() == nil else { throw Failure.invalidReview }
        let read = gate.readAfterLocalReviewAction()
        guard read.stage == .locallyRead, reads == 1 else { throw Failure.invalidReview }
        let localOnlyProof = gate.prepareTestOnlyProofAfterSeparateLocalReview(receiptKey: fixture.receiptKey,
                                                                              currentPrivacyMode: .localOnly)
        guard localOnlyProof == nil, let proof = externalProof(), externalProof() == nil else {
            throw Failure.invalidReview
        }
        return proof
    }

    private static func send(_ request: URLRequest, session: URLSession, delegate: FixtureTrust) async throws -> Data {
        let (stream, response) = try await session.bytes(for: request, delegate: delegate)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, http.url == request.url,
              http.value(forHTTPHeaderField: "Cache-Control") == "no-store",
              http.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8" else {
            throw Failure.invalidResponse
        }
        var data = Data()
        for try await byte in stream {
            guard data.count < AgentLoopRelayClaimProtocol.maxResponseBytes else { throw Failure.invalidResponse }
            data.append(byte)
        }
        return data
    }
}
