import Foundation

public enum MemoryScope: String, CaseIterable, Sendable {
    case session
    case task
}

public struct MemoryEntry: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let scope: MemoryScope
    public let key: String
    public let value: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: UUID = UUID(),
        scope: MemoryScope,
        key: String,
        value: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scope = scope
        self.key = key
        self.value = value
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public final class MemoryStore: @unchecked Sendable {
    private let entriesByScope = LockedBox<[MemoryScope: [String: MemoryEntry]]>([:])

    public init(entries: [MemoryEntry] = []) {
        for entry in entries {
            entriesByScope.withValue { $0[entry.scope, default: [:]][entry.key] = entry }
        }
    }

    @discardableResult
    public func save(key: String, value: String, scope: MemoryScope) -> MemoryEntry {
        entriesByScope.withValue { entriesByScope in
            let now = Date()
            let existingEntry = entriesByScope[scope]?[key]
            let entry = MemoryEntry(
                id: existingEntry?.id ?? UUID(),
                scope: scope,
                key: key,
                value: value,
                createdAt: existingEntry?.createdAt ?? now,
                updatedAt: now
            )
            entriesByScope[scope, default: [:]][key] = entry
            return entry
        }
    }

    public func entries(in scope: MemoryScope) -> [MemoryEntry] {
        entriesByScope.withValue { entriesByScope in
            entriesByScope[scope, default: [:]].values.sorted { lhs, rhs in
                lhs.key < rhs.key
            }
        }
    }

    public func delete(scope: MemoryScope) {
        entriesByScope.withValue { $0[scope] = nil }
    }
}
