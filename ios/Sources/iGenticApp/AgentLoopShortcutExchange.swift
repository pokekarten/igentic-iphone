import Foundation
import AgentCore
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A deliberately small, iPhone-local inbox for one sequential Shortcuts AI
/// exchange. It has no network client, model execution or capability dispatcher.
public struct AgentLoopExchange: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let createdAt: Date
    public let task: String
    public var answer: String?
    public var answeredAt: Date?

    public var isAnswered: Bool { answer != nil }
}

public enum AgentLoopExchangeError: Error, Equatable {
    case invalidTask
    case sensitiveTask
    case exchangeAlreadyExists
    case noPendingExchange
    case expired
    case invalidAnswer
    case alreadyAnswered
    case invalidStoredExchange
    case mismatchedTaskID
    case exchangeBusy
}

extension AgentLoopExchangeError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidTask:
            return "Auftrag fehlt, ist zu lang oder enthält ungültige Zeichen."
        case .sensitiveTask:
            return "Automatische KI-Übergabe wegen erkennbarer sensibler Angaben blockiert."
        case .exchangeAlreadyExists:
            return "Zuerst die vorhandene KI-Aufgabe in iGentic prüfen und löschen."
        case .noPendingExchange:
            return "Kein vorher vorbereiteter KI-Auftrag vorhanden."
        case .expired:
            return "Die KI-Aufgabe ist abgelaufen. Bitte lokal löschen und neu beginnen."
        case .invalidAnswer:
            return "KI-Antwort leer, zu lang oder ungültig."
        case .alreadyAnswered:
            return "Die KI-Antwort wurde bereits übernommen. Kein zweiter Aufruf möglich."
        case .invalidStoredExchange:
            return "Gespeicherter KI-Auftrag ist beschädigt. Keine Aktion ausgeführt."
        case .mismatchedTaskID:
            return "KI-Antwort gehört nicht zum aktuell offenen Auftrag. Nichts übernommen."
        case .exchangeBusy:
            return "Eine andere iGentic-Kurzbefehle-Aktion bearbeitet den Auftrag. Bitte erneut versuchen."
        }
    }
}

@MainActor
public final class AgentLoopShortcutExchangeStore {
    public static let maximumTaskBytes = 2048
    public static let maximumAnswerBytes = 8192
    public static let expiration: TimeInterval = 30 * 60
    private let fileURL: URL
    private let clock: () -> Date
    // Cross-process file locks protect the disk state; the main-actor guard
    // also prevents a synchronous callback re-entering a mutation locally.
    private static var activeMutationPaths = Set<String>()

    public init(fileURL: URL = defaultFileURL(), clock: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.clock = clock
    }

    public static func defaultFileURL() -> URL {
        let library = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        return library.appendingPathComponent("iGentic", isDirectory: true)
            .appendingPathComponent("shortcut-ai-exchange-v1.json")
    }

    /// A write is one transaction across the app and its App Intents
    /// processes. A persistent, private lock file is intentionally never
    /// unlinked: removing it while another process holds its inode would
    /// create two independent locks. OS flock releases on process death.
    private func withExclusiveMutation<T>(_ body: () throws -> T) throws -> T {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let lockPath = fileURL.appendingPathExtension("lock").standardizedFileURL.path
        guard !Self.activeMutationPaths.contains(lockPath) else {
            throw AgentLoopExchangeError.exchangeBusy
        }
        Self.activeMutationPaths.insert(lockPath)
        defer { Self.activeMutationPaths.remove(lockPath) }

        #if canImport(Darwin) || canImport(Glibc)
        let fd = open(lockPath, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw AgentLoopExchangeError.exchangeBusy }
        defer { _ = close(fd) }
        var metadata = stat()
        guard fstat(fd, &metadata) == 0,
              (metadata.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              (metadata.st_mode & 0o077) == 0,
              metadata.st_uid == geteuid(),
              metadata.st_nlink == 1 else {
            throw AgentLoopExchangeError.exchangeBusy
        }
        // Refuse contention rather than hanging Siri/Shortcuts on a lock.
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw AgentLoopExchangeError.exchangeBusy
        }
        defer { _ = flock(fd, LOCK_UN) }
        return try body()
        #else
        throw AgentLoopExchangeError.exchangeBusy
        #endif
    }

    private func createPendingExchange(task: String) throws -> AgentLoopExchange {
        let trimmed = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 512,
              trimmed.utf8.count <= Self.maximumTaskBytes, !containsUnsafeControl(trimmed)
        else { throw AgentLoopExchangeError.invalidTask }

        // This must also be checked before acquiring any disk lock.
        guard !SensitiveDataDetector().detect(in: trimmed).hasFindings else {
            throw AgentLoopExchangeError.sensitiveTask
        }

        return try withExclusiveMutation {
            if try snapshot() != nil {
                throw AgentLoopExchangeError.exchangeAlreadyExists
            }
            let exchange = AgentLoopExchange(
                id: UUID(), createdAt: clock(), task: trimmed,
                answer: nil, answeredAt: nil
            )
            try save(exchange)
            return exchange
        }
    }

    /// Returns text for Shortcuts' built-in "Use Model" action; the caller
    /// chooses Apple On-Device, Apple Cloud, or the ChatGPT extension.
    /// The raw instruction is never sent by this method.
    @discardableResult
    public func begin(task: String) throws -> String {
        Self.modelPrompt(for: try createPendingExchange(task: task).task)
    }

    /// Allows the iGentic app to prepare a task locally and launch the fixed
    /// owner-installed Shortcut with no user text or token embedded in its URL.
    public func pendingPrompt() throws -> String {
        guard let state = try snapshot() else {
            throw AgentLoopExchangeError.noPendingExchange
        }
        let age = clock().timeIntervalSince(state.createdAt)
        guard age >= 0, age <= Self.expiration else {
            throw AgentLoopExchangeError.expired
        }
        guard state.answer == nil else {
            throw AgentLoopExchangeError.alreadyAnswered
        }
        return Self.modelPrompt(for: state.task)
    }

    /// Returns the correlation ID as a separate Shortcuts variable, never
    /// embedded in the ChatGPT prompt or a launch URL. This is not an auth token.
    public func pendingTaskID() throws -> String {
        guard let state = try snapshot() else {
            throw AgentLoopExchangeError.noPendingExchange
        }
        let age = clock().timeIntervalSince(state.createdAt)
        guard age >= 0, age <= Self.expiration else {
            throw AgentLoopExchangeError.expired
        }
        guard state.answer == nil else {
            throw AgentLoopExchangeError.alreadyAnswered
        }
        return state.id.uuidString.lowercased()
    }

    /// Structured handoff for Shortcuts: save taskId separately and send only
    /// prompt to Apple's "Use Model" action. The ID is correlation, not auth.
    private struct ShortcutTicket: Encodable {
        let schema = 1
        let taskId: String
        let prompt: String
    }

    public func beginTicket(task: String) throws -> String {
        // The ticket must refer to the very task we just committed. Do not
        // re-read a later exchange created by another Shortcuts process.
        try encodeTicket(for: createPendingExchange(task: task))
    }

    public func pendingTicket() throws -> String {
        guard let current = try snapshot() else {
            throw AgentLoopExchangeError.noPendingExchange
        }
        let age = clock().timeIntervalSince(current.createdAt)
        guard age >= 0, age <= Self.expiration else {
            throw AgentLoopExchangeError.expired
        }
        guard current.answer == nil else {
            throw AgentLoopExchangeError.alreadyAnswered
        }
        return try encodeTicket(for: current)
    }

    private func encodeTicket(for current: AgentLoopExchange) throws -> String {
        let ticket = ShortcutTicket(
            taskId: current.id.uuidString.lowercased(),
            prompt: Self.modelPrompt(for: current.task)
        )
        // Stable key order prevents nondeterministic Shortcuts ticket text
        // when the same pending task is read in successive model turns.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let serialized = String(data: try encoder.encode(ticket), encoding: .utf8)
        else { throw AgentLoopExchangeError.invalidStoredExchange }
        return serialized
    }

    private static func modelPrompt(for task: String) -> String {
        """
        Du beantwortest eine Frage aus einem iGentic-Kurzbefehl.
        Gib eine hilfreiche kurze Antwort auf Deutsch als reinen Text zurück.
        Du hast KEINEN direkten Zugriff auf das iPhone, kannst keine Befehle
        ausführen und darfst keinen Erfolg einer Geräteaktion behaupten.
        Deine Antwort wird ausschließlich in iGentic zur manuellen Prüfung gespeichert.

        Aufgabe:
        \(task)
        """
    }

    /// The Shortcuts output of "Use Model" is untrusted input. It becomes a
    /// *review-only* local reply, never a command, approval or Shortcut name.
    @discardableResult
    public func receive(answer: String, taskID: String) throws -> String {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.utf8.count <= Self.maximumAnswerBytes,
              !containsUnsafeControl(trimmed)
        else { throw AgentLoopExchangeError.invalidAnswer }
        return try withExclusiveMutation {
            guard var exchange = try snapshot() else {
                throw AgentLoopExchangeError.noPendingExchange
            }
            guard let expectedID = UUID(uuidString: taskID),
                  expectedID.uuidString.lowercased() == taskID.lowercased(),
                  exchange.id == expectedID else {
                throw AgentLoopExchangeError.mismatchedTaskID
            }
            let age = clock().timeIntervalSince(exchange.createdAt)
            guard age >= 0, age <= Self.expiration else {
                throw AgentLoopExchangeError.expired
            }
            guard exchange.answer == nil else {
                throw AgentLoopExchangeError.alreadyAnswered
            }
            exchange.answer = trimmed
            exchange.answeredAt = clock()
            try save(exchange)
            return "iGentic: KI-Antwort lokal übernommen. Keine iPhone-Aktion ausgeführt. Bitte in iGentic Agent prüfen."
        }
    }

    /// Read-only snapshot for the owner's iGentic screen.
    /// The file never leaves the sandbox through an MCP tool or remote endpoint.
    public func snapshot() throws -> AgentLoopExchange? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let bytes = try Data(contentsOf: fileURL)
        guard bytes.count <= 16_384,
              let state = try? JSONDecoder().decode(AgentLoopExchange.self, from: bytes),
              state.task.count <= 512,
              state.task.utf8.count <= Self.maximumTaskBytes,
              !state.task.isEmpty,
              !containsUnsafeControl(state.task),
              state.answer.map({ $0.utf8.count <= Self.maximumAnswerBytes
                  && !$0.isEmpty && !containsUnsafeControl($0) }) ?? true,
              (state.answer == nil) == (state.answeredAt == nil)
        else { throw AgentLoopExchangeError.invalidStoredExchange }
        return state
    }

    public func clear() throws {
        try withExclusiveMutation {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    private func save(_ exchange: AgentLoopExchange) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let bytes = try JSONEncoder().encode(exchange)
        try bytes.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600], ofItemAtPath: fileURL.path
        )
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path
        )
        #endif
    }

    private func containsUnsafeControl(_ text: String) -> Bool {
        text.unicodeScalars.contains {
            ($0.value < 32 && $0.value != 9 && $0.value != 10)
                || $0.value == 127
        }
    }
}
