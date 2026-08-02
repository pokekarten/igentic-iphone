import XCTest
@testable import iGenticApp

final class ExploreSearchResultSummaryTests: XCTestCase {
    func testBlankQueriesProduceNoSummary() {
        XCTAssertNil(
            ExploreSearchResultSummary(
                query: "  \n  ",
                topicCount: 3,
                collectionCount: 2
            )
        )
    }

    func testZeroResultsUsePluralLabels() throws {
        let summary = try XCTUnwrap(
            ExploreSearchResultSummary(
                query: "missing",
                topicCount: 0,
                collectionCount: 0
            )
        )

        XCTAssertEqual(summary.topicCount, 0)
        XCTAssertEqual(summary.collectionCount, 0)
        XCTAssertEqual(summary.text, "0 results · 0 topics · 0 collections")
    }

    func testSingularTopicAndCollectionLabels() throws {
        let topicSummary = try XCTUnwrap(
            ExploreSearchResultSummary(
                query: "topic",
                topicCount: 1,
                collectionCount: 0
            )
        )
        XCTAssertEqual(topicSummary.text, "1 result · 1 topic · 0 collections")

        let collectionSummary = try XCTUnwrap(
            ExploreSearchResultSummary(
                query: "collection",
                topicCount: 0,
                collectionCount: 1
            )
        )
        XCTAssertEqual(collectionSummary.text, "1 result · 0 topics · 1 collection")
    }

    func testMixedPluralCountsAreDeterministic() throws {
        let summary = try XCTUnwrap(
            ExploreSearchResultSummary(
                query: "local",
                topicCount: 2,
                collectionCount: 3
            )
        )

        XCTAssertEqual(summary.text, "5 results · 2 topics · 3 collections")
    }

    func testBundledSearchCountsCanFeedSummaryWithoutChangingOrder() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()
        let results = index.search("privacy")
        let summary = try XCTUnwrap(
            ExploreSearchResultSummary(
                query: "privacy",
                topicCount: results.topics.count,
                collectionCount: results.collections.count
            )
        )

        XCTAssertEqual(results.topics.map(\.slug), ["privacy"])
        XCTAssertEqual(results.collections.map(\.slug), ["getting-started", "security"])
        XCTAssertEqual(summary.text, "3 results · 1 topic · 2 collections")
    }
}
