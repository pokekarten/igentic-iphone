import XCTest
@testable import AgentCore

final class SensitiveDataDetectorTests: XCTestCase {

    private let detector = SensitiveDataDetector()

    private func compatibilityFullWidth(_ text: String) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x21...0x7E).contains(value), let mapped = UnicodeScalar(value + 0xFEE0) {
                result.unicodeScalars.append(mapped)
            } else {
                result.unicodeScalars.append(scalar)
            }
        }
        return result
    }

    // MARK: - IBAN detection

    func testDetectsGermanIBANLikePattern() {
        // Well-formed IBAN shape: 2 letters, 2 digits, 11-30 alphanumeric.
        let result = detector.detect(in: "DE89370400440532013000")
        XCTAssertTrue(result.hasFindings)
        XCTAssertTrue(result.findings.contains { $0.category == .iban })
    }

    func testOrdinaryTextDoesNotMatchIBANPattern() {
        let result = detector.detect(in: "Please review the quarterly report by Friday.")
        XCTAssertFalse(result.hasFindings)
    }

    func testDetectsCompatibilityEquivalentFullWidthIBAN() {
        let syntheticIBAN = ["DE", "89", "3704", "0044", "0532", "0130", "00"].joined()
        let result = detector.detect(in: compatibilityFullWidth(syntheticIBAN))
        XCTAssertTrue(result.findings.contains { $0.category == .iban })
    }

    func testDetectsCompatibilityEquivalentFullWidthEmail() {
        let syntheticEmail = ["user", "@", "example", ".", "com"].joined()
        let result = detector.detect(in: compatibilityFullWidth(syntheticEmail))
        XCTAssertTrue(result.findings.contains { $0.category == .emailAddress })
    }

    // MARK: - German phone-like pattern detection

    func testDetectsNationalPrefixPhoneNumber() {
        // "0" + at least 7 more digits (>= 8 total) triggers a match.
        let result = detector.detect(in: "Call me at 0891234567")
        XCTAssertTrue(result.findings.contains { $0.category == .phoneNumber })
    }

    func testDetectsPhoneNumberWithSeparators() {
        // Separators (space, (), /, ., -) are ignored during normalization.
        let result = detector.detect(in: "0170-123 45 67")
        XCTAssertTrue(result.findings.contains { $0.category == .phoneNumber })
    }

    func testDetectsInternationalPlusPrefixPhoneNumber() {
        // "+49" + digits reaching total length >= 10 triggers a match.
        let result = detector.detect(in: "+491701234567")
        XCTAssertTrue(result.findings.contains { $0.category == .phoneNumber })
    }

    func testDetectsCompatibilityEquivalentFullWidthPhoneNumber() {
        let syntheticPhone = ["+", "49", "170", "123", "4567"].joined()
        let result = detector.detect(in: compatibilityFullWidth(syntheticPhone))
        XCTAssertTrue(result.findings.contains { $0.category == .phoneNumber })
    }

    func testPlainNonZeroLeadingDigitsDoNotMatch() {
        // Digits that never start with "0", "+49", or "0049" never match,
        // regardless of length.
        let result = detector.detect(in: "1201234567")
        XCTAssertFalse(result.findings.contains { $0.category == .phoneNumber })
    }

    // MARK: - Length cap regression test
    // Prior hardening gap: containsGermanPhoneLikePattern(in:) accumulated
    // digits with no length cap. Source now caps normalization at
    // maxNormalizedLength = 20; once exceeded, further digits are skipped
    // until a non-digit/non-separator character resets accumulation.
    // These tests lock in that fixed behavior.

    func testLongDigitRunWithNoMatchingPrefixDoesNotMatchAndCompletes() {
        // 5000 digits that never start with a matching prefix (leading "9").
        // This exercises the cap path without ever satisfying a prefix
        // check, verifying the function terminates promptly and returns
        // false rather than accumulating an unbounded string.
        let longDigitRun = String(repeating: "9", count: 5_000)
        let result = detector.detect(in: longDigitRun)
        XCTAssertFalse(result.findings.contains { $0.category == .phoneNumber })
    }

    func testAccumulationResetsAfterNonDigitNonSeparatorCharacter() {
        // "12" (junk, non-matching prefix) then "X" resets accumulation,
        // then "01234567" (8 digits, national prefix) should still match
        // cleanly after the reset.
        let result = detector.detect(in: "12X01234567")
        XCTAssertTrue(result.findings.contains { $0.category == .phoneNumber })
    }

    func testDigitsWithoutResetDoNotConcatenateAcrossUnrelatedPrefix() {
        // Same digits as above but withOUT the reset character in between:
        // "1201234567" is one continuous 10-digit run starting with "1",
        // so it never matches a national/international prefix.
        let result = detector.detect(in: "1201234567")
        XCTAssertFalse(result.findings.contains { $0.category == .phoneNumber })
    }

    // MARK: - Findings do not retain raw sensitive values

    func testFindingsCarryCategoryAndReasonOnlyNotRawText() {
        let result = detector.detect(in: "IBAN: DE89370400440532013000")
        guard let finding = result.findings.first(where: { $0.category == .iban }) else {
            return XCTFail("Expected an IBAN finding")
        }
        XCTAssertEqual(finding.reason, "IBAN-like pattern detected.")
        XCTAssertEqual(result.suggestedDataClassification.level, .restrictedSensitiveData)
    }
}
