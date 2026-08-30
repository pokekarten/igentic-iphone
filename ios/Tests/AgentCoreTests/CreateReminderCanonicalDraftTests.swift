import Foundation
import XCTest
@testable import AgentCore

final class CreateReminderCanonicalDraftTests: XCTestCase {
    private func due(
        year: Int = 2026,
        month: Int = 1,
        day: Int = 15,
        hour: Int = 12,
        minute: Int = 30,
        zone: String = "Europe/Berlin"
    ) throws -> ReminderDueDate {
        try ReminderDueDate.resolve(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            timeZoneIdentifier: zone
        )
    }

    private func draft(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String = "Pflanzen gießen",
        due: ReminderDueDate? = nil,
        sensitivity: DataSensitivityLevel = .contextualPrivateData,
        destination: ActionDataDestination = .deviceLocalStore,
        binding: String = "opaque-target-A"
    ) throws -> CreateReminderDraft {
        CreateReminderDraft(
            id: id,
            title: try CanonicalReminderTitle(title),
            due: try due ?? self.due(),
            effectiveDataSensitivity: sensitivity,
            actionDataDestination: destination,
            targetBinding: ReminderTargetBinding(opaqueValue: binding)!
        )
    }

    func testOrdinaryDueDateFreezesUniqueInstantAndOffset() throws {
        let value = try due()
        XCTAssertEqual(value.timeZoneIdentifier, "Europe/Berlin")
        XCTAssertEqual(value.resolvedUTCOffsetSeconds, 3600)
        XCTAssertEqual(value.resolvedUnixSeconds % 60, 0)
    }

    func testImpossibleGregorianDateIsRejected() {
        XCTAssertThrowsError(try due(month: 2, day: 30)) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .invalidCalendarDate)
        }
    }

    func testUnknownTimeZoneIsRejected() {
        XCTAssertThrowsError(try due(zone: "Mars/Olympus_Mons")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .unknownTimeZone)
        }
    }

    func testFoundationFixedOffsetAndAbbreviationIdentifiersAreRejected() {
        XCTAssertThrowsError(try due(zone: "GMT+0200")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .unknownTimeZone)
        }
        XCTAssertThrowsError(try due(zone: "PST")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .unknownTimeZone)
        }
        XCTAssertNoThrow(try due(zone: "Etc/UTC"))
    }

    func testBerlinGapAndOverlapAreRejected() {
        XCTAssertThrowsError(try due(month: 3, day: 29, hour: 2, minute: 30)) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .nonexistentLocalTime)
        }
        XCTAssertThrowsError(try due(month: 10, day: 25, hour: 2, minute: 30)) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .repeatedLocalTime)
        }
    }

    func testNewYorkGapAndOverlapAreRejected() {
        XCTAssertThrowsError(try due(month: 3, day: 8, hour: 2, minute: 30, zone: "America/New_York")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .nonexistentLocalTime)
        }
        XCTAssertThrowsError(try due(month: 11, day: 1, hour: 1, minute: 30, zone: "America/New_York")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .repeatedLocalTime)
        }
    }

    func testLordHoweThirtyMinuteGapAndOverlapAreRejected() {
        XCTAssertThrowsError(try due(month: 10, day: 4, hour: 2, minute: 15, zone: "Australia/Lord_Howe")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .nonexistentLocalTime)
        }
        XCTAssertThrowsError(try due(month: 4, day: 5, hour: 1, minute: 45, zone: "Australia/Lord_Howe")) { error in
            XCTAssertEqual(error as? ReminderDueDateValidationError, .repeatedLocalTime)
        }
    }

    func testTitleUsesTrimThenNFCAndPreservesEmojiZWJ() throws {
        let composed = try CanonicalReminderTitle("  Café 👩‍💻  ")
        let decomposed = try CanonicalReminderTitle("Cafe\u{301} 👩‍💻")
        XCTAssertEqual(composed, decomposed)
        XCTAssertEqual(composed.value, "Café 👩‍💻")
    }

    func testTitleRejectsEmptyControlsBidiAndForbiddenZeroWidthScalars() {
        XCTAssertThrowsError(try CanonicalReminderTitle(" \n\t "))
        XCTAssertThrowsError(try CanonicalReminderTitle("line\nbreak"))
        XCTAssertThrowsError(try CanonicalReminderTitle("abc\u{202E}def"))
        XCTAssertThrowsError(try CanonicalReminderTitle("abc\u{200B}def"))
        XCTAssertThrowsError(try CanonicalReminderTitle("abc\u{2060}def"))
        XCTAssertThrowsError(try CanonicalReminderTitle("abc\u{FEFF}def"))
    }

    func testTitleRejectsOtherDefaultIgnorableDisplayAliases() {
        XCTAssertThrowsError(try CanonicalReminderTitle("pay\u{00AD}load")) // SOFT HYPHEN
        XCTAssertThrowsError(try CanonicalReminderTitle("pay\u{034F}load")) // COMBINING GRAPHEME JOINER
        XCTAssertThrowsError(try CanonicalReminderTitle("pay\u{180E}load")) // MONGOLIAN VOWEL SEPARATOR
        XCTAssertThrowsError(try CanonicalReminderTitle("pay\u{3164}load")) // HANGUL FILLER
        XCTAssertThrowsError(try CanonicalReminderTitle("pay\u{E0020}load")) // TAG SPACE
    }

    func testTitlePreservesEmojiVariationSelector() throws {
        XCTAssertEqual(try CanonicalReminderTitle("✈️").value, "✈️")
    }

    func testFingerprintIsStableForCanonicallyEquivalentTitles() throws {
        let first = try draft(title: "Café")
        let second = try draft(title: "Cafe\u{301}")
        XCTAssertEqual(first.fingerprint, second.fingerprint)
    }

    func testEveryAuthorityFieldMutationChangesFingerprint() throws {
        let baseDue = try due()
        let base = try draft(due: baseDue)
        let changedDue = try due(minute: 31)

        XCTAssertNotEqual(base.fingerprint, try draft(title: "Andere Aufgabe", due: baseDue).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: changedDue).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: baseDue, sensitivity: .highlyPrivateData).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: baseDue, destination: .systemSyncedPersonalStore).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: baseDue, binding: "opaque-target-B").fingerprint)
    }

    func testResolvedInstantOffsetAndZoneParticipateInFingerprint() throws {
        let original = try due()
        let base = try draft(due: original)

        let shiftedInstant = ReminderDueDate(
            year: original.year,
            month: original.month,
            day: original.day,
            hour: original.hour,
            minute: original.minute,
            timeZoneIdentifier: original.timeZoneIdentifier,
            resolvedUnixSeconds: original.resolvedUnixSeconds + 60,
            resolvedUTCOffsetSeconds: original.resolvedUTCOffsetSeconds
        )
        let shiftedOffset = ReminderDueDate(
            year: original.year,
            month: original.month,
            day: original.day,
            hour: original.hour,
            minute: original.minute,
            timeZoneIdentifier: original.timeZoneIdentifier,
            resolvedUnixSeconds: original.resolvedUnixSeconds,
            resolvedUTCOffsetSeconds: original.resolvedUTCOffsetSeconds + 60
        )
        let changedZone = ReminderDueDate(
            year: original.year,
            month: original.month,
            day: original.day,
            hour: original.hour,
            minute: original.minute,
            timeZoneIdentifier: "Etc/GMT-1",
            resolvedUnixSeconds: original.resolvedUnixSeconds,
            resolvedUTCOffsetSeconds: original.resolvedUTCOffsetSeconds
        )

        XCTAssertNotEqual(base.fingerprint, try draft(due: shiftedInstant).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: shiftedOffset).fingerprint)
        XCTAssertNotEqual(base.fingerprint, try draft(due: changedZone).fingerprint)
    }

    func testZWNJAndZWJRemainAccepted() throws {
        XCTAssertEqual(try CanonicalReminderTitle("می\u{200C}روم").value, "می\u{200C}روم")
        XCTAssertEqual(try CanonicalReminderTitle("👩‍💻").value, "👩‍💻")
    }

    func testFixedToolAndExecuteRiskCannotBeLoweredByCaller() throws {
        let value = try draft()
        XCTAssertEqual(value.toolName, "createReminder")
        XCTAssertEqual(value.actionRisk, .execute)
        XCTAssertTrue(value.actionRisk.requiresApproval)
    }
}
