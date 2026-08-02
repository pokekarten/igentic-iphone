import XCTest
@testable import iGenticApp

final class ExploreDiscoveryIndexTests: XCTestCase {
    func testSampleMatchesExpectedLocalDiscoveryShape() {
        let index = ExploreDiscoveryIndex.sample

        XCTAssertEqual(index.schemaVersion, 1)
        XCTAssertEqual(index.topics.map(\.slug), ["approvals", "local-ai", "privacy"])
        XCTAssertEqual(index.collections.map(\.slug), ["architecture", "getting-started", "security"])
        XCTAssertEqual(
            index.resolvedFeaturedItems.map(\.title),
            ["Privacy First", "Approvals", "Local AI", "Getting Started"]
        )
    }

    func testFeaturedResolutionPreservesOrderAndSkipsUnknownReferences() {
        let sample = ExploreDiscoveryIndex.sample
        let index = ExploreDiscoveryIndex(
            schemaVersion: sample.schemaVersion,
            featured: [
                .init(kind: .collection, slug: "getting-started"),
                .init(kind: .topic, slug: "missing"),
                .init(kind: .topic, slug: "privacy")
            ],
            topics: sample.topics,
            collections: sample.collections
        )

        XCTAssertEqual(index.resolvedFeaturedItems.map(\.title), ["Getting Started", "Privacy First"])
    }

    func testSearchUsesOnlyLocalTopicAndCollectionMetadata() {
        let index = ExploreDiscoveryIndex.sample

        let policyResults = index.search("policy")
        XCTAssertEqual(policyResults.topics.map(\.slug), ["approvals"])
        XCTAssertTrue(policyResults.collections.isEmpty)

        let privacyResults = index.search("privacy")
        XCTAssertEqual(privacyResults.topics.map(\.slug), ["privacy"])
        XCTAssertEqual(privacyResults.collections.map(\.slug), ["getting-started", "security"])

        XCTAssertEqual(index.search("   ").topics, index.topics)
        XCTAssertEqual(index.search("   ").collections, index.collections)
    }
}
