import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public enum AppleBaselineProfile: String, CaseIterable, Sendable {
    case routerSmall = "Router-small"
    case routerNormal = "Router-normal"

    public var inputLimitTokens: Int {
        switch self {
        case .routerSmall: 512
        case .routerNormal: 1_024
        }
    }

    public var outputLimitTokens: Int {
        switch self {
        case .routerSmall: 32
        case .routerNormal: 64
        }
    }
}

public struct AppleBenchmarkCase: Decodable, Equatable, Sendable {
    public let caseID: String
    public let language: String
    public let userText: String

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case language
        case userText = "user_text"
    }
}

public enum AppleProposalType: String, Codable, CaseIterable, Sendable {
    case toolCall = "tool_call"
    case clarify
    case noTool = "no_tool"
    case refuse
}

public enum AppleProposalIntent: String, Codable, CaseIterable, Sendable {
    case createReminder
    case summarizeNote
    case findFile
    case requestApproval
    case unknown
}

public enum AppleProposalTool: String, Codable, CaseIterable, Sendable {
    case createReminder
    case summarizeNote
    case findFile
    case requestApproval
}

public enum AppleProposalArgumentName: String, Codable, CaseIterable, Sendable {
    case title
    case time
    case date
    case noteText = "note_text"
    case noteReference = "note_reference"
    case query
    case fileType = "file_type"
    case dateHint = "date_hint"
    case actionSummary = "action_summary"
}

public enum AppleProposalReasonCode: String, Codable, CaseIterable, Sendable {
    case directIntent = "direct_intent"
    case missingRequiredArgument = "missing_required_argument"
    case ambiguousRequiredArguments = "ambiguous_required_arguments"
    case unresolvedNoteReference = "unresolved_note_reference"
    case ambiguousFileReference = "ambiguous_file_reference"
    case ambiguousActionReference = "ambiguous_action_reference"
    case unclearIntent = "unclear_intent"
    case unsupportedTool = "unsupported_tool"
    case unsupportedSensitiveAction = "unsupported_sensitive_action"
    case noMatchingLocalTool = "no_matching_local_tool"
}

public struct AppleProposalArguments: Codable, Equatable, Sendable {
    public let title: String?
    public let time: String?
    public let date: String?
    public let noteText: String?
    public let noteReference: String?
    public let query: String?
    public let fileType: String?
    public let dateHint: String?
    public let actionSummary: String?

    public init(
        title: String? = nil,
        time: String? = nil,
        date: String? = nil,
        noteText: String? = nil,
        noteReference: String? = nil,
        query: String? = nil,
        fileType: String? = nil,
        dateHint: String? = nil,
        actionSummary: String? = nil
    ) {
        self.title = title
        self.time = time
        self.date = date
        self.noteText = noteText
        self.noteReference = noteReference
        self.query = query
        self.fileType = fileType
        self.dateHint = dateHint
        self.actionSummary = actionSummary
    }

    public var normalizedDictionary: [String: String] {
        var values: [String: String] = [:]
        if let title { values[AppleProposalArgumentName.title.rawValue] = title }
        if let time { values[AppleProposalArgumentName.time.rawValue] = time }
        if let date { values[AppleProposalArgumentName.date.rawValue] = date }
        if let noteText { values[AppleProposalArgumentName.noteText.rawValue] = noteText }
        if let noteReference { values[AppleProposalArgumentName.noteReference.rawValue] = noteReference }
        if let query { values[AppleProposalArgumentName.query.rawValue] = query }
        if let fileType { values[AppleProposalArgumentName.fileType.rawValue] = fileType }
        if let dateHint { values[AppleProposalArgumentName.dateHint.rawValue] = dateHint }
        if let actionSummary { values[AppleProposalArgumentName.actionSummary.rawValue] = actionSummary }
        return values
    }
}

public struct AppleProposalSnapshot: Codable, Equatable, Sendable {
    public let proposalType: AppleProposalType
    public let intent: AppleProposalIntent
    public let tool: AppleProposalTool?
    public let arguments: AppleProposalArguments
    public let missingArguments: [AppleProposalArgumentName]
    public let reasonCode: AppleProposalReasonCode

    public init(
        proposalType: AppleProposalType,
        intent: AppleProposalIntent,
        tool: AppleProposalTool?,
        arguments: AppleProposalArguments,
        missingArguments: [AppleProposalArgumentName],
        reasonCode: AppleProposalReasonCode
    ) {
        self.proposalType = proposalType
        self.intent = intent
        self.tool = tool
        self.arguments = arguments
        self.missingArguments = missingArguments
        self.reasonCode = reasonCode
    }
}

public struct AppleNormalizedProposal: Codable, Equatable, Sendable {
    public let caseID: String
    public let proposalType: String
    public let intent: String
    public let tool: String?
    public let arguments: [String: String]
    public let missingArguments: [String]
    public let reasonCode: String
    public let repetitionDetected: Bool
    public let truncationDetected: Bool

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case proposalType
        case intent
        case tool
        case arguments
        case missingArguments
        case reasonCode
        case repetitionDetected
        case truncationDetected
    }

    public init(caseID: String, snapshot: AppleProposalSnapshot) {
        self.caseID = caseID
        proposalType = snapshot.proposalType.rawValue
        intent = snapshot.intent.rawValue
        tool = snapshot.tool?.rawValue
        arguments = snapshot.arguments.normalizedDictionary
        missingArguments = snapshot.missingArguments.map(\.rawValue)
        reasonCode = snapshot.reasonCode.rawValue
        repetitionDetected = false
        truncationDetected = false
    }
}

public struct AppleRawProposalRecord: Codable, Equatable, Sendable {
    public let caseID: String
    public let proposal: AppleProposalSnapshot
    public let inputTokenCount: Int
    public let outputTokenCount: Int

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case proposal
        case inputTokenCount = "input_token_count"
        case outputTokenCount = "output_token_count"
    }
}

public struct AppleTokenCountRecord: Codable, Equatable, Sendable {
    public let caseID: String
    public let preflightInputTokenCount: Int
    public let responseInputTokenCount: Int
    public let responseOutputTokenCount: Int

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case preflightInputTokenCount = "preflight_input_token_count"
        case responseInputTokenCount = "response_input_token_count"
        case responseOutputTokenCount = "response_output_token_count"
    }
}

public struct AppleGenerationConfig: Codable, Equatable, Sendable {
    public let samplingMode = "greedy"
    public let samplingEnabled = false
    public let temperature = 0.0
    public let topP = 1.0
    public let topK: Int? = nil
    public let maximumResponseTokens: Int
    public let seedSupported = false
    public let seed: Int? = nil
    public let includeSchemaInPrompt = true
    public let toolsCount = 0

    enum CodingKeys: String, CodingKey {
        case samplingMode = "sampling_mode"
        case samplingEnabled = "sampling_enabled"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case maximumResponseTokens = "maximum_response_tokens"
        case seedSupported = "seed_supported"
        case seed
        case includeSchemaInPrompt = "include_schema_in_prompt"
        case toolsCount = "tools_count"
    }

    public init(maximumResponseTokens: Int) {
        self.maximumResponseTokens = maximumResponseTokens
    }
}

public struct AppleRunMetadata: Codable, Equatable, Sendable {
    public let backendClass = "apple_system"
    public let framework = "Apple Foundation Models"
    public let profile: String
    public let benchmarkCaseCount: Int
    public let systemModelIdentifier: String
    public let contextLimitTokens: Int
    public let os: String
    public let architecture: String
    public let swiftToolchain: String
    public let instructionsID = "igentic-apple-router-v0"
    public let instructionsText: String
    public let evidenceClass = "host"
    public let physicalDeviceRun = false
    public let physicalDeviceReadinessClaimed = false

    enum CodingKeys: String, CodingKey {
        case backendClass = "backend_class"
        case framework
        case profile
        case benchmarkCaseCount = "benchmark_case_count"
        case systemModelIdentifier = "system_model_identifier"
        case contextLimitTokens = "context_limit_tokens"
        case os
        case architecture
        case swiftToolchain = "swift_toolchain"
        case instructionsID = "instructions_id"
        case instructionsText = "instructions_text"
        case evidenceClass = "evidence_class"
        case physicalDeviceRun = "physical_device_run"
        case physicalDeviceReadinessClaimed = "physical_device_readiness_claimed"
    }
}

public enum AppleFoundationBaselineError: Error, Equatable, CustomStringConvertible, Sendable {
    case invalidBenchmark(String)
    case outputDirectoryMissing
    case outputDirectoryNotDirectory
    case outputDirectoryIsSymlink
    case outputDirectoryNotEmpty
    case unsupportedPlatform
    case modelUnavailable(String)
    case inputBudgetExceeded(caseID: String, measured: Int, limit: Int)
    case invalidUsage(caseID: String)
    case evidenceWriteFailed(String)

    public var description: String {
        switch self {
        case .invalidBenchmark(let reason):
            return "invalid benchmark: \(reason)"
        case .outputDirectoryMissing:
            return "output directory does not exist"
        case .outputDirectoryNotDirectory:
            return "output path is not a directory"
        case .outputDirectoryIsSymlink:
            return "output directory must not be a symlink"
        case .outputDirectoryNotEmpty:
            return "output directory must be empty"
        case .unsupportedPlatform:
            return "Apple Foundation Models runner is unsupported on this platform or SDK"
        case .modelUnavailable(let reason):
            return "Apple system model unavailable: \(reason)"
        case let .inputBudgetExceeded(caseID, measured, limit):
            return "input token budget exceeded for \(caseID): \(measured) > \(limit)"
        case .invalidUsage(let caseID):
            return "invalid response token usage for \(caseID)"
        case .evidenceWriteFailed(let file):
            return "failed to write evidence file: \(file)"
        }
    }
}

public enum AppleFoundationBaselineContract {
    public static let expectedCaseCount = 40
    public static let instructions = """
    Classify one synthetic request into exactly one structured iGentic routing proposal. Do not execute anything. Supported intents and local route names are createReminder, summarizeNote, findFile, requestApproval, and unknown. Use clarify when required input is missing or ambiguous, noTool when no supported local route matches, and refuse for an unsupported sensitive action. Preserve only argument values supported by the request; do not invent missing values. For non-tool proposals, return no tool.
    """

    public static func loadBenchmark(data: Data) throws -> [AppleBenchmarkCase] {
        guard var text = String(data: data, encoding: .utf8) else {
            throw AppleFoundationBaselineError.invalidBenchmark("UTF-8 required")
        }

        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        var lines = text.components(separatedBy: "\n")
        if lines.last == "" {
            lines.removeLast()
        }
        guard !lines.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw AppleFoundationBaselineError.invalidBenchmark("blank JSONL line")
        }
        guard lines.count == expectedCaseCount else {
            throw AppleFoundationBaselineError.invalidBenchmark("expected 40 records")
        }

        let decoder = JSONDecoder()
        var cases: [AppleBenchmarkCase] = []
        var seenIDs = Set<String>()
        var languageCounts = ["de": 0, "en": 0]

        for line in lines {
            guard let lineData = line.data(using: .utf8) else {
                throw AppleFoundationBaselineError.invalidBenchmark("UTF-8 line conversion failed")
            }
            let record: AppleBenchmarkCase
            do {
                record = try decoder.decode(AppleBenchmarkCase.self, from: lineData)
            } catch {
                throw AppleFoundationBaselineError.invalidBenchmark("record JSON/schema invalid")
            }
            guard !record.caseID.isEmpty, !record.userText.isEmpty else {
                throw AppleFoundationBaselineError.invalidBenchmark("empty case id or user text")
            }
            guard seenIDs.insert(record.caseID).inserted else {
                throw AppleFoundationBaselineError.invalidBenchmark("duplicate case id")
            }
            guard languageCounts[record.language] != nil else {
                throw AppleFoundationBaselineError.invalidBenchmark("unsupported language")
            }
            languageCounts[record.language, default: 0] += 1
            cases.append(record)
        }

        guard languageCounts["de"] == 20, languageCounts["en"] == 20 else {
            throw AppleFoundationBaselineError.invalidBenchmark("expected 20 German and 20 English records")
        }
        return cases
    }

    public static func validateEmptyOutputDirectory(_ url: URL) throws {
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw AppleFoundationBaselineError.outputDirectoryMissing
        }
        guard isDirectory.boolValue else {
            throw AppleFoundationBaselineError.outputDirectoryNotDirectory
        }
        let values = try url.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard values.isSymbolicLink != true else {
            throw AppleFoundationBaselineError.outputDirectoryIsSymlink
        }
        let contents = try manager.contentsOfDirectory(atPath: url.path)
        guard contents.isEmpty else {
            throw AppleFoundationBaselineError.outputDirectoryNotEmpty
        }
    }

    public static func normalizedProposal(
        caseID: String,
        snapshot: AppleProposalSnapshot
    ) -> AppleNormalizedProposal {
        AppleNormalizedProposal(caseID: caseID, snapshot: snapshot)
    }

    public static var foundationModelsCompiled: Bool {
        #if canImport(FoundationModels)
        true
        #else
        false
        #endif
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Routing proposal type")
enum FMProposalType {
    case toolCall
    case clarify
    case noTool
    case refuse
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Supported iGentic intent")
enum FMProposalIntent {
    case createReminder
    case summarizeNote
    case findFile
    case requestApproval
    case unknown
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Supported local route")
enum FMProposalTool {
    case createReminder
    case summarizeNote
    case findFile
    case requestApproval
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Missing argument name")
enum FMProposalArgumentName {
    case title
    case time
    case date
    case noteText
    case noteReference
    case query
    case fileType
    case dateHint
    case actionSummary
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Routing reason")
enum FMProposalReasonCode {
    case directIntent
    case missingRequiredArgument
    case ambiguousRequiredArguments
    case unresolvedNoteReference
    case ambiguousFileReference
    case ambiguousActionReference
    case unclearIntent
    case unsupportedTool
    case unsupportedSensitiveAction
    case noMatchingLocalTool
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "Values explicitly supported by the synthetic request")
struct FMProposalArguments {
    var title: String?
    var time: String?
    var date: String?
    var noteText: String?
    var noteReference: String?
    var query: String?
    var fileType: String?
    var dateHint: String?
    var actionSummary: String?
}

@available(iOS 26.0, macOS 26.0, *)
@Generable(description: "One proposal only; never execute it")
struct FMGeneratedProposal {
    var proposalType: FMProposalType
    var intent: FMProposalIntent
    var tool: FMProposalTool?
    var arguments: FMProposalArguments
    @Guide(.maximumCount(9))
    var missingArguments: [FMProposalArgumentName]
    var reasonCode: FMProposalReasonCode
}

@available(iOS 26.0, macOS 26.0, *)
extension FMGeneratedProposal {
    var snapshot: AppleProposalSnapshot {
        AppleProposalSnapshot(
            proposalType: proposalType.snapshot,
            intent: intent.snapshot,
            tool: tool?.snapshot,
            arguments: arguments.snapshot,
            missingArguments: missingArguments.map(\.snapshot),
            reasonCode: reasonCode.snapshot
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalType {
    var snapshot: AppleProposalType {
        switch self {
        case .toolCall: .toolCall
        case .clarify: .clarify
        case .noTool: .noTool
        case .refuse: .refuse
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalIntent {
    var snapshot: AppleProposalIntent {
        switch self {
        case .createReminder: .createReminder
        case .summarizeNote: .summarizeNote
        case .findFile: .findFile
        case .requestApproval: .requestApproval
        case .unknown: .unknown
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalTool {
    var snapshot: AppleProposalTool {
        switch self {
        case .createReminder: .createReminder
        case .summarizeNote: .summarizeNote
        case .findFile: .findFile
        case .requestApproval: .requestApproval
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalArgumentName {
    var snapshot: AppleProposalArgumentName {
        switch self {
        case .title: .title
        case .time: .time
        case .date: .date
        case .noteText: .noteText
        case .noteReference: .noteReference
        case .query: .query
        case .fileType: .fileType
        case .dateHint: .dateHint
        case .actionSummary: .actionSummary
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalReasonCode {
    var snapshot: AppleProposalReasonCode {
        switch self {
        case .directIntent: .directIntent
        case .missingRequiredArgument: .missingRequiredArgument
        case .ambiguousRequiredArguments: .ambiguousRequiredArguments
        case .unresolvedNoteReference: .unresolvedNoteReference
        case .ambiguousFileReference: .ambiguousFileReference
        case .ambiguousActionReference: .ambiguousActionReference
        case .unclearIntent: .unclearIntent
        case .unsupportedTool: .unsupportedTool
        case .unsupportedSensitiveAction: .unsupportedSensitiveAction
        case .noMatchingLocalTool: .noMatchingLocalTool
        }
    }
}

@available(iOS 26.0, macOS 26.0, *)
private extension FMProposalArguments {
    var snapshot: AppleProposalArguments {
        AppleProposalArguments(
            title: title,
            time: time,
            date: date,
            noteText: noteText,
            noteReference: noteReference,
            query: query,
            fileType: fileType,
            dateHint: dateHint,
            actionSummary: actionSummary
        )
    }
}
#endif

public struct AppleFoundationBaselineRunner: Sendable {
    public init() {}

    public func run(
        benchmarkURL: URL,
        profile: AppleBaselineProfile,
        outputDirectory: URL
    ) async throws {
        try AppleFoundationBaselineContract.validateEmptyOutputDirectory(outputDirectory)
        let benchmarkData = try Data(contentsOf: benchmarkURL)
        let cases = try AppleFoundationBaselineContract.loadBenchmark(data: benchmarkData)

        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            try await runFoundationModels(
                cases: cases,
                profile: profile,
                outputDirectory: outputDirectory
            )
            return
        }
        #endif

        throw AppleFoundationBaselineError.unsupportedPlatform
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, iOS 26.0, *)
    private func runFoundationModels(
        cases: [AppleBenchmarkCase],
        profile: AppleBaselineProfile,
        outputDirectory: URL
    ) async throws {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw AppleFoundationBaselineError.modelUnavailable("deviceNotEligible")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw AppleFoundationBaselineError.modelUnavailable("appleIntelligenceNotEnabled")
        case .unavailable(.modelNotReady):
            throw AppleFoundationBaselineError.modelUnavailable("modelNotReady")
        case .unavailable:
            throw AppleFoundationBaselineError.modelUnavailable("unknownSystemCondition")
        @unknown default:
            throw AppleFoundationBaselineError.modelUnavailable("unknownSystemCondition")
        }

        let instructions = Instructions(AppleFoundationBaselineContract.instructions)
        let contextLimit = try await model.contextSize
        let instructionsTokens = try await model.tokenCount(for: instructions)
        let schemaTokens = try await model.tokenCount(for: FMGeneratedProposal.generationSchema)
        let options = GenerationOptions(
            sampling: .greedy,
            temperature: 0.0,
            maximumResponseTokens: profile.outputLimitTokens
        )

        var rawRecords: [AppleRawProposalRecord] = []
        var normalizedRecords: [AppleNormalizedProposal] = []
        var tokenRecords: [AppleTokenCountRecord] = []

        for benchmarkCase in cases {
            let prompt = Prompt(benchmarkCase.userText)
            let promptTokens = try await model.tokenCount(for: prompt)
            let preflightInputTokens = instructionsTokens + schemaTokens + promptTokens
            guard preflightInputTokens <= profile.inputLimitTokens else {
                throw AppleFoundationBaselineError.inputBudgetExceeded(
                    caseID: benchmarkCase.caseID,
                    measured: preflightInputTokens,
                    limit: profile.inputLimitTokens
                )
            }

            let session = LanguageModelSession(
                model: model,
                tools: [],
                instructions: instructions
            )
            let response = try await session.respond(
                generating: FMGeneratedProposal.self,
                includeSchemaInPrompt: true,
                options: options
            ) {
                benchmarkCase.userText
            }

            let responseInputTokens = response.usage.input.totalTokenCount
            let responseTotalTokens = response.usage.totalTokenCount
            guard responseInputTokens <= profile.inputLimitTokens else {
                throw AppleFoundationBaselineError.inputBudgetExceeded(
                    caseID: benchmarkCase.caseID,
                    measured: responseInputTokens,
                    limit: profile.inputLimitTokens
                )
            }
            guard responseTotalTokens >= responseInputTokens else {
                throw AppleFoundationBaselineError.invalidUsage(caseID: benchmarkCase.caseID)
            }
            let responseOutputTokens = responseTotalTokens - responseInputTokens
            let snapshot = response.content.snapshot

            rawRecords.append(
                AppleRawProposalRecord(
                    caseID: benchmarkCase.caseID,
                    proposal: snapshot,
                    inputTokenCount: responseInputTokens,
                    outputTokenCount: responseOutputTokens
                )
            )
            normalizedRecords.append(
                AppleFoundationBaselineContract.normalizedProposal(
                    caseID: benchmarkCase.caseID,
                    snapshot: snapshot
                )
            )
            tokenRecords.append(
                AppleTokenCountRecord(
                    caseID: benchmarkCase.caseID,
                    preflightInputTokenCount: preflightInputTokens,
                    responseInputTokenCount: responseInputTokens,
                    responseOutputTokenCount: responseOutputTokens
                )
            )
        }

        let metadata = AppleRunMetadata(
            profile: profile.rawValue,
            benchmarkCaseCount: cases.count,
            systemModelIdentifier: model.variant.displayName,
            contextLimitTokens: contextLimit,
            os: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: Self.architecture,
            swiftToolchain: Self.swiftToolchain(),
            instructionsText: AppleFoundationBaselineContract.instructions
        )
        let generationConfig = AppleGenerationConfig(
            maximumResponseTokens: profile.outputLimitTokens
        )

        try Self.writeEvidence(
            outputDirectory: outputDirectory,
            rawRecords: rawRecords,
            normalizedRecords: normalizedRecords,
            tokenRecords: tokenRecords,
            generationConfig: generationConfig,
            metadata: metadata
        )
    }
    #endif

    private static var architecture: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }

    private static func swiftToolchain() -> String {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["swift", "--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return "unavailable" }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unavailable"
        } catch {
            return "unavailable"
        }
        #else
        return "unsupported-platform"
        #endif
    }

    private static func writeEvidence(
        outputDirectory: URL,
        rawRecords: [AppleRawProposalRecord],
        normalizedRecords: [AppleNormalizedProposal],
        tokenRecords: [AppleTokenCountRecord],
        generationConfig: AppleGenerationConfig,
        metadata: AppleRunMetadata
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]

        let files: [(String, Data)] = try [
            ("raw-proposals.jsonl", jsonLines(rawRecords, encoder: encoder)),
            ("normalized-proposals.jsonl", jsonLines(normalizedRecords, encoder: encoder)),
            ("token-counts.json", jsonDocument(tokenRecords, encoder: encoder)),
            ("applied-generation-config.json", jsonDocument(generationConfig, encoder: encoder)),
            ("run-metadata.json", jsonDocument(metadata, encoder: encoder)),
        ]

        var created: [URL] = []
        do {
            for (name, data) in files {
                let target = outputDirectory.appendingPathComponent(name, isDirectory: false)
                try data.write(to: target, options: .withoutOverwriting)
                created.append(target)
            }
        } catch {
            for target in created.reversed() {
                try? FileManager.default.removeItem(at: target)
            }
            let failedName = files.first { name, _ in
                !FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent(name).path)
            }?.0 ?? "unknown"
            throw AppleFoundationBaselineError.evidenceWriteFailed(failedName)
        }
    }

    private static func jsonLines<T: Encodable>(
        _ records: [T],
        encoder: JSONEncoder
    ) throws -> Data {
        var data = Data()
        for record in records {
            data.append(try encoder.encode(record))
            data.append(0x0A)
        }
        return data
    }

    private static func jsonDocument<T: Encodable>(
        _ value: T,
        encoder: JSONEncoder
    ) throws -> Data {
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }
}
