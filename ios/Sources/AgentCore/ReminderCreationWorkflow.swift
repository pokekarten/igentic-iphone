import Foundation

package enum ReminderCreationState: String, Equatable, Sendable {
    case editing, needsPermission, invalidInput, destinationBlocked, targetUnavailable
    case needsApproval, cancelled, expired, approvalRejected, executing
    case verified, uncertain, targetChanged
}

package enum ReminderSaveResult: Equatable, Sendable {
    case verified, uncertain, permissionUnavailable, targetChanged, cancelled
}

/// No model, raw task, or caller-supplied calendar identifier reaches this seam.
@MainActor
package protocol ReminderStoreBackend: AnyObject {
    var authorization: ReminderTargetAuthorizationState { get }
    func requestAccess() async -> Bool
    func resolveTarget() -> ReminderTargetResolutionResult
    func saveAndVerify(_ draft: CreateReminderDraft) -> ReminderSaveResult
}

/// One foreground transaction. Approval and capabilities are never restored or retried.
/// A terminal uncertain result requires manual reconciliation, not another save.
@MainActor
package final class ReminderCreationWorkflow {
    package private(set) var state: ReminderCreationState = .editing
    package private(set) var subject: CreateReminderApprovalSubject?
    private let backend: any ReminderStoreBackend
    private let audit: AuditLog
    private let ledger = SafeActionExecutionCapabilityLedger()
    private let now: () -> Date
    private var draft: CreateReminderDraft?
    private var privacyMode: PrivacyMode = .localOnly
    private var preparedAt: Date?

    package init(
        backend: any ReminderStoreBackend,
        audit: AuditLog = AuditLog(),
        now: @escaping () -> Date = Date.init
    ) {
        self.backend = backend
        self.audit = audit
        self.now = now
    }

    package var authorization: ReminderTargetAuthorizationState { backend.authorization }

    package func requestAccess() async -> Bool {
        guard state != .executing else { return false }
        invalidateDraft()
        return await backend.requestAccess()
    }

    package func invalidateDraft() {
        guard state != .executing, state != .verified, state != .uncertain else { return }
        draft = nil
        subject = nil
        preparedAt = nil
        state = .editing
    }

    package func cancel() {
        guard state != .executing, state != .verified, state != .uncertain else { return }
        draft = nil
        subject = nil
        preparedAt = nil
        state = .cancelled
    }

    package func prepare(title: String, due: ReminderDueDate, allowSyncedStore: Bool) {
        guard state != .executing, state != .verified, state != .uncertain else { return }
        invalidateDraft()
        guard title.utf8.count <= 512,
              let canonicalTitle = try? CanonicalReminderTitle(title) else {
            state = .invalidInput
            return
        }
        guard backend.authorization == .fullAccess else {
            state = .needsPermission
            return
        }
        guard case .resolved(let target) = backend.resolveTarget() else {
            state = .targetUnavailable
            return
        }
        let detection = SensitiveDataDetector().detect(in: canonicalTitle.value)
        let classification = DataClassification.effectiveClassification(
            baseClassification: .init(level: .contextualPrivateData, reason: "Personal reminder."),
            detectorResult: detection
        )
        let candidate = CreateReminderDraft(
            title: canonicalTitle,
            due: due,
            effectiveDataSensitivity: classification.level,
            actionDataDestination: target.destination,
            targetBinding: target.binding
        )
        // This per-transaction choice permits a synced reminder destination only;
        // it does not configure a provider or authorize any compute delegation.
        let mode: PrivacyMode = allowSyncedStore ? .trustedDevices : .localOnly
        guard CreateReminderDestinationPolicy().evaluate(candidate, privacyMode: mode) == .allowed else {
            state = .destinationBlocked
            return
        }
        let response = AgentKernel(auditLog: audit).handle(
            task(for: candidate), privacyMode: mode
        )
        guard response.policyDecision.isAllowed, response.policyDecision.requiresApproval,
              response.approvalStatus == .pending else {
            state = .approvalRejected
            return
        }
        draft = candidate
        subject = CreateReminderApprovalSubject(draft: candidate)
        privacyMode = mode
        preparedAt = now()
        state = .needsApproval
    }

    package func execute(approval: CreateReminderBoundApprovalReceipt) async {
        guard state == .needsApproval, let draft, let preparedAt else { return }
        guard !Task.isCancelled else { cancel(); return }
        let age = now().timeIntervalSince(preparedAt)
        guard age >= 0, age <= 300 else {
            state = .expired
            subject = nil
            return
        }
        // Generic auto-approval policies and synthetic receipts cannot enter the
        // production route. The existing human UI supplies this exact receipt.
        let policy = BoundReminderDecisionPolicy(draft: draft, approval: approval)
        let response = AgentKernel(
            auditLog: audit,
            approvalManager: ApprovalManager(policy: policy)
        ).handle(task(for: draft), privacyMode: privacyMode)
        guard response.policyDecision.isAllowed,
              response.approvalStatus == .approved,
              response.approvalReceipt?.mayContinueRouting == true,
              case .localTool(name: "createReminder", reason: _) = response.route else {
            state = .approvalRejected
            subject = nil
            return
        }
        let issuer = CreateReminderCapabilityIssuer(ledger: ledger)
        guard case .issued(let capability) = issuer.issue(
            draft: draft, approval: approval, privacyMode: privacyMode, use: .productionSideEffect
        ) else {
            state = .approvalRejected
            subject = nil
            return
        }
        state = .executing
        subject = nil
        audit.record(.init(type: .reminderExecutionStarted, message: "createReminder.started", dataSensitivity: draft.effectiveDataSensitivity))
        let consumed = await ledger.consume(capability.id) { @MainActor [backend] in
            guard !Task.isCancelled else { return ReminderSaveResult.cancelled }
            return backend.saveAndVerify(draft)
        }
        switch consumed {
        case .rejected:
            state = .approvalRejected
        case .completed(let result):
            switch result {
            case .verified: state = .verified
            case .uncertain: state = .uncertain
            case .permissionUnavailable: state = .needsPermission
            case .targetChanged: state = .targetChanged
            case .cancelled: state = .cancelled
            }
        }
        self.draft = nil
        self.preparedAt = nil
        audit.record(.init(type: .reminderExecutionFinished, message: "createReminder.\(state.rawValue)", dataSensitivity: draft.effectiveDataSensitivity))
    }

    private func task(for draft: CreateReminderDraft) -> TaskRequest {
        TaskRequest(
            userText: draft.title.value,
            intent: .createReminder,
            dataClassification: .init(level: draft.effectiveDataSensitivity, reason: "Canonical reminder."),
            actionRisk: .execute,
            requestedDelegationTarget: .localDevice
        )
    }
}

private struct BoundReminderDecisionPolicy: ApprovalDecisionPolicy {
    let draft: CreateReminderDraft
    let approval: CreateReminderBoundApprovalReceipt

    func decide(_ request: ApprovalRequest) -> ApprovalStatus {
        guard approval.origin == .explicitHuman,
              approval.status == .approved,
              !approval.requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              approval.subject.matches(draft),
              request.actionRisk == .execute,
              request.dataClassification.level == draft.effectiveDataSensitivity else {
            return .rejected
        }
        return .approved
    }
}
