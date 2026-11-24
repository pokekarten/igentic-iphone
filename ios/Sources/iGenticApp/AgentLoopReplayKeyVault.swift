import Foundation

#if canImport(Security) && canImport(Darwin)
import Darwin
import Security

/// Fail-closed storage for the *local replay-marker HMAC key* only.
/// This is NOT a relay signing key, remote credential or execution identity.
/// The caller must explicitly opt into enrollment; merely inspecting a
/// signed task must never generate, rotate or recreate this key.
public enum AgentLoopReplayKeyVaultError: Error, Equatable {
    case notEnrolled
    case alreadyEnrolled
    case unsafeDirectory
    case unavailable
}

protocol AgentLoopReplayKeyBackend {
    /// nil only when an item is definitely absent, not on storage errors.
    func load() throws -> Data?
    /// Atomically creates once. false means an existing item won the race.
    func createOnce(_ key: Data) throws -> Bool
}

/// This is separate from CellularCompanion credentials and all relay keys.
/// The Keychain item is non-synchronizing and usable only while unlocked.
private struct SystemReplayKeychainBackend: AgentLoopReplayKeyBackend {
    private let service = "de.bos.igentic.owner-replay-key-v1"
    private let account = "local-one-shot-markers"

    private var lookup: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    func load() throws -> Data? {
        var query = lookup
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess:
            guard let key = item as? Data else {
                throw AgentLoopReplayKeyVaultError.unavailable
            }
            return key
        case errSecItemNotFound:
            return nil
        default:
            throw AgentLoopReplayKeyVaultError.unavailable
        }
    }

    func createOnce(_ key: Data) throws -> Bool {
        var item = lookup
        item[kSecValueData as String] = key
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        switch SecItemAdd(item as CFDictionary, nil) {
        case errSecSuccess:
            return true
        case errSecDuplicateItem:
            return false
        default:
            throw AgentLoopReplayKeyVaultError.unavailable
        }
    }
}

enum AgentLoopReplayKeyEnrollment {
    /// A marker directory with previous tasks or a key binding must never be
    /// reprovisioned from an empty Keychain; that would erase replay history.
    static func validateFreshPrivateDirectory(_ url: URL) throws {
        guard url.isFileURL, url.path.hasPrefix("/"),
              url.standardizedFileURL.path == url.path else {
            throw AgentLoopReplayKeyVaultError.unsafeDirectory
        }
        let fd = open(url.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard fd >= 0 else { throw AgentLoopReplayKeyVaultError.unsafeDirectory }
        defer { _ = close(fd) }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0,
              (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
              (metadata.st_mode & 0o077) == 0,
              metadata.st_uid == geteuid() else {
            throw AgentLoopReplayKeyVaultError.unsafeDirectory
        }
        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(atPath: url.path)
        } catch {
            throw AgentLoopReplayKeyVaultError.unsafeDirectory
        }
        // Verify that the path still names the opened directory after the
        // directory scan. No global rollback defense is claimed here.
        var current = stat()
        guard lstat(url.path, &current) == 0,
              current.st_dev == metadata.st_dev,
              current.st_ino == metadata.st_ino,
              entries.isEmpty else {
            throw AgentLoopReplayKeyVaultError.unsafeDirectory
        }
    }

    static func loadExisting(backend: any AgentLoopReplayKeyBackend) throws -> Data {
        guard let secret = try backend.load() else {
            throw AgentLoopReplayKeyVaultError.notEnrolled
        }
        guard secret.count == 32, Set(secret).count > 1 else {
            throw AgentLoopReplayKeyVaultError.unavailable
        }
        return secret
    }

    /// Explicit human-initiated enrollment in an already existing empty,
    /// owner-private replay directory. Never overwrite/recover automatically.
    static func enrollExplicitly(
        directory: URL,
        backend: any AgentLoopReplayKeyBackend,
        randomKey: () throws -> Data
    ) throws -> Data {
        if try backend.load() != nil {
            throw AgentLoopReplayKeyVaultError.alreadyEnrolled
        }
        try validateFreshPrivateDirectory(directory)
        let key = try randomKey()
        guard key.count == 32, Set(key).count > 1 else {
            throw AgentLoopReplayKeyVaultError.unavailable
        }
        // SecItemAdd provides the single-winner race protection. There is no
        // SecItemUpdate, delete, reset or silent key rotation in this API.
        guard try backend.createOnce(key) else {
            throw AgentLoopReplayKeyVaultError.alreadyEnrolled
        }
        let persisted = try loadExisting(backend: backend)
        guard persisted == key else {
            throw AgentLoopReplayKeyVaultError.unavailable
        }
        return persisted
    }

    static func openExistingJournal(
        directory: URL,
        backend: any AgentLoopReplayKeyBackend
    ) throws -> AgentLoopLocalReplayJournal {
        let key = try loadExisting(backend: backend)
        return try AgentLoopLocalReplayJournal(directory: directory, key: key)
    }
}

public enum AgentLoopReplayKeyVault {
    /// Reads an enrolled, protected local key. Absent and corrupt are distinct
    /// failures. No key is created or replaced on a normal task.
    public static func loadExisting() throws -> Data {
        try AgentLoopReplayKeyEnrollment.loadExisting(
            backend: SystemReplayKeychainBackend()
        )
    }

    /// Fails closed if the protected local replay key is missing, corrupt or
    /// the directory cannot be verified. No silent enrollment on task receipt.
    /// Native policy and owner review remain mandatory independent gates.
    public static func openExistingJournal(
        directory: URL
    ) throws -> AgentLoopLocalReplayJournal {
        try AgentLoopReplayKeyEnrollment.openExistingJournal(
            directory: directory,
            backend: SystemReplayKeychainBackend()
        )
    }

    /// To be called only from a future explicit, local owner setup UI.
    /// The caller must already have created its private 0700 replay directory.
    /// This API does not provision an owner relay, send any task or act on iOS.
    public static func enrollExplicitly(directory: URL) throws -> Data {
        try AgentLoopReplayKeyEnrollment.enrollExplicitly(
            directory: directory,
            backend: SystemReplayKeychainBackend()
        ) {
            var bytes = [UInt8](repeating: 0, count: 32)
            let rc = bytes.withUnsafeMutableBytes {
                SecRandomCopyBytes(kSecRandomDefault, $0.count, $0.baseAddress!)
            }
            guard rc == errSecSuccess else {
                throw AgentLoopReplayKeyVaultError.unavailable
            }
            return Data(bytes)
        }
    }
}
#endif
