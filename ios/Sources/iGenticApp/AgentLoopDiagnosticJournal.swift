import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// Metadata only. No observation, prompt, approval, credential or action payload.
struct AgentLoopDiagnosticCheckpoint: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable { case queued, running, completed, stopped }
    struct Ticket: Codable, Equatable, Sendable {
        let id: UUID
        let goal: AgentLoopDiagnosticGoal
    }
    let schema: Int
    let id: UUID
    let goal: AgentLoopDiagnosticGoal
    var steps: [AgentLoopDiagnosticStep]
    var stage: Stage
    // Optional field preserves canonical decoding of existing v1 journals.
    var pending: [Ticket]? = nil

    var queuedTickets: [Ticket] {
        (stage == .queued ? [Ticket(id: id, goal: goal)] : []) + (pending ?? [])
    }

    var valid: Bool {
        let reads = goal.requiredReads
        let waiting = pending ?? []
        guard queuedTickets.count <= 4, waiting.allSatisfy({ $0.id != id }),
              Set(waiting.map(\.id)).count == waiting.count,
              pending == nil || !waiting.isEmpty,
              stage != .queued || steps.isEmpty else { return false }
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
    enum Failure: Error, Equatable { case busy, invalid, recoveryRequired, staleRecovery, queueFull, queuePending, staleTicket }
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
        // The cooperating writer holds the journal lease. Prepare private
        // bytes and permissions before publication, on the same filesystem.
        // A failed preparation must not replace the previous checkpoint.
        // Power-loss durability and hostile parent directories are outside
        // this contract.
        let staging = url.deletingLastPathComponent().appendingPathComponent(
            ".igentic-journal-" + UUID().uuidString, isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: staging, withIntermediateDirectories: false,
                                    attributes: [.posixPermissions: 0o700])
        defer { try? manager.removeItem(at: staging) }
        let candidate = staging.appendingPathComponent("candidate")
        #if os(iOS)
        try data.write(to: candidate, options: [.withoutOverwriting, .completeFileProtection])
        #else
        try data.write(to: candidate, options: .withoutOverwriting)
        #endif
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: candidate.path)
        guard rename(candidate.path, url.path) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        // No throwing operation after successful publication.
    }

    /// A running record returned here is necessarily abandoned by the
    /// cooperating writer, since we acquired its exclusive lease.
    func snapshot() throws -> AgentLoopDiagnosticCheckpoint? {
        let fd = try claim()
        defer { _ = close(fd) }
        return try load()
    }

    /// Queue a fixed read-only goal. Never launches a model or tool.
    @discardableResult
    func enqueue(goal: AgentLoopDiagnosticGoal) throws -> UUID {
        let fd = try claim()
        defer { _ = close(fd) }
        let ticket = AgentLoopDiagnosticCheckpoint.Ticket(id: UUID(), goal: goal)
        if var state = try load() {
            guard state.queuedTickets.count < 4 else { throw Failure.queueFull }
            if state.stage == .running { throw Failure.recoveryRequired }
            if state.stage == .queued || !state.queuedTickets.isEmpty {
                state.pending = (state.pending ?? []) + [ticket]
                try save(state)
                return ticket.id
            }
        }
        try save(.init(schema: 1, id: ticket.id, goal: goal, steps: [], stage: .queued))
        return ticket.id
    }

    /// Remove only a matching waiting task. No active or completed attempt
    /// can be cancelled or rewritten by a stale queue selection.
    func removeQueued(id: UUID) throws {
        let fd = try claim()
        defer { _ = close(fd) }
        guard var state = try load(), state.stage != .running,
              state.queuedTickets.contains(where: { $0.id == id }) else { throw Failure.staleTicket }
        if state.stage == .queued && state.id == id {
            let remaining = state.pending ?? []
            if let first = remaining.first {
                let rest = Array(remaining.dropFirst())
                state = .init(schema: 1, id: first.id, goal: first.goal, steps: [], stage: .queued,
                              pending: rest.isEmpty ? nil : rest)
            } else {
                state.stage = .stopped
            }
        } else {
            let remaining = (state.pending ?? []).filter { $0.id != id }
            state.pending = remaining.isEmpty ? nil : remaining
        }
        try save(state)
    }

    func run(goal: AgentLoopDiagnosticGoal, restartID: UUID? = nil, queuedID: UUID? = nil,
             operation: @MainActor ((@MainActor ([AgentLoopDiagnosticStep]) throws -> Void)) async -> AgentLoopDiagnosticReport
    ) async throws -> AgentLoopDiagnosticReport {
        let fd = try claim()
        defer { _ = close(fd) }
        let previous = try load()
        guard restartID == nil || queuedID == nil else { throw Failure.invalid }
        var pending = previous?.pending
        var attemptID = UUID()
        if let restartID {
            guard let previous, previous.id == restartID, previous.stage == .running,
                  previous.goal == goal else { throw Failure.staleRecovery }
        } else if let queuedID {
            guard let previous, previous.stage != .running,
                  let next = previous.queuedTickets.first,
                  next.id == queuedID, next.goal == goal else { throw Failure.staleTicket }
            attemptID = next.id
            let remaining = Array(previous.queuedTickets.dropFirst())
            pending = remaining.isEmpty ? nil : remaining
        } else {
            if previous?.stage == .running { throw Failure.recoveryRequired }
            if !(previous?.queuedTickets.isEmpty ?? true) { throw Failure.queuePending }
        }
        try Task.checkCancellation()
        var state = AgentLoopDiagnosticCheckpoint(schema: 1, id: attemptID, goal: goal,
                                                  steps: [], stage: .running, pending: pending)
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
        // The operation is trusted local code, but its terminal receipt must
        // still agree with durable progress and the bounded execution contract.
        guard report.steps == state.steps,
              (0...(goal.requiredReads.count + 1)).contains(report.modelTurns) else { throw Failure.invalid }
        if report.outcome == .completed {
            guard !Task.isCancelled, state.steps.last == .finish,
                  let result = report.localReport, !result.isEmpty,
                  report.modelTurns == 0 || report.modelTurns == state.steps.count else { throw Failure.invalid }
            state.stage = .completed
        } else {
            guard report.localReport == nil, !state.steps.contains(.finish) else { throw Failure.invalid }
            state.stage = .stopped
        }
        try save(state)
        return report
    }
}
