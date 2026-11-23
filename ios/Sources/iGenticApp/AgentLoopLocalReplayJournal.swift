import Foundation

#if canImport(CryptoKit) && canImport(Darwin)
import CryptoKit
import Darwin

/// Durable, local one-shot marker for a previously verified owner-task preview.
///
/// This is not device authorization, an execution receipt, transport, or a
/// device-identity proof. The caller must separately verify the signed task,
/// native policy and any owner consent before an action can run.
public enum AgentLoopLocalReplayJournalError: Error, Equatable {
    case unavailable
    case alreadyRecorded
    case invalidPreview
}

public final class AgentLoopLocalReplayJournal {
    private let directory: URL
    private let key: Data
    private let device: dev_t
    private let inode: ino_t
    private static let domain = "igentic-ios-local-replay-marker-v1\n"

    /// The private directory must be explicitly provisioned by the owner app.
    /// Do not silently create, reset or rotate it on a verification failure.
    public init(directory: URL, key: Data) throws {
        guard directory.isFileURL,
              directory.path.hasPrefix("/"),
              directory.standardizedFileURL.path == directory.path,
              key.count == 32, Set(key).count > 1 else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        let descriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard descriptor >= 0 else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        defer { _ = close(descriptor) }
        var metadata = stat()
        guard fstat(descriptor, &metadata) == 0,
              (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
              (metadata.st_mode & 0o077) == 0,
              metadata.st_uid == geteuid() else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        self.directory = directory
        self.key = Data(key)
        self.device = metadata.st_dev
        self.inode = metadata.st_ino
    }

    /// Inspect exact signed relay bytes and make a durable local one-shot
    /// reservation as one fail-closed operation. This is the public entry
    /// point for future read-only relay consumers; callers cannot pass an
    /// arbitrary preview here or skip the cryptographic signature check.
    ///
    /// The reservation consumes the request ID even if a caller crashes
    /// afterwards. Neither its success nor the returned preview authorizes
    /// an iPhone action, proves owner consent, or generates a device receipt.
    @discardableResult
    public func inspectAndReserveCanonicalProposal(
        _ bytes: Data,
        relayKey: Data,
        nowSeconds: Int
    ) throws -> AgentLoopRemoteTaskPreview {
        guard let preview = AgentLoopRemoteTaskVerifier.inspectCanonicalProposal(
            bytes, relayKey: relayKey, nowSeconds: nowSeconds
        ) else {
            throw AgentLoopLocalReplayJournalError.invalidPreview
        }
        try reserveVerifiedPreview(preview, nowSeconds: nowSeconds)
        return preview
    }

    /// Atomically reserves a single task ID before any possible dispatch.
    /// A crash after file creation is treated as "possibly already handled":
    /// the same ID cannot be reserved again, even in a new app process.
    ///
    /// A successful return ONLY means a local marker was persisted. It never
    /// sets replayAdmitted, ownerApproved or actionExecuted in the preview.
    func reserveVerifiedPreview(
        _ preview: AgentLoopRemoteTaskPreview,
        nowSeconds: Int
    ) throws {
        guard nowSeconds >= 0, preview.expiresAt > nowSeconds,
              preview.capability == "igentic.own_app.status.read",
              let id = UUID(uuidString: preview.requestID),
              id.uuidString.lowercased() == preview.requestID else {
            throw AgentLoopLocalReplayJournalError.invalidPreview
        }
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data((Self.domain + preview.requestID).utf8),
            using: SymmetricKey(data: key)
        ).map { String(format: "%02x", $0) }.joined()
        let name = digest + ".attempt"

        // openat pins the validated directory, avoiding path replacement
        // between checking it and atomically creating the marker.
        let directoryFD = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW)
        guard directoryFD >= 0 else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        defer { _ = close(directoryFD) }
        var metadata = stat()
        guard fstat(directoryFD, &metadata) == 0,
              metadata.st_dev == device, metadata.st_ino == inode,
              (metadata.st_mode & 0o077) == 0,
              metadata.st_uid == geteuid() else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }

        // A new local HMAC key would otherwise change every filename and
        // silently re-admit already consumed requests. Bind the store to a
        // stable key, never silently reprovision it after a crash or reset.
        let bindingDigest = HMAC<SHA256>.authenticationCode(
            for: Data("igentic-ios-local-replay-key-binding-v1\n".utf8),
            using: SymmetricKey(data: key)
        ).map { String(format: "%02x", $0) }.joined()
        let binding = ".key." + bindingDigest
        let entries: [String]
        do {
            entries = try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            )
        } catch {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        let bindings = entries.filter { $0.hasPrefix(".key.") }
        guard bindings.isEmpty || bindings == [binding] else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        if bindings.isEmpty {
            // Existing attempt markers without a binding cannot be safely
            // assigned to this key. Draft-format migration must be explicit.
            guard entries.isEmpty else {
                throw AgentLoopLocalReplayJournalError.unavailable
            }
            let bindingFD = openat(
                directoryFD, binding, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW,
                0o600
            )
            if bindingFD < 0 && errno != EEXIST {
                throw AgentLoopLocalReplayJournalError.unavailable
            }
            if bindingFD >= 0 {
                let flushed = fsync(bindingFD) == 0
                let closed = close(bindingFD) == 0
                guard flushed, closed, fsync(directoryFD) == 0 else {
                    throw AgentLoopLocalReplayJournalError.unavailable
                }
            }
        }
        // A concurrent process may have provisioned a different binding
        // after our first scan. Never send a payload with two key identities.
        let refreshed: [String]
        do {
            refreshed = try FileManager.default.contentsOfDirectory(
                atPath: directory.path
            )
        } catch {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        guard refreshed.filter({ $0.hasPrefix(".key.") }) == [binding] else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        var bindingMetadata = stat()
        guard fstatat(directoryFD, binding, &bindingMetadata, AT_SYMLINK_NOFOLLOW) == 0,
              (bindingMetadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              (bindingMetadata.st_mode & 0o077) == 0,
              bindingMetadata.st_uid == geteuid(),
              bindingMetadata.st_size == 0 else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }

        let fileFD = openat(
            directoryFD, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600
        )
        guard fileFD >= 0 else {
            if errno == EEXIST {
                throw AgentLoopLocalReplayJournalError.alreadyRecorded
            }
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        defer { _ = close(fileFD) }

        // Crash durability: persist the marker inode and directory entry
        // before the caller can receive a successful reservation.
        guard fsync(fileFD) == 0, fsync(directoryFD) == 0 else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
        var current = stat()
        guard lstat(directory.path, &current) == 0,
              current.st_dev == device, current.st_ino == inode else {
            throw AgentLoopLocalReplayJournalError.unavailable
        }
    }
}
#endif
