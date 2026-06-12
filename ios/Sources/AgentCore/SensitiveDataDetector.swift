import Foundation

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

public struct SensitiveDataDetector: Sendable {
    public init() {}

    public func detect(in text: String) -> SensitiveDataDetectionResult {
        var findings: [SensitiveDataFinding] = []

        if containsIBANLikePattern(in: text) {
            findings.append(
                SensitiveDataFinding(category: .iban, reason: SensitiveDataCategory.iban.detectionReason)
            )
        }

        if contains(pattern: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#, in: text) {
            findings.append(
                SensitiveDataFinding(category: .emailAddress, reason: SensitiveDataCategory.emailAddress.detectionReason)
            )
        }

        if contains(pattern: #"(?:\+49|0049|0)[0-9][0-9 ()/.-]{6,}[0-9]"#, in: text) {
            findings.append(
                SensitiveDataFinding(category: .phoneNumber, reason: SensitiveDataCategory.phoneNumber.detectionReason)
            )
        }

        return SensitiveDataDetectionResult(findings: findings)
    }

    private func containsIBANLikePattern(in text: String) -> Bool {
        let uppercasedText = text.uppercased()
        return contains(pattern: #"[A-Z]{2}\s?[0-9]{2}(?:\s?[A-Z0-9]){11,30}"#, in: uppercasedText)
    }

    private func contains(pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}
