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
    private let lock = NSLock()
    private var events: [AuditEvent] = []

    public init() {}

    public func record(_ event: AuditEvent) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    public func allEvents() -> [AuditEvent] {
        withLockedEvents { $0 }
    }

    public func metadataSnapshot() -> [AuditEventMetadata] {
        withLockedEvents { events in
            events.map(AuditEventMetadata.init)
        }
    }

    public func metadataSnapshot(ofType type: AuditEventType) -> [AuditEventMetadata] {
        withLockedEvents { events in
            events
                .filter { $0.type == type }
                .map(AuditEventMetadata.init)
        }
    }

    public func metadataSnapshot(
        atOrAbove minimumSensitivity: DataSensitivityLevel
    ) -> [AuditEventMetadata] {
        withLockedEvents { events in
            events
                .filter { $0.dataSensitivity >= minimumSensitivity }
                .map(AuditEventMetadata.init)
        }
    }

    public func count(ofType type: AuditEventType) -> Int {
        withLockedEvents { events in
            events.lazy.filter { $0.type == type }.count
        }
    }

    public func count(
        atOrAbove minimumSensitivity: DataSensitivityLevel
    ) -> Int {
        withLockedEvents { events in
            events.lazy.filter { $0.dataSensitivity >= minimumSensitivity }.count
        }
    }

    private func withLockedEvents<Result>(
        _ body: ([AuditEvent]) -> Result
    ) -> Result {
        lock.lock()
        defer { lock.unlock() }
        return body(events)
    }
}
