import Foundation
import XCTest
@testable import AgentCore

final class ReminderTargetResolverTests: XCTestCase {
    private let resolver = ReminderTargetResolver()
    private let rechecker = ReminderTargetPreSaveRechecker()

    func testLocalSourceResolvesDeviceLocalDestination() {
        let result = resolver.resolve(
            ReminderTargetSnapshot(
                authorization: .fullAccess,
                sourceClass: .local,
                opaqueTargetIdentity: "opaque-local-target"
            )
        )

        guard case .resolved(let target) = result else {
            return XCTFail("Expected local reminder target to resolve")
        }
        XCTAssertEqual(target.destination, .deviceLocalStore)
    }

    func testCalDAVAndExchangeResolveSystemSyncedDestination() {
        for sourceClass in [ReminderTargetSourceClass.calDAV, .exchange] {
            let result = resolver.resolve(
                ReminderTargetSnapshot(
                    authorization: .fullAccess,
                    sourceClass: sourceClass,
                    opaqueTargetIdentity: "opaque-synced-target"
                )
            )

            guard case .resolved(let target) = result else {
                return XCTFail("Expected synced reminder target to resolve")
            }
            XCTAssertEqual(target.destination, .systemSyncedPersonalStore)
        }
    }

    func testUnsupportedSourceFailsClosed() {
        XCTAssertEqual(
            resolver.resolve(
                ReminderTargetSnapshot(
                    authorization: .fullAccess,
                    sourceClass: .unsupported,
                    opaqueTargetIdentity: "opaque-unsupported-target"
                )
            ),
            .unavailable(.unsupportedSource)
        )
    }

    func testPermissionStatesFailBeforeTargetResolution() {
        let cases: [(ReminderTargetAuthorizationState, ReminderTargetResolutionFailure)] = [
            (.setupRequired, .permissionSetupRequired),
            (.denied, .permissionDenied),
            (.restricted, .permissionRestricted),
            (.unsupported, .unsupportedAuthorization),
        ]

        for (authorization, expectedFailure) in cases {
            XCTAssertEqual(
                resolver.resolve(
                    ReminderTargetSnapshot(
                        authorization: authorization,
                        sourceClass: .local,
                        opaqueTargetIdentity: "must-not-authorize"
                    )
                ),
                .unavailable(expectedFailure)
            )
        }
    }

    func testMissingDefaultTargetAndEmptyBindingFailClosed() {
        XCTAssertEqual(
            resolver.resolve(ReminderTargetSnapshot(authorization: .fullAccess)),
            .unavailable(.defaultTargetUnavailable)
        )

        XCTAssertEqual(
            resolver.resolve(
                ReminderTargetSnapshot(
                    authorization: .fullAccess,
                    sourceClass: .local,
                    opaqueTargetIdentity: ""
                )
            ),
            .unavailable(.invalidTargetBinding)
        )
    }

    func testRecheckMatchesExactApprovedDestinationAndTarget() throws {
        let draft = try makeDraft(
            destination: .deviceLocalStore,
            targetIdentity: "opaque-target-a"
        )
        let current = resolver.resolve(
            ReminderTargetSnapshot(
                authorization: .fullAccess,
                sourceClass: .local,
                opaqueTargetIdentity: "opaque-target-a"
            )
        )

        XCTAssertEqual(rechecker.recheck(draft: draft, current: current), .matched)
    }

    func testRecheckFailsClosedWhenTargetIdentityChanges() throws {
        let draft = try makeDraft(
            destination: .deviceLocalStore,
            targetIdentity: "opaque-target-a"
        )
        let current = resolver.resolve(
            ReminderTargetSnapshot(
                authorization: .fullAccess,
                sourceClass: .local,
                opaqueTargetIdentity: "opaque-target-b"
            )
        )

        XCTAssertEqual(rechecker.recheck(draft: draft, current: current), .targetChanged)
    }

    func testRecheckFailsClosedWhenDestinationClassChanges() throws {
        let draft = try makeDraft(
            destination: .deviceLocalStore,
            targetIdentity: "opaque-target-a"
        )
        let current = resolver.resolve(
            ReminderTargetSnapshot(
                authorization: .fullAccess,
                sourceClass: .calDAV,
                opaqueTargetIdentity: "opaque-target-a"
            )
        )

        XCTAssertEqual(rechecker.recheck(draft: draft, current: current), .targetChanged)
    }

    func testRecheckPropagatesPermissionFailureWithoutMatch() throws {
        let draft = try makeDraft(
            destination: .deviceLocalStore,
            targetIdentity: "opaque-target-a"
        )

        XCTAssertEqual(
            rechecker.recheck(
                draft: draft,
                current: .unavailable(.permissionDenied)
            ),
            .unavailable(.permissionDenied)
        )
    }

    func testEventKitResolverSourceContainsNoReminderReadOrWriteAPIs() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let iosRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = iosRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("AgentCore")
            .appendingPathComponent("ReminderTargetResolver.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        for forbidden in [
            "fetchReminders(",
            "predicateForReminders(",
            "EKReminder(",
            "eventStore.save(",
            "eventStore.calendars(for:",
        ] {
            XCTAssertFalse(
                source.contains(forbidden),
                "V0 target resolution must not use existing-reminder reads, broader calendar enumeration, or saves: \(forbidden)"
            )
        }
    }

    private func makeDraft(
        destination: ActionDataDestination,
        targetIdentity: String
    ) throws -> CreateReminderDraft {
        let title = try CanonicalReminderTitle("Synthetic reminder")
        let due = try ReminderDueDate.resolve(
            year: 2026,
            month: 9,
            day: 2,
            hour: 9,
            minute: 30,
            timeZoneIdentifier: "Europe/Berlin"
        )
        guard let binding = ReminderTargetBinding(opaqueValue: targetIdentity) else {
            throw TestError.invalidBinding
        }

        return CreateReminderDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000341")!,
            title: title,
            due: due,
            effectiveDataSensitivity: .contextualPrivateData,
            actionDataDestination: destination,
            targetBinding: binding
        )
    }

    private enum TestError: Error {
        case invalidBinding
    }
}
