import Foundation

public enum CreateReminderApprovalOrigin: String, Equatable, Sendable {
    case explicitHuman
    case syntheticTest
}

public enum CreateReminderCapabilityUse: String, Equatable, Sendable {
    case fakeExecutorTest
    case productionSideEffect
}

public struct CreateReminderApprovalSubject: Equatable, Sendable {
    public let draftID: UUID
    public let draftFingerprint: String
    public let title: CanonicalReminderTitle
    public let due: ReminderDueDate
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let actionRisk: ActionRisk
    public let actionDataDestination: ActionDataDestination

    public init(draft: CreateReminderDraft) {
        draftID = draft.id
        draftFingerprint = draft.fingerprint
        title = draft.title
        due = draft.due
        effectiveDataSensitivity = draft.effectiveDataSensitivity
        actionRisk = draft.actionRisk
        actionDataDestination = draft.actionDataDestination
    }

    func matches(_ draft: CreateReminderDraft) -> Bool {
        draftID == draft.id
            && draftFingerprint == draft.fingerprint
            && title == draft.title
            && due == draft.due
            && effectiveDataSensitivity == draft.effectiveDataSensitivity
            && actionRisk == draft.actionRisk
            && actionDataDestination == draft.actionDataDestination
    }
}

public struct CreateReminderBoundApprovalReceipt: Equatable, Sendable {
    public let requestID: String
    public let subject: CreateReminderApprovalSubject
    public let status: ApprovalStatus
    public let origin: CreateReminderApprovalOrigin

    public init(
        requestID: String,
        subject: CreateReminderApprovalSubject,
        status: ApprovalStatus,
        origin: CreateReminderApprovalOrigin
    ) {
        self.requestID = requestID
        self.subject = subject
        self.status = status
        self.origin = origin
    }
}

public struct CreateReminderExecutionCapability: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let draftID: UUID
    public let draftFingerprint: String
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let actionRisk: ActionRisk
    public let actionDataDestination: ActionDataDestination

    let targetBinding: ReminderTargetBinding

    init(id: UUID, draft: CreateReminderDraft) {
        self.id = id
        draftID = draft.id
        draftFingerprint = draft.fingerprint
        effectiveDataSensitivity = draft.effectiveDataSensitivity
        actionRisk = draft.actionRisk
        actionDataDestination = draft.actionDataDestination
        targetBinding = draft.targetBinding
    }
}

public enum CreateReminderCapabilityIssueRejection: Equatable, Sendable {
    case emptyApprovalRequestID
    case approvalNotApproved(ApprovalStatus)
    case approvalSubjectMismatch
    case syntheticApprovalNotAllowedForProduction
    case destinationBlocked(CreateReminderDestinationBlockReason)
    case duplicateCapabilityID
}

public enum CreateReminderCapabilityIssueResult: Equatable, Sendable {
    case issued(CreateReminderExecutionCapability)
    case rejected(CreateReminderCapabilityIssueRejection)
}

struct CreateReminderCapabilityIssuer: Sendable {
    private let ledger: SafeActionExecutionCapabilityLedger
    private let destinationPolicy: CreateReminderDestinationPolicy

    init(
        ledger: SafeActionExecutionCapabilityLedger = SafeActionExecutionCapabilityLedger(),
        destinationPolicy: CreateReminderDestinationPolicy = CreateReminderDestinationPolicy()
    ) {
        self.ledger = ledger
        self.destinationPolicy = destinationPolicy
    }

    func issue(
        draft: CreateReminderDraft,
        approval: CreateReminderBoundApprovalReceipt,
        privacyMode: PrivacyMode,
        use: CreateReminderCapabilityUse,
        capabilityID: UUID = UUID()
    ) -> CreateReminderCapabilityIssueResult {
        guard !approval.requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .rejected(.emptyApprovalRequestID)
        }
        guard approval.status == .approved else {
            return .rejected(.approvalNotApproved(approval.status))
        }
        guard approval.subject.matches(draft) else {
            return .rejected(.approvalSubjectMismatch)
        }
        if approval.origin == .syntheticTest, use == .productionSideEffect {
            return .rejected(.syntheticApprovalNotAllowedForProduction)
        }

        switch destinationPolicy.evaluate(draft, privacyMode: privacyMode) {
        case .allowed:
            break
        case .blocked(let reason):
            return .rejected(.destinationBlocked(reason))
        }

        let capability = CreateReminderExecutionCapability(id: capabilityID, draft: draft)
        guard ledger.issue(capability.id) else {
            return .rejected(.duplicateCapabilityID)
        }
        return .issued(capability)
    }
}
