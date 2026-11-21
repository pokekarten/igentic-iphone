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
            let result = await preview.generateReview(for: prompt)
            XCTAssertEqual(result, .inputRejected)
        }
    }

    func testRejectsKnownSensitivePatternsWithoutModel() async {
        for prompt in [
            "Send a reminder to sample@example.org",
            "Check IBAN DE89370400440532013000"
        ] {
            XCTAssertFalse(preview.allowsPrompt(prompt, trustedDataClassification: .publicDefault))
            XCTAssertEqual(await preview.generateReview(for: prompt), .inputRejected)
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
        XCTAssertEqual(
            await preview.generateReview(for: prompt, trustedDataClassification: classification),
            .inputRejected
        )
    }
}
