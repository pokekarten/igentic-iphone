import XCTest
@testable import AgentCore

final class MemoryStoreTests: XCTestCase {
    func testSaveCreatesNewEntryWithMatchingCreatedAtAndUpdatedAt() {
        let store = MemoryStore()

        let entry = store.save(key: "remember-me", value: "alpha", scope: .session)

        XCTAssertEqual(entry.scope, .session)
        XCTAssertEqual(entry.key, "remember-me")
        XCTAssertEqual(entry.value, "alpha")
        XCTAssertEqual(entry.createdAt, entry.updatedAt)
    }

    func testSavingSameKeyInSameScopePreservesIdentityAndUpdatesValueAndUpdatedAt() {
        let store = MemoryStore()

        let original = store.save(key: "theme", value: "light", scope: .session)
        let updated = store.save(key: "theme", value: "dark", scope: .session)

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertEqual(updated.value, "dark")
        XCTAssertGreaterThanOrEqual(updated.updatedAt, original.updatedAt)
    }

    func testEntriesInScopeReturnsOnlyRequestedScopeSortedByKey() {
        let store = MemoryStore()
        store.save(key: "zeta", value: "3", scope: .session)
        store.save(key: "alpha", value: "1", scope: .session)
        store.save(key: "beta", value: "2", scope: .session)
        store.save(key: "task-only", value: "x", scope: .task)

        let entries = store.entries(in: .session)

        XCTAssertEqual(entries.map(\/.key), ["alpha", "beta", "zeta"])
        XCTAssertTrue(entries.allSatisfy { $0.scope == .session })
    }

    func testSessionAndTaskScopesAreIsolatedForSameKey() {
        let store = MemoryStore()

        let sessionEntry = store.save(key: "shared", value: "session", scope: .session)
        let taskEntry = store.save(key: "shared", value: "task", scope: .task)

        XCTAssertEqual(store.entries(in: .session), [sessionEntry])
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
        XCTAssertNotEqual(sessionEntry.id, taskEntry.id)
        XCTAssertNotEqual(sessionEntry.scope, taskEntry.scope)
    }

    func testDeleteScopeClearsOnlyTargetedScopeAndLeavesOthersIntact() {
        let store = MemoryStore()
        let sessionEntry = store.save(key: "session-key", value: "a", scope: .session)
        let taskEntry = store.save(key: "task-key", value: "b", scope: .task)

        store.delete(scope: .session)

        XCTAssertTrue(store.entries(in: .session).isEmpty)
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
        XCTAssertEqual(store.entries(in: .task).first, taskEntry)
        XCTAssertEqual(taskEntry.key, "task-key")
        XCTAssertEqual(sessionEntry.scope, .session)
    }

    func testInitWithEntriesSeedsEntriesByScope() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let sessionEntry = MemoryEntry(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            scope: .session,
            key: "session-key",
            value: "session-value",
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let taskEntry = MemoryEntry(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            scope: .task,
            key: "task-key",
            value: "task-value",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let store = MemoryStore(entries: [taskEntry, sessionEntry])

        XCTAssertEqual(store.entries(in: .session), [sessionEntry])
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
    }
}
