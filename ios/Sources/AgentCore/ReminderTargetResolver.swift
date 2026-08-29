import Foundation

#if canImport(EventKit)
import EventKit
#endif

package enum ReminderTargetAuthorizationState: Equatable, Sendable {
    case fullAccess
    case setupRequired
    case denied
    case restricted
    case unsupported
}

package enum ReminderTargetSourceClass: Equatable, Sendable {
    case local
    case calDAV
    case exchange
    case unsupported
}

package struct ReminderTargetSnapshot: Equatable, Sendable {
    package let authorization: ReminderTargetAuthorizationState
    package let sourceClass: ReminderTargetSourceClass?
    package let opaqueTargetIdentity: String?

    package init(
        authorization: ReminderTargetAuthorizationState,
        sourceClass: ReminderTargetSourceClass? = nil,
        opaqueTargetIdentity: String? = nil
    ) {
        self.authorization = authorization
        self.sourceClass = sourceClass
        self.opaqueTargetIdentity = opaqueTargetIdentity
    }
}

package enum ReminderTargetResolutionFailure: Equatable, Sendable {
    case permissionSetupRequired
    case permissionDenied
    case permissionRestricted
    case unsupportedAuthorization
    case defaultTargetUnavailable
    case unsupportedSource
    case invalidTargetBinding
}

package struct ResolvedReminderTarget: Equatable, Sendable {
    package let destination: ActionDataDestination
    let binding: ReminderTargetBinding

    init(destination: ActionDataDestination, binding: ReminderTargetBinding) {
        self.destination = destination
        self.binding = binding
    }
}

package enum ReminderTargetResolutionResult: Equatable, Sendable {
    case resolved(ResolvedReminderTarget)
    case unavailable(ReminderTargetResolutionFailure)
}

package struct ReminderTargetResolver: Sendable {
    package init() {}

    package func resolve(_ snapshot: ReminderTargetSnapshot) -> ReminderTargetResolutionResult {
        switch snapshot.authorization {
        case .fullAccess:
            break
        case .setupRequired:
            return .unavailable(.permissionSetupRequired)
        case .denied:
            return .unavailable(.permissionDenied)
        case .restricted:
            return .unavailable(.permissionRestricted)
        case .unsupported:
            return .unavailable(.unsupportedAuthorization)
        }

        guard let sourceClass = snapshot.sourceClass,
              let opaqueTargetIdentity = snapshot.opaqueTargetIdentity else {
            return .unavailable(.defaultTargetUnavailable)
        }

        let destination: ActionDataDestination
        switch sourceClass {
        case .local:
            destination = .deviceLocalStore
        case .calDAV, .exchange:
            destination = .systemSyncedPersonalStore
        case .unsupported:
            return .unavailable(.unsupportedSource)
        }

        guard let binding = ReminderTargetBinding(opaqueValue: opaqueTargetIdentity) else {
            return .unavailable(.invalidTargetBinding)
        }

        return .resolved(
            ResolvedReminderTarget(
                destination: destination,
                binding: binding
            )
        )
    }
}

package enum ReminderTargetRecheckResult: Equatable, Sendable {
    case matched
    case targetChanged
    case unavailable(ReminderTargetResolutionFailure)
}

package struct ReminderTargetPreSaveRechecker: Sendable {
    package init() {}

    package func recheck(
        draft: CreateReminderDraft,
        current: ReminderTargetResolutionResult
    ) -> ReminderTargetRecheckResult {
        switch current {
        case .unavailable(let failure):
            return .unavailable(failure)
        case .resolved(let target):
            guard target.destination == draft.actionDataDestination,
                  target.binding == draft.targetBinding else {
                return .targetChanged
            }
            return .matched
        }
    }
}

#if canImport(EventKit)
package struct EventKitReminderTargetResolver {
    private let eventStore: EKEventStore
    private let resolver: ReminderTargetResolver

    package init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
        self.resolver = ReminderTargetResolver()
    }

    package func resolve() -> ReminderTargetResolutionResult {
        let authorization = Self.authorizationState(
            EKEventStore.authorizationStatus(for: .reminder)
        )

        guard authorization == .fullAccess else {
            return resolver.resolve(
                ReminderTargetSnapshot(authorization: authorization)
            )
        }

        guard let calendar = eventStore.defaultCalendarForNewReminders() else {
            return resolver.resolve(
                ReminderTargetSnapshot(authorization: .fullAccess)
            )
        }

        let source = calendar.source
        let targetBinding = Self.processLocalTargetBinding(
            calendarIdentifier: calendar.calendarIdentifier,
            sourceIdentifier: source.sourceIdentifier
        )

        return resolver.resolve(
            ReminderTargetSnapshot(
                authorization: .fullAccess,
                sourceClass: Self.sourceClass(source.sourceType),
                opaqueTargetIdentity: targetBinding
            )
        )
    }

    private static func authorizationState(
        _ status: EKAuthorizationStatus
    ) -> ReminderTargetAuthorizationState {
        if status == .fullAccess {
            return .fullAccess
        }

        switch status {
        case .notDetermined:
            return .setupRequired
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .writeOnly:
            // EventKit exposes write-only authorization for events, not reminders.
            // Treat any such reminder status as unsupported rather than assuming access.
            return .unsupported
        default:
            return .unsupported
        }
    }

    private static func sourceClass(_ sourceType: EKSourceType) -> ReminderTargetSourceClass {
        switch sourceType {
        case .local:
            return .local
        case .calDAV:
            return .calDAV
        case .exchange:
            return .exchange
        default:
            return .unsupported
        }
    }

    private static func processLocalTargetBinding(
        calendarIdentifier: String,
        sourceIdentifier: String
    ) -> String {
        // Swift's Hasher is randomly seeded per process. The same EventKit target
        // therefore compares equal during one execution transaction without
        // persisting or exposing raw calendar/source identifiers. A process
        // restart deliberately invalidates the binding and requires a fresh draft.
        var first = Hasher()
        first.combine("iGentic.reminder-target.v1.a")
        first.combine(calendarIdentifier)
        first.combine(sourceIdentifier)

        var second = Hasher()
        second.combine("iGentic.reminder-target.v1.b")
        second.combine(sourceIdentifier)
        second.combine(calendarIdentifier)

        return String(UInt(bitPattern: first.finalize()), radix: 16)
            + ":"
            + String(UInt(bitPattern: second.finalize()), radix: 16)
    }
}
#endif
