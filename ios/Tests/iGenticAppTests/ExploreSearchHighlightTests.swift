import Foundation
import XCTest
@testable import iGenticApp

final class ExploreSearchHighlightTests: XCTestCase {
    func testFindsCaseInsensitiveVisibleQueryRange() throws {
        let excerpt = "Approvals"
        let highlight = ExploreSearchHighlight(excerpt: excerpt, query: "PRO")
        let range = try XCTUnwrap(highlight.range)

        XCTAssertEqual(range, 2..<5)
        XCTAssertEqual(substring(in: excerpt, range: range).lowercased(), "pro")
    }

    func testFindsBodyAndReferenceRanges() throws {
        let index = try ExploreDiscoveryIndexLoader.loadBundled()
        let privacy = try XCTUnwrap(index.topic(slug: "privacy"))
        let architecture = try XCTUnwrap(index.collection(slug: "architecture"))

        let bodyMatch = try XCTUnwrap(index.searchMatch(for: privacy, query: "ReDaCtIoN"))
        let bodyRange = try XCTUnwrap(
            ExploreSearchHighlight(excerpt: bodyMatch.excerpt, query: "ReDaCtIoN").range
        )
        XCTAssertEqual(
            substring(in: bodyMatch.excerpt, range: bodyRange).lowercased(),
            "redaction"
        )

        let referenceMatch = try XCTUnwrap(
            index.searchMatch(for: architecture, query: "LOCAL-AI")
        )
        XCTAssertEqual(referenceMatch.field, .topicReference)
        let referenceRange = try XCTUnwrap(
            ExploreSearchHighlight(excerpt: referenceMatch.excerpt, query: "LOCAL-AI").range
        )
        XCTAssertEqual(
            substring(in: referenceMatch.excerpt, range: referenceRange),
            "local-ai"
        )
    }

    func testHighlightsVisibleFragmentWhenLongQueryIsTruncated() throws {
        let longQuery = String(repeating: "x", count: 180)
        let topic = ExploreDiscoveryIndex.Topic(
            slug: "long-query",
            title: "Synthetic",
            summary: "Synthetic long-query highlight fixture.",
            bodyMarkdown: "prefix \(longQuery) suffix",
            tags: [],
            difficulty: "test",
            icon: "doc",
            isFeatured: false
        )
        let index = ExploreDiscoveryIndex(
            schemaVersion: 2,
            featured: [],
            topics: [topic],
            collections: []
        )
        let match = try XCTUnwrap(index.searchMatch(for: topic, query: longQuery))
        let range = try XCTUnwrap(
            ExploreSearchHighlight(excerpt: match.excerpt, query: longQuery).range
        )

        XCTAssertEqual(match.excerpt.count, 142)
        XCTAssertEqual(range, 1..<141)
        XCTAssertEqual(
            substring(in: match.excerpt, range: range),
            String(repeating: "x", count: 140)
        )
    }

    func testBlankOrMissingQueriesHaveNoHighlightRange() {
        XCTAssertNil(ExploreSearchHighlight(excerpt: "Approvals", query: "   ").range)
        XCTAssertNil(ExploreSearchHighlight(excerpt: "Approvals", query: "privacy").range)
    }

    private func substring(in value: String, range: Range<Int>) -> String {
        let lowerBound = value.index(value.startIndex, offsetBy: range.lowerBound)
        let upperBound = value.index(value.startIndex, offsetBy: range.upperBound)
        return String(value[lowerBound..<upperBound])
    }
}
