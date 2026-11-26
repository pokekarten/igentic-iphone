import Foundation
import os

/// Conservative research guardrails. The process allowance is dynamic, not
/// physical free RAM or a promise that a subsequent model load will succeed.
public enum LargeModelPreflight {
    static let minimumReserve: UInt64 = 1_073_741_824
    static let minimumStorageReserve: UInt64 = 2_147_483_648
    static func allowed(weightBytes: UInt64, available: UInt64, nominal: Bool) -> Bool {
        guard nominal, available >= minimumReserve else { return false }
        return weightBytes <= available - minimumReserve
    }
    public static func report() -> String {
        let thermal = ProcessInfo.processInfo.thermalState
        let nominal = thermal == .nominal
        let available = UInt64(os_proc_available_memory())
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let capacity = (try? root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage).flatMap { $0 >= 0 ? UInt64($0) : nil }
        let weights: UInt64 = 3_034_300_695
        let storageOK = capacity.map { $0 >= weights + minimumStorageReserve } ?? false
        let memoryOK = allowed(weightBytes: weights, available: available, nominal: nominal)
        return "LARGE_PREFLIGHT=completed; physicalMemory=\(ProcessInfo.processInfo.physicalMemory); processAvailable=\(available); storageAvailable=\(capacity.map(String.init) ?? "NA"); nominal=\(nominal); qwen4bMemoryGate=\(memoryOK); qwen4bStorageGate=\(storageOK); actionsExecuted=0"
    }
}
