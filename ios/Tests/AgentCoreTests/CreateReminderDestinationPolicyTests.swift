import Foundation
import XCTest
@testable import AgentCore

final class CreateReminderDestinationPolicyTests: XCTestCase {
    private let policy = CreateReminderDestinationPolicy()

    private func draft(
        sensitivity: DataSensitivityLevel = .contextualPrivateData,
        destination: ActionDataDestination
    ) throws -> CreateReminderDraft {
        CreateReminderDraft(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000341")!,
            title: try CanonicalReminderTitle("Test reminder"),
            due: try ReminderDueDate.resolve(
                year: 2026,
                month: 9,
                day: 1,
                hour: 12,
                minute: 0,
                timeZoneIdentifier: "Europe/Berlin"
            ),
            effectiveDataSensitivity: sensitivity,
            actionDataDestination: destination,
            targetBinding: ReminderTargetBinding(opaqueValue: "opaque-target-policy-test")!
        )
    }

    func testLocalOnlyAllowsResolvedDeviceLocalStore() throws {
        XCTAssertEqual(
            policy.evaluate(try draft(destination: .deviceLocalStore), privacyMode: .localOnly),
            .allowed
        )
    }

    func testLocalOnlyBlocksSystemSyncedPersonalStore() throws {
        XCTAssertEqual(
            policy.evaluate(try draft(destination: .systemSyncedPersonalStore), privacyMode: .localOnly),
            .blocked(.localOnlyRequiresDeviceLocalStore)
        )
    }

    func testUnknownAndMissingDestinationsFailClosed() throws {
        XCTAssertEqual(
            policy.evaluate(try draft(destination: .unknown), privacyMode: .trustedDevices),
            .blocked(.unknownDestination)
        )
        XCTAssertEqual(
            policy.evaluate(try draft(destination: .none), privacyMode: .trustedDevices),
            .blocked(.missingDestination)
        )
    }

    func testRestrictedSensitiveDataCannotUseSyncedStore() throws {
        XCTAssertEqual(
            policy.evaluate(
                try draft(
                    sensitivity: .restrictedSensitiveData,
                    destination: .systemSyncedPersonalStore
                ),
                privacyMode: .trustedDevices
            ),
            .blocked(.restrictedSensitiveDataRequiresDeviceLocalStore)
        )
    }

    func testRestrictedSensitiveDataMayContinueWithDeviceLocalStore() throws {
        XCTAssertEqual(
            policy.evaluate(
                try draft(
                    sensitivity: .restrictedSensitiveData,
                    destination: .deviceLocalStore
                ),
                privacyMode: .localOnly
            ),
            .allowed
        )
    }

    func testContextualAndHighlyPrivateDataMayUseSyncedStoreWhenPrivacyModePermits() throws {
        XCTAssertEqual(
            policy.evaluate(
                try draft(
                    sensitivity: .contextualPrivateData,
                    destination: .systemSyncedPersonalStore
                ),
                privacyMode: .trustedDevices
            ),
            .allowed
        )
        XCTAssertEqual(
            policy.evaluate(
                try draft(
                    sensitivity: .highlyPrivateData,
                    destination: .systemSyncedPersonalStore
                ),
                privacyMode: .trustedDevices
            ),
            .allowed
        )
    }
}
