public struct ModelSelectionProposalInput: Equatable, Sendable {
    public let request: ModelSelectionRequest
    public let candidates: [ModelCandidate]
    public let policy: ModelSelectionPolicy

    public init(
        request: ModelSelectionRequest,
        candidates: [ModelCandidate],
        policy: ModelSelectionPolicy = .v1
    ) {
        self.request = request
        self.candidates = candidates
        self.policy = policy
    }
}
