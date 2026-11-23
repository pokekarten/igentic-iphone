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

    /// Atomically reserves a single task ID before any possible dispatch.
    /// A crash after file creation is treated as "possibly already handled":
    /// the same ID cannot be reserved again, even in a new app process.
    ///
    /// A successful return ONLY means a local marker was persisted. It never
    /// sets replayAdmitted, ownerApproved or actionExecuted in the preview.
    public func reserveVerifiedPreview(
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
