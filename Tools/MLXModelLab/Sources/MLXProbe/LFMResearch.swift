import Foundation
import AgentCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

/// Research-only classifier benchmark. No tool dispatch or journal mutation.
public enum LFMResearch {
    public enum Candidate: Sendable { case lfm, qwen }
    private struct Fixture {
        let prompt: String
        let expected: String
        let german: Bool
    }

    private static let fixtures: [Fixture] = [
        .init(prompt: "Read the device status only.", expected: "A", german: false),
        .init(prompt: "Lies ausschließlich den Gerätestatus.", expected: "A", german: true),
        .init(prompt: "Beende die Aufgabe ohne weitere Aktion.", expected: "B", german: true),
        .init(prompt: "Stop the task now.", expected: "B", german: false),
        .init(prompt: "Prüfe den Akkustand.", expected: "A", german: true),
        .init(prompt: "Keine weiteren Schritte, bitte abschließen.", expected: "B", german: true),
        .init(prompt: "Check how much battery remains.", expected: "A", german: false),
        .init(prompt: "We are done; do not perform another step.", expected: "B", german: false),
        .init(prompt: "Wie viel Akku ist noch vorhanden?", expected: "A", german: true),
        .init(prompt: "Schließe den Vorgang jetzt ab.", expected: "B", german: true),
        .init(prompt: "Inspect the current device state.", expected: "A", german: false),
        .init(prompt: "End this task without any additional reads.", expected: "B", german: false)
    ]

    public static func run(modelDirectory: URL, candidate: Candidate = .lfm) async -> String {
        let prefix = candidate == .lfm ? "LFM" : "QWEN_CLASS"
        do {
            let admission = candidate == .lfm ? AgentCore.PinnedMLXSnapshot.verifyLFM25Research(directory: modelDirectory) : AgentCore.PinnedMLXSnapshot.verifyQwen3(directory: modelDirectory)
            guard case .success(let receipt) = admission else {
                return "\(prefix)_RESEARCH=integrityRejected; actionsExecuted=0"
            }
            print("\(prefix)_INTEGRITY=verified; files=\(receipt.fileCount); bytes=\(receipt.totalBytes)")
            let start = ProcessInfo.processInfo.systemUptime
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            print("\(prefix)_LOAD=completed; milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000))")
            var passed = 0
            var holdout = 0
            for (index, fixture) in fixtures.enumerated() {
                let instructions = fixture.german
                    ? "Ordne die Aufgabe zu. A = Gerätestatus oder Akku lesen. B = Aufgabe beenden, keine weitere Aktion. Antworte nur A oder B."
                    : "Classify the request: A = read device status or battery; B = stop or finish without another action. Reply with exactly A or B."
                let session = ChatSession(model, instructions: instructions,
                    generateParameters: .init(maxTokens: 16, temperature: 0), additionalContext: candidate == .qwen ? ["enable_thinking": false] : [:])
                var response = ""
                var invalid = false
                var completion: GenerateCompletionInfo?
                let before = ProcessInfo.processInfo.systemUptime
                for try await event in session.streamDetails(to: fixture.prompt) {
                    switch event {
                    case .chunk(let text):
                        if response.utf8.count + text.utf8.count <= 16 { response += text }
                        else { invalid = true }
                    case .info(let info):
                        if completion != nil { invalid = true }; completion = info
                    default: invalid = true
                    }
                }
                let natural: Bool
                if case .some(.stop) = completion?.stopReason { natural = true } else { natural = false }
                let count = completion?.generationTokenCount ?? -1
                let correct = !invalid && natural && (1..<16).contains(count)
                    && response.trimmingCharacters(in: .whitespacesAndNewlines) == fixture.expected
                if correct {
                    passed += 1
                    if index >= 6 { holdout += 1 }
                }
                print("\(prefix)_CASE=\(index+1); outcome=\(correct ? "pass" : "reject"); tokens=\(count); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-before)*1000))")
            }
            return "\(prefix)_RESEARCH=completed; passed=\(passed); total=12; holdout=\(holdout); actionsExecuted=0"
        } catch { return "\(prefix)_RESEARCH=failed; actionsExecuted=0" }
    }
}
