import Foundation
import AgentCore

/// Native owner-selected tools. No model, remote transport or arbitrary
/// command interpreter can invoke this controller.
enum StandaloneDeviceTool: String, CaseIterable, Sendable {
    case status = "device.status.read"
    case storage = "device.storage.read"
    case torchState = "device.torch.read"
    case torchPulse = "device.torch.pulse"

    var definition: ToolDefinition {
        .init(name: rawValue, requiredDataLevel: self == .torchPulse ? .publicData : .contextualPrivateData,
              actionRisk: self == .torchPulse ? .execute : .read,
              description: "Owner-selected local device tool.")
    }
}

enum StandaloneTorchState: String, Sendable {
    case off, active, unavailable, unknown
}

enum StandaloneTorchStart: Sendable { case started, blocked, uncertain }
enum StandaloneTorchOutcome: String, Equatable, Sendable {
    case verified, blocked, cancelledAndOff, notObservedAndOff, uncertain
}

@MainActor
protocol StandaloneDeviceBackend {
    func status() -> AgentLoopLocalStatus
    func availableStorage() -> Int64?
    func torchState() -> StandaloneTorchState
    /// Atomically checks off/available, then begins a low-level pulse.
    /// If configuration fails after an attempted change, backend handles cleanup.
    func startPulseIfOff() -> StandaloneTorchStart
    /// Called only after this transaction started the torch.
    func stopOwnedPulse() -> Bool
}

@MainActor
enum StandaloneDeviceTools {
    private static let registry = ToolRegistry(tools: StandaloneDeviceTool.allCases.map(\.definition))

    static func permitted(_ tool: StandaloneDeviceTool, ownerConfirmed: Bool = false) -> Bool {
        guard let entry = registry.tool(named: tool.rawValue) else { return false }
        let decision = PolicyEngine().decide(.init(
            privacyMode: .localOnly,
            dataClassification: .init(level: entry.requiredDataLevel, reason: "Local device tool, local UI only."),
            actionRisk: entry.actionRisk, requestedDelegationTarget: .localDevice))
        return decision.isAllowed && (!decision.requiresApproval || ownerConfirmed)
    }

    /// Data returned only to this screen; no persistence or external provider.
    static func readReport(backend: any StandaloneDeviceBackend) -> String? {
        guard [.status, .storage, .torchState].allSatisfy({ permitted($0) }) else { return nil }
        let status = backend.status()
        let battery = status.batteryPercent.map { "\($0) %" } ?? "unbekannt"
        let storage = backend.availableStorage().flatMap { $0 >= 0 ? $0 : nil }.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        } ?? "unbekannt"
        let power = status.lowPowerModeEnabled ? "aktiv" : "aus"
        return "Akku: \(battery)\nStromsparmodus: \(power)\niOS: \(status.osVersion)\nVerfügbarer Speicher (Schätzung): \(storage)\nTaschenlampe: \(backend.torchState().rawValue)"
    }

    /// This is a fixed, one-shot foreground action, not a model callable tool.
    /// Cancellation still attempts cleanup. No automatic repeat after uncertainty.
    static func pulse(backend: any StandaloneDeviceBackend, ownerConfirmed: Bool,
                      foreground: () -> Bool, wait: () async throws -> Void) async -> StandaloneTorchOutcome {
        guard permitted(.torchPulse, ownerConfirmed: ownerConfirmed),
              foreground(), !Task.isCancelled else { return .blocked }
        switch backend.startPulseIfOff() {
        case .blocked: return .blocked
        case .uncertain: return .uncertain
        case .started: break
        }
        let active = backend.torchState() == .active
        var cancelled = false
        do { try await wait() } catch { cancelled = true }
        cancelled = cancelled || Task.isCancelled || !foreground()
        // Cleanup is required even if cancellation happened during the wait.
        guard backend.stopOwnedPulse(), backend.torchState() == .off else { return .uncertain }
        if cancelled { return .cancelledAndOff }
        return active ? .verified : .notObservedAndOff
    }
}

#if os(iOS) && canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

@MainActor
final class NativeStandaloneDeviceBackend: StandaloneDeviceBackend {
    private var ownedDevice: AVCaptureDevice?

    func status() -> AgentLoopLocalStatus { AgentLoopDeviceStatusReader.read() }

    func availableStorage() -> Int64? {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    private func device() -> AVCaptureDevice? { AVCaptureDevice.default(for: .video) }

    func torchState() -> StandaloneTorchState {
        guard let device = ownedDevice ?? device(), device.hasTorch else { return .unavailable }
        if device.isTorchActive { return .active }
        if device.torchMode == .off { return .off }
        return .unknown
    }

    func startPulseIfOff() -> StandaloneTorchStart {
        guard ownedDevice == nil, let device = device(), device.hasTorch,
              device.isTorchAvailable, device.isTorchModeSupported(.on),
              device.isTorchModeSupported(.off) else { return .blocked }
        do { try device.lockForConfiguration() } catch { return .blocked }
        defer { device.unlockForConfiguration() }
        guard device.isTorchAvailable, device.torchMode == .off, !device.isTorchActive else { return .blocked }
        do {
            try device.setTorchModeOn(level: 0.1)
            ownedDevice = device
            return .started
        } catch {
            // The lock still belongs to this transaction; prior state was off.
            device.torchMode = .off
            return device.torchMode == .off && !device.isTorchActive ? .blocked : .uncertain
        }
    }

    func stopOwnedPulse() -> Bool {
        guard let device = ownedDevice else { return false }
        defer { ownedDevice = nil }
        do { try device.lockForConfiguration() } catch { return false }
        defer { device.unlockForConfiguration() }
        guard device.isTorchModeSupported(.off) else { return false }
        device.torchMode = .off
        return device.torchMode == .off && !device.isTorchActive
    }
}
#endif
