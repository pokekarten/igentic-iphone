import Foundation
import AgentCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

/// Research-only, synthetic tool declarations. No dispatcher or executable tools.
public enum ToolCallingResearch {
    public enum Candidate: String, Sendable {
        case falcon90, miniCPM5, qwen35
    }

    private struct Fixture {
        let prompt: String
        let function: String
        let key: String
        let value: String
    }

    private static let fixtures: [Fixture] = [
        .init(prompt: "Read the battery metric.", function: "read_metric", key: "metric", value: "battery"),
        .init(prompt: "Find the note with search query atlas.", function: "find_note", key: "query", value: "atlas"),
        .init(prompt: "Lies den Speicherstatus (storage).", function: "read_metric", key: "metric", value: "storage"),
        .init(prompt: "Suche eine Notiz mit dem Suchbegriff orbit.", function: "find_note", key: "query", value: "orbit")
    ]

    private static func declarations() -> [ToolSpec] {
        let metric: [String: any Sendable] = ["type": "string", "enum": ["battery", "storage"]]
        let query: [String: any Sendable] = ["type": "string"]
        func spec(_ name: String, _ description: String, _ key: String, _ property: [String: any Sendable]) -> ToolSpec {
            let properties: [String: any Sendable] = [key: property]
            let parameters: [String: any Sendable] = ["type": "object", "properties": properties, "required": [key], "additionalProperties": false]
            let function: [String: any Sendable] = ["name": name, "description": description, "parameters": parameters]
            return ["type": "function", "function": function]
        }
        return [spec("read_metric", "Read a synthetic device metric.", "metric", metric),
                spec("find_note", "Search synthetic notes by a literal query.", "query", query)]
    }

    public static func run(modelDirectory: URL, candidate: Candidate) async -> String {
        let prefix = "TOOL_RESEARCH_" + candidate.rawValue.uppercased()
        do {
            let admission: Result<PinnedMLXSnapshot.Receipt, PinnedMLXSnapshot.Rejection>
            switch candidate {
            case .falcon90: admission = PinnedMLXSnapshot.verifyFalcon90Research(directory: modelDirectory)
            case .miniCPM5: admission = PinnedMLXSnapshot.verifyMiniCPM5Research(directory: modelDirectory)
            case .qwen35: admission = PinnedMLXSnapshot.verifyQwen35Research(directory: modelDirectory)
            }
            guard case .success = admission else { return "\(prefix)=integrityRejected; actionsExecuted=0" }
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            var exact = 0, rejected = 0, capped = 0
            for (index, fixture) in fixtures.enumerated() {
                let session = ChatSession(model, instructions: "Select exactly one declared function matching the request. Do not invent arguments.",
                    generateParameters: .init(maxTokens: 96, temperature: 0),
                    additionalContext: candidate == .falcon90 ? nil : ["enable_thinking": false],
                    tools: declarations(), toolDispatch: nil)
                var calls: [ToolCall] = []
                var rejectedCall = false, extraText = false, unexpected = false
                var completion: GenerateCompletionInfo?
                let before = ProcessInfo.processInfo.systemUptime
                for try await event in session.streamDetails(to: fixture.prompt) {
                    switch event {
                    case .toolCall(let call): calls.append(call)
                    case .rejectedToolCall: rejectedCall = true
                    case .chunk(let text): if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { extraText = true }
                    case .reasoning: unexpected = true
                    case .info(let info): if completion != nil { unexpected = true }; completion = info
                    default: unexpected = true
                    }
                }
                let natural: Bool
                if case .some(.stop) = completion?.stopReason { natural = true } else { natural = false }
                let count = completion?.generationTokenCount ?? -1
                let expected = ToolCall.Function(name: fixture.function, arguments: [fixture.key: JSONValue.string(fixture.value)])
                let pass = !rejectedCall && !extraText && !unexpected && natural && (1..<96).contains(count)
                    && calls.count == 1 && calls.first?.function == expected
                if pass { exact += 1 }
                if rejectedCall { rejected += 1 }
                if count >= 96 { capped += 1 }
                print("\(prefix)_CASE=\(index+1); pass=\(pass); calls=\(calls.count); rejected=\(rejectedCall); extraText=\(extraText); natural=\(natural); tokens=\(count); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-before)*1000))")
            }
            return "\(prefix)=completed; passed=\(exact); total=4; parserRejected=\(rejected); capped=\(capped); actionsExecuted=0"
        } catch { return "\(prefix)=failed; actionsExecuted=0" }
    }
}
