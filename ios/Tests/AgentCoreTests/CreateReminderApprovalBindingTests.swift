import Foundation
import XCTest
@testable import AgentCore

final class CreateReminderApprovalBindingTests: XCTestCase {
    private func due(minute: Int = 0) throws -> ReminderDueDate {
        try ReminderDueDate.resolve(
            year: 2026,
            month: 9,
            day: 1,
            hour: 12,
            minute: minute,
            timeZoneIdentifier: "Europe/Berlin"
        )
    }

    private func draft(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000342")!,
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

    private func receipt(
        for draft: CreateReminderDraft,
        requestID: String = "approval-342",
        status: ApprovalStatus = .approved,
        origin: CreateReminderApprovalOrigin = .explicitHuman
    ) -> CreateReminderBoundApprovalReceipt {
        CreateReminderBoundApprovalReceipt(
            requestID: requestID,
            subject: CreateReminderApprovalSubject(draft: draft),
            status: status,
            origin: origin
        )
    }

    func testSubjectIsDerivedFromExactCanonicalDraft() throws {
        let value = try draft()
        let subject = CreateReminderApprovalSubject(draft: value)

        XCTAssertEqual(subject.draftID, value.id)
        XCTAssertEqual(subject.draftFingerprint, value.fingerprint)
        XCTAssertEqual(subject.title, value.title)
        XCTAssertEqual(subject.due, value.due)
        XCTAssertEqual(subject.effectiveDataSensitivity, value.effectiveDataSensitivity)
        XCTAssertEqual(subject.actionRisk, .execute)
        XCTAssertEqual(subject.actionDataDestination, value.actionDataDestination)
    }

    func testExplicitHumanApprovalMayIssueProductionCapability() throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let issuer = CreateReminderCapabilityIssuer(ledger: ledger)
        let value = try draft()
        let capabilityID = UUID(uuidString: "00000000-0000-0000-0000-000000000999")!

        let result = issuer.issue(
            draft: value,
            approval: receipt(for: value),
            privacyMode: .localOnly,
            use: .productionSideEffect,
            capabilityID: capabilityID
        )

        guard case .issued(let capability) = result else {
            return XCTFail("Expected a capability for exact explicit-human approval")
        }
        XCTAssertEqual(capability.id, capabilityID)
        XCTAssertEqual(capability.draftID, value.id)
        XCTAssertEqual(capability.draftFingerprint, value.fingerprint)
        XCTAssertEqual(capability.approvalRequestID, "approval-342")
        XCTAssertEqual(capability.targetBinding, value.targetBinding)
        XCTAssertEqual(ledger.state(for: capabilityID), .issued)
    }

    func testSyntheticApprovalIsRestrictedToFakeExecutorUse() throws {
        let value = try draft()
        let synthetic = receipt(for: value, origin: .syntheticTest)

        XCTAssertEqual(
            CreateReminderCapabilityIssuer().issue(
                draft: value,
                approval: synthetic,
                privacyMode: .localOnly,
                use: .productionSideEffect
            ),
            .rejected(.syntheticApprovalNotAllowedForProduction)
        )

        guard case .issued = CreateReminderCapabilityIssuer().issue(
            draft: value,
            approval: synthetic,
            privacyMode: .localOnly,
            use: .fakeExecutorTest
        ) else {
            return XCTFail("Synthetic approval should remain usable for fake-only tests")
        }
    }

    func testPendingRejectedAndNotRequiredCannotIssueCapability() throws {
        let value = try draft()

        for status in [ApprovalStatus.pending, .rejected, .notRequired] {
            XCTAssertEqual(
                CreateReminderCapabilityIssuer().issue(
                    draft: value,
                    approval: receipt(for: value, status: status),
                    privacyMode: .localOnly,
                    use: .productionSideEffect
                ),
                .rejected(.approvalNotApproved(status))
            )
        }
    }

    func testAnyAuthorityMutationInvalidatesBoundApproval() throws {
        let original = try draft()
        let boundApproval = receipt(for: original)
        let changedDrafts = [
            try draft(title: "Andere Aufgabe"),
            try draft(due: due(minute: 1)),
            try draft(sensitivity: .highlyPrivateData),
            try draft(destination: .systemSyncedPersonalStore),
            try draft(binding: "opaque-target-B"),
        ]

        for changed in changedDrafts {
            XCTAssertEqual(
                CreateReminderCapabilityIssuer().issue(
                    draft: changed,
                    approval: boundApproval,
                    privacyMode: .trustedDevices,
                    use: .productionSideEffect
                ),
                .rejected(.approvalSubjectMismatch)
            )
        }
    }

    func testEmptyApprovalRequestIdentityFailsClosed() throws {
        let value = try draft()

        XCTAssertEqual(
            CreateReminderCapabilityIssuer().issue(
                draft: value,
                approval: receipt(for: value, requestID: "  \n"),
                privacyMode: .localOnly,
                use: .productionSideEffect
            ),
            .rejected(.emptyApprovalRequestID)
        )
    }

    func testDestinationPolicyStillAppliesBeforeCapabilityIssuance() throws {
        let value = try draft(destination: .systemSyncedPersonalStore)

        XCTAssertEqual(
            CreateReminderCapabilityIssuer().issue(
                draft: value,
                approval: receipt(for: value),
                privacyMode: .localOnly,
                use: .productionSideEffect
            ),
            .rejected(.destinationBlocked(.localOnlyRequiresDeviceLocalStore))
        )
    }

    func testApprovalRequestCannotMintMultipleCapabilities() throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let issuer = CreateReminderCapabilityIssuer(ledger: ledger)
        let value = try draft()
        let firstCapabilityID = UUID(uuidString: "00000000-0000-0000-0000-000000000997")!
        let secondCapabilityID = UUID(uuidString: "00000000-0000-0000-0000-000000000996")!

        let first = issuer.issue(
            draft: value,
            approval: receipt(for: value, requestID: " approval-342 "),
            privacyMode: .localOnly,
            use: .productionSideEffect,
            capabilityID: firstCapabilityID
        )

        guard case .issued(let capability) = first else {
            return XCTFail("Expected first approval use to issue a capability")
        }
        XCTAssertEqual(capability.approvalRequestID, "approval-342")

        XCTAssertEqual(
            issuer.issue(
                draft: value,
                approval: receipt(for: value, requestID: "approval-342"),
                privacyMode: .localOnly,
                use: .productionSideEffect,
                capabilityID: secondCapabilityID
            ),
            .rejected(.approvalRequestAlreadyUsed)
        )
        XCTAssertNil(ledger.state(for: secondCapabilityID))
    }

    func testDuplicateCapabilityIdentityFailsClosed() throws {
        let ledger = SafeActionExecutionCapabilityLedger()
        let issuer = CreateReminderCapabilityIssuer(ledger: ledger)
        let value = try draft()
        let capabilityID = UUID(uuidString: "00000000-0000-0000-0000-000000000998")!

        guard case .issued = issuer.issue(
            draft: value,
            approval: receipt(for: value),
            privacyMode: .localOnly,
            use: .productionSideEffect,
            capabilityID: capabilityID
        ) else {
            return XCTFail("Expected first issuance to succeed")
        }

        XCTAssertEqual(
            issuer.issue(
                draft: value,
                approval: receipt(for: value),
                privacyMode: .localOnly,
                use: .productionSideEffect,
                capabilityID: capabilityID
            ),
            .rejected(.duplicateCapabilityID)
        )
    }
}
