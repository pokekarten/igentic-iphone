import Foundation

struct ExploreSearchResultSummary: Equatable, Sendable {
    let topicCount: Int
    let collectionCount: Int
    let text: String

    init?(query: String, topicCount: Int, collectionCount: Int) {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return nil
        }

        let safeTopicCount = max(0, topicCount)
        let safeCollectionCount = max(0, collectionCount)
        let totalCount = safeTopicCount + safeCollectionCount

        self.topicCount = safeTopicCount
        self.collectionCount = safeCollectionCount
        self.text = [
            Self.countLabel(totalCount, singular: "result", plural: "results"),
            Self.countLabel(safeTopicCount, singular: "topic", plural: "topics"),
            Self.countLabel(safeCollectionCount, singular: "collection", plural: "collections")
        ].joined(separator: " · ")
    }

    private static func countLabel(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
    }
}
