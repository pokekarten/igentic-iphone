import XCTest
@testable import AgentCore

final class RuntimeBudgetAssessorTests: XCTestCase {
    private let assessor = RuntimeBudgetAssessor()

    func testFindFileMapsToTinyLocalLow() {
        let task = TaskRequest(
            userText: "Locate the project README.",
            intent: .findFile,
            dataClassification: .publicDefault,
            actionRisk: .read,
            requestedDelegationTarget: .localDevice
        )

        let budget = assessor.assess(task, privacyMode: .trustedDevices)

        XCTAssertEqual(budget.executionClass, .tiny)
        XCTAssertEqual(budget.expectedLocality, .localOnly)
        XCTAssertEqual(budget.estimatedMemoryClass, .low)
        XCTAssertEqual(budget.reasons, ["Intent family: lookup -> tiny."])
    }

    func testDataClassificationEscalatesMemoryOneStep() {
        let task = TaskRequest(
            userText: "Find the most likely matching file.",
            intent: .findFile,
            dataClassification: DataClassification(level: .lowRiskAppData, reason: "Synthetic low-risk app data."),
            actionRisk: .read,
            requestedDelegationTarget: .localDevice
        )

        let budget = assessor.assess(task, privacyMode: .trustedDevices)

        XCTAssertEqual(budget.executionClass, .tiny)
        XCTAssertEqual(budget.expectedLocality, .localOnly)
        XCTAssertEqual(budget.estimatedMemoryClass, .moderate)
        XCTAssertEqual(
            budget.reasons,
            [
                "Intent family: lookup -> tiny.",
                "Data classification escalates memory to moderate.",
            ]
        )
    }

    func testActionRiskEscalatesExecutionClass() {
        let task = TaskRequest(
            userText: "Summarize the note and execute the follow-up.",
            intent: .summarizeNote,
            dataClassification: .publicDefault,
            actionRisk: .execute,
            requestedDelegationTarget: .localDevice
        )

        let budget = assessor.assess(task, privacyMode: .trustedDevices)

        XCTAssertEqual(budget.executionClass, .large)
        XCTAssertEqual(budget.expectedLocality, .localOnly)
        XCTAssertEqual(budget.estimatedMemoryClass, .moderate)
        XCTAssertEqual(
            budget.reasons,
            [
                "Intent family: bounded synthesis -> small.",
                "Action risk escalates execution class to large.",
            ]
        )
    }

    func testLocalTrustedAndExternalLocalityMappingsStayDeterministic() {
        let localTask = TaskRequest(
            userText: "Find a file locally.",
            intent: .findFile,
            dataClassification: .publicDefault,
            actionRisk: .read,
            requestedDelegationTarget: .localDevice
        )
        let trustedTask = TaskRequest(
            userText: "Look up a file via a trusted machine.",
            intent: .findFile,
            dataClassification: .publicDefault,
            actionRisk: .read,
            requestedDelegationTarget: .trustedMac
        )
        let externalTask = TaskRequest(
            userText: "Request approval for external execution.",
            intent: .requestApproval,
            dataClassification: .publicDefault,
            actionRisk: .read,
            requestedDelegationTarget: .externalProvider
        )

        let localBudget = assessor.assess(localTask, privacyMode: .localOnly)
        let trustedBudget = assessor.assess(trustedTask, privacyMode: .trustedDevices)
        let externalBudget = assessor.assess(externalTask, privacyMode: .externalAI)
        let externalBudgetRepeat = assessor.assess(externalTask, privacyMode: .externalAI)

        XCTAssertEqual(localBudget.expectedLocality, .localOnly)
        XCTAssertEqual(trustedBudget.expectedLocality, .trustedDevice)
        XCTAssertEqual(externalBudget.expectedLocality, .externalRequired)
        XCTAssertTrue(externalBudget.requiresExternalRuntime)
        XCTAssertEqual(externalBudget, externalBudgetRepeat)
    }

    func testReasonsAreOrderedAndStableForTheFullEscalationPath() {
        let task = TaskRequest(
            userText: "Summarize the note, escalate risk, and prepare for external runtime.",
            intent: .summarizeNote,
            dataClassification: DataClassification(level: .lowRiskAppData, reason: "Synthetic low-risk app data."),
            actionRisk: .execute,
            requestedDelegationTarget: .externalProvider
        )

        let budget = assessor.assess(task, privacyMode: .externalAI)
        let secondBudget = assessor.assess(task, privacyMode: .externalAI)

        XCTAssertEqual(budget, secondBudget)
        XCTAssertEqual(budget.executionClass, .large)
        XCTAssertEqual(budget.expectedLocality, .externalRequired)
        XCTAssertEqual(budget.estimatedMemoryClass, .high)
        XCTAssertTrue(budget.requiresExternalRuntime)
        XCTAssertEqual(
            budget.reasons,
            [
                "Intent family: bounded synthesis -> small.",
                "Data classification escalates memory to high.",
                "Action risk escalates execution class to large.",
                "Requested delegation target maps locality to external-required.",
                "Policy result requires an external runtime.",
            ]
        )
    }

    func testLocalOnlyCapsExternalProviderWithoutTurningIntoRouting() {
        let task = TaskRequest(
            userText: "Try to route externally, but keep it local.",
            intent: .findFile,
            dataClassification: .publicDefault,
            actionRisk: .read,
            requestedDelegationTarget: .externalProvider
        )

        let budget = assessor.assess(task, privacyMode: .localOnly)

        XCTAssertEqual(budget.executionClass, .tiny)
        XCTAssertEqual(budget.expectedLocality, .localOnly)
        XCTAssertFalse(budget.requiresExternalRuntime)
        XCTAssertEqual(
            budget.reasons,
            [
                "Intent family: lookup -> tiny.",
                "Requested delegation target maps locality to trusted-device.",
                "Privacy mode constrains locality to local-only.",
            ]
        )
    }
}
