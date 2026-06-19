import XCTest
@testable import AgentCore

final class RuntimeBudgetTests: XCTestCase {
    func testRuntimeBudgetStoresDeterministicMetadataOnlyValues() {
        let budget = RuntimeBudget(
            executionClass: .small,
            expectedLocality: .localOnly,
            estimatedMemoryClass: .moderate,
            reasons: [
                "Synthetic diagnostic workload.",
                "No hardware measurement performed.",
            ]
        )

        XCTAssertEqual(budget.executionClass, .small)
        XCTAssertEqual(budget.expectedLocality, .localOnly)
        XCTAssertEqual(budget.estimatedMemoryClass, .moderate)
        XCTAssertFalse(budget.requiresExternalRuntime)
        XCTAssertEqual(
            budget.metadataLines,
            [
                "executionClass=small",
                "expectedLocality=local-only",
                "estimatedMemoryClass=moderate",
                "reasonCount=2",
                "reason[0]=Synthetic diagnostic workload.",
                "reason[1]=No hardware measurement performed.",
            ]
        )
    }

    func testExternalRuntimeRequirementIsExplicit() {
        let budget = RuntimeBudget(
            executionClass: .large,
            expectedLocality: .externalRequired,
            estimatedMemoryClass: .high
        )

        XCTAssertTrue(budget.requiresExternalRuntime)
        XCTAssertEqual(budget.reasons, [])
        XCTAssertEqual(budget.metadataLines.last, "reasonCount=0")
    }

    func testExecutionAndMemoryClassesHaveStableOrdering() {
        XCTAssertEqual(RuntimeExecutionClass.allCases.sorted(), [.tiny, .small, .large])
        XCTAssertEqual(RuntimeMemoryClass.allCases.sorted(), [.low, .moderate, .high])
    }

    func testRuntimeBudgetEqualityIncludesReasons() {
        let first = RuntimeBudget(
            executionClass: .tiny,
            expectedLocality: .trustedDevice,
            estimatedMemoryClass: .low,
            reasons: ["Synthetic trusted-device plan."]
        )
        let second = RuntimeBudget(
            executionClass: .tiny,
            expectedLocality: .trustedDevice,
            estimatedMemoryClass: .low,
            reasons: ["Synthetic trusted-device plan."]
        )

        XCTAssertEqual(first, second)
    }
}
