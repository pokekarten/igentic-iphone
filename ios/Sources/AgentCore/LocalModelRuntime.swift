public enum LocalModelExecutionKind: String, CaseIterable, Sendable {
    case system
    case local
    case delegated
}

public enum LocalModelCapability: String, CaseIterable, Hashable, Sendable {
    case textGeneration
    case structuredProposal
    case summarization
    case classification
}

public enum LocalModelContextBudgetClass: String, CaseIterable, Comparable, Sendable {
    case compact
    case standard
    case extended

    private var rank: Int {
        switch self {
        case .compact: 0
        case .standard: 1
        case .extended: 2
        }
    }

    public static func < (lhs: LocalModelContextBudgetClass, rhs: LocalModelContextBudgetClass) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum LocalModelRuntimeUnavailabilityReason: String, Equatable, Sendable {
    case notConfigured
    case disabledByPolicy
    case unsupportedPlatform
}

public enum LocalModelRuntimeAvailability: Equatable, Sendable {
    case available
    case unavailable(LocalModelRuntimeUnavailabilityReason)
}

public struct LocalModelRuntimeDescriptor: Equatable, Sendable {
    public let identifier: String
    public let modelFamily: String
    public let executionKind: LocalModelExecutionKind
    public let supportedCapabilities: Set<LocalModelCapability>
    public let maximumDataSensitivity: DataSensitivityLevel
    public let contextBudgetClass: LocalModelContextBudgetClass
    public let memoryBudgetClass: RuntimeMemoryClass

    public init(
        identifier: String,
        modelFamily: String,
        executionKind: LocalModelExecutionKind,
        supportedCapabilities: Set<LocalModelCapability>,
        maximumDataSensitivity: DataSensitivityLevel,
        contextBudgetClass: LocalModelContextBudgetClass,
        memoryBudgetClass: RuntimeMemoryClass
    ) {
        self.identifier = identifier
        self.modelFamily = modelFamily
        self.executionKind = executionKind
        self.supportedCapabilities = supportedCapabilities
        self.maximumDataSensitivity = maximumDataSensitivity
        self.contextBudgetClass = contextBudgetClass
        self.memoryBudgetClass = memoryBudgetClass
    }
}

public struct LocalModelRequest: Equatable, Sendable {
    public let capability: LocalModelCapability
    public let dataSensitivity: DataSensitivityLevel

    public init(capability: LocalModelCapability, dataSensitivity: DataSensitivityLevel) {
        self.capability = capability
        self.dataSensitivity = dataSensitivity
    }
}

public enum LocalModelRequestRejectionReason: Equatable, Sendable {
    case runtimeUnavailable(LocalModelRuntimeUnavailabilityReason)
    case unsupportedCapability(LocalModelCapability)
    case dataSensitivityExceedsCeiling(
        requested: DataSensitivityLevel,
        maximum: DataSensitivityLevel
    )
}

public enum LocalModelRequestDecision: Equatable, Sendable {
    case accepted
    case rejected(LocalModelRequestRejectionReason)

    public var isAccepted: Bool {
        self == .accepted
    }
}

public protocol LocalModelRuntime: Sendable {
    var descriptor: LocalModelRuntimeDescriptor { get }
    var availability: LocalModelRuntimeAvailability { get }
}

public extension LocalModelRuntime {
    func assess(_ request: LocalModelRequest) -> LocalModelRequestDecision {
        if case let .unavailable(reason) = availability {
            return .rejected(.runtimeUnavailable(reason))
        }

        guard descriptor.supportedCapabilities.contains(request.capability) else {
            return .rejected(.unsupportedCapability(request.capability))
        }

        guard request.dataSensitivity <= descriptor.maximumDataSensitivity else {
            return .rejected(
                .dataSensitivityExceedsCeiling(
                    requested: request.dataSensitivity,
                    maximum: descriptor.maximumDataSensitivity
                )
            )
        }

        return .accepted
    }
}
