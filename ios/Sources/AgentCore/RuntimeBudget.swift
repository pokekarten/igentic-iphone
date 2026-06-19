public enum RuntimeExecutionClass: String, CaseIterable, Comparable, Sendable {
    case tiny
    case small
    case large

    private var rank: Int {
        switch self {
        case .tiny: 0
        case .small: 1
        case .large: 2
        }
    }

    public static func < (lhs: RuntimeExecutionClass, rhs: RuntimeExecutionClass) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum RuntimeLocality: String, CaseIterable, Sendable {
    case localOnly = "local-only"
    case trustedDevice = "trusted-device"
    case externalRequired = "external-required"
}

public enum RuntimeMemoryClass: String, CaseIterable, Comparable, Sendable {
    case low
    case moderate
    case high

    private var rank: Int {
        switch self {
        case .low: 0
        case .moderate: 1
        case .high: 2
        }
    }

    public static func < (lhs: RuntimeMemoryClass, rhs: RuntimeMemoryClass) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct RuntimeBudget: Equatable, Sendable {
    public let executionClass: RuntimeExecutionClass
    public let expectedLocality: RuntimeLocality
    public let estimatedMemoryClass: RuntimeMemoryClass
    public let reasons: [String]

    public init(
        executionClass: RuntimeExecutionClass,
        expectedLocality: RuntimeLocality,
        estimatedMemoryClass: RuntimeMemoryClass,
        reasons: [String] = []
    ) {
        self.executionClass = executionClass
        self.expectedLocality = expectedLocality
        self.estimatedMemoryClass = estimatedMemoryClass
        self.reasons = reasons
    }

    public var requiresExternalRuntime: Bool {
        expectedLocality == .externalRequired
    }

    public var metadataLines: [String] {
        [
            "executionClass=\(executionClass.rawValue)",
            "expectedLocality=\(expectedLocality.rawValue)",
            "estimatedMemoryClass=\(estimatedMemoryClass.rawValue)",
            "reasonCount=\(reasons.count)",
        ] + reasons.enumerated().map { index, reason in
            "reason[\(index)]=\(reason)"
        }
    }
}
