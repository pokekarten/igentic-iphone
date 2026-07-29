import XCTest
@testable import AgentCore

final class ModelSelectionDecisionTraceTests: XCTestCase {
    private let policy = ModelSelectionPolicy.v1

    func testTraceCapturesHardConstraintRejectionsAndScoreComponents() throws {
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

        let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
            candidates: candidates,
            request: request,
            policy: policy
        )

        XCTAssertEqual(trace.schemaVersion, "v1")
        XCTAssertEqual(trace.selectedModelID, "model-valid")
        XCTAssertEqual(trace.selectionReason, .highestWeightedScore)
        XCTAssertNil(trace.fallbackReason)
        XCTAssertEqual(trace.candidates.count, 2)

        let rejected = try XCTUnwrap(trace.candidates.first)
        XCTAssertFalse(rejected.eligible)
        XCTAssertEqual(rejected.rejectionReasons, [.contextSizeExceedsMaxContextTokens])
        XCTAssertNil(rejected.weightedScore)
        XCTAssertNil(rejected.scoreComponents)

        let winner = try XCTUnwrap(trace.candidates.last)
        XCTAssertTrue(winner.eligible)
        XCTAssertEqual(winner.rejectionReasons, [])
        XCTAssertEqual(winner.weightedScore ?? 0, 0.79, accuracy: 0.000001)
        XCTAssertEqual(winner.scoreComponents?.evaluation ?? 0, 0.40, accuracy: 0.000001)
        XCTAssertEqual(winner.scoreComponents?.latency ?? 0, 0.12, accuracy: 0.000001)
        XCTAssertEqual(winner.scoreComponents?.capability ?? 0, 0.27, accuracy: 0.000001)
    }

    func testTraceCapturesLowestLatencyTieBreak() throws {
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
            )
        ]

        let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
            candidates: candidates,
            request: request,
            policy: policy
        )

        XCTAssertEqual(trace.selectedModelID, "model-beta")
        XCTAssertEqual(trace.selectionReason, .lowestLatencyValidModel)
        XCTAssertNil(trace.fallbackReason)
        XCTAssertEqual(trace.selectedScore ?? 0, 0.73, accuracy: 0.000001)
    }

    func testTraceCapturesSafeRefusalWhenEligibleCandidatesRemainTied() {
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
            )
        ]

        let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
            candidates: candidates,
            request: request,
            policy: policy
        )

        XCTAssertEqual(trace.selectedModelID, "model-safe-refusal")
        XCTAssertEqual(trace.selectionReason, .safeRefusalModel)
        XCTAssertEqual(trace.fallbackReason, .unresolvedScoreAndLatencyTie)
    }

    func testTraceCapturesNoEligibleCandidatesFallback() {
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
            )
        ]

        let trace = ModelSelectionDecisionTraceGenerator.makeTrace(
            candidates: candidates,
            request: request,
            policy: policy
        )

        XCTAssertEqual(trace.selectedModelID, "model-safe-refusal")
        XCTAssertEqual(trace.selectionReason, .safeRefusalModel)
        XCTAssertEqual(trace.fallbackReason, .noEligibleCandidates)
    }
}
