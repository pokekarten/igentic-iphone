import AgentCore
import Foundation

public struct CreateReminderApprovalPresentation: Equatable, Sendable {
    public let actionSummary: String
    public let title: String
    public let dueSummary: String
    public let destinationSummary: String
    public let persistentWriteNotice: String
    public let canApprove: Bool

    public init(subject: CreateReminderApprovalSubject) {
        actionSummary = "Create one reminder"
        title = subject.title.value
        dueSummary = Self.dueSummary(for: subject.due)
        destinationSummary = Self.destinationSummary(for: subject.actionDataDestination)
        persistentWriteNotice = "This action writes persistent user data."
        canApprove = subject.actionRisk == .execute
            && subject.actionDataDestination != .none
            && subject.actionDataDestination != .unknown
    }

    private static func dueSummary(for due: ReminderDueDate) -> String {
        let offsetSeconds = Int(due.resolvedUTCOffsetSeconds)
        let sign = offsetSeconds >= 0 ? "+" : "-"
        let absoluteOffset = abs(offsetSeconds)
        let offsetHours = absoluteOffset / 3_600
        let offsetMinutes = (absoluteOffset % 3_600) / 60

        return "\(fourDigits(due.year))-\(twoDigits(due.month))-\(twoDigits(due.day)) "
            + "\(twoDigits(due.hour)):\(twoDigits(due.minute)) "
            + "(\(due.timeZoneIdentifier), UTC\(sign)\(twoDigits(offsetHours)):\(twoDigits(offsetMinutes)))"
    }

    private static func destinationSummary(for destination: ActionDataDestination) -> String {
        switch destination {
        case .deviceLocalStore:
            return "Device-local storage"
        case .systemSyncedPersonalStore:
            return "System-synced personal storage"
        case .none:
            return "No storage destination"
        case .unknown:
            return "Unknown storage destination"
        }
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func fourDigits(_ value: Int) -> String {
        switch value {
        case 0..<10:
            return "000\(value)"
        case 10..<100:
            return "00\(value)"
        case 100..<1_000:
            return "0\(value)"
        default:
            return "\(value)"
        }
    }
}

public enum CreateReminderHumanApprovalDecision: Equatable, Sendable {
    case approved(CreateReminderBoundApprovalReceipt)
    case rejected(CreateReminderBoundApprovalReceipt)
    case cancelled
}

package struct CreateReminderHumanApprovalSession: Sendable {
    package let subject: CreateReminderApprovalSubject
    package let presentation: CreateReminderApprovalPresentation

    package init(subject: CreateReminderApprovalSubject) {
        self.subject = subject
        self.presentation = CreateReminderApprovalPresentation(subject: subject)
    }

    package func approve(requestID: String) -> CreateReminderHumanApprovalDecision {
        guard presentation.canApprove,
              !requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .cancelled
        }
        return .approved(
            CreateReminderBoundApprovalReceipt(
                requestID: requestID,
                subject: subject,
                status: .approved,
                origin: .explicitHuman
            )
        )
    }

    package func reject(requestID: String) -> CreateReminderHumanApprovalDecision {
        guard !requestID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .cancelled
        }
        return .rejected(
            CreateReminderBoundApprovalReceipt(
                requestID: requestID,
                subject: subject,
                status: .rejected,
                origin: .explicitHuman
            )
        )
    }

    package func cancel() -> CreateReminderHumanApprovalDecision {
        .cancelled
    }
}

#if canImport(SwiftUI)
import SwiftUI

public struct CreateReminderApprovalView: View {
    private let session: CreateReminderHumanApprovalSession
    private let onDecision: (CreateReminderHumanApprovalDecision) -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        subject: CreateReminderApprovalSubject,
        onDecision: @escaping (CreateReminderHumanApprovalDecision) -> Void
    ) {
        self.session = CreateReminderHumanApprovalSession(subject: subject)
        self.onDecision = onDecision
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    LabeledContent("Action", value: session.presentation.actionSummary)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Reminder title")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(session.presentation.title)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)

                    LabeledContent("Due", value: session.presentation.dueSummary)
                    LabeledContent("Storage", value: session.presentation.destinationSummary)
                }

                Section("Confirmation") {
                    Text(session.presentation.persistentWriteNotice)
                        .fixedSize(horizontal: false, vertical: true)

                    if !session.presentation.canApprove {
                        Text("Approval is unavailable until the action has a resolved, supported storage destination.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button("Approve") {
                        finish(session.approve(requestID: UUID().uuidString))
                    }
                    .disabled(!session.presentation.canApprove)

                    Button("Reject", role: .destructive) {
                        finish(session.reject(requestID: UUID().uuidString))
                    }

                    Button("Cancel", role: .cancel) {
                        finish(session.cancel())
                    }
                }
            }
            .navigationTitle("Review reminder")
        }
        .interactiveDismissDisabled()
    }

    private func finish(_ decision: CreateReminderHumanApprovalDecision) {
        onDecision(decision)
        dismiss()
    }
}
#endif
