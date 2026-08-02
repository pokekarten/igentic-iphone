import Foundation

public struct ExploreDiscoveryIndex: Codable, Equatable, Sendable {
    public struct Topic: Codable, Equatable, Identifiable, Sendable {
        public let slug: String
        public let title: String
        public let summary: String
        public let tags: [String]
        public let difficulty: String
        public let icon: String
        public let isFeatured: Bool

        public var id: String { slug }

        public init(
            slug: String,
            title: String,
            summary: String,
            tags: [String],
            difficulty: String,
            icon: String,
            isFeatured: Bool
        ) {
            self.slug = slug
            self.title = title
            self.summary = summary
            self.tags = tags
            self.difficulty = difficulty
            self.icon = icon
            self.isFeatured = isFeatured
        }

        private enum CodingKeys: String, CodingKey {
            case slug
            case title
            case summary
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
        public let topicSlugs: [String]
        public let isFeatured: Bool

        public var id: String { slug }

        public init(
            slug: String,
            title: String,
            description: String,
            topicSlugs: [String],
            isFeatured: Bool
        ) {
            self.slug = slug
            self.title = title
            self.description = description
            self.topicSlugs = topicSlugs
            self.isFeatured = isFeatured
        }

        private enum CodingKeys: String, CodingKey {
            case slug
            case title
            case description
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
                return topics.first(where: { $0.slug == reference.slug }).map(FeaturedItem.topic)
            case .collection:
                return collections.first(where: { $0.slug == reference.slug }).map(FeaturedItem.collection)
            }
        }
    }

    public func search(_ query: String) -> SearchResults {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedQuery.isEmpty else {
            return SearchResults(topics: topics, collections: collections)
        }

        return SearchResults(
            topics: topics.filter { topic in
                [topic.title, topic.summary, topic.difficulty]
                    .contains(where: { $0.lowercased().contains(normalizedQuery) })
                    || topic.tags.contains(where: { $0.lowercased().contains(normalizedQuery) })
            },
            collections: collections.filter { collection in
                [collection.title, collection.description]
                    .contains(where: { $0.lowercased().contains(normalizedQuery) })
                    || collection.topicSlugs.contains(where: { $0.lowercased().contains(normalizedQuery) })
            }
        )
    }
}

public enum ExploreDiscoveryIndexLoader {
    public static let supportedSchemaVersion = 1

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
