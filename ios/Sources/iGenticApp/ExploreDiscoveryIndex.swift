import Foundation

public struct ExploreDiscoveryIndex: Equatable, Sendable {
    public struct Topic: Equatable, Identifiable, Sendable {
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
    }

    public struct Collection: Equatable, Identifiable, Sendable {
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
    }

    public struct FeaturedReference: Equatable, Sendable {
        public enum Kind: String, Equatable, Sendable {
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

public extension ExploreDiscoveryIndex {
    static let sample = ExploreDiscoveryIndex(
        schemaVersion: 1,
        featured: [
            FeaturedReference(kind: .topic, slug: "privacy"),
            FeaturedReference(kind: .topic, slug: "approvals"),
            FeaturedReference(kind: .topic, slug: "local-ai"),
            FeaturedReference(kind: .collection, slug: "getting-started")
        ],
        topics: [
            Topic(
                slug: "approvals",
                title: "Approvals",
                summary: "Defining when iGentic should ask before an action is executed.",
                tags: ["approvals", "policy", "safety"],
                difficulty: "beginner",
                icon: "checkmark.circle",
                isFeatured: true
            ),
            Topic(
                slug: "local-ai",
                title: "Local AI",
                summary: "Routing, running, and validating AI work locally before any delegation.",
                tags: ["local-ai", "runtime", "routing"],
                difficulty: "intermediate",
                icon: "cpu",
                isFeatured: true
            ),
            Topic(
                slug: "privacy",
                title: "Privacy First",
                summary: "Building AI that keeps personal data on device whenever possible.",
                tags: ["privacy", "security", "local-first"],
                difficulty: "beginner",
                icon: "shield",
                isFeatured: true
            )
        ],
        collections: [
            Collection(
                slug: "architecture",
                title: "Architecture",
                description: "The main building blocks and how they fit together.",
                topicSlugs: ["local-ai", "approvals"],
                isFeatured: true
            ),
            Collection(
                slug: "getting-started",
                title: "Getting Started",
                description: "The shortest path into the core iGentic concepts.",
                topicSlugs: ["privacy", "approvals", "local-ai"],
                isFeatured: true
            ),
            Collection(
                slug: "security",
                title: "Security",
                description: "Privacy, auditability, and safe execution boundaries.",
                topicSlugs: ["privacy", "approvals"],
                isFeatured: false
            )
        ]
    )
}
