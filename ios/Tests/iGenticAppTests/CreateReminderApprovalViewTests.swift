import AgentCore
import XCTest
@testable import iGenticApp

final class CreateReminderApprovalViewTests: XCTestCase {
    func testPresentationUsesExactCanonicalSubjectFields() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview()
        let presentation = CreateReminderApprovalPresentation(subject: subject)

        XCTAssertEqual(presentation.actionSummary, "Create one reminder")
        XCTAssertEqual(presentation.title, subject.title.value)
        XCTAssertEqual(
            presentation.dueSummary,
            "2026-09-01 12:00 (Europe/Berlin, UTC+02:00)"
        )
        XCTAssertEqual(presentation.destinationSummary, "Device-local storage")
        XCTAssertEqual(presentation.persistentWriteNotice, "This action writes persistent user data.")
        XCTAssertTrue(presentation.canApprove)
    }

    func testApproveProducesExplicitHumanReceiptForExactSubject() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview()
        let session = CreateReminderHumanApprovalSession(subject: subject)

        guard case .approved(let receipt) = session.approve(requestID: "human-approval-342") else {
            return XCTFail("Expected explicit approval receipt")
        }

        XCTAssertEqual(receipt.requestID, "human-approval-342")
        XCTAssertEqual(receipt.subject, subject)
        XCTAssertEqual(receipt.status, .approved)
        XCTAssertEqual(receipt.origin, .explicitHuman)
    }

    func testRejectProducesExplicitHumanRejectedReceipt() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview()
        let session = CreateReminderHumanApprovalSession(subject: subject)

        guard case .rejected(let receipt) = session.reject(requestID: "human-rejection-342") else {
            return XCTFail("Expected explicit rejection receipt")
        }

        XCTAssertEqual(receipt.subject, subject)
        XCTAssertEqual(receipt.status, .rejected)
        XCTAssertEqual(receipt.origin, .explicitHuman)
    }

    func testCancelProducesNoReceipt() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview()
        let session = CreateReminderHumanApprovalSession(subject: subject)

        XCTAssertEqual(session.cancel(), .cancelled)
    }

    func testUnknownDestinationCannotBeApproved() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview(destination: .unknown)
        let session = CreateReminderHumanApprovalSession(subject: subject)

        XCTAssertEqual(session.presentation.destinationSummary, "Unknown storage destination")
        XCTAssertFalse(session.presentation.canApprove)
        XCTAssertEqual(session.approve(requestID: "should-not-authorize"), .cancelled)
    }

    func testSyncedDestinationIsPresentedAsSyncedRatherThanLocal() {
        let subject = CreateReminderApprovalSubject.syntheticDiagnosticPreview(
            destination: .systemSyncedPersonalStore
        )
        let presentation = CreateReminderApprovalPresentation(subject: subject)

        XCTAssertEqual(presentation.destinationSummary, "System-synced personal storage")
        XCTAssertTrue(presentation.canApprove)
    }
}
