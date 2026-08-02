import Foundation
import XCTest
@testable import iGenticApp

final class ExploreDiscoveryIndexTests: XCTestCase {
    func testBundledIndexMatchesExpectedLocalDiscoveryShape() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()

        XCTAssertEqual(index.schemaVersion, 2)
        XCTAssertEqual(index.topics.map(\.slug), ["approvals", "local-ai", "privacy"])
        XCTAssertEqual(index.collections.map(\.slug), ["architecture", "getting-started", "security"])
        XCTAssertEqual(
            index.resolvedFeaturedItems.map(\.title),
            ["Privacy First", "Approvals", "Local AI", "Getting Started"]
        )
    }

    func testBundledMarkdownBodiesAreNormalizedAndNonEmpty() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()
        let bodies = index.topics.map(\.bodyMarkdown) + index.collections.map(\.bodyMarkdown)

        XCTAssertFalse(bodies.isEmpty)
        for body in bodies {
            XCTAssertFalse(body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(body.contains("---"))
            XCTAssertFalse(body.hasPrefix("# "))
        }

        XCTAssertTrue(
            try XCTUnwrap(index.topic(slug: "privacy"))
                .bodyMarkdown
                .contains("## Related ideas")
        )
        XCTAssertEqual(
            try XCTUnwrap(index.collection(slug: "getting-started"))
                .bodyMarkdown,
            "A small curated path for new contributors and readers who want the core control-plane concepts first."
        )
    }

    func testFeaturedResolutionPreservesOrderAndSkipsUnknownReferences() throws {
        let bundled = try ExploreDiscoveryIndexLoader.loadBundled()
        let index = ExploreDiscoveryIndex(
            schemaVersion: bundled.schemaVersion,
            featured: [
                .init(kind: .collection, slug: "getting-started"),
                .init(kind: .topic, slug: "missing"),
                .init(kind: .topic, slug: "privacy")
            ],
            topics: bundled.topics,
            collections: bundled.collections
        )

        XCTAssertEqual(index.resolvedFeaturedItems.map(\.title), ["Getting Started", "Privacy First"])
    }

    func testLocalLookupsResolveTopicsAndCollections() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()

        XCTAssertEqual(index.topic(slug: "privacy")?.title, "Privacy First")
        XCTAssertEqual(index.collection(slug: "security")?.title, "Security")
        XCTAssertNil(index.topic(slug: "missing"))
        XCTAssertNil(index.collection(slug: "missing"))
    }

    func testCollectionTopicResolutionPreservesOrderAndSkipsUnknownReferences() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()
        let gettingStarted = try XCTUnwrap(index.collection(slug: "getting-started"))

        XCTAssertEqual(
            index.topics(in: gettingStarted).map(\.slug),
            ["privacy", "approvals", "local-ai"]
        )

        let collectionWithUnknownReference = ExploreDiscoveryIndex.Collection(
            slug: "test",
            title: "Test",
            description: "Synthetic local test collection.",
            bodyMarkdown: "Synthetic local body.",
            topicSlugs: ["local-ai", "missing", "approvals"],
            isFeatured: false
        )

        XCTAssertEqual(
            index.topics(in: collectionWithUnknownReference).map(\.slug),
            ["local-ai", "approvals"]
        )
    }

    func testSearchUsesOnlyBundledLocalContent() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()

        let policyResults = index.search("policy")
        XCTAssertEqual(policyResults.topics.map(\.slug), ["approvals", "privacy"])
        XCTAssertEqual(policyResults.collections.map(\.slug), ["security"])

        let privacyResults = index.search("privacy")
        XCTAssertEqual(privacyResults.topics.map(\.slug), ["privacy"])
        XCTAssertEqual(privacyResults.collections.map(\.slug), ["getting-started", "security"])

        let topicBodyResults = index.search("  ReDaCtIoN  ")
        XCTAssertEqual(topicBodyResults.topics.map(\.slug), ["privacy"])
        XCTAssertTrue(topicBodyResults.collections.isEmpty)

        let collectionBodyResults = index.search("CONTROL PIPELINE")
        XCTAssertTrue(collectionBodyResults.topics.isEmpty)
        XCTAssertEqual(collectionBodyResults.collections.map(\.slug), ["architecture"])

        XCTAssertEqual(index.search("   ").topics, index.topics)
        XCTAssertEqual(index.search("   ").collections, index.collections)
    }

    func testMalformedJSONFailsDeterministically() {
        XCTAssertThrowsError(
            try ExploreDiscoveryIndexLoader.decode(Data("not-json".utf8))
        ) { error in
            XCTAssertEqual(
                error as? ExploreDiscoveryIndexLoader.LoadingError,
                .invalidData
            )
        }
    }

    func testSchemaTwoWithoutMarkdownBodiesFailsDeterministically() {
        let data = Data(
            """
            {
              "schemaVersion": 2,
              "featured": [],
              "topics": [
                {
                  "slug": "missing-body",
                  "title": "Missing Body",
                  "summary": "Synthetic malformed record.",
                  "tags": ["test"],
                  "difficulty": "beginner",
                  "icon": "doc",
                  "featured": false
                }
              ],
              "collections": []
            }
            """.utf8
        )

        XCTAssertThrowsError(try ExploreDiscoveryIndexLoader.decode(data)) { error in
            XCTAssertEqual(
                error as? ExploreDiscoveryIndexLoader.LoadingError,
                .invalidData
            )
        }
    }

    func testUnsupportedSchemaVersionFailsDeterministically() {
        let data = Data(
            """
            {
              "schemaVersion": 1,
              "featured": [],
              "topics": [],
              "collections": []
            }
            """.utf8
        )

        XCTAssertThrowsError(try ExploreDiscoveryIndexLoader.decode(data)) { error in
            XCTAssertEqual(
                error as? ExploreDiscoveryIndexLoader.LoadingError,
                .unsupportedSchemaVersion(1)
            )
        }
    }
}
