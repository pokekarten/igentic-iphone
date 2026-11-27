import Foundation
import FoundationModels
import AgentCore
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import Tokenizers
import HuggingFace

/// Independent closed-answer reasoning smoke. Original synthetic inputs; no tools.
public enum ReasoningPilot {
    public enum Candidate: String, Sendable { case qwen35, qwen3, miniCPM5, qwen2b, lfm12, qwen3text4b }
    private struct Fixture {
        let prompt: String
        let expected: String
        let category: String
        init(_ prompt: String, _ expected: String, _ category: String) {
            self.prompt = prompt; self.expected = expected; self.category = category
        }
    }
    private static let instructions = "Solve the task using only the supplied facts. Return exactly the requested number, letter or comma-separated sequence, without explanation."
    private static let fixtures: [Fixture] = [
        .init("A battery has 80 units. A task costs 17 units and charging adds 9. Return the final number of units.", "72", "arithmetic"),
        .init("Ein Budget von 125 Euro wird um 38 Euro und danach um 19 Euro reduziert. Gib nur den Restbetrag als Zahl aus.", "68", "arithmetic"),
        .init("A job starts at 09:20, lasts 45 minutes, and must be followed by a 10-minute break. Return the end time of the break as HH:MM.", "10:15", "arithmetic"),
        .init("Vier gleich große Dateien belegen jeweils 23 MB. Danach wird eine Datei gelöscht. Gib den danach belegten Speicher in MB als Zahl aus.", "69", "arithmetic"),
        .init("Three tasks: A must follow B, B must follow C. Return their only valid execution order as comma-separated letters.", "C,B,A", "planning"),
        .init("Drei Schritte: X muss vor Z erfolgen, Y unmittelbar nach X, Z zuletzt. Gib die Reihenfolge mit Kommas aus.", "X,Y,Z", "planning"),
        .init("Choose the earliest available 30-minute slot. Busy: 09:00–09:45 and 10:00–10:30. Options A=09:30, B=09:45, C=10:30. Return the letter.", "C", "planning"),
        .init("Wähle die billigste zulässige Option mit mindestens 8 GB RAM: A=6 GB für 90 Euro, B=8 GB für 120 Euro, C=12 GB für 110 Euro. Nur Buchstabe.", "C", "planning"),
        .init("State starts at 2 notes. Add 3, delete 1, then attempt a denied deletion of 2 that has no effect. Return final note count.", "4", "state"),
        .init("Ein Zähler beginnt bei 5. Erhöhe um 4, ein fehlgeschlagener Schritt ändert nichts, reduziere um 2. Gib den Endwert aus.", "7", "state"),
        .init("Start with 6, process message X (+3) once, replay X (a replay has no effect), then process message Y (-2). Final number?", "7", "state"),
        .init("Ein Wert ist 10. Aktion A erhöht um 2, Aktion B ist abgebrochen und ändert nichts, Aktion C halbiert den Wert. Nur Endwert als Zahl.", "6", "state"),
        .init("Source A states Paris; source B states Rome. Neither is preferred. Options A=Paris, B=Rome, C=conflict. Return letter.", "C", "evidence"),
        .init("Quelle A nennt 12, Quelle B nennt 12. Option A=Übereinstimmung, B=Widerspruch, C=keine Belege. Nur Buchstabe.", "A", "evidence"),
        .init("The only record says 'location unknown'. Options A=Berlin, B=Munich, C=insufficient information. Return letter.", "C", "evidence"),
        .init("Für eine Buchung ist eine bestätigte Uhrzeit nötig. Der Datensatz enthält nur das Datum. A=buchen, B=nach Uhrzeit fragen, C=Uhrzeit erfinden. Nur Buchstabe.", "B", "evidence")
    ]
    private static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ", ", with: ",")
    }
    public static func run(modelDirectory: URL, candidate: Candidate) async -> String {
        let prefix = "REASON_V1_" + candidate.rawValue.uppercased()
        do {
            let admission: Result<PinnedMLXSnapshot.Receipt, PinnedMLXSnapshot.Rejection>
            switch candidate {
            case .qwen35: admission = PinnedMLXSnapshot.verifyQwen35Research(directory: modelDirectory)
            case .qwen3: admission = PinnedMLXSnapshot.verifyQwen3(directory: modelDirectory)
            case .miniCPM5: admission = PinnedMLXSnapshot.verifyMiniCPM5Research(directory: modelDirectory)
            case .qwen2b: admission = PinnedMLXSnapshot.verifyQwen2BResearch(directory: modelDirectory)
            case .lfm12: admission = PinnedMLXSnapshot.verifyLFM12Research(directory: modelDirectory)
            case .qwen3text4b: admission = PinnedMLXSnapshot.verifyQwen3Text4BResearch(directory: modelDirectory)
            }
            guard case .success = admission else { return "\(prefix)=integrityRejected; actionsExecuted=0" }
            if (candidate == .qwen2b || candidate == .qwen3text4b) && !LargeModelPreflight.canLoad(weightBytes: candidate == .qwen2b ? 1_722_271_785 : 2_263_022_417) {
                return "\(prefix)=memoryOrThermalBlocked; actionsExecuted=0"
            }
            let model = try await LLMModelFactory.shared.loadContainer(from: modelDirectory, using: #huggingFaceTokenizerLoader())
            var exact = 0, capped = 0, completed = 0
            var resourceStopped = false
            for (index, fixture) in fixtures.enumerated() {
                if (candidate == .qwen2b || candidate == .qwen3text4b) && !LargeModelPreflight.canContinue() {
                    resourceStopped = true; break
                }
                let thermal = ProcessInfo.processInfo.thermalState
                if thermal == .serious || thermal == .critical { break }
                let session = ChatSession(model, instructions: instructions, generateParameters: .init(maxTokens: 96, temperature: 0),
                    additionalContext: (candidate == .lfm12 || candidate == .qwen3text4b) ? nil : ["enable_thinking": false])
                var text = "", unexpected = false
                var completion: GenerateCompletionInfo?
                let start = ProcessInfo.processInfo.systemUptime
                for try await event in session.streamDetails(to: fixture.prompt) {
                    switch event {
                    case .chunk(let chunk):
                        if text.utf8.count + chunk.utf8.count <= 4096 { text += chunk } else { unexpected = true }
                    case .info(let info): if completion != nil { unexpected = true }; completion = info
                    default: unexpected = true
                    }
                }
                let natural: Bool
                if case .some(.stop) = completion?.stopReason { natural = true } else { natural = false }
                let n = completion?.generationTokenCount ?? -1
                let pass = !unexpected && natural && (1..<96).contains(n) && normalized(text) == fixture.expected
                if pass { exact += 1 }
                if n >= 96 { capped += 1 }
                completed += 1
                print("\(prefix)_CASE=\(index+1); category=\(fixture.category); pass=\(pass); tokens=\(n); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000))")
            }
            return "\(prefix)=\(completed==16 ? "completed" : (resourceStopped ? "resourceStopped" : "thermalStopped")); passed=\(exact); completed=\(completed); total=16; capped=\(capped); actionsExecuted=0"
        } catch { return "\(prefix)=failed; actionsExecuted=0" }
    }
    @MainActor public static func runApple() async -> String {
        let prefix = "REASON_V1_APPLE"
        guard SystemLanguageModel.default.isAvailable else { return "\(prefix)=unavailable; actionsExecuted=0" }
        var exact = 0, completed = 0, errors = 0
        for (index, fixture) in fixtures.enumerated() {
            let thermal = ProcessInfo.processInfo.thermalState
            if thermal == .serious || thermal == .critical { break }
            let start = ProcessInfo.processInfo.systemUptime
            var pass = false, failed = false
            do {
                let session = LanguageModelSession(model: SystemLanguageModel.default, tools: [], instructions: instructions)
                let reply = try await session.respond(to: fixture.prompt, options: GenerationOptions(sampling: .greedy, maximumResponseTokens: 96)).content
                pass = normalized(reply) == fixture.expected
            } catch { failed = true; errors += 1 }
            if pass { exact += 1 }; completed += 1
            print("\(prefix)_CASE=\(index+1); category=\(fixture.category); pass=\(pass); error=\(failed); milliseconds=\(Int((ProcessInfo.processInfo.systemUptime-start)*1000))")
        }
        return "\(prefix)=\(completed==16 ? "completed" : "thermalStopped"); passed=\(exact); completed=\(completed); total=16; errors=\(errors); actionsExecuted=0"
    }
}
