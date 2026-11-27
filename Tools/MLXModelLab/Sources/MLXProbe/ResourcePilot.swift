import Foundation
import FoundationModels
import Darwin
import os
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace
import AgentCore

/// Short matched semantic workload, not equal generated-token counts or thermal endurance.
public enum ResourcePilot {
    public enum Candidate: String, Sendable, CaseIterable {
        case falcon90, smol135, granite350, lfm, qwen3, qwen35, miniCPM5, lfm12, qwen2b, qwen3text4b
    }

    private static let prompts = [
        "List five useful things to check before a day trip. Use one short sentence per item.",
        "Nenne fünf Schritte zur Vorbereitung einer Reise. Verwende kurze Sätze.",
        "Explain why backing up a file before editing is useful, in three sentences."
    ]
    private static let instructions = "Answer the request briefly. Do not use tools."

    private struct Sample: Sendable {
        let footprint: UInt64?
        let available: UInt64
        let thermal: Int
    }
    private static func sample() -> Sample {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let state: Int
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: state = 0
        case .fair: state = 1
        case .serious: state = 2
        case .critical: state = 3
        @unknown default: state = 4
        }
        return .init(footprint: result == KERN_SUCCESS ? info.phys_footprint : nil,
                     available: UInt64(os_proc_available_memory()), thermal: state)
    }
    private static func value(_ n: UInt64?) -> String { n.map(String.init) ?? "NA" }

    /// The timer owns its samples on one serial queue. Finish synchronizes
    /// after cancelling the timer; snapshots are not guaranteed true peaks.
    private final class Sampler: @unchecked Sendable {
        private let queue = DispatchQueue(label: "igentic.resource.sample")
        private var samples: [Sample] = []
        private let timer: DispatchSourceTimer
        init() {
            timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
            timer.setEventHandler { [weak self] in
                guard let self, self.samples.count < 1500 else { return }
                self.samples.append(ResourcePilot.sample())
            }
            timer.resume()
        }
        func finish(_ endpoints: [Sample]) -> [Sample] {
            timer.cancel()
            return queue.sync { samples + endpoints }
        }
    }

    private static func emit(_ prefix: String, status: String, base: Sample, loaded: Sample?,
                             samples: [Sample], completed: Int, tokens: Int?,
                             elapsed: Int, loadMs: Int?, mlxPeak: Int?) -> String {
        let maximum = samples.compactMap(\.footprint).max()
        let minAvailable = samples.map(\.available).min() ?? base.available
        let worst = samples.map(\.thermal).max() ?? base.thermal
        let end = sample()
        return "\(prefix)=\(status); cases=\(completed); total=3; tokens=\(tokens.map(String.init) ?? "NA"); elapsedMs=\(elapsed); loadMs=\(loadMs.map(String.init) ?? "NA"); baseline=\(value(base.footprint)); loaded=\(value(loaded?.footprint)); sampledPeak=\(value(maximum)); availableStart=\(base.available); availableMin=\(minAvailable); availableEnd=\(end.available); mlxPeak=\(mlxPeak.map(String.init) ?? "NA"); thermalStart=\(base.thermal); thermalMax=\(max(worst,end.thermal)); thermalEnd=\(end.thermal); samples=\(samples.count); actionsExecuted=0"
    }
    private static func admission(_ candidate: Candidate, _ dir: URL) -> Result<PinnedMLXSnapshot.Receipt, PinnedMLXSnapshot.Rejection> {
        switch candidate {
        case .falcon90: return PinnedMLXSnapshot.verifyFalcon90Research(directory: dir)
        case .smol135: return PinnedMLXSnapshot.verifySmol135Research(directory: dir)
        case .granite350: return PinnedMLXSnapshot.verifyGranite350Research(directory: dir)
        case .lfm: return PinnedMLXSnapshot.verifyLFM25Research(directory: dir)
        case .qwen3: return PinnedMLXSnapshot.verifyQwen3(directory: dir)
        case .qwen35: return PinnedMLXSnapshot.verifyQwen35Research(directory: dir)
        case .miniCPM5: return PinnedMLXSnapshot.verifyMiniCPM5Research(directory: dir)
        case .lfm12: return PinnedMLXSnapshot.verifyLFM12Research(directory: dir)
        case .qwen2b: return PinnedMLXSnapshot.verifyQwen2BResearch(directory: dir)
        case .qwen3text4b: return PinnedMLXSnapshot.verifyQwen3Text4BResearch(directory: dir)
        }
    }
    @MainActor public static func run(modelDirectory: URL, candidate: Candidate) async -> String {
        let prefix = "RESOURCE_V1_" + candidate.rawValue.uppercased()
        guard case .success(let receipt) = admission(candidate, modelDirectory) else {
            return "\(prefix)=integrityRejected; actionsExecuted=0"
        }
        let base = sample()
        guard LargeModelPreflight.allowed(weightBytes: UInt64(receipt.totalBytes), available: base.available, nominal: base.thermal == 0) else {
            return "\(prefix)=resourceBlocked; actionsExecuted=0"
        }
        let sampler = Sampler()
        let start = ProcessInfo.processInfo.systemUptime
        var loaded: Sample?, loadMs: Int?, endpoints = [base], completed = 0, tokens = 0
        var status = "completed"
        Memory.peakMemory = 0
        do {
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            let s = sample(); loaded = s; endpoints.append(s)
            loadMs = Int((ProcessInfo.processInfo.systemUptime-start)*1000)
            for prompt in prompts {
                let s = sample(); endpoints.append(s)
                guard s.thermal < 2, s.available >= 536_870_912, !Task.isCancelled else { status = "resourceStopped"; break }
                let session = ChatSession(model, instructions: instructions,
                    generateParameters: .init(maxTokens: 64, temperature: 0),
                    additionalContext: (candidate == .qwen3 || candidate == .qwen35 || candidate == .qwen2b || candidate == .miniCPM5) ? ["enable_thinking": false] : [:])
                var completion: GenerateCompletionInfo?
                for try await event in session.streamDetails(to: prompt) {
                    if case .info(let info) = event { completion = info }
                }
                guard let n = completion?.generationTokenCount, (0...64).contains(n) else { status = "failed"; break }
                tokens += n; completed += 1; endpoints.append(sample())
            }
        } catch { status = "failed" }
        endpoints.append(sample())
        let observations = sampler.finish(endpoints)
        return emit(prefix, status: status, base: base, loaded: loaded, samples: observations,
                    completed: completed, tokens: tokens, elapsed: Int((ProcessInfo.processInfo.systemUptime-start)*1000),
                    loadMs: loadMs, mlxPeak: Memory.peakMemory)
    }

    @MainActor public static func runApple() async -> String {
        let prefix = "RESOURCE_V1_APPLE"
        guard SystemLanguageModel.default.isAvailable else { return "\(prefix)=unavailable; actionsExecuted=0" }
        let base = sample()
        guard base.thermal == 0, base.available >= 536_870_912 else { return "\(prefix)=resourceBlocked; actionsExecuted=0" }
        let sampler = Sampler(), start = ProcessInfo.processInfo.systemUptime
        var completed = 0, endpoints = [base], status = "completed"
        do {
            for prompt in prompts {
                let s = sample(); endpoints.append(s)
                guard s.thermal < 2, s.available >= 536_870_912, !Task.isCancelled else { status = "resourceStopped"; break }
                let session = LanguageModelSession(model: SystemLanguageModel.default, tools: [], instructions: instructions)
                _ = try await session.respond(to: prompt, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 64))
                completed += 1; endpoints.append(sample())
            }
        } catch { status = "failed" }
        endpoints.append(sample())
        return emit(prefix, status: status, base: base, loaded: nil, samples: sampler.finish(endpoints),
                    completed: completed, tokens: nil, elapsed: Int((ProcessInfo.processInfo.systemUptime-start)*1000),
                    loadMs: nil, mlxPeak: nil)
    }
}
