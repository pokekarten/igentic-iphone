import Foundation
import XCTest
@testable import ModelResearchSupport

final class AppleFoundationBaselineEvidenceEncodingTests: XCTestCase {
    func testNormalizedProposalEncodesNullToolExplicitly() throws {
        let proposal = AppleNormalizedProposal(
            caseID: "synthetic-clarify",
            snapshot: AppleProposalSnapshot(
                proposalType: .clarify,
                intent: .findFile,
                tool: nil,
                arguments: AppleProposalArguments(dateHint: "last week"),
                missingArguments: [.query],
                reasonCode: .ambiguousFileReference
            )
        )

        let object = try jsonObject(proposal)

        XCTAssertEqual(
            Set(object.keys),
            [
                "case_id",
                "proposalType",
                "intent",
                "tool",
                "arguments",
                "missingArguments",
                "reasonCode",
                "repetitionDetected",
                "truncationDetected",
            ]
        )
        XCTAssertTrue(object["tool"] is NSNull)
        XCTAssertEqual(object["proposalType"] as? String, "clarify")
        XCTAssertEqual(object["intent"] as? String, "findFile")
        XCTAssertEqual(object["missingArguments"] as? [String], ["query"])
        XCTAssertEqual(object["reasonCode"] as? String, "ambiguous_file_reference")
        XCTAssertEqual(object["repetitionDetected"] as? Bool, false)
        XCTAssertEqual(object["truncationDetected"] as? Bool, false)
    }

    func testNormalizedProposalKeepsToolStringWhenPresent() throws {
        let proposal = AppleNormalizedProposal(
            caseID: "synthetic-tool",
            snapshot: AppleProposalSnapshot(
                proposalType: .toolCall,
                intent: .findFile,
                tool: .findFile,
                arguments: AppleProposalArguments(query: "Garden Plan 2026"),
                missingArguments: [],
                reasonCode: .directIntent
            )
        )

        let object = try jsonObject(proposal)

        XCTAssertEqual(object["tool"] as? String, "findFile")
        XCTAssertEqual(object["proposalType"] as? String, "tool_call")
    }

    func testGenerationConfigEncodesNullTopKAndSeedExplicitly() throws {
        let config = AppleGenerationConfig(maximumResponseTokens: 32)
        let object = try jsonObject(config)

        XCTAssertEqual(
            Set(object.keys),
            [
                "sampling_mode",
                "sampling_enabled",
                "temperature",
                "top_p",
                "top_k",
                "maximum_response_tokens",
                "seed_supported",
                "seed",
                "include_schema_in_prompt",
                "tools_count",
            ]
        )
        XCTAssertTrue(object["top_k"] is NSNull)
        XCTAssertTrue(object["seed"] is NSNull)
        XCTAssertEqual(object["sampling_mode"] as? String, "greedy")
        XCTAssertEqual(object["sampling_enabled"] as? Bool, false)
        XCTAssertEqual(object["temperature"] as? Double, 0.0)
        XCTAssertEqual(object["top_p"] as? Double, 1.0)
        XCTAssertEqual(object["maximum_response_tokens"] as? Int, 32)
        XCTAssertEqual(object["seed_supported"] as? Bool, false)
        XCTAssertEqual(object["include_schema_in_prompt"] as? Bool, true)
        XCTAssertEqual(object["tools_count"] as? Int, 0)
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        let value = try JSONSerialization.jsonObject(with: data)
        return try XCTUnwrap(value as? [String: Any])
    }
}
