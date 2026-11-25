import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Metadata only. No observation, prompt, approval, credential or action payload.
struct AgentLoopDiagnosticCheckpoint: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable { case running, completed, stopped }
    let schema: Int
    let id: UUID
    let goal: AgentLoopDiagnosticGoal
    var steps: [AgentLoopDiagnosticStep]
    var stage: Stage

    var valid: Bool {
        let reads = goal.requiredReads
        guard schema == 1, Set(steps).count == steps.count,
              steps.allSatisfy({ reads.contains($0) || $0 == .finish }) else { return false }
        if steps.contains(.finish) {
            guard steps.last == .finish, Set(steps.dropLast()) == Set(reads) else { return false }
        }
        return stage != .completed || steps.last == .finish
    }
}

/// A single local read-only attempt, held under an advisory lock across model
/// awaits. A surviving running record with no lock means interrupted, NOT
/// completed. Recovery is a fresh, explicitly requested attempt; no stale
/// observation is reused and this type grants no write or remote authority.
@MainActor
final class AgentLoopDiagnosticJournal {
    enum Failure: Error, Equatable { case busy, invalid, recoveryRequired, staleRecovery }
    private let url: URL
    init(url: URL = defaultURL()) { self.url = url }
    static func defaultURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("iGentic", isDirectory: true)
            .appendingPathComponent("native-diagnostic-journal-v1.json")
    }
    private func claim() throws -> Int32 {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let fd = open(url.appendingPathExtension("lock").path, O_RDWR | O_CREAT | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK, 0o600)
        guard fd >= 0 else { throw Failure.busy }
        var meta = stat()
        guard fstat(fd, &meta) == 0, meta.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              meta.st_uid == geteuid(), meta.st_nlink == 1, meta.st_mode & 0o077 == 0,
              flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            _ = close(fd); throw Failure.busy
        }
        return fd
    }
    private func encode(_ state: AgentLoopDiagnosticCheckpoint) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(state)
    }
    private func load() throws -> AgentLoopDiagnosticCheckpoint? {
        let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard fd >= 0 else {
            if errno == ENOENT { return nil }
            throw Failure.invalid
        }
        defer { _ = close(fd) }
        var meta = stat()
        guard fstat(fd, &meta) == 0, meta.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              meta.st_uid == geteuid(), meta.st_nlink == 1, meta.st_mode & 0o077 == 0,
              (1...2048).contains(meta.st_size) else { throw Failure.invalid }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let data = try handle.read(upToCount: 2049) ?? Data()
        guard data.count == Int(meta.st_size),
              let state = try? JSONDecoder().decode(AgentLoopDiagnosticCheckpoint.self, from: data),
              state.valid, try encode(state) == data else { throw Failure.invalid }
        return state
    }
    private func save(_ state: AgentLoopDiagnosticCheckpoint) throws {
        guard state.valid else { throw Failure.invalid }
        let data = try encode(state)
        guard data.count <= 2048 else { throw Failure.invalid }
        // No private payload is persisted. Atomic replacement plus strict
        // mode checks on load; filesystem rollback is outside this contract.
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    /// A running record returned here is necessarily abandoned by the
    /// cooperating writer, since we acquired its exclusive lease.
    func snapshot() throws -> AgentLoopDiagnosticCheckpoint? {
        let fd = try claim()
        defer { _ = close(fd) }
        return try load()
    }

    func run(goal: AgentLoopDiagnosticGoal, restartID: UUID? = nil,
             operation: @MainActor ((@MainActor ([AgentLoopDiagnosticStep]) throws -> Void)) async -> AgentLoopDiagnosticReport
    ) async throws -> AgentLoopDiagnosticReport {
        let fd = try claim()
        defer { _ = close(fd) }
        let previous = try load()
        if let restartID {
            guard let previous, previous.id == restartID, previous.stage == .running,
                  previous.goal == goal else { throw Failure.staleRecovery }
        } else if previous?.stage == .running { throw Failure.recoveryRequired }
        try Task.checkCancellation()
        var state = AgentLoopDiagnosticCheckpoint(schema: 1, id: UUID(), goal: goal, steps: [], stage: .running)
        try save(state)
        var acceptingProgress = true
        let report = await operation { steps in
            guard acceptingProgress, steps.count == state.steps.count + 1,
                  Array(steps.dropLast()) == state.steps else { throw Failure.invalid }
            var next = state
            next.steps = steps
            try self.save(next)
            state = next
        }
        acceptingProgress = false
        guard report.steps == state.steps else { throw Failure.invalid }
        state.stage = report.outcome == .completed ? .completed : .stopped
        try save(state)
        return report
    }
}
