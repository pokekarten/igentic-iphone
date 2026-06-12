import Foundation

public enum AuditEventType: String, Sendable {
    case taskReceived
    case policyDecision
    case routeSelected
    case approvalRequired
    case blocked
}

public struct AuditEvent: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: AuditEventType
    public let message: String
    public let dataSensitivity: DataSensitivityLevel

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: AuditEventType,
        message: String,
        dataSensitivity: DataSensitivityLevel
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.message = message
        self.dataSensitivity = dataSensitivity
    }
}

public final class AuditLog: @unchecked Sendable {
    private var events: [AuditEvent] = []

    public init() {}

    public func record(_ event: AuditEvent) {
        events.append(event)
    }

    public func allEvents() -> [AuditEvent] {
        events
    }
}
