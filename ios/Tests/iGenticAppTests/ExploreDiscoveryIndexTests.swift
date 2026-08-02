import Foundation
import XCTest
@testable import iGenticApp

final class ExploreDiscoveryIndexTests: XCTestCase {
    func testBundledIndexMatchesExpectedLocalDiscoveryShape() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()

        XCTAssertEqual(index.schemaVersion, 1)
        XCTAssertEqual(index.topics.map(\.slug), ["approvals", "local-ai", "privacy"])
        XCTAssertEqual(index.collections.map(\.slug), ["architecture", "getting-started", "security"])
        XCTAssertEqual(
            index.resolvedFeaturedItems.map(\.title),
            ["Privacy First", "Approvals", "Local AI", "Getting Started"]
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

    func testSearchUsesOnlyLocalTopicAndCollectionMetadata() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()

        let policyResults = index.search("policy")
        XCTAssertEqual(policyResults.topics.map(\.slug), ["approvals"])
        XCTAssertTrue(policyResults.collections.isEmpty)

        let privacyResults = index.search("privacy")
        XCTAssertEqual(privacyResults.topics.map(\.slug), ["privacy"])
        XCTAssertEqual(privacyResults.collections.map(\.slug), ["getting-started", "security"])

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

    func testUnsupportedSchemaVersionFailsDeterministically() {
        let data = Data(
            """
            {
              "schemaVersion": 2,
              "featured": [],
              "topics": [],
              "collections": []
            }
            """.utf8
        )

        XCTAssertThrowsError(try ExploreDiscoveryIndexLoader.decode(data)) { error in
            XCTAssertEqual(
                error as? ExploreDiscoveryIndexLoader.LoadingError,
                .unsupportedSchemaVersion(2)
            )
        }
    }
}
