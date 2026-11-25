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
