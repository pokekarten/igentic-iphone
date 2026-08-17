#if canImport(SwiftUI)
import AgentCore
import XCTest
@testable import iGenticApp

final class AppActionApprovalPolicyPresentationTests: XCTestCase {
    func testEffectiveApprovalPolicyFieldsUseInjectedPolicy() {
        let policy = AppActionApprovalPolicy(
            schemaVersion: 4,
            rules: [
                .init(actionKind: .sendMessage, requiresApproval: true),
                .init(actionKind: .deleteRecord, requiresApproval: false),
                .init(actionKind: .updateRecord, requiresApproval: true),
                .init(actionKind: .exportData, requiresApproval: false)
            ]
        )

        let fields = Dictionary(
            uniqueKeysWithValues: DiagnosticViewState
                .effectiveApprovalPolicyFields(for: policy)
                .map { ($0.label, $0.value) }
        )

        XCTAssertEqual(fields["Policy schema"], "v4")
        XCTAssertEqual(fields["Send message additional approval"], "Yes")
        XCTAssertEqual(fields["Delete record additional approval"], "No")
        XCTAssertEqual(fields["Update record additional approval"], "Yes")
        XCTAssertEqual(fields["Export data additional approval"], "No")
    }
}
#endif
