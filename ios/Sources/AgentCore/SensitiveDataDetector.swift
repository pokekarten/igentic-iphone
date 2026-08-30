import Foundation

public protocol SensitiveDataDetecting: Sendable {
    func detect(in text: String) -> SensitiveDataDetectionResult
}

public enum SensitiveDataCategory: String, CaseIterable, Sendable {
    case iban
    case emailAddress
    case phoneNumber

    public var suggestedLevel: DataSensitivityLevel {
        switch self {
        case .iban:
            return .restrictedSensitiveData
        case .emailAddress, .phoneNumber:
            return .contextualPrivateData
        }
    }

    public var detectionReason: String {
        switch self {
        case .iban:
            return "IBAN-like pattern detected."
        case .emailAddress:
            return "Email-like pattern detected."
        case .phoneNumber:
            return "Phone-like pattern detected."
        }
    }
}

public struct SensitiveDataFinding: Equatable, Sendable {
    public let category: SensitiveDataCategory
    public let reason: String

    public init(category: SensitiveDataCategory, reason: String) {
        self.category = category
        self.reason = reason
    }
}

public struct SensitiveDataDetectionResult: Equatable, Sendable {
    public let findings: [SensitiveDataFinding]
    public let suggestedDataClassification: DataClassification

    public init(findings: [SensitiveDataFinding]) {
        self.findings = findings
        let highestLevel = findings
            .map(\.category.suggestedLevel)
            .max() ?? .publicData
        self.suggestedDataClassification = DataClassification(
            level: highestLevel,
            reason: findings.isEmpty
                ? "No sensitive pattern detected."
                : "Sensitive pattern categories detected; raw values were not retained."
        )
    }

    public var hasFindings: Bool {
        !findings.isEmpty
    }
}

public struct SensitiveDataDetector: SensitiveDataDetecting {
    public init() {}

    public func detect(in text: String) -> SensitiveDataDetectionResult {
        var findings: [SensitiveDataFinding] = []

        // Normalize Unicode representations for classification only.
        // Compatibility forms (for example full-width ASCII) and non-ASCII
        // decimal digits must not bypass the built-in privacy floor. The
        // normalized text is never retained in findings or audit output.
        let detectionText = normalizedDetectionText(text)

        // Email detection first (keeps expected ordering in tests). This is a
        // privacy heuristic rather than a mailbox validator, so recognize
        // internationalized letter/number forms and ASCII punycode TLDs too.
        if contains(
            pattern: #"[\p{L}\p{N}._%+\-]+@[\p{L}\p{N}.-]+\.(?:[\p{L}]{2,}|xn--[A-Z0-9-]{2,})"#,
            in: detectionText
        ) {
            findings.append(
                SensitiveDataFinding(category: .emailAddress, reason: SensitiveDataCategory.emailAddress.detectionReason)
            )
        }

        // Phone detection next
        if containsGermanPhoneLikePattern(in: detectionText) {
            findings.append(
                SensitiveDataFinding(category: .phoneNumber, reason: SensitiveDataCategory.phoneNumber.detectionReason)
            )
        }

        // IBAN detection last and stricter: require word boundaries to avoid
        // accidental matches across adjacent text fragments.
        if containsIBANLikePattern(in: detectionText) {
            findings.append(
                SensitiveDataFinding(category: .iban, reason: SensitiveDataCategory.iban.detectionReason)
            )
        }

        return SensitiveDataDetectionResult(findings: findings)
    }

    private func normalizedDetectionText(_ text: String) -> String {
        let compatibilityMapped = text.precomposedStringWithCompatibilityMapping
        var normalized = ""

        for scalar in compatibilityMapped.unicodeScalars {
            if scalar.properties.numericType == .decimal,
               let numericValue = scalar.properties.numericValue,
               (0...9).contains(numericValue),
               let asciiDigit = UnicodeScalar(0x30 + UInt32(numericValue)) {
                normalized.unicodeScalars.append(asciiDigit)
            } else {
                normalized.unicodeScalars.append(scalar)
            }
        }

        return normalized
    }

    private func containsIBANLikePattern(in text: String) -> Bool {
        // Require a word boundary before and after the IBAN to avoid matching
        // across adjacent words (e.g. "REFERENZ 0049..."). Match typical IBAN
        // form: two letters, two digits, then 11–30 alphanumeric characters.
        let uppercasedText = text.uppercased()
        return contains(pattern: #"\b[A-Z]{2}\s?[0-9]{2}(?:\s?[A-Z0-9]){11,30}\b"#, in: uppercasedText)
    }

    private func containsGermanPhoneLikePattern(in text: String) -> Bool {
        let allowedSeparators = CharacterSet(charactersIn: " ()/.-")
        let maxNormalizedLength = 20
        var normalized = ""
        var exceededMaximumLength = false

        for scalar in text.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) || scalar == "+" {
                if exceededMaximumLength {
                    continue
                }

                normalized.unicodeScalars.append(scalar)
                if normalized.count > maxNormalizedLength {
                    normalized.removeAll(keepingCapacity: true)
                    exceededMaximumLength = true
                    continue
                }
            } else if allowedSeparators.contains(scalar) {
                continue
            } else {
                normalized.removeAll(keepingCapacity: true)
                exceededMaximumLength = false
            }

            let nationalPrefix = "0"
            let internationalPrefix = "+" + "49"
            let internationalDialPrefix = "00" + "49"
            if normalized.hasPrefix(nationalPrefix), normalized.count >= 8 {
                return true
            }
            if normalized.hasPrefix(internationalPrefix), normalized.count >= 10 {
                return true
            }
            if normalized.hasPrefix(internationalDialPrefix), normalized.count >= 11 {
                return true
            }
        }

        return false
    }

    private func contains(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}

func requiredSensitiveDataDetection(
    in text: String,
    supplementalDetector: (any SensitiveDataDetecting)? = nil,
    precomputedSupplemental: SensitiveDataDetectionResult? = nil
) -> SensitiveDataDetectionResult {
    let baseline = SensitiveDataDetector().detect(in: text)
    let supplemental = precomputedSupplemental ?? supplementalDetector?.detect(in: text)

    guard let supplemental else {
        return baseline
    }

    var seenCategories = Set<String>()
    let mergedFindings = (baseline.findings + supplemental.findings).filter { finding in
        seenCategories.insert(finding.category.rawValue).inserted
    }

    return SensitiveDataDetectionResult(findings: mergedFindings)
}
