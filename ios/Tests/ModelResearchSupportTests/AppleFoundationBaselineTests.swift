import Foundation
import XCTest
@testable import ModelResearchSupport

final class AppleFoundationBaselineTests: XCTestCase {
    func testProfilesKeepCanonicalV0Budgets() {
        XCTAssertEqual(AppleBaselineProfile.routerSmall.inputLimitTokens, 512)
        XCTAssertEqual(AppleBaselineProfile.routerSmall.outputLimitTokens, 32)
        XCTAssertEqual(AppleBaselineProfile.routerNormal.inputLimitTokens, 1_024)
        XCTAssertEqual(AppleBaselineProfile.routerNormal.outputLimitTokens, 64)
    }

    func testBenchmarkLoaderReadsOnlyExecutionFieldsAndPreservesOrder() throws {
        let data = makeBenchmarkData()
        let records = try AppleFoundationBaselineContract.loadBenchmark(data: data)

        XCTAssertEqual(records.count, 40)
        XCTAssertEqual(records.first?.caseID, "de-case-001")
        XCTAssertEqual(records.last?.caseID, "en-case-020")
        XCTAssertEqual(records.first?.userText, "Synthetic request 1")
        XCTAssertEqual(records.filter { $0.language == "de" }.count, 20)
        XCTAssertEqual(records.filter { $0.language == "en" }.count, 20)
    }

    func testBenchmarkLoaderRejectsDuplicateCaseID() throws {
        let data = makeBenchmarkData(duplicateCaseIDAt: 1)

        XCTAssertThrowsError(try AppleFoundationBaselineContract.loadBenchmark(data: data)) { error in
            XCTAssertEqual(
                error as? AppleFoundationBaselineError,
                .invalidBenchmark("duplicate case id")
            )
        }
    }

    func testBenchmarkLoaderRejectsWrongLanguageSplit() throws {
        let data = makeBenchmarkData(forceLastLanguage: "de")

        XCTAssertThrowsError(try AppleFoundationBaselineContract.loadBenchmark(data: data)) { error in
            XCTAssertEqual(
                error as? AppleFoundationBaselineError,
                .invalidBenchmark("expected 20 German and 20 English records")
            )
        }
    }

    func testNormalizationCopiesGeneratedMeaningWithoutSemanticRepair() {
        let snapshot = AppleProposalSnapshot(
            proposalType: .clarify,
            intent: .findFile,
            tool: .createReminder,
            arguments: AppleProposalArguments(
                title: "Unrelated but model-generated",
                dateHint: "last week"
            ),
            missingArguments: [.query, .query],
            reasonCode: .ambiguousFileReference
        )

        let normalized = AppleFoundationBaselineContract.normalizedProposal(
            caseID: "synthetic-case",
            snapshot: snapshot
        )

        XCTAssertEqual(normalized.proposalType, "clarify")
        XCTAssertEqual(normalized.intent, "findFile")
        XCTAssertEqual(normalized.tool, "createReminder")
        XCTAssertEqual(
            normalized.arguments,
            ["title": "Unrelated but model-generated", "date_hint": "last week"]
        )
        XCTAssertEqual(normalized.missingArguments, ["query", "query"])
        XCTAssertEqual(normalized.reasonCode, "ambiguous_file_reference")
        XCTAssertFalse(normalized.repetitionDetected)
        XCTAssertFalse(normalized.truncationDetected)
    }

    func testArgumentNormalizationOmitsOnlyNilValues() {
        let arguments = AppleProposalArguments(
            title: "",
            time: "tomorrow 09:00",
            noteText: nil,
            fileType: "pdf"
        )

        XCTAssertEqual(
            arguments.normalizedDictionary,
            [
                "title": "",
                "time": "tomorrow 09:00",
                "file_type": "pdf",
            ]
        )
    }

    func testOutputDirectoryMustExistAndBeEmpty() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        XCTAssertThrowsError(
            try AppleFoundationBaselineContract.validateEmptyOutputDirectory(root)
        ) { error in
            XCTAssertEqual(error as? AppleFoundationBaselineError, .outputDirectoryMissing)
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        XCTAssertNoThrow(try AppleFoundationBaselineContract.validateEmptyOutputDirectory(root))

        try Data("occupied".utf8).write(to: root.appendingPathComponent("existing.txt"))
        XCTAssertThrowsError(
            try AppleFoundationBaselineContract.validateEmptyOutputDirectory(root)
        ) { error in
            XCTAssertEqual(error as? AppleFoundationBaselineError, .outputDirectoryNotEmpty)
        }
    }

    func testOutputDirectoryRejectsSymlink() throws {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = parent.appendingPathComponent("target", isDirectory: true)
        let link = parent.appendingPathComponent("link", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)

        XCTAssertThrowsError(
            try AppleFoundationBaselineContract.validateEmptyOutputDirectory(link)
        ) { error in
            XCTAssertEqual(error as? AppleFoundationBaselineError, .outputDirectoryIsSymlink)
        }
    }

    func testGenerationConfigPinsGreedyNoSeedNoTools() {
        let config = AppleGenerationConfig(maximumResponseTokens: 32)

        XCTAssertEqual(config.samplingMode, "greedy")
        XCTAssertFalse(config.samplingEnabled)
        XCTAssertEqual(config.temperature, 0.0)
        XCTAssertEqual(config.topP, 1.0)
        XCTAssertNil(config.topK)
        XCTAssertEqual(config.maximumResponseTokens, 32)
        XCTAssertFalse(config.seedSupported)
        XCTAssertNil(config.seed)
        XCTAssertTrue(config.includeSchemaInPrompt)
        XCTAssertEqual(config.toolsCount, 0)
    }

    #if !canImport(FoundationModels)
    func testRunnerFailsUnsupportedWithoutWritingEvidenceWhenFrameworkIsAbsent() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let output = root.appendingPathComponent("output", isDirectory: true)
        let benchmark = root.appendingPathComponent("benchmark.jsonl")
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try makeBenchmarkData().write(to: benchmark)

        do {
            try await AppleFoundationBaselineRunner().run(
                benchmarkURL: benchmark,
                profile: .routerSmall,
                outputDirectory: output
            )
            XCTFail("Expected unsupported platform")
        } catch {
            XCTAssertEqual(error as? AppleFoundationBaselineError, .unsupportedPlatform)
        }
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: output.path), [])
    }
    #endif

    private func makeBenchmarkData(
        duplicateCaseIDAt duplicateIndex: Int? = nil,
        forceLastLanguage: String? = nil
    ) -> Data {
        var lines: [String] = []
        for index in 0..<40 {
            let language = index < 20 ? "de" : "en"
            let ordinal = index < 20 ? index + 1 : index - 19
            var caseID = String(format: "%@-case-%03d", language, ordinal)
            if duplicateIndex == index {
                caseID = "de-case-001"
            }
            let actualLanguage = index == 39 ? (forceLastLanguage ?? language) : language
            let record: [String: Any] = [
                "case_id": caseID,
                "language": actualLanguage,
                "user_text": "Synthetic request \(index + 1)",
                "expected_proposal_type": "refuse",
                "expected_intent": "unknown",
                "expected_tool": NSNull(),
                "expected_arguments": ["secret_expected_value": "must never be decoded"],
                "required_arguments": [],
                "expected_missing_arguments": [],
                "expected_reason_code": "unsupported_sensitive_action",
                "category": "refusal",
                "immutable_test": true,
            ]
            let data = try! JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
            lines.append(String(data: data, encoding: .utf8)!)
        }
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }
}
