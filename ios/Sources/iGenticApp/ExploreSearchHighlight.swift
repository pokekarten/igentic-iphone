import Foundation

struct ExploreSearchHighlight: Equatable, Sendable {
    let range: Range<Int>?

    init(excerpt: String, query: String) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            self.range = nil
            return
        }

        if let matchRange = excerpt.range(of: normalizedQuery, options: .caseInsensitive) {
            let lowerBound = excerpt.distance(from: excerpt.startIndex, to: matchRange.lowerBound)
            let upperBound = excerpt.distance(from: excerpt.startIndex, to: matchRange.upperBound)
            self.range = lowerBound..<upperBound
            return
        }

        guard excerpt.hasPrefix("…") || excerpt.hasSuffix("…") else {
            self.range = nil
            return
        }

        let lowerBound = excerpt.hasPrefix("…") ? 1 : 0
        let upperBound = excerpt.count - (excerpt.hasSuffix("…") ? 1 : 0)
        guard lowerBound < upperBound else {
            self.range = nil
            return
        }

        let visibleStart = excerpt.index(excerpt.startIndex, offsetBy: lowerBound)
        let visibleEnd = excerpt.index(excerpt.startIndex, offsetBy: upperBound)
        let visibleFragment = String(excerpt[visibleStart..<visibleEnd])

        guard normalizedQuery.range(of: visibleFragment, options: .caseInsensitive) != nil else {
            self.range = nil
            return
        }

        self.range = lowerBound..<upperBound
    }
}
