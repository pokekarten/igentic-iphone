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
