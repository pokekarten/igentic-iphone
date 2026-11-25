import Foundation

/// Minimal, non-identifying model-readiness report for an on-device Shortcut.
/// Reads no prompts or user records and never requests model generation.
public enum OnDeviceModelReadiness {
    public static func code(for availability: LocalModelRuntimeAvailability) -> String {
        switch availability {
        case .available:
            return "available"
        case .unavailable(let reason):
            return reason.rawValue
        }
    }

    public static func summary(for availability: LocalModelRuntimeAvailability) -> String {
        "iGentic local AI readiness: \(code(for: availability)). No prompt was processed or sent. This is not a device health check."
    }
}
