import Foundation

public enum AuditEventType: String, Equatable, Sendable {
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

public struct AuditEventMetadata: Equatable, Sendable {
    public let timestamp: Date
    public let type: AuditEventType
    public let dataSensitivity: DataSensitivityLevel

    public init(
        timestamp: Date,
        type: AuditEventType,
        dataSensitivity: DataSensitivityLevel
    ) {
        self.timestamp = timestamp
        self.type = type
        self.dataSensitivity = dataSensitivity
    }

    public init(_ event: AuditEvent) {
        self.init(
            timestamp: event.timestamp,
            type: event.type,
            dataSensitivity: event.dataSensitivity
        )
    }
}

public final class AuditLog: @unchecked Sendable {
    private let events = LockedBox<[AuditEvent]>([])

    public init() {}

    public func record(_ event: AuditEvent) {
        events.withValue { $0.append(event) }
    }

    public func allEvents() -> [AuditEvent] {
        events.withValue { $0 }
    }

    public func metadataSnapshot() -> [AuditEventMetadata] {
        events.withValue { events in
            events.map(AuditEventMetadata.init)
        }
    }

    public func metadataSnapshot(ofType type: AuditEventType) -> [AuditEventMetadata] {
        events.withValue { events in
            events
                .filter { $0.type == type }
                .map(AuditEventMetadata.init)
        }
    }

    public func metadataSnapshot(
        atOrAbove minimumSensitivity: DataSensitivityLevel
    ) -> [AuditEventMetadata] {
        events.withValue { events in
            events
                .filter { $0.dataSensitivity >= minimumSensitivity }
                .map(AuditEventMetadata.init)
        }
    }

    public func count(ofType type: AuditEventType) -> Int {
        events.withValue { events in
            events.lazy.filter { $0.type == type }.count
        }
    }

    public func count(
        atOrAbove minimumSensitivity: DataSensitivityLevel
    ) -> Int {
        events.withValue { events in
            events.lazy.filter { $0.dataSensitivity >= minimumSensitivity }.count
        }
    }
}
