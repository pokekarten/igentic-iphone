import Foundation
import AgentCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public enum AgentLoopStatusShortcutError: Error, Equatable {
    case busy
    case existingPendingTask
    case missingTask
    case invalidStoredTask
    case taskMismatch
    case expired
    case rejected
    case uncertainRead
    case alreadyFinished
}

/// One bounded on-device Shortcuts task. The task ID correlates responses;
/// it is NOT authorization, owner approval, or a cryptographic device receipt.
public enum AgentLoopStatusShortcutStage: String, Codable, Sendable {
    case awaitingStatus
    case readAttempted
    case awaitingFinish
    case finished
    case rejected
    case expired
}

private struct AgentLoopStatusShortcutJournal: Codable {
    let schema: Int
    let id: UUID
    let createdAt: Date
    var stage: AgentLoopStatusShortcutStage
}

private struct AgentLoopReviewedAction: Decodable {
    let schema: Int
    let taskId: String?
    let decision: String
    let nextAction: String
    let approved: Bool
    let executed: Bool
}

private struct AgentLoopStatusShortcutTicket: Encodable {
    let schema = 1
    let taskId: String
    let prompt = """
    Gib ausschließlich dieses JSON zurück, ohne Markdown oder weitere Schlüssel:
    {"action":"status.read"}
    Es wird damit nur ein begrenzter Status-Lesevorgang in der iGentic-App vorgeschlagen.
    Du kannst keine iPhone-Aktion freigeben oder ausführen.
    """
}

private struct AgentLoopStatusShortcutResult: Encodable {
    let schema = 1
    let taskId: String
    let stage: String
    let localStatusRead: Bool
    let remoteActionExecuted = false
    let ownerApproved = false
    let observation: String?
    let nextPrompt: String?
}

/// Real, cross-invocation Shortcuts handoff. Persistent state only; no model,
/// network, remote host or external tool invocation is performed in this type.
/// An OS-managed advisory file lock serializes participating App Intent
/// processes and releases automatically on process exit. Independently, the
/// durable readAttempted marker stops speculative re-execution after a crash.
@MainActor
public final class AgentLoopStatusShortcutStore {
    public static let ttl: TimeInterval = 300
    private let fileURL: URL
    private let clock: () -> Date
    private var lockURL: URL {
        fileURL.deletingLastPathComponent()
            .appendingPathComponent("shortcuts-status-loop-v1.lock")
    }

    public init(fileURL: URL = defaultFileURL(), clock: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.clock = clock
    }

    public static func defaultFileURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iGentic", isDirectory: true)
            .appendingPathComponent("shortcuts-status-loop-v1.json")
    }

    /// Only fixed non-personal instructions are returned for a Shortcut's
    /// optional "Use Model" action. The task ID is not inserted in the prompt.
    public func begin() throws -> String {
        try withClaim {
            let now = clock()
            guard now.timeIntervalSince1970.isFinite else {
                throw AgentLoopStatusShortcutError.invalidStoredTask
            }
            if let current = try load() {
                let age = now.timeIntervalSince(current.createdAt)
                guard age >= 0 else { throw AgentLoopStatusShortcutError.invalidStoredTask }
                if age < Self.ttl,
                   [.awaitingStatus, .readAttempted, .awaitingFinish].contains(current.stage) {
                    throw AgentLoopStatusShortcutError.existingPendingTask
                }
            }
            let journal = AgentLoopStatusShortcutJournal(
                schema: 1, id: UUID(), createdAt: now, stage: .awaitingStatus
            )
            try save(journal)
            return try encode(AgentLoopStatusShortcutTicket(
                taskId: journal.id.uuidString.lowercased()
            ))
        }
    }

    /// First model reply can request only status.read, the second only finish.
    /// The pending read is marked on disk BEFORE calling the status reader:
    /// a crash cannot cause a speculative automatic second read.
    public func advance(
        taskID: String, modelReply: String,
        statusReader: () -> AgentLoopLocalStatus
    ) throws -> String {
        try withClaim {
            guard var state = try load() else {
                throw AgentLoopStatusShortcutError.missingTask
            }
            guard taskID == state.id.uuidString.lowercased() else {
                throw AgentLoopStatusShortcutError.taskMismatch
            }
            let age = clock().timeIntervalSince(state.createdAt)
            guard age >= 0, age < Self.ttl else {
                state.stage = .expired
                try save(state)
                throw AgentLoopStatusShortcutError.expired
            }
            switch state.stage {
            case .readAttempted: throw AgentLoopStatusShortcutError.uncertainRead
            case .finished: throw AgentLoopStatusShortcutError.alreadyFinished
            case .rejected: throw AgentLoopStatusShortcutError.rejected
            case .expired: throw AgentLoopStatusShortcutError.expired
            case .awaitingStatus, .awaitingFinish: break
            }

            let checked = AgentLoopModelHandoff.review(
                taskID: taskID, modelReply: modelReply
            )
            guard let data = checked.data(using: .utf8),
                  let model = try? JSONDecoder().decode(AgentLoopReviewedAction.self, from: data),
                  model.schema == 1,
                  model.taskId == taskID,
                  !model.approved, !model.executed else {
                state.stage = .rejected
                try save(state)
                throw AgentLoopStatusShortcutError.rejected
            }

            if state.stage == .awaitingStatus {
                guard model.decision == "previewOnly",
                      model.nextAction == "status.read" else {
                    state.stage = .rejected
                    try save(state)
                    throw AgentLoopStatusShortcutError.rejected
                }
                let decision = PolicyEngine().decide(PolicyRequest(
                    privacyMode: .localOnly,
                    dataClassification: DataClassification(
                        level: .contextualPrivateData,
                        reason: "Owner-configured Shortcuts coarse local status read."
                    ),
                    actionRisk: .read,
                    requestedDelegationTarget: .localDevice
                ))
                guard decision.isAllowed && !decision.requiresApproval else {
                    state.stage = .rejected
                    try save(state)
                    throw AgentLoopStatusShortcutError.rejected
                }
                // Crash window: no reader is invoked again after this marker.
                state.stage = .readAttempted
                try save(state)
                let summary = statusReader().shortcutSummary
                state.stage = .awaitingFinish
                try save(state)
                return try encode(AgentLoopStatusShortcutResult(
                    taskId: taskID, stage: "awaitingFinish",
                    localStatusRead: true,
                    observation: summary,
                    nextPrompt: """
                    Antworte ausschließlich mit {"action":"finish"}.
                    Du kannst weder eine Aktion freigeben noch ihren Erfolg behaupten.
                    """
                ))
            }

            guard model.decision == "stopped",
                  model.nextAction == "none" else {
                state.stage = .rejected
                try save(state)
                throw AgentLoopStatusShortcutError.rejected
            }
            state.stage = .finished
            try save(state)
            return try encode(AgentLoopStatusShortcutResult(
                taskId: taskID, stage: "finished",
                localStatusRead: true,
                observation: nil, nextPrompt: nil
            ))
        }
    }

    /// Owner-visible, truthful state, including timeouts while idle. A read
    /// never creates a status observation or retries an uncertain read.
    public func stageForOwner() throws -> AgentLoopStatusShortcutStage? {
        try withClaim {
            guard var state = try load() else { return nil }
            if [.awaitingStatus, .readAttempted, .awaitingFinish].contains(state.stage) {
                let age = clock().timeIntervalSince(state.createdAt)
                if !age.isFinite || age < 0 || age >= Self.ttl {
                    state.stage = .expired
                    try save(state)
                }
            }
            return state.stage
        }
    }

    private func withClaim<T>(_ action: () throws -> T) throws -> T {
        let manager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        try manager.createDirectory(at: directory, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        // Keep the lock inode stable: deleting a lock file after unlocking
        // could let two processes lock different inodes under the same name.
        // O_NOFOLLOW rejects a substituted symbolic link.
        let fd = lockURL.path.withCString {
            open($0, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
        guard fd >= 0 else { throw AgentLoopStatusShortcutError.busy }
        defer { _ = close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw AgentLoopStatusShortcutError.busy
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try action()
    }

    private func load() throws -> AgentLoopStatusShortcutJournal? {
        #if canImport(Darwin) || canImport(Glibc)
        // The journal is read from a pinned inode. Path-based metadata checks
        // followed by Data(contentsOf:) allow substituted symlinks/hardlinks.
        let fd = fileURL.path.withCString {
            open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        }
        guard fd >= 0 else {
            if errno == ENOENT { return nil }
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        defer { _ = close(fd) }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0,
              (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              (metadata.st_mode & 0o077) == 0,
              metadata.st_uid == geteuid(),
              metadata.st_nlink == 1,
              metadata.st_size >= 0,
              metadata.st_size <= 4096 else {
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        let bytes: Data
        do {
            // Limit the read itself, not merely the bytes after allocation.
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            bytes = try handle.read(upToCount: 4097) ?? Data()
        } catch {
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        guard bytes.count <= 4096,
              bytes.count == Int(metadata.st_size),
              let payload = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(payload.keys) == Set(["schema", "id", "createdAt", "stage"]),
              let state = try? JSONDecoder().decode(AgentLoopStatusShortcutJournal.self, from: bytes),
              state.schema == 1,
              state.createdAt.timeIntervalSince1970.isFinite else {
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        return state
        #else
        throw AgentLoopStatusShortcutError.invalidStoredTask
        #endif
    }

    private func save(_ state: AgentLoopStatusShortcutJournal) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: fileURL.path),
           (try? manager.destinationOfSymbolicLink(atPath: fileURL.path)) != nil {
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let bytes = try encoder.encode(state)
        guard bytes.count <= 4096 else {
            throw AgentLoopStatusShortcutError.invalidStoredTask
        }
        try bytes.write(to: fileURL, options: .atomic)
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        #if os(iOS)
        try manager.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path
        )
        #endif
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
