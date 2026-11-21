import XCTest
@testable import AgentCore

final class AppleOnDeviceProposalPreviewTests: XCTestCase {
    private let preview = AppleOnDeviceProposalPreview()

    func testAcceptsOnlyShortPublicNonSensitivePrompt() {
        XCTAssertTrue(
            preview.allowsPrompt(
                "Suggest a synthetic reminder for a demo.",
                trustedDataClassification: .publicDefault
            )
        )
    }

    func testRejectsEmptyAndOversizedInputBeforeModel() async {
        for prompt in ["", "  ", String(repeating: "x", count: 257)] {
            XCTAssertFalse(preview.allowsPrompt(prompt, trustedDataClassification: .publicDefault))
            let result = await preview.generateReview(for: prompt, trustedDataClassification: .publicDefault)
            XCTAssertEqual(result, .inputRejected)
        }
    }

    func testUTF8ByteBoundaryIsEnforcedBeforeInference() async {
        let atLimit = String(repeating: "a", count: 256)
        let beyondLimit = String(repeating: "ä", count: 129)
        XCTAssertEqual(atLimit.utf8.count, 256)
        XCTAssertEqual(beyondLimit.utf8.count, 258)
        XCTAssertTrue(preview.allowsPrompt(atLimit, trustedDataClassification: .publicDefault))
        XCTAssertFalse(preview.allowsPrompt(beyondLimit, trustedDataClassification: .publicDefault))
        let result = await preview.generateReview(for: beyondLimit, trustedDataClassification: .publicDefault)
        XCTAssertEqual(result, .inputRejected)
    }

    func testRejectsWhitespaceOnlyUnicodeBeforeInference() async {
        let prompt = "\n\t  \r"
        XCTAssertFalse(preview.allowsPrompt(prompt, trustedDataClassification: .publicDefault))
        let result = await preview.generateReview(for: prompt, trustedDataClassification: .publicDefault)
        XCTAssertEqual(result, .inputRejected)
    }

    func testRejectsKnownSensitivePatternsWithoutModel() async {
        for prompt in [
            "Send a reminder to sample@example.org",
            "Check IBAN DE89370400440532013000"
        ] {
            XCTAssertFalse(preview.allowsPrompt(prompt, trustedDataClassification: .publicDefault))
            let result = await preview.generateReview(for: prompt, trustedDataClassification: .publicDefault)
            XCTAssertEqual(result, .inputRejected)
        }
    }

    func testModelCannotDowngradeTrustedPrivateClassification() async {
        let classification = DataClassification(
            level: .contextualPrivateData,
            reason: "Trusted caller marked the input private."
        )
        let prompt = "Create a short synthetic reminder"
        XCTAssertFalse(
            preview.allowsPrompt(prompt, trustedDataClassification: classification)
        )
        let result = await preview.generateReview(
            for: prompt,
            trustedDataClassification: classification
        )
        XCTAssertEqual(result, .inputRejected)
    }
}
