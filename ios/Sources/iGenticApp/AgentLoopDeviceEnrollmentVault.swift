import Foundation
#if canImport(Security) && canImport(Darwin)
import Security

enum AgentLoopDeviceEnrollmentError: Error, Equatable {
    case notEnrolled, alreadyEnrolled, revoked, invalidEnrollment, unavailable
}

/// Local, owner-provisioned credential bundle. Not an account identity,
/// attestation, or permission to perform a task. Never expose to models.
struct AgentLoopDeviceEnrollment: Equatable, Sendable {
    let id: UUID
    let deviceAccessKey: Data
    let proposalKey: Data
    let receiptKey: Data

    func valid(separateReplayKey: Data) -> Bool {
        let keys = [deviceAccessKey, proposalKey, receiptKey, separateReplayKey]
        return keys.allSatisfy { $0.count == 32 && Set($0).count > 1 }
            && Set(keys).count == keys.count
    }
}

protocol AgentLoopDeviceEnrollmentBackend {
    func load() throws -> Data?
    func createOnce(_ bytes: Data) throws -> Bool
    /// Compare then atomically replace under single-process vault serialization.
    func revokeExisting(expected: Data, replacement: Data) throws -> Bool
}

/// Single owner installation, serialized by the main actor. A revoked
/// record is a permanent tombstone; no delete, auto-enroll, or key rotation.
@MainActor
struct AgentLoopDeviceEnrollmentVault {
    private let backend: any AgentLoopDeviceEnrollmentBackend
    private let separateReplayKey: Data

    init(backend: any AgentLoopDeviceEnrollmentBackend, separateReplayKey: Data) {
        self.backend = backend
        self.separateReplayKey = separateReplayKey
    }

    private func encode(_ value: AgentLoopDeviceEnrollment) throws -> Data {
        guard value.valid(separateReplayKey: separateReplayKey) else {
            throw AgentLoopDeviceEnrollmentError.invalidEnrollment
        }
        return Data([1]) + Data(value.id.uuidString.lowercased().utf8)
            + value.deviceAccessKey + value.proposalKey + value.receiptKey
    }

    private func decode(_ bytes: Data) throws -> AgentLoopDeviceEnrollment {
        if bytes == Data([2]) { throw AgentLoopDeviceEnrollmentError.revoked }
        guard bytes.count == 133, bytes.first == 1,
              let text = String(data: bytes.subdata(in: 1..<37), encoding: .utf8),
              let id = UUID(uuidString: text), id.uuidString.lowercased() == text else {
            throw AgentLoopDeviceEnrollmentError.unavailable
        }
        let value = AgentLoopDeviceEnrollment(id: id,
            deviceAccessKey: bytes.subdata(in: 37..<69),
            proposalKey: bytes.subdata(in: 69..<101),
            receiptKey: bytes.subdata(in: 101..<133))
        guard value.valid(separateReplayKey: separateReplayKey) else {
            throw AgentLoopDeviceEnrollmentError.unavailable
        }
        return value
    }

    func loadExisting() throws -> AgentLoopDeviceEnrollment {
        guard let bytes = try backend.load() else {
            throw AgentLoopDeviceEnrollmentError.notEnrolled
        }
        return try decode(bytes)
    }

    /// Import only from an explicit trusted local owner setup path.
    /// An absent vault never enrolls itself during a claim or read.
    func enrollExplicitly(_ value: AgentLoopDeviceEnrollment) throws {
        if let old = try backend.load() {
            _ = try decode(old)
            throw AgentLoopDeviceEnrollmentError.alreadyEnrolled
        }
        let bytes = try encode(value)
        guard try backend.createOnce(bytes) else {
            throw AgentLoopDeviceEnrollmentError.alreadyEnrolled
        }
        guard try loadExisting() == value else {
            throw AgentLoopDeviceEnrollmentError.unavailable
        }
    }

    func revokeExplicitly(id: UUID) throws {
        guard let old = try backend.load() else {
            throw AgentLoopDeviceEnrollmentError.notEnrolled
        }
        guard try decode(old).id == id else {
            throw AgentLoopDeviceEnrollmentError.invalidEnrollment
        }
        guard try backend.revokeExisting(expected: old, replacement: Data([2])),
              try backend.load() == Data([2]) else {
            throw AgentLoopDeviceEnrollmentError.unavailable
        }
    }
}

#if os(iOS)
/// App-private, non-synchronizing, unlocked-device-only Keychain item.
/// Only this main-actor vault is intended to write it. No shared access group.
/// SecItemUpdate is atomic, but Keychain has no compare-and-swap API;
/// the read/compare/update sequence relies on single-process ownership.
private struct NativeDeviceEnrollmentKeychain: AgentLoopDeviceEnrollmentBackend {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "de.bos.igentic.device-relay-enrollment-v1",
         kSecAttrAccount as String: "owner-device-bundle",
         kSecAttrSynchronizable as String: kCFBooleanFalse as Any]
    }

    func load() throws -> Data? {
        var q = query
        q[kSecReturnData as String] = kCFBooleanTrue
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        switch SecItemCopyMatching(q as CFDictionary, &item) {
        case errSecItemNotFound: return nil
        case errSecSuccess:
            guard let data = item as? Data else { throw AgentLoopDeviceEnrollmentError.unavailable }
            return data
        default: throw AgentLoopDeviceEnrollmentError.unavailable
        }
    }

    func createOnce(_ bytes: Data) throws -> Bool {
        var q = query
        q[kSecValueData as String] = bytes
        q[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        switch SecItemAdd(q as CFDictionary, nil) {
        case errSecSuccess: return true
        case errSecDuplicateItem: return false
        default: throw AgentLoopDeviceEnrollmentError.unavailable
        }
    }

    func revokeExisting(expected: Data, replacement: Data) throws -> Bool {
        guard try load() == expected else { return false }
        let attrs = [kSecValueData as String: replacement]
        switch SecItemUpdate(query as CFDictionary, attrs as CFDictionary) {
        case errSecSuccess: return true
        case errSecItemNotFound: return false
        default: throw AgentLoopDeviceEnrollmentError.unavailable
        }
    }
}

extension AgentLoopDeviceEnrollmentVault {
    /// No implicit replay-key enrollment. This is not wired to UI/network yet.
    static func openNative() throws -> Self {
        Self(backend: NativeDeviceEnrollmentKeychain(),
             separateReplayKey: try AgentLoopReplayKeyVault.loadExisting())
    }
}
#endif
#endif
