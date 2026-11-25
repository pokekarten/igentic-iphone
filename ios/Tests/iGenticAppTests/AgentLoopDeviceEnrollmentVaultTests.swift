import Foundation
import XCTest
@testable import iGenticApp

#if canImport(Security) && canImport(Darwin)
private final class EnrollmentMemoryBackend: AgentLoopDeviceEnrollmentBackend {
    var bytes: Data?
    var writes = 0
    var unavailable = false
    func load() throws -> Data? {
        if unavailable { throw AgentLoopDeviceEnrollmentError.unavailable }
        return bytes
    }
    func createOnce(_ data: Data) throws -> Bool {
        guard bytes == nil else { return false }
        writes += 1; bytes = data; return true
    }
    func revokeExisting(expected: Data, replacement: Data) throws -> Bool {
        guard bytes == expected else { return false }
        writes += 1; bytes = replacement; return true
    }
}

final class AgentLoopDeviceEnrollmentVaultTests: XCTestCase {
    private static func key(_ start: Int) -> Data { Data((start..<(start+32)).map(UInt8.init)) }
    private static func enrollment() -> AgentLoopDeviceEnrollment {
        .init(id: UUID(), deviceAccessKey: key(0), proposalKey: key(32), receiptKey: key(64))
    }

    func testExplicitEnrollmentAndPermanentRevocation() async throws {
        try await MainActor.run {
            let backend = EnrollmentMemoryBackend(), replayKey = Self.key(96)
            let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: replayKey)
            XCTAssertThrowsError(try vault.loadExisting()) {
                XCTAssertEqual($0 as? AgentLoopDeviceEnrollmentError, .notEnrolled)
            }
            XCTAssertEqual(backend.writes, 0)
            let value = Self.enrollment()
            try vault.enrollExplicitly(value)
            let reopened = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: replayKey)
            XCTAssertEqual(try reopened.loadExisting(), value)
            XCTAssertThrowsError(try reopened.enrollExplicitly(Self.enrollment()))
            XCTAssertThrowsError(try reopened.revokeExplicitly(id: UUID()))
            XCTAssertEqual(backend.writes, 1)
            try reopened.revokeExplicitly(id: value.id)
            XCTAssertEqual(backend.bytes, Data([2]))
            XCTAssertThrowsError(try vault.loadExisting()) {
                XCTAssertEqual($0 as? AgentLoopDeviceEnrollmentError, .revoked)
            }
            XCTAssertThrowsError(try vault.enrollExplicitly(Self.enrollment())) {
                XCTAssertEqual($0 as? AgentLoopDeviceEnrollmentError, .revoked)
            }
            XCTAssertEqual(backend.writes, 2)
        }
    }

    func testWeakReusedAndReplayKeysCannotEnroll() async throws {
        try await MainActor.run {
            let backend = EnrollmentMemoryBackend(), replay = Self.key(96)
            let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: replay)
            for bad in [Data(repeating: 0,count:32), Self.key(0), replay, Data([1])] {
                let value = AgentLoopDeviceEnrollment(id: UUID(), deviceAccessKey: Self.key(0),
                    proposalKey: Self.key(32), receiptKey: bad)
                XCTAssertThrowsError(try vault.enrollExplicitly(value))
            }
            XCTAssertEqual(backend.writes, 0)
        }
    }

    func testCorruptionAndUnavailableStorageNeverReset() async throws {
        try await MainActor.run {
            let backend = EnrollmentMemoryBackend()
            let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: Self.key(96))
            for bad in [Data(), Data([1]), Data([2,0]), Data(repeating: 0,count:133)] {
                backend.bytes = bad
                XCTAssertThrowsError(try vault.loadExisting())
                XCTAssertThrowsError(try vault.enrollExplicitly(Self.enrollment()))
                XCTAssertEqual(backend.bytes, bad)
            }
            backend.unavailable = true
            XCTAssertThrowsError(try vault.loadExisting())
            XCTAssertThrowsError(try vault.enrollExplicitly(Self.enrollment()))
            XCTAssertEqual(backend.writes, 0)
        }
    }
}
#endif

#if canImport(Security) && canImport(Darwin)
import AgentCore

private actor EnrollmentClaimProbe {
    private(set) var calls = 0
    private(set) var keysMatched = false
    private var continuation: CheckedContinuation<Void, Never>?
    func claim(device: Data, proposal: Data) async -> AgentLoopRelayClaim? {
        calls += 1
        keysMatched = device == Data((0..<32).map(UInt8.init))
            && proposal == Data((32..<64).map(UInt8.init))
        await withCheckedContinuation { continuation = $0 }
        return nil
    }
    func release() {
        continuation?.resume()
        continuation = nil
    }
    func isWaiting() -> Bool { continuation != nil }
}

extension AgentLoopDeviceEnrollmentVaultTests {
    @MainActor
    func testEnrolledClaimUsesDistinctKeysAndRejectsRevocationDuringIO() async throws {
        let backend = EnrollmentMemoryBackend()
        let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: Self.key(96))
        let enrollment = Self.enrollment()
        try vault.enrollExplicitly(enrollment)
        let probe = EnrollmentClaimProbe()
        let session = AgentLoopEnrolledClaimSession(vault: vault, currentPrivacyMode: { .externalAI }) {
            _, device, proposal in await probe.claim(device: device, proposal: proposal)
        }
        let pending = Task { try await session.claimAfterLocalAction(port: 12345) }
        for _ in 0..<1000 {
            if await probe.isWaiting() { break }
            try await Task.sleep(for: .milliseconds(1))
        }
        let waiting = await probe.isWaiting()
        XCTAssertTrue(waiting)
        guard waiting else { pending.cancel(); return }
        try vault.revokeExplicitly(id: enrollment.id)
        await probe.release()
        do {
            _ = try await pending.value
            XCTFail("Revoked session returned a claim")
        } catch {
            XCTAssertEqual(error as? AgentLoopEnrolledClaimSession.Failure, .enrollmentChanged)
        }
        let calls = await probe.calls
        let matched = await probe.keysMatched
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(matched)
        do {
            _ = try await session.claimAfterLocalAction(port: 12345)
            XCTFail("Second attempt was not rejected")
        } catch {
            XCTAssertEqual(error as? AgentLoopEnrolledClaimSession.Failure, .alreadyAttempted)
        }
    }

    @MainActor
    func testClaimStagesReviewAndRequiresSeparateReadWithLiveEnrollment() async throws {
        for scenario in ["success", "revoked", "local-only", "mismatched-claim", "revoked-after-read", "local-only-after-read", "expired-after-read", "outside-session-read"] {
            let backend = EnrollmentMemoryBackend()
            let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: Self.key(96))
            let enrollment = AgentLoopDeviceEnrollment(id: UUID(), deviceAccessKey: Self.key(32),
                proposalKey: Self.key(0), receiptKey: Self.key(64))
            try vault.enrollExplicitly(enrollment)
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false,
                                                     attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: dir) }
            let wire = #"{"body":{"schema":1,"kind":"read-only-task-proposal","requestId":"11111111-2222-4333-8444-555555555555","issuedAt":2000000000,"expiresAt":2000000060,"capability":"igentic.own_app.status.read","parameters":{}},"signature":"5109a32fd50436db89b96cd4970abd29626f0d0fd786fd71f79e0855821093b2"}"#
            let claim = AgentLoopRelayClaim(canonicalWire: Data(wire.utf8),
                requestID: scenario == "mismatched-claim" ? UUID().uuidString.lowercased() : "11111111-2222-4333-8444-555555555555",
                receiptNonce: "22222222-3333-4444-8555-666666666666", expiresAt: 2_000_000_060)
            var mode = PrivacyMode.externalAI
            var reads = 0
            var time = 2_000_000_000
            let gate = AgentLoopSignedOwnerStatusGate(
                replayJournal: try AgentLoopLocalReplayJournal(directory: dir, key: Self.key(96)),
                clockSeconds: { time }, statusReader: {
                    reads += 1
                    return AgentLoopLocalStatus(batteryFraction: 0.64, lowPowerModeEnabled: true, osVersion: "27.2")
                })
            let session = AgentLoopEnrolledClaimSession(vault: vault, currentPrivacyMode: { mode }) {
                _, _, _ in claim
            }
            XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction())
            XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
            let staged = try await session.stageClaimAfterLocalAction(port: 12345, gate: gate)
            XCTAssertEqual(reads, 0)
            XCTAssertNil(staged?.ownerAppObservation)
            XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
            if scenario == "mismatched-claim" {
                XCTAssertEqual(staged?.stage, .denied)
                XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction())
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path).count, 0)
                continue
            }
            XCTAssertEqual(staged?.stage, .awaitingOwnerReview)
            XCTAssertEqual(staged?.remoteActionExecuted, false)
            if scenario == "revoked" {
                try vault.revokeExplicitly(id: enrollment.id)
                XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction()) {
                    XCTAssertEqual($0 as? AgentLoopEnrolledClaimSession.Failure, .enrollmentChanged)
                }
            } else if scenario == "local-only" {
                mode = .localOnly
                XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction()) {
                    XCTAssertEqual($0 as? AgentLoopEnrolledClaimSession.Failure, .privacyDenied)
                }
                mode = .externalAI
            } else if scenario == "outside-session-read" {
                XCTAssertEqual(gate.readAfterLocalReviewAction().stage, .locallyRead)
                XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction())
            } else {
                let result = try session.readAfterSeparateLocalReviewAction()
                XCTAssertEqual(result.stage, .locallyRead)
                XCTAssertTrue(result.localReadCompleted)
                XCTAssertFalse(result.externalDataShared)
                XCTAssertFalse(result.remoteActionExecuted)
                XCTAssertEqual(result.independentDeviceReceipt, "none")
                if scenario == "revoked-after-read" {
                    try vault.revokeExplicitly(id: enrollment.id)
                    XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
                } else if scenario == "local-only-after-read" {
                    mode = .localOnly
                    XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
                    mode = .externalAI
                } else if scenario == "expired-after-read" {
                    time += 60
                    XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
                    time -= 59
                } else {
                    let proof = try session.prepareProofAfterSeparateLocalShareAction()
                    XCTAssertEqual(String(decoding: proof, as: UTF8.self),
                        #"{"body":{"schema":1,"kind":"read-only-device-key-ack","requestId":"11111111-2222-4333-8444-555555555555","capability":"igentic.own_app.status.read","nonce":"22222222-3333-4444-8555-666666666666","observedAt":2000000000,"status":"key-holder-reports-read"},"signature":"27ecb277fcdcf0c6591740d8bb58f9885bdacc54e986748116f77842ddec3a6e"}"#)
                    XCTAssertFalse(String(decoding: proof, as: UTF8.self).contains("64 %"))
                    XCTAssertFalse(gate.snapshot().remoteActionExecuted)
                }
            }
            XCTAssertThrowsError(try session.readAfterSeparateLocalReviewAction())
            XCTAssertThrowsError(try session.prepareProofAfterSeparateLocalShareAction())
            XCTAssertEqual(reads, ["revoked", "local-only"].contains(scenario) ? 0 : 1)
        }
    }

    @MainActor
    func testLocalOnlyAndMissingEnrollmentDoNotContactTransport() async throws {
        let backend = EnrollmentMemoryBackend()
        let vault = AgentLoopDeviceEnrollmentVault(backend: backend, separateReplayKey: Self.key(96))
        var privacy = PrivacyMode.localOnly
        let session = AgentLoopEnrolledClaimSession(vault: vault, currentPrivacyMode: { privacy }) {
            _, _, _ in throw AgentLoopRelayClaimError.transportUncertain
        }
        do {
            _ = try await session.claimAfterLocalAction(port: 12345)
            XCTFail("Local Only was not blocked")
        } catch {
            XCTAssertEqual(error as? AgentLoopEnrolledClaimSession.Failure, .privacyDenied)
        }
        privacy = .trustedDevices
        do {
            _ = try await session.claimAfterLocalAction(port: 12345)
            XCTFail("Unenrolled external relay is not a trusted device")
        } catch {
            XCTAssertEqual(error as? AgentLoopEnrolledClaimSession.Failure, .privacyDenied)
        }
        privacy = .externalAI
        do {
            _ = try await session.claimAfterLocalAction(port: 12345)
            XCTFail("Missing enrollment was not blocked")
        } catch {
            XCTAssertEqual(error as? AgentLoopDeviceEnrollmentError, .notEnrolled)
        }
        XCTAssertEqual(backend.writes, 0)
    }
}
#endif
