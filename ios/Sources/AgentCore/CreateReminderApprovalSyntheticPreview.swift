import Foundation

public extension CreateReminderApprovalSubject {
    /// Fixed public-safe subject for the diagnostic human-approval demo.
    ///
    /// The matching draft and target binding never leave AgentCore, so a
    /// receipt produced from this preview cannot authorize a real capability.
    static func syntheticDiagnosticPreview(
        destination: ActionDataDestination = .deviceLocalStore
    ) -> CreateReminderApprovalSubject {
        guard let draftID = UUID(uuidString: "00000000-0000-0000-0000-000000000342"),
              let targetBinding = ReminderTargetBinding(
                opaqueValue: "synthetic-diagnostic-reminder-target"
              ),
              let title = try? CanonicalReminderTitle("Pflanzen gießen"),
              let due = try? ReminderDueDate.resolve(
                year: 2026,
                month: 9,
                day: 1,
                hour: 12,
                minute: 0,
                timeZoneIdentifier: "Europe/Berlin"
              ) else {
            preconditionFailure("The fixed Safe Action diagnostic preview must remain valid.")
        }

        let draft = CreateReminderDraft(
            id: draftID,
            title: title,
            due: due,
            effectiveDataSensitivity: .contextualPrivateData,
            actionDataDestination: destination,
            targetBinding: targetBinding
        )
        return CreateReminderApprovalSubject(draft: draft)
    }
}
