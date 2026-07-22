import XCTest
@testable import AgentCore

final class ModelSelectionEngineTests: XCTestCase {
    private let policy = ModelSelectionPolicy.v1

    func testTieBreakLowestLatency() throws {
        let request = ModelSelectionRequest(latencyBudget: .low, contextSize: 2048, toolUsageRequired: true)
        let candidates = [
            ModelCandidate(
                modelID: "model-alpha",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 120,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-beta",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 80,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-gamma",
                evaluationScore: 0.70,
                latencyScore: 0.90,
                capabilityMatch: 0.30,
                latencyMS: 40,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            )
        ]

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: policy)

        XCTAssertEqual(result.selectedModelID, "model-beta")
        XCTAssertEqual(result.reason, .lowestLatencyValidModel)
        let score = try XCTUnwrap(result.score)
        XCTAssertEqual(score, 0.73, accuracy: 0.000001)
    }

    func testTieBreakSafeRefusal() throws {
        let request = ModelSelectionRequest(latencyBudget: .low, contextSize: 2048, toolUsageRequired: true)
        let candidates = [
            ModelCandidate(
                modelID: "model-alpha",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 100,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-beta",
                evaluationScore: 0.90,
                latencyScore: 0.80,
                capabilityMatch: 0.40,
                latencyMS: 100,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-gamma",
                evaluationScore: 0.60,
                latencyScore: 0.70,
                capabilityMatch: 0.30,
                latencyMS: 60,
                contextSize: 2048,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            )
        ]

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: policy)

        XCTAssertEqual(result.selectedModelID, "model-safe-refusal")
        XCTAssertEqual(result.reason, .safeRefusalModel)
        let score = try XCTUnwrap(result.score)
        XCTAssertEqual(score, 0.73, accuracy: 0.000001)
    }

    func testHardConstraintExcludesBestScore() throws {
        let request = ModelSelectionRequest(latencyBudget: .low, contextSize: 4096, toolUsageRequired: true)
        let candidates = [
            ModelCandidate(
                modelID: "model-over-limit",
                evaluationScore: 0.99,
                latencyScore: 0.99,
                capabilityMatch: 1.00,
                latencyMS: 50,
                contextSize: 4096,
                maxContextTokens: 2048,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-valid",
                evaluationScore: 0.80,
                latencyScore: 0.60,
                capabilityMatch: 0.90,
                latencyMS: 70,
                contextSize: 4096,
                maxContextTokens: 8192,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            )
        ]

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: policy)

        XCTAssertEqual(result.selectedModelID, "model-valid")
        XCTAssertEqual(result.reason, .highestWeightedScore)
        let score = try XCTUnwrap(result.score)
        XCTAssertEqual(score, 0.79, accuracy: 0.000001)
    }

    func testUniqueWinnerControl() throws {
        let request = ModelSelectionRequest(latencyBudget: .low, contextSize: 1024, toolUsageRequired: true)
        let candidates = [
            ModelCandidate(
                modelID: "model-alpha",
                evaluationScore: 0.70,
                latencyScore: 0.60,
                capabilityMatch: 0.50,
                latencyMS: 90,
                contextSize: 1024,
                maxContextTokens: 4096,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-delta",
                evaluationScore: 0.95,
                latencyScore: 0.90,
                capabilityMatch: 0.95,
                latencyMS: 65,
                contextSize: 1024,
                maxContextTokens: 4096,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            ),
            ModelCandidate(
                modelID: "model-epsilon",
                evaluationScore: 0.80,
                latencyScore: 0.70,
                capabilityMatch: 0.60,
                latencyMS: 60,
                contextSize: 1024,
                maxContextTokens: 4096,
                latencyBudgetClass: .high,
                toolUsageSupported: true
            )
        ]

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: policy)

        XCTAssertEqual(result.selectedModelID, "model-delta")
        XCTAssertEqual(result.reason, .highestWeightedScore)
        let score = try XCTUnwrap(result.score)
        XCTAssertEqual(score, 0.94, accuracy: 0.000001)
    }
}
