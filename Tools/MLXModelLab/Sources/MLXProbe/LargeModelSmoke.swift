import Foundation
import os
import AgentCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

/// Explicit isolated text-model smoke; no tools, no automatic retries.
public enum LargeModelSmoke {
    public static func run(modelDirectory: URL) async -> String {
        let prefix = "QWEN3TEXT4B_SMOKE"
        let weights: UInt64 = 2_263_022_417
        func available() -> UInt64 { UInt64(os_proc_available_memory()) }
        func nominal() -> Bool { ProcessInfo.processInfo.thermalState == .nominal }
        let pre = available()
        guard LargeModelPreflight.allowed(weightBytes: weights, available: pre, nominal: nominal()) else {
            return "\(prefix)=memoryOrThermalBlocked; available=\(pre); actionsExecuted=0"
        }
        guard case .success(let receipt) = PinnedMLXSnapshot.verifyQwen3Text4BResearch(directory: modelDirectory) else {
            return "\(prefix)=integrityRejected; actionsExecuted=0"
        }
        let before = available()
        guard LargeModelPreflight.allowed(weightBytes: weights, available: before, nominal: nominal()) else {
            return "\(prefix)=memoryOrThermalBlocked; available=\(before); actionsExecuted=0"
        }
        do {
            let start = ProcessInfo.processInfo.systemUptime
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            let after = available()
            print("\(prefix)_LOAD=completed; files=\(receipt.fileCount); bytes=\(receipt.totalBytes); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000)); availableBefore=\(before); availableAfter=\(after)")
            let cases = [("Return only the integer 18 plus 7.", "25"),
                         ("Gib nur den Buchstaben B aus.", "B"),
                         ("Order C before B and B before A. Return only comma-separated letters.", "C,B,A")]
            var completed = 0, passed = 0
            for (i, fixture) in cases.enumerated() {
                guard nominal(), available() >= 536_870_912 else { break }
                let session = ChatSession(model, instructions: "Return only the requested answer, no explanation.",
                    generateParameters: .init(maxTokens: 32, temperature: 0))
                var reply = "", invalid = false
                var completion: GenerateCompletionInfo?
                let t = ProcessInfo.processInfo.systemUptime
                for try await event in session.streamDetails(to: fixture.0) {
                    switch event {
                    case .chunk(let text):
                        if reply.utf8.count + text.utf8.count <= 256 { reply += text } else { invalid = true }
                    case .info(let info): if completion != nil { invalid = true }; completion = info
                    default: invalid = true
                    }
                }
                let n = completion?.generationTokenCount ?? -1
                let natural: Bool
                if case .some(.stop) = completion?.stopReason { natural = true } else { natural = false }
                let ok = !invalid && natural && (1..<32).contains(n) &&
                    reply.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ", ", with: ",") == fixture.1
                if ok { passed += 1 }; completed += 1
                print("\(prefix)_CASE=\(i+1); pass=\(ok); tokens=\(n); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-t)*1000)); available=\(available()); nominal=\(nominal())")
            }
            return "\(prefix)=\(completed == 3 ? "completed" : "resourceStopped"); passed=\(passed); completed=\(completed); total=3; actionsExecuted=0"
        } catch { return "\(prefix)=failed; actionsExecuted=0" }
    }
}
