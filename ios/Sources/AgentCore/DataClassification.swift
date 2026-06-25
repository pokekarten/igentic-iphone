import Foundation

public enum DataSensitivityLevel: Int, Comparable, Sendable {
    case publicData = 0
    case lowRiskAppData = 1
    case contextualPrivateData = 2
    case highlyPrivateData = 3
    case restrictedSensitiveData = 4

    public static func < (lhs: DataSensitivityLevel, rhs: DataSensitivityLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var requiresExplicitApproval: Bool {
        self >= .highlyPrivateData
    }

    public var blocksAutomaticExternalDelegation: Bool {
        self == .restrictedSensitiveData
    }
}

public struct DataClassification: Equatable, Sendable {
    public let level: DataSensitivityLevel
    public let reason: String

    public init(level: DataSensitivityLevel, reason: String) {
        self.level = level
        self.reason = reason
    }

    public static let publicDefault = DataClassification(
        level: .publicData,
        reason: "No private user context required."
    )
}

public enum PrivacyMode: String, CaseIterable, Sendable {
    case localOnly = "Local Only"
    case trustedDevices = "Trusted Devices"
    case externalAI = "External AI"
}

public enum ActionRisk: String, Sendable {
    case read
    case prepare
    case execute
    case destructive
    case externalShare
    case critical

    public var requiresApproval: Bool {
        switch self {
        case .read, .prepare:
            return false
        case .execute, .destructive, .externalShare, .critical:
            return true
        }
    }
}

public enum DelegationTarget: String, Sendable {
    case none
    case localDevice
    case trustedMac
    case homeServer
    case privateCloudCompute
    case externalProvider
}

extension DelegationTarget {
    var leavesLocalDevice: Bool {
        self != .none && self != .localDevice
    }
}
