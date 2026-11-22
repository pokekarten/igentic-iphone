import Foundation
import XCTest
@testable import AgentCore

@MainActor
private final class FakeReminderStore: ReminderStoreBackend {
    var authorization: ReminderTargetAuthorizationState = .fullAccess
    var source: ReminderTargetSourceClass = .local
    var identity = "synthetic-list-A"
    var result: ReminderSaveResult = .verified
    var resolveCount = 0
    var requestCount = 0
    var saveCount = 0
    var executionCount = 0
    var lastDraft: CreateReminderDraft?

    func requestAccess() async -> Bool { requestCount += 1; return authorization == .fullAccess }
    func resolveTarget() -> ReminderTargetResolutionResult {
        resolveCount += 1
        return ReminderTargetResolver().resolve(.init(
            authorization: authorization, sourceClass: source, opaqueTargetIdentity: identity
        ))
    }
    func saveAndVerify(_ draft: CreateReminderDraft) -> ReminderSaveResult {
        executionCount += 1
        // The fake models the adapter's final permission and target checks.
        guard authorization == .fullAccess else { return .permissionUnavailable }
        guard ReminderTargetPreSaveRechecker().recheck(draft: draft, current: resolveTarget()) == .matched else {
            return .targetChanged
        }
        saveCount += 1
        lastDraft = draft
        return result
    }
}

final class ReminderCreationWorkflowTests: XCTestCase {
    private func due() throws -> ReminderDueDate {
        try .resolve(year: 2026, month: 11, day: 23, hour: 18, minute: 0, timeZoneIdentifier: "Europe/Berlin")
    }

    @MainActor
    private func receipt(
        _ workflow: ReminderCreationWorkflow,
        status: ApprovalStatus = .approved,
        origin: CreateReminderApprovalOrigin = .explicitHuman
    ) throws -> CreateReminderBoundApprovalReceipt {
        .init(requestID: UUID().uuidString, subject: try XCTUnwrap(workflow.subject), status: status, origin: origin)
    }

    @MainActor
    func testExactHumanApprovalExecutesOnceAndReportsVerifiedReadback() async throws {
        let store = FakeReminderStore()
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "  Demo-Pflanze gießen  ", due: try due(), allowSyncedStore: false)
        XCTAssertEqual(flow.state, .needsApproval)
        XCTAssertEqual(store.saveCount, 0)
        XCTAssertEqual(flow.subject?.title.value, "Demo-Pflanze gießen")
        XCTAssertEqual(flow.subject?.effectiveDataSensitivity, .contextualPrivateData)
        let approval = try receipt(flow)
        await flow.execute(approval: approval)
        await flow.execute(approval: approval)
        XCTAssertEqual(flow.state, .verified)
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(store.lastDraft?.title, approval.subject.title)
        XCTAssertEqual(store.lastDraft?.due, approval.subject.due)
    }

    @MainActor
    func testUnapprovedAndSyntheticReceiptsNeverCallExecutor() async throws {
        for (status, origin) in [(ApprovalStatus.pending, CreateReminderApprovalOrigin.explicitHuman),
                                 (.rejected, .explicitHuman), (.notRequired, .explicitHuman), (.approved, .syntheticTest)] {
            let store = FakeReminderStore()
            let flow = ReminderCreationWorkflow(backend: store)
            flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
            await flow.execute(approval: try receipt(flow, status: status, origin: origin))
            XCTAssertEqual(flow.state, .approvalRejected)
            XCTAssertEqual(store.saveCount, 0)
            XCTAssertEqual(store.executionCount, 0)
        }
    }

    @MainActor
    func testEditingOrCancellingInvalidatesOldApproval() async throws {
        let store = FakeReminderStore()
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "First draft", due: try due(), allowSyncedStore: false)
        let old = try receipt(flow)
        flow.prepare(title: "Changed draft", due: try due(), allowSyncedStore: false)
        await flow.execute(approval: old)
        XCTAssertEqual(flow.state, .approvalRejected)
        XCTAssertEqual(store.saveCount, 0)

        flow.prepare(title: "Cancelled draft", due: try due(), allowSyncedStore: false)
        let cancelled = try receipt(flow)
        flow.cancel()
        await flow.execute(approval: cancelled)
        XCTAssertEqual(flow.state, .cancelled)
        XCTAssertEqual(store.saveCount, 0)
    }

    @MainActor
    func testPermissionMissingDoesNotResolveTargetOrPromptAutomatically() async throws {
        for state in [ReminderTargetAuthorizationState.setupRequired, .denied, .restricted, .unsupported] {
            let store = FakeReminderStore()
            store.authorization = state
            let flow = ReminderCreationWorkflow(backend: store)
            flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
            XCTAssertEqual(flow.state, .needsPermission)
            XCTAssertNil(flow.subject)
            XCTAssertEqual(store.resolveCount, 0)
            XCTAssertEqual(store.requestCount, 0)
            XCTAssertEqual(store.saveCount, 0)
        }
    }

    @MainActor
    func testInvalidTitleCannotReachTargetOrApproval() async throws {
        for title in ["  ", "bad\nline", "bad\u{202E}title", String(repeating: "ä", count: 257)] {
            let store = FakeReminderStore()
            let flow = ReminderCreationWorkflow(backend: store)
            flow.prepare(title: title, due: try due(), allowSyncedStore: false)
            XCTAssertEqual(flow.state, .invalidInput)
            XCTAssertEqual(store.resolveCount, 0)
            XCTAssertEqual(store.saveCount, 0)
        }
    }

    @MainActor
    func testSyncedDestinationRequiresExplicitPerTaskChoice() async throws {
        let store = FakeReminderStore()
        store.source = .calDAV
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
        XCTAssertEqual(flow.state, .destinationBlocked)
        XCTAssertNil(flow.subject)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: true)
        XCTAssertEqual(flow.subject?.actionDataDestination, .systemSyncedPersonalStore)
        XCTAssertEqual(flow.state, .needsApproval)
        await flow.execute(approval: try receipt(flow))
        XCTAssertEqual(store.saveCount, 1)
    }

    @MainActor
    func testSensitiveTitleCannotOverrideSyncedDestinationBlock() async throws {
        let store = FakeReminderStore()
        store.source = .calDAV
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Synthetic IBAN DE89370400440532013000", due: try due(), allowSyncedStore: true)
        XCTAssertEqual(flow.state, .destinationBlocked)
        XCTAssertNil(flow.subject)
        XCTAssertEqual(store.executionCount, 0)
        store.source = .local
        flow.prepare(title: "Synthetic IBAN DE89370400440532013000", due: try due(), allowSyncedStore: false)
        XCTAssertEqual(flow.state, .needsApproval)
        XCTAssertEqual(flow.subject?.effectiveDataSensitivity, .restrictedSensitiveData)
    }

    @MainActor
    func testUnsupportedDestinationCannotReachApproval() async throws {
        let store = FakeReminderStore()
        store.source = .unsupported
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: true)
        XCTAssertEqual(flow.state, .targetUnavailable)
        XCTAssertNil(flow.subject)
        XCTAssertEqual(store.executionCount, 0)
    }

    @MainActor
    func testChangedTargetAndRevokedPermissionCauseZeroSaves() async throws {
        for revokePermission in [false, true] {
            let store = FakeReminderStore()
            let flow = ReminderCreationWorkflow(backend: store)
            flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
            let approval = try receipt(flow)
            if revokePermission { store.authorization = .denied } else { store.identity = "synthetic-list-B" }
            await flow.execute(approval: approval)
            XCTAssertEqual(flow.state, revokePermission ? .needsPermission : .targetChanged)
            XCTAssertEqual(store.saveCount, 0)
        }
    }

    @MainActor
    func testExpiredAndClockRollbackApprovalsCauseZeroSaves() async throws {
        for delta in [301.0, -1.0] {
            var clock = Date(timeIntervalSince1970: 1_800_000_000)
            let store = FakeReminderStore()
            let flow = ReminderCreationWorkflow(backend: store, now: { clock })
            flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
            let approval = try receipt(flow)
            clock = clock.addingTimeInterval(delta)
            await flow.execute(approval: approval)
            XCTAssertEqual(flow.state, .expired)
            XCTAssertEqual(store.saveCount, 0)
        }
    }

    @MainActor
    func testUncertainSaveIsTerminalAndCannotBeBlindlyRetried() async throws {
        let store = FakeReminderStore()
        store.result = .uncertain
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
        let approval = try receipt(flow)
        await flow.execute(approval: approval)
        flow.invalidateDraft()
        flow.cancel()
        flow.prepare(title: "Retry", due: try due(), allowSyncedStore: false)
        await flow.execute(approval: approval)
        XCTAssertEqual(flow.state, .uncertain)
        XCTAssertNil(flow.subject)
        XCTAssertEqual(store.saveCount, 1)
    }

    @MainActor
    func testCancelledTaskBeforeExecutionCausesZeroSaves() async throws {
        let store = FakeReminderStore()
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
        let approval = try receipt(flow)
        let task = Task { @MainActor in await flow.execute(approval: approval) }
        task.cancel()
        await task.value
        XCTAssertEqual(flow.state, .cancelled)
        XCTAssertEqual(store.saveCount, 0)
    }

    @MainActor
    func testConcurrentDuplicateApprovalCausesOneSave() async throws {
        let store = FakeReminderStore()
        let flow = ReminderCreationWorkflow(backend: store)
        flow.prepare(title: "Demo", due: try due(), allowSyncedStore: false)
        let approval = try receipt(flow)
        let first = Task { @MainActor in await flow.execute(approval: approval) }
        let second = Task { @MainActor in await flow.execute(approval: approval) }
        await first.value
        await second.value
        XCTAssertEqual(store.saveCount, 1)
        XCTAssertEqual(flow.state, .verified)
    }

    @MainActor
    func testAuditContainsOnlyMetadataAndNoTitleTimeOrTarget() async throws {
        let audit = AuditLog()
        let store = FakeReminderStore()
        let flow = ReminderCreationWorkflow(backend: store, audit: audit)
        flow.prepare(title: "PrivateSyntheticMarker", due: try due(), allowSyncedStore: false)
        await flow.execute(approval: try receipt(flow))
        let messages = audit.allEvents().map(\.message).joined(separator: " ")
        for privateValue in ["PrivateSyntheticMarker", "2026", "18:00", "Europe/Berlin", "synthetic-list-A"] {
            XCTAssertFalse(messages.contains(privateValue))
        }
        XCTAssertEqual(audit.count(ofType: .reminderExecutionStarted), 1)
        XCTAssertEqual(audit.count(ofType: .reminderExecutionFinished), 1)
    }
}
