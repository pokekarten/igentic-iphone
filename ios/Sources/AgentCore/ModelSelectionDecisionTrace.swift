import Foundation

public enum ModelSelectionConstraintRejectionReason: String, Equatable, Sendable {
    case contextSizeExceedsMaxContextTokens
    case latencyBudgetExceedsCandidateClass
    case toolUsageRequiredButUnsupported
}

public enum ModelSelectionTraceFallbackReason: String, Equatable, Sendable {
    case noEligibleCandidates
    case unresolvedScoreAndLatencyTie
}

public struct ModelSelectionTraceScoreComponents: Equatable, Sendable {
    public let evaluation: Double
    public let latency: Double
    public let capability: Double

    public init(evaluation: Double, latency: Double, capability: Double) {
        self.evaluation = evaluation
        self.latency = latency
        self.capability = capability
    }
}

public struct ModelSelectionTraceCandidate: Equatable, Sendable {
    public let modelID: String
    public let eligible: Bool
    public let rejectionReasons: [ModelSelectionConstraintRejectionReason]
    public let weightedScore: Double?
    public let scoreComponents: ModelSelectionTraceScoreComponents?
    public let latencyMS: Int

    public init(
        modelID: String,
        eligible: Bool,
        rejectionReasons: [ModelSelectionConstraintRejectionReason],
        weightedScore: Double?,
        scoreComponents: ModelSelectionTraceScoreComponents?,
        latencyMS: Int
    ) {
        self.modelID = modelID
        self.eligible = eligible
        self.rejectionReasons = rejectionReasons
        self.weightedScore = weightedScore
        self.scoreComponents = scoreComponents
        self.latencyMS = latencyMS
    }
}

public struct ModelSelectionDecisionTrace: Equatable, Sendable {
    public let schemaVersion: String
    public let request: ModelSelectionRequest
    public let candidates: [ModelSelectionTraceCandidate]
    public let selectedModelID: String
    public let selectionReason: ModelSelectionReason
    public let selectedScore: Double?
    public let fallbackReason: ModelSelectionTraceFallbackReason?

    public init(
        schemaVersion: String = "v1",
        request: ModelSelectionRequest,
        candidates: [ModelSelectionTraceCandidate],
        selectedModelID: String,
        selectionReason: ModelSelectionReason,
        selectedScore: Double?,
        fallbackReason: ModelSelectionTraceFallbackReason?
    ) {
        self.schemaVersion = schemaVersion
        self.request = request
        self.candidates = candidates
        self.selectedModelID = selectedModelID
        self.selectionReason = selectionReason
        self.selectedScore = selectedScore
        self.fallbackReason = fallbackReason
    }
}

public enum ModelSelectionDecisionTraceGenerator {
    public static func makeTrace(
        candidates: [ModelCandidate],
        request: ModelSelectionRequest,
        policy: ModelSelectionPolicy
    ) -> ModelSelectionDecisionTrace {
        let tracedCandidates = candidates.map { candidate in
            let rejectionReasons = rejectionReasons(for: candidate, request: request)
            guard rejectionReasons.isEmpty else {
                return ModelSelectionTraceCandidate(
                    modelID: candidate.modelID,
                    eligible: false,
                    rejectionReasons: rejectionReasons,
                    weightedScore: nil,
                    scoreComponents: nil,
                    latencyMS: candidate.latencyMS
                )
            }

            let components = scoreComponents(for: candidate, policy: policy)
            return ModelSelectionTraceCandidate(
                modelID: candidate.modelID,
                eligible: true,
                rejectionReasons: [],
                weightedScore: components.evaluation + components.latency + components.capability,
                scoreComponents: components,
                latencyMS: candidate.latencyMS
            )
        }

        let result = ModelSelectionEngine.select(candidates: candidates, request: request, policy: policy)
        let eligibleCandidates = tracedCandidates.filter(\.eligible)
        let fallbackReason: ModelSelectionTraceFallbackReason?

        if result.reason == .safeRefusalModel {
            if eligibleCandidates.isEmpty {
                fallbackReason = .noEligibleCandidates
            } else {
                fallbackReason = .unresolvedScoreAndLatencyTie
            }
        } else {
            fallbackReason = nil
        }

        return ModelSelectionDecisionTrace(
            request: request,
            candidates: tracedCandidates,
            selectedModelID: result.selectedModelID,
            selectionReason: result.reason,
            selectedScore: result.score,
            fallbackReason: fallbackReason
        )
    }

    private static func rejectionReasons(
        for candidate: ModelCandidate,
        request: ModelSelectionRequest
    ) -> [ModelSelectionConstraintRejectionReason] {
        var reasons: [ModelSelectionConstraintRejectionReason] = []

        if request.contextSize > candidate.maxContextTokens {
            reasons.append(.contextSizeExceedsMaxContextTokens)
        }

        if latencyRank(request.latencyBudget) > latencyRank(candidate.latencyBudgetClass) {
            reasons.append(.latencyBudgetExceedsCandidateClass)
        }

        if request.toolUsageRequired && !candidate.toolUsageSupported {
            reasons.append(.toolUsageRequiredButUnsupported)
        }

        return reasons
    }

    private static func scoreComponents(
        for candidate: ModelCandidate,
        policy: ModelSelectionPolicy
    ) -> ModelSelectionTraceScoreComponents {
        ModelSelectionTraceScoreComponents(
            evaluation: candidate.evaluationScore * policy.evaluationWeight,
            latency: candidate.latencyScore * policy.latencyWeight,
            capability: candidate.capabilityMatch * policy.capabilityWeight
        )
    }

    private static func latencyRank(_ budget: LatencyBudgetClass) -> Int {
        switch budget {
        case .low:
            return 0
        case .medium:
            return 1
        case .high:
            return 2
        }
    }
}
