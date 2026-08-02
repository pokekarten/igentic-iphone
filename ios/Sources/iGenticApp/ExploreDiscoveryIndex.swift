import Foundation

public struct ExploreDiscoveryIndex: Codable, Equatable, Sendable {
    public struct Topic: Codable, Equatable, Identifiable, Sendable {
        public let slug: String
        public let title: String
        public let summary: String
        public let bodyMarkdown: String
        public let tags: [String]
        public let difficulty: String
        public let icon: String
        public let isFeatured: Bool

        public var id: String { slug }

        public init(
            slug: String,
            title: String,
            summary: String,
            bodyMarkdown: String,
            tags: [String],
            difficulty: String,
            icon: String,
            isFeatured: Bool
        ) {
            self.slug = slug
            self.title = title
            self.summary = summary
            self.bodyMarkdown = bodyMarkdown
            self.tags = tags
            self.difficulty = difficulty
            self.icon = icon
            self.isFeatured = isFeatured
        }

        private enum CodingKeys: String, CodingKey {
            case slug
            case title
            case summary
            case bodyMarkdown
            case tags
            case difficulty
            case icon
            case isFeatured = "featured"
        }
    }

    public struct Collection: Codable, Equatable, Identifiable, Sendable {
        public let slug: String
        public let title: String
        public let description: String
        public let bodyMarkdown: String
        public let topicSlugs: [String]
        public let isFeatured: Bool

        public var id: String { slug }

        public init(
            slug: String,
            title: String,
            description: String,
            bodyMarkdown: String,
            topicSlugs: [String],
            isFeatured: Bool
        ) {
            self.slug = slug
            self.title = title
            self.description = description
            self.bodyMarkdown = bodyMarkdown
            self.topicSlugs = topicSlugs
            self.isFeatured = isFeatured
        }

        private enum CodingKeys: String, CodingKey {
            case slug
            case title
            case description
            case bodyMarkdown
            case topicSlugs = "topics"
            case isFeatured = "featured"
        }
    }

    public struct FeaturedReference: Codable, Equatable, Sendable {
        public enum Kind: String, Codable, Equatable, Sendable {
            case topic
            case collection
        }

        public let kind: Kind
        public let slug: String

        public init(kind: Kind, slug: String) {
            self.kind = kind
            self.slug = slug
        }
    }

    public enum FeaturedItem: Equatable, Identifiable, Sendable {
        case topic(Topic)
        case collection(Collection)

        public var id: String {
            switch self {
            case .topic(let topic):
                return "topic:\(topic.slug)"
            case .collection(let collection):
                return "collection:\(collection.slug)"
            }
        }

        public var title: String {
            switch self {
            case .topic(let topic):
                return topic.title
            case .collection(let collection):
                return collection.title
            }
        }

        public var summary: String {
            switch self {
            case .topic(let topic):
                return topic.summary
            case .collection(let collection):
                return collection.description
            }
        }

        public var kindLabel: String {
            switch self {
            case .topic:
                return "Topic"
            case .collection:
                return "Collection"
            }
        }
    }

    public struct SearchMatch: Equatable, Sendable {
        public enum Field: Equatable, Sendable {
            case title
            case summary
            case difficulty
            case tag
            case content
            case description
            case topicReference

            public var label: String {
                switch self {
                case .title:
                    return "title"
                case .summary:
                    return "summary"
                case .difficulty:
                    return "difficulty"
                case .tag:
                    return "tag"
                case .content:
                    return "content"
                case .description:
                    return "description"
                case .topicReference:
                    return "topic reference"
                }
            }
        }

        public let field: Field
        public let excerpt: String

        public init(field: Field, excerpt: String) {
            self.field = field
            self.excerpt = excerpt
        }
    }

    public struct SearchResults: Equatable, Sendable {
        public let topics: [Topic]
        public let collections: [Collection]

        public init(topics: [Topic], collections: [Collection]) {
            self.topics = topics
            self.collections = collections
        }
    }

    public let schemaVersion: Int
    public let featured: [FeaturedReference]
    public let topics: [Topic]
    public let collections: [Collection]

    public init(
        schemaVersion: Int,
        featured: [FeaturedReference],
        topics: [Topic],
        collections: [Collection]
    ) {
        self.schemaVersion = schemaVersion
        self.featured = featured
        self.topics = topics
        self.collections = collections
    }

    public var resolvedFeaturedItems: [FeaturedItem] {
        featured.compactMap { reference in
            switch reference.kind {
            case .topic:
                return topic(slug: reference.slug).map(FeaturedItem.topic)
            case .collection:
                return collection(slug: reference.slug).map(FeaturedItem.collection)
            }
        }
    }

    public func topic(slug: String) -> Topic? {
        topics.first(where: { $0.slug == slug })
    }

    public func collection(slug: String) -> Collection? {
        collections.first(where: { $0.slug == slug })
    }

    public func topics(in collection: Collection) -> [Topic] {
        collection.topicSlugs.compactMap { topic(slug: $0) }
    }

    public func searchMatch(for topic: Topic, query: String) -> SearchMatch? {
        guard let normalizedQuery = Self.normalizedSearchQuery(query) else {
            return nil
        }

        let scalarFields: [(SearchMatch.Field, String)] = [
            (.title, topic.title),
            (.summary, topic.summary),
            (.difficulty, topic.difficulty),
            (.content, topic.bodyMarkdown)
        ]

        for (field, value) in scalarFields where Self.matches(value, query: normalizedQuery) {
            return SearchMatch(
                field: field,
                excerpt: Self.boundedExcerpt(from: value, query: normalizedQuery)
            )
        }

        if let tag = topic.tags.first(where: { Self.matches($0, query: normalizedQuery) }) {
            return SearchMatch(field: .tag, excerpt: tag)
        }

        return nil
    }

    public func searchMatch(for collection: Collection, query: String) -> SearchMatch? {
        guard let normalizedQuery = Self.normalizedSearchQuery(query) else {
            return nil
        }

        let scalarFields: [(SearchMatch.Field, String)] = [
            (.title, collection.title),
            (.description, collection.description),
            (.content, collection.bodyMarkdown)
        ]

        for (field, value) in scalarFields where Self.matches(value, query: normalizedQuery) {
            return SearchMatch(
                field: field,
                excerpt: Self.boundedExcerpt(from: value, query: normalizedQuery)
            )
        }

        if let topicReference = collection.topicSlugs.first(
            where: { Self.matches($0, query: normalizedQuery) }
        ) {
            return SearchMatch(field: .topicReference, excerpt: topicReference)
        }

        return nil
    }

    public func search(_ query: String) -> SearchResults {
        guard Self.normalizedSearchQuery(query) != nil else {
            return SearchResults(topics: topics, collections: collections)
        }

        return SearchResults(
            topics: topics.filter { searchMatch(for: $0, query: query) != nil },
            collections: collections.filter { searchMatch(for: $0, query: query) != nil }
        )
    }

    private static func normalizedSearchQuery(_ query: String) -> String? {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? nil : normalized
    }

    private static func matches(_ value: String, query: String) -> Bool {
        value.lowercased().contains(query)
    }

    private static func boundedExcerpt(
        from value: String,
        query: String,
        maximumLength: Int = 140
    ) -> String {
        let collapsed = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard collapsed.count > maximumLength else {
            return collapsed
        }

        guard let matchRange = collapsed.range(of: query, options: .caseInsensitive) else {
            return String(collapsed.prefix(maximumLength - 1)) + "…"
        }

        let matchStart = collapsed.distance(from: collapsed.startIndex, to: matchRange.lowerBound)
        let matchLength = collapsed.distance(from: matchRange.lowerBound, to: matchRange.upperBound)
        let contextBudget = max(0, maximumLength - matchLength)
        let preferredLeadingContext = min(48, contextBudget / 2)
        let startOffset = max(0, matchStart - preferredLeadingContext)
        let remainingLeadingContext = matchStart - startOffset
        let trailingContext = contextBudget - remainingLeadingContext
        let endOffset = min(collapsed.count, matchStart + matchLength + trailingContext)

        let startIndex = collapsed.index(collapsed.startIndex, offsetBy: startOffset)
        let endIndex = collapsed.index(collapsed.startIndex, offsetBy: endOffset)
        var excerpt = String(collapsed[startIndex..<endIndex])

        if startOffset > 0 {
            excerpt = "…" + excerpt
        }
        if endOffset < collapsed.count {
            excerpt += "…"
        }

        let displayMaximumLength = maximumLength + 2
        guard excerpt.count > displayMaximumLength else {
            return excerpt
        }
        return String(excerpt.prefix(displayMaximumLength - 1)) + "…"
    }
}

public enum ExploreDiscoveryIndexLoader {
    public static let supportedSchemaVersion = 2

    public enum LoadingError: Error, Equatable, LocalizedError, Sendable {
        case resourceNotFound
        case unreadableResource
        case invalidData
        case unsupportedSchemaVersion(Int)

        public var errorDescription: String? {
            switch self {
            case .resourceNotFound:
                return "The bundled Explore index is missing."
            case .unreadableResource:
                return "The bundled Explore index could not be read."
            case .invalidData:
                return "The bundled Explore index is not valid JSON for this app."
            case .unsupportedSchemaVersion(let version):
                return "Explore index schema version \(version) is not supported."
            }
        }
    }

    public static func decode(_ data: Data) throws -> ExploreDiscoveryIndex {
        let index: ExploreDiscoveryIndex
        do {
            index = try JSONDecoder().decode(ExploreDiscoveryIndex.self, from: data)
        } catch {
            throw LoadingError.invalidData
        }

        guard index.schemaVersion == supportedSchemaVersion else {
            throw LoadingError.unsupportedSchemaVersion(index.schemaVersion)
        }
        return index
    }

    public static func loadBundled() throws -> ExploreDiscoveryIndex {
        guard let resourceURL = Bundle.module.url(
            forResource: "explore-index",
            withExtension: "json"
        ) else {
            throw LoadingError.resourceNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: resourceURL)
        } catch {
            throw LoadingError.unreadableResource
        }
        return try decode(data)
    }
}
