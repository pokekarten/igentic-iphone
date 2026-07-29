import XCTest
@testable import AgentCore

final class MemoryStoreTests: XCTestCase {
    func testSaveCreatesNewEntryWithMatchingCreatedAtAndUpdatedAt() throws {
        let store = MemoryStore()

        let entry = try store.save(
            key: "remember-me",
            value: "alpha",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )

        XCTAssertEqual(entry.scope, .session)
        XCTAssertEqual(entry.key, "remember-me")
        XCTAssertEqual(entry.value, "alpha")
        XCTAssertEqual(entry.dataSensitivity, .lowRiskAppData)
        XCTAssertEqual(entry.createdAt, entry.updatedAt)
    }

    func testSaveAcceptsEveryAllowedSensitivityLevel() throws {
        let store = MemoryStore()
        let allowedLevels: [DataSensitivityLevel] = [
            .publicData,
            .lowRiskAppData,
            .contextualPrivateData,
            .highlyPrivateData
        ]

        for (index, level) in allowedLevels.enumerated() {
            let entry = try store.save(
                key: "allowed-\(index)",
                value: "value-\(index)",
                scope: .session,
                dataSensitivity: level
            )
            XCTAssertEqual(entry.dataSensitivity, level)
        }

        XCTAssertEqual(store.entries(in: .session).count, allowedLevels.count)
    }

    func testRestrictedSensitiveDataIsRejectedBeforeStoreMutation() throws {
        let store = MemoryStore()
        _ = try store.save(
            key: "existing",
            value: "safe",
            scope: .session,
            dataSensitivity: .contextualPrivateData
        )

        XCTAssertThrowsError(
            try store.save(
                key: "restricted",
                value: "must-not-persist",
                scope: .session,
                dataSensitivity: .restrictedSensitiveData
            )
        ) { error in
            XCTAssertEqual(error as? MemoryStoreWriteError, .restrictedSensitiveDataNotStorable)
        }

        XCTAssertEqual(store.entries(in: .session).map(\.key), ["existing"])
    }

    func testRestrictedSensitiveDataCannotOverwriteExistingEntry() throws {
        let store = MemoryStore()
        let original = try store.save(
            key: "protected",
            value: "safe",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )

        XCTAssertThrowsError(
            try store.save(
                key: "protected",
                value: "restricted",
                scope: .session,
                dataSensitivity: .restrictedSensitiveData
            )
        )

        XCTAssertEqual(store.entries(in: .session), [original])
    }

    func testSavingSameKeyInSameScopePreservesIdentityAndUpdatesValueAndSensitivity() throws {
        let store = MemoryStore()

        let original = try store.save(
            key: "theme",
            value: "light",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )
        let updated = try store.save(
            key: "theme",
            value: "dark",
            scope: .session,
            dataSensitivity: .contextualPrivateData
        )

        XCTAssertEqual(updated.id, original.id)
        XCTAssertEqual(updated.createdAt, original.createdAt)
        XCTAssertEqual(updated.value, "dark")
        XCTAssertEqual(updated.dataSensitivity, .contextualPrivateData)
        XCTAssertGreaterThanOrEqual(updated.updatedAt, original.updatedAt)
    }

    func testEntriesInScopeReturnsOnlyRequestedScopeSortedByKey() throws {
        let store = MemoryStore()
        _ = try store.save(key: "zeta", value: "3", scope: .session, dataSensitivity: .publicData)
        _ = try store.save(key: "alpha", value: "1", scope: .session, dataSensitivity: .lowRiskAppData)
        _ = try store.save(key: "beta", value: "2", scope: .session, dataSensitivity: .contextualPrivateData)
        _ = try store.save(key: "task-only", value: "x", scope: .task, dataSensitivity: .highlyPrivateData)

        let entries = store.entries(in: .session)

        XCTAssertEqual(entries.map(\.key), ["alpha", "beta", "zeta"])
        XCTAssertTrue(entries.allSatisfy { $0.scope == .session })
    }

    func testSessionAndTaskScopesAreIsolatedForSameKey() throws {
        let store = MemoryStore()

        let sessionEntry = try store.save(
            key: "shared",
            value: "session",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )
        let taskEntry = try store.save(
            key: "shared",
            value: "task",
            scope: .task,
            dataSensitivity: .contextualPrivateData
        )

        XCTAssertEqual(store.entries(in: .session), [sessionEntry])
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
        XCTAssertNotEqual(sessionEntry.id, taskEntry.id)
        XCTAssertNotEqual(sessionEntry.scope, taskEntry.scope)
    }

    func testDeleteScopeClearsOnlyTargetedScopeAndLeavesOthersIntact() throws {
        let store = MemoryStore()
        let sessionEntry = try store.save(
            key: "session-key",
            value: "a",
            scope: .session,
            dataSensitivity: .lowRiskAppData
        )
        let taskEntry = try store.save(
            key: "task-key",
            value: "b",
            scope: .task,
            dataSensitivity: .contextualPrivateData
        )

        store.delete(scope: .session)

        XCTAssertTrue(store.entries(in: .session).isEmpty)
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
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
            dataSensitivity: .lowRiskAppData,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
        let taskEntry = MemoryEntry(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            scope: .task,
            key: "task-key",
            value: "task-value",
            dataSensitivity: .contextualPrivateData,
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        let store = MemoryStore(entries: [taskEntry, sessionEntry])

        XCTAssertEqual(store.entries(in: .session), [sessionEntry])
        XCTAssertEqual(store.entries(in: .task), [taskEntry])
    }
}
