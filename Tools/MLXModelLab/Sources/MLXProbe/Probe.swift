import Foundation
import AgentCore
import iGenticApp
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

public enum MLXProbe {
    /// Select a provider before starting a journaled attempt. Explicit lab-only
    /// opt-in permits the pinned Qwen candidate; the production app is unchanged.
    @MainActor
    public static func runRoutedAgent(modelDirectory: URL,
                                      preference: DiagnosticModelRouter.Preference,
                                      qwenOptIn: Bool) async -> String {
        let appleReady = AppleFoundationModelsRuntime().assess(.init(
            capability: .structuredProposal, dataSensitivity: .publicData,
            allowedExecutionKinds: [.system])).isAccepted
        let needsQwen = preference == .qwen || (preference == .automatic && !appleReady)
        let admitted: Bool
        if qwenOptIn && needsQwen,
           case .success = PinnedMLXSnapshot.verifyQwen3(directory: modelDirectory) {
            admitted = true
        } else { admitted = false }
        let selected = DiagnosticModelRouter.select(preference: preference,
            appleReady: appleReady, qwenOptIn: qwenOptIn, qwenArtifactAdmitted: admitted)
        print("MLX_ROUTE=\(selected.rawValue); appleReady=\(appleReady); qwenAdmitted=\(admitted)")
        do {
            return try await DiagnosticModelRouter.dispatch(selected, apple: {
                let start = ProcessInfo.processInfo.systemUptime
                let report = try await DiagnosticModelRouter.runSystem()
                return "MLX_AGENT=\(report.outcome.rawValue); turns=\(report.modelTurns); steps=\(report.steps.map(\.rawValue).joined(separator: ",")); reportPrepared=\(report.localReport != nil); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000))"
            }, qwen: {
                await runAgent(modelDirectory: modelDirectory)
            }) ?? "MLX_AGENT=blocked"
        } catch { return "MLX_AGENT=blocked" }
    }

    @MainActor
    public static func runAgent(modelDirectory: URL) async -> String {
        do {
            guard case .success = AgentCore.PinnedMLXSnapshot.verifyQwen3(directory: modelDirectory) else { return "MLX_AGENT=integrityRejected" }
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            let start = ProcessInfo.processInfo.systemUptime
            let report = try await AgentLoopLocalDiagnosticWorkflow.runJournaledLocalAdapter(goal: .extended) { request in
                let allowed = request.allowedActions
                let prompt = "Remaining actions: " + allowed.joined(separator: ", ") + ". Already completed: " + request.completedActions.joined(separator: ", ") + ". Choose one remaining action now."
                let session = ChatSession(model, instructions: "Choose exactly one allowed action. Output a single raw JSON object. Start with { and end with }. No Markdown, no backticks, no code fences, no explanation. Format example: {\"action\":\"status.read\"}. Use only an action listed as remaining.", generateParameters: .init(maxTokens: 48, temperature: 0), additionalContext: ["enable_thinking": false])
                var reply = ""
                var invalid = false
                var completion: GenerateCompletionInfo?
                for try await event in session.streamDetails(to: prompt) {
                    switch event {
                    case .chunk(let text):
                        if reply.utf8.count + text.utf8.count <= 256 { reply += text } else { invalid = true }
                    case .info(let info):
                        if completion != nil { invalid = true }; completion = info
                    default: invalid = true
                    }
                }
                guard !invalid, let completion, case .stop = completion.stopReason, (1..<48).contains(completion.generationTokenCount), let choice = allowed.first(where: { ProbeDecision.matches(reply, expected: $0) }) else { return "abort" }
                return choice
            }
            return "MLX_AGENT=\(report.outcome.rawValue); turns=\(report.modelTurns); steps=\(report.steps.map(\.rawValue).joined(separator: ",")); reportPrepared=\(report.localReport != nil); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime - start)*1000))"
        } catch { return "MLX_AGENT=blocked" }
    }

    public static func run(modelDirectory: URL) async -> String {
        do {
            guard case .success(let receipt) = AgentCore.PinnedMLXSnapshot.verifyQwen3(directory: modelDirectory) else { return "MLX_PHYSICAL_PROBE=integrityRejected; actionsExecuted=0" }
            print("MLX_PHYSICAL_INTEGRITY=verified; files=\(receipt.fileCount); bytes=\(receipt.totalBytes)")
            let loadStart = ProcessInfo.processInfo.systemUptime
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            print("MLX_PHYSICAL_LOAD=completed; milliseconds=\(Int((ProcessInfo.processInfo.systemUptime - loadStart) * 1000))")
            let cases = [("Read the device status only.", "status.read"), ("Lies ausschließlich den Gerätestatus.", "status.read"), ("Beende die Aufgabe ohne weitere Aktion.", "finish")]
            var results: [String] = []
            for (index, fixture) in cases.enumerated() {
                let (prompt, expected) = fixture
                let session = ChatSession(model, instructions: "Choose exactly one action: status.read or finish. Output a single raw JSON object. Start with { and end with }. No Markdown, no backticks, no code fences, no explanation. Format example: {\"action\":\"finish\"}. Choose the action matching the task.", generateParameters: .init(maxTokens: 48, temperature: 0), additionalContext: ["enable_thinking": false])
                var reply = ""
                var unexpectedEvent = false
                var completion: GenerateCompletionInfo?
                let start = ProcessInfo.processInfo.systemUptime
                for try await event in session.streamDetails(to: prompt) {
                    switch event {
                    case .chunk(let text):
                        if reply.utf8.count + text.utf8.count <= 256 { reply += text }
                        else { unexpectedEvent = true }
                    case .info(let info):
                        if completion != nil { unexpectedEvent = true }
                        completion = info
                    default: unexpectedEvent = true
                    }
                }
                let count = completion?.generationTokenCount ?? -1
                let endedNaturally: Bool
                if case .some(.stop) = completion?.stopReason { endedNaturally = true } else { endedNaturally = false }
                let accepted = !unexpectedEvent && endedNaturally && (1..<48).contains(count) && ProbeDecision.matches(reply, expected: expected)
                let parsed = (try? JSONSerialization.jsonObject(with: Data(reply.utf8))) as? [String: Any]
                let expectedValue = parsed?["action"] as? String == expected
                let shape = parsed?.keys.count == 1 && parsed?["action"] is String
                let fenced = reply.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
                print("MLX_PHYSICAL_FORMAT=\(index + 1); json=\(parsed != nil); shape=\(shape); expected=\(expectedValue); fenced=\(fenced); naturalStop=\(endedNaturally); extraEvent=\(unexpectedEvent)")
                let result = accepted ? "pass" : "reject"
                results.append(result)
                let ms = Int((ProcessInfo.processInfo.systemUptime - start) * 1000)
                print("MLX_PHYSICAL_CASE=\(index + 1); outcome=\(result); tokens=\(count); milliseconds=\(ms)")
            }
            return "MLX_PHYSICAL_PROBE=completed; cases=\(results.joined(separator: ",")); actionsExecuted=0"
        } catch { return "MLX_PHYSICAL_PROBE=failed; actionsExecuted=0" }
    }
}
