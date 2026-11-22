#if canImport(EventKit)
import EventKit
import Foundation

@MainActor
package final class EventKitReminderStore: ReminderStoreBackend {
    private let store = EKEventStore()

    package init() {}

    package var authorization: ReminderTargetAuthorizationState {
        EventKitReminderTargetResolver.authorizationState(EKEventStore.authorizationStatus(for: .reminder))
    }

    package func requestAccess() async -> Bool {
        if authorization == .fullAccess { return true }
        guard authorization == .setupRequired else { return false }
        // No fetch/create operation precedes this explicit user-triggered request.
        do { return try await store.requestFullAccessToReminders() }
        catch { return false } // Raw platform errors may contain private data.
    }

    package func resolveTarget() -> ReminderTargetResolutionResult {
        EventKitReminderTargetResolver(eventStore: store).resolve()
    }

    package func saveAndVerify(_ draft: CreateReminderDraft) -> ReminderSaveResult {
        guard !Task.isCancelled else { return .cancelled }
        guard authorization == .fullAccess else { return .permissionUnavailable }
        guard let calendar = store.defaultCalendarForNewReminders(),
              calendar.allowsContentModifications,
              let source = calendar.source else { return .targetChanged }
        let target = ReminderTargetResolver().resolve(.init(
            authorization: .fullAccess,
            sourceClass: EventKitReminderTargetResolver.sourceClass(source.sourceType),
            opaqueTargetIdentity: EventKitReminderTargetResolver.processLocalTargetBinding(
                calendarIdentifier: calendar.calendarIdentifier,
                sourceIdentifier: source.sourceIdentifier
            )
        ))
        guard ReminderTargetPreSaveRechecker().recheck(draft: draft, current: target) == .matched else {
            return .targetChanged
        }
        let reminder = EKReminder(eventStore: store)
        reminder.title = draft.title.value
        reminder.calendar = calendar
        var due = DateComponents()
        due.calendar = Calendar(identifier: .gregorian)
        due.timeZone = TimeZone(identifier: draft.due.timeZoneIdentifier)
        due.year = draft.due.year
        due.month = draft.due.month
        due.day = draft.due.day
        due.hour = draft.due.hour
        due.minute = draft.due.minute
        due.second = 0
        reminder.dueDateComponents = due

        guard !Task.isCancelled else { return .cancelled }
        guard authorization == .fullAccess else { return .permissionUnavailable }
        guard ReminderTargetPreSaveRechecker().recheck(draft: draft, current: resolveTarget()) == .matched else {
            return .targetChanged
        }
        do {
            try store.save(reminder, commit: true) // Exactly one attempt; no automatic retry.
        } catch {
            return .uncertain // A thrown save is not proof of absence of a side effect.
        }

        // Read only the newly created item, by its returned identifier. No
        // enumeration, predicates, existing-content search or model access.
        guard authorization == .fullAccess, !reminder.calendarItemIdentifier.isEmpty else { return .uncertain }
        let verifier = EKEventStore()
        guard let saved = verifier.calendarItem(withIdentifier: reminder.calendarItemIdentifier) as? EKReminder,
              saved.calendar.calendarIdentifier == calendar.calendarIdentifier,
              saved.calendar.source?.sourceIdentifier == source.sourceIdentifier,
              saved.title == draft.title.value,
              !saved.isCompleted,
              let actualDue = saved.dueDateComponents,
              actualDue.year == due.year, actualDue.month == due.month, actualDue.day == due.day,
              actualDue.hour == due.hour, actualDue.minute == due.minute,
              (actualDue.second ?? 0) == 0,
              actualDue.timeZone?.identifier == due.timeZone?.identifier else { return .uncertain }
        return .verified
    }
}
#endif
