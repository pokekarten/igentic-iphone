public enum DevicePerformanceProfile: String, CaseIterable, Sendable {
    case eco, balanced, performance
}

public enum DeviceThermalCondition: String, CaseIterable, Sendable {
    case nominal, fair, serious, critical, unknown
}

public enum DeviceMemoryCondition: String, CaseIterable, Sendable {
    case normal, warning, critical, unknown
}

/// Only resource metadata; no user content. Unknown readings must stay unknown.
public struct DeviceModelConditions: Equatable, Sendable {
    public let thermal: DeviceThermalCondition
    public let memory: DeviceMemoryCondition
    public let batteryPercent: Int?
    public let isCharging: Bool
    public let lowPowerMode: Bool

    public init(thermal: DeviceThermalCondition, memory: DeviceMemoryCondition,
                batteryPercent: Int?, isCharging: Bool, lowPowerMode: Bool) {
        self.thermal = thermal
        self.memory = memory
        self.batteryPercent = batteryPercent.flatMap { (0...100).contains($0) ? $0 : nil }
        self.isCharging = isCharging
        self.lowPowerMode = lowPowerMode
    }
}

public enum DeviceModelAdmission: Equatable, Sendable {
    case allowed
    case exceedsMemoryBudget(maximum: RuntimeMemoryClass)
    case suspended
    case notLocal
}

public struct DeviceModelBudget: Equatable, Sendable {
    public let effectiveProfile: DevicePerformanceProfile
    /// nil means no new model inference should start.
    public let maximumMemoryClass: RuntimeMemoryClass?

    public func admit(_ descriptor: LocalModelRuntimeDescriptor) -> DeviceModelAdmission {
        guard descriptor.executionKind != .delegated else { return .notLocal }
        guard let maximumMemoryClass else { return .suspended }
        guard descriptor.memoryBudgetClass <= maximumMemoryClass else {
            return .exceedsMemoryBudget(maximum: maximumMemoryClass)
        }
        return .allowed
    }
}

/// A deterministic, conservative admission policy, not an OS resource monitor.
/// It does not replace privacy/capability checks or authorize delegation.
/// The 20% threshold and memory classes are provisional until device validation.
public enum DeviceModelGovernor {
    public static func budget(
        for conditions: DeviceModelConditions,
        requestedProfile: DevicePerformanceProfile = .balanced
    ) -> DeviceModelBudget {
        if conditions.thermal == .critical || conditions.memory == .critical {
            return DeviceModelBudget(effectiveProfile: .eco, maximumMemoryClass: nil)
        }
        let batteryConstrained = !conditions.isCharging && (conditions.batteryPercent ?? 0) <= 20
        if requestedProfile == .eco || conditions.lowPowerMode || batteryConstrained
            || conditions.thermal == .serious || conditions.thermal == .unknown
            || conditions.memory == .warning || conditions.memory == .unknown {
            return DeviceModelBudget(effectiveProfile: .eco, maximumMemoryClass: .low)
        }
        if requestedProfile == .performance && conditions.isCharging
            && conditions.thermal == .nominal && conditions.memory == .normal {
            return DeviceModelBudget(effectiveProfile: .performance, maximumMemoryClass: .high)
        }
        return DeviceModelBudget(effectiveProfile: .balanced, maximumMemoryClass: .moderate)
    }
}
