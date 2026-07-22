import Foundation

public enum LatencyBudgetClass: String, CaseIterable, Sendable {
    case low
    case medium
    case high
}

public struct ModelCandidate: Equatable, Sendable {
    public let modelID: String
    public let evaluationScore: Double
    public let latencyScore: Double
    public let capabilityMatch: Double
    public let latencyMS: Int
    public let contextSize: Int
    public let maxContextTokens: Int
    public let latencyBudgetClass: LatencyBudgetClass
    public let toolUsageSupported: Bool

    public init(
        modelID: String,
        evaluationScore: Double,
        latencyScore: Double,
        capabilityMatch: Double,
        latencyMS: Int,
        contextSize: Int,
        maxContextTokens: Int,
        latencyBudgetClass: LatencyBudgetClass,
        toolUsageSupported: Bool
    ) {
        self.modelID = modelID
        self.evaluationScore = evaluationScore
        self.latencyScore = latencyScore
        self.capabilityMatch = capabilityMatch
        self.latencyMS = latencyMS
        self.contextSize = contextSize
        self.maxContextTokens = maxContextTokens
        self.latencyBudgetClass = latencyBudgetClass
        self.toolUsageSupported = toolUsageSupported
    }
}

public struct ModelSelectionRequest: Equatable, Sendable {
    public let latencyBudget: LatencyBudgetClass
    public let contextSize: Int
    public let toolUsageRequired: Bool

    public init(latencyBudget: LatencyBudgetClass, contextSize: Int, toolUsageRequired: Bool) {
        self.latencyBudget = latencyBudget
        self.contextSize = contextSize
        self.toolUsageRequired = toolUsageRequired
    }
}

public enum ModelSelectionReason: Equatable, Sendable {
    case highestWeightedScore
    case lowestLatencyValidModel
    case safeRefusalModel
}

public struct ModelSelectionResult: Equatable, Sendable {
    public let selectedModelID: String
    public let reason: ModelSelectionReason
    public let score: Double?

    public init(selectedModelID: String, reason: ModelSelectionReason, score: Double?) {
        self.selectedModelID = selectedModelID
        self.reason = reason
        self.score = score
    }
}

/// Source of truth for these weights: `docs/model-selection/SELECTION_POLICY_v1.yaml`.
/// Keep this constant in sync with that file; this type intentionally does not parse YAML.
public struct ModelSelectionPolicy: Equatable, Sendable {
    public let evaluationWeight: Double
    public let latencyWeight: Double
    public let capabilityWeight: Double
    public let safeRefusalModelID: String

    public init(
        evaluationWeight: Double,
        latencyWeight: Double,
        capabilityWeight: Double,
        safeRefusalModelID: String
    ) {
        self.evaluationWeight = evaluationWeight
        self.latencyWeight = latencyWeight
        self.capabilityWeight = capabilityWeight
        self.safeRefusalModelID = safeRefusalModelID
    }

    public static let v1 = ModelSelectionPolicy(
        evaluationWeight: 0.50,
        latencyWeight: 0.20,
        capabilityWeight: 0.30,
        safeRefusalModelID: "model-safe-refusal"
    )
}

public enum ModelSelectionEngine {
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

    private static func scoreCandidate(_ candidate: ModelCandidate, policy: ModelSelectionPolicy) -> Double {
        (candidate.evaluationScore * policy.evaluationWeight)
            + (candidate.latencyScore * policy.latencyWeight)
            + (candidate.capabilityMatch * policy.capabilityWeight)
    }

    private static func satisfiesHardConstraints(
        candidate: ModelCandidate,
        request: ModelSelectionRequest
    ) -> Bool {
        guard request.contextSize <= candidate.maxContextTokens else {
            return false
        }
        guard latencyRank(request.latencyBudget) <= latencyRank(candidate.latencyBudgetClass) else {
            return false
        }
        if request.toolUsageRequired, !candidate.toolUsageSupported {
            return false
        }
        return true
    }

    public static func select(
        candidates: [ModelCandidate],
        request: ModelSelectionRequest,
        policy: ModelSelectionPolicy
    ) -> ModelSelectionResult {
        let eligibleCandidates = candidates.filter { satisfiesHardConstraints(candidate: $0, request: request) }
        guard !eligibleCandidates.isEmpty else {
            return ModelSelectionResult(
                selectedModelID: policy.safeRefusalModelID,
                reason: .safeRefusalModel,
                score: nil
            )
        }

        let scoredCandidates: [(candidate: ModelCandidate, score: Double)] = eligibleCandidates.map { candidate in
            (candidate: candidate, score: scoreCandidate(candidate, policy: policy))
        }
        guard let bestScore = scoredCandidates.map({ $0.score }).max() else {
            return ModelSelectionResult(
                selectedModelID: policy.safeRefusalModelID,
                reason: .safeRefusalModel,
                score: nil
            )
        }

        let bestScoredCandidates = scoredCandidates.filter { $0.score == bestScore }
        if bestScoredCandidates.count == 1, let winner = bestScoredCandidates.first {
            return ModelSelectionResult(
                selectedModelID: winner.candidate.modelID,
                reason: .highestWeightedScore,
                score: bestScore
            )
        }

        guard let lowestLatencyMS = bestScoredCandidates.map({ $0.candidate.latencyMS }).min() else {
            return ModelSelectionResult(
                selectedModelID: policy.safeRefusalModelID,
                reason: .safeRefusalModel,
                score: bestScore
            )
        }

        let lowestLatencyCandidates = bestScoredCandidates.filter { $0.candidate.latencyMS == lowestLatencyMS }
        if lowestLatencyCandidates.count == 1, let winner = lowestLatencyCandidates.first {
            return ModelSelectionResult(
                selectedModelID: winner.candidate.modelID,
                reason: .lowestLatencyValidModel,
                score: bestScore
            )
        }

        return ModelSelectionResult(
            selectedModelID: policy.safeRefusalModelID,
            reason: .safeRefusalModel,
            score: bestScore
        )
    }
}
