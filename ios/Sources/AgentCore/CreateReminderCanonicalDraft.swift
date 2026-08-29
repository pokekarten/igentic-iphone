import Foundation

public enum ReminderDueDateValidationError: Error, Equatable, Sendable {
    case invalidCalendarDate
    case unknownTimeZone
    case nonexistentLocalTime
    case repeatedLocalTime
}

public struct ReminderDueDate: Equatable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let timeZoneIdentifier: String
    public let resolvedUnixSeconds: Int64
    public let resolvedUTCOffsetSeconds: Int32

    public static func resolve(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZoneIdentifier: String
    ) throws -> ReminderDueDate {
        let hasExplicitIANAIdentity = timeZoneIdentifier == "GMT" || timeZoneIdentifier.contains("/")
        guard hasExplicitIANAIdentity,
              let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            throw ReminderDueDateValidationError.unknownTimeZone
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ReminderDueDateValidationError.invalidCalendarDate
        }

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let requested = DateComponents(
            calendar: utc,
            timeZone: utc.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: 0
        )
        guard let neutralReference = utc.date(from: requested),
              utc.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: neutralReference
              ) == requested.canonicalGregorianComponents else {
            throw ReminderDueDateValidationError.invalidCalendarDate
        }

        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let expected = requested.canonicalGregorianComponents
        let searchRadiusMinutes = 36 * 60
        var matches: [Date] = []
        matches.reserveCapacity(2)

        for minuteOffset in -searchRadiusMinutes...searchRadiusMinutes {
            let candidate = neutralReference.addingTimeInterval(TimeInterval(minuteOffset * 60))
            let projected = local.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: candidate
            )
            if projected == expected {
                matches.append(candidate)
                if matches.count > 1 {
                    throw ReminderDueDateValidationError.repeatedLocalTime
                }
            }
        }

        guard let resolved = matches.first else {
            throw ReminderDueDateValidationError.nonexistentLocalTime
        }
        let unixSeconds = Int64(resolved.timeIntervalSince1970.rounded())
        let offset = timeZone.secondsFromGMT(for: resolved)
        guard let offset32 = Int32(exactly: offset) else {
            throw ReminderDueDateValidationError.invalidCalendarDate
        }

        let roundTrip = local.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: Date(timeIntervalSince1970: TimeInterval(unixSeconds))
        )
        guard roundTrip == expected,
              timeZone.secondsFromGMT(for: resolved) == Int(offset32) else {
            throw ReminderDueDateValidationError.invalidCalendarDate
        }

        return ReminderDueDate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            timeZoneIdentifier: timeZoneIdentifier,
            resolvedUnixSeconds: unixSeconds,
            resolvedUTCOffsetSeconds: offset32
        )
    }
}

private extension DateComponents {
    var canonicalGregorianComponents: DateComponents {
        var value = DateComponents()
        value.year = year
        value.month = month
        value.day = day
        value.hour = hour
        value.minute = minute
        value.second = second
        return value
    }
}

public enum ReminderTitleValidationError: Error, Equatable, Sendable {
    case empty
    case unsafeDisplayScalar
}

public struct CanonicalReminderTitle: Equatable, Sendable {
    public let value: String

    public init(_ rawValue: String) throws {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping

        guard !normalized.isEmpty else {
            throw ReminderTitleValidationError.empty
        }
        guard normalized.unicodeScalars.allSatisfy(Self.isDisplaySafe) else {
            throw ReminderTitleValidationError.unsafeDisplayScalar
        }
        value = normalized
    }

    private static func isDisplaySafe(_ scalar: Unicode.Scalar) -> Bool {
        if scalar.properties.generalCategory == .control {
            return false
        }
        switch scalar.value {
        case 0x2028, 0x2029,
             0x061C, 0x200E, 0x200F,
             0x202A...0x202E,
             0x2066...0x2069,
             0x200B, 0x2060, 0xFEFF:
            return false
        default:
            return true
        }
    }
}

public enum ActionDataDestination: String, Equatable, Sendable {
    case none
    case deviceLocalStore
    case systemSyncedPersonalStore
    case unknown
}

struct ReminderTargetBinding: Equatable, Sendable {
    let opaqueValue: String

    init?(opaqueValue: String) {
        guard !opaqueValue.isEmpty else {
            return nil
        }
        self.opaqueValue = opaqueValue
    }
}

public struct CreateReminderDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: CanonicalReminderTitle
    public let due: ReminderDueDate
    public let effectiveDataSensitivity: DataSensitivityLevel
    public let actionDataDestination: ActionDataDestination

    let targetBinding: ReminderTargetBinding

    public var actionRisk: ActionRisk { .execute }
    public var toolName: String { "createReminder" }

    init(
        id: UUID = UUID(),
        title: CanonicalReminderTitle,
        due: ReminderDueDate,
        effectiveDataSensitivity: DataSensitivityLevel,
        actionDataDestination: ActionDataDestination,
        targetBinding: ReminderTargetBinding
    ) {
        self.id = id
        self.title = title
        self.due = due
        self.effectiveDataSensitivity = effectiveDataSensitivity
        self.actionDataDestination = actionDataDestination
        self.targetBinding = targetBinding
    }

    var fingerprint: String {
        let fields = [
            id.uuidString.lowercased(),
            toolName,
            title.value,
            String(due.year),
            String(due.month),
            String(due.day),
            String(due.hour),
            String(due.minute),
            "0",
            due.timeZoneIdentifier,
            String(due.resolvedUnixSeconds),
            String(due.resolvedUTCOffsetSeconds),
            String(effectiveDataSensitivity.rawValue),
            actionRisk.rawValue,
            actionDataDestination.rawValue,
            targetBinding.opaqueValue,
        ]
        return fields
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
    }
}
