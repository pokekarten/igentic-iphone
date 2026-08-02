#if canImport(SwiftUI)
import Foundation
import SwiftUI

public struct ExploreView: View {
    private enum Source {
        case loaded(ExploreDiscoveryIndex)
        case failed(ExploreDiscoveryIndexLoader.LoadingError)
    }

    private let source: Source
    @State private var searchText = ""

    public init() {
        do {
            self.source = .loaded(try ExploreDiscoveryIndexLoader.loadBundled())
        } catch let error as ExploreDiscoveryIndexLoader.LoadingError {
            self.source = .failed(error)
        } catch {
            self.source = .failed(.invalidData)
        }
    }

    public init(index: ExploreDiscoveryIndex) {
        self.source = .loaded(index)
    }

    public var body: some View {
        switch source {
        case .loaded(let index):
            ExploreContentView(index: index, searchText: $searchText)
        case .failed(let error):
            ContentUnavailableView(
                "Explore unavailable",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            )
            .navigationTitle("Explore")
        }
    }
}

private struct ExploreContentView: View {
    let index: ExploreDiscoveryIndex
    @Binding var searchText: String

    var body: some View {
        let results = index.search(searchText)
        let resultSummary = ExploreSearchResultSummary(
            query: searchText,
            topicCount: results.topics.count,
            collectionCount: results.collections.count
        )

        List {
            Section("Local discovery") {
                LabeledContent("Index schema", value: "v\(index.schemaVersion)")
                Text("Searches only the bundled generated index. No network request, model call, or private user data is used.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let resultSummary {
                Section("Search results") {
                    Label(
                        resultSummary.text,
                        systemImage: "line.3.horizontal.decrease.circle"
                    )
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(resultSummary.text))
                }
            }

            Section("Featured") {
                ForEach(index.resolvedFeaturedItems) { item in
                    NavigationLink {
                        featuredDestination(for: item)
                    } label: {
                        ExploreCard(
                            title: item.title,
                            summary: item.summary,
                            metadata: item.kindLabel
                        )
                    }
                }
            }

            Section("Topics") {
                if results.topics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results.topics) { topic in
                        NavigationLink {
                            ExploreTopicDetailView(topic: topic)
                        } label: {
                            ExploreCard(
                                title: topic.title,
                                summary: topic.summary,
                                metadata: "\(topic.difficulty.capitalized) · \(topic.tags.joined(separator: ", "))",
                                systemImage: exploreSystemImageName(for: topic.icon),
                                match: index.searchMatch(for: topic, query: searchText),
                                query: searchText
                            )
                        }
                    }
                }
            }

            Section("Collections") {
                if results.collections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results.collections) { collection in
                        NavigationLink {
                            ExploreCollectionDetailView(index: index, collection: collection)
                        } label: {
                            ExploreCard(
                                title: collection.title,
                                summary: collection.description,
                                metadata: "\(collection.topicSlugs.count) local topics",
                                systemImage: "square.grid.2x2",
                                match: index.searchMatch(for: collection, query: searchText),
                                query: searchText
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .searchable(text: $searchText, prompt: "Search local Explore content")
    }

    @ViewBuilder
    private func featuredDestination(for item: ExploreDiscoveryIndex.FeaturedItem) -> some View {
        switch item {
        case .topic(let topic):
            ExploreTopicDetailView(topic: topic)
        case .collection(let collection):
            ExploreCollectionDetailView(index: index, collection: collection)
        }
    }
}

private struct ExploreTopicDetailView: View {
    let topic: ExploreDiscoveryIndex.Topic

    var body: some View {
        List {
            Section("Overview") {
                Label(topic.title, systemImage: exploreSystemImageName(for: topic.icon))
                    .font(.headline)
                Text(topic.summary)
            }

            Section("Content") {
                ExploreMarkdownBody(markdown: topic.bodyMarkdown)
            }

            Section("Metadata") {
                LabeledContent("Difficulty", value: topic.difficulty.capitalized)
                LabeledContent("Featured", value: topic.isFeatured ? "Yes" : "No")
                LabeledContent("Slug", value: topic.slug)
            }

            Section("Tags") {
                ForEach(topic.tags, id: \.self) { tag in
                    Label(tag, systemImage: "tag")
                }
            }

            Section("Local data") {
                Text("This detail view uses only Markdown bundled in the generated Explore index.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(topic.title)
    }
}

private struct ExploreCollectionDetailView: View {
    let index: ExploreDiscoveryIndex
    let collection: ExploreDiscoveryIndex.Collection

    var body: some View {
        let topics = index.topics(in: collection)

        List {
            Section("Overview") {
                Label(collection.title, systemImage: "square.grid.2x2")
                    .font(.headline)
                Text(collection.description)
                LabeledContent("Featured", value: collection.isFeatured ? "Yes" : "No")
                LabeledContent("Slug", value: collection.slug)
            }

            Section("Content") {
                ExploreMarkdownBody(markdown: collection.bodyMarkdown)
            }

            Section("Topics") {
                if topics.isEmpty {
                    ContentUnavailableView(
                        "No local topics",
                        systemImage: "tray",
                        description: Text("This collection has no valid topic references in the bundled index.")
                    )
                } else {
                    ForEach(topics) { topic in
                        NavigationLink {
                            ExploreTopicDetailView(topic: topic)
                        } label: {
                            ExploreCard(
                                title: topic.title,
                                summary: topic.summary,
                                metadata: topic.difficulty.capitalized,
                                systemImage: exploreSystemImageName(for: topic.icon)
                            )
                        }
                    }
                }
            }

            Section("Local data") {
                Text("Content and topic order come only from the bundled generated Explore index.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(collection.title)
    }
}

private struct ExploreMarkdownBody: View {
    let markdown: String

    var body: some View {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .full
            )
        ) {
            Text(attributed)
        } else {
            Text(markdown)
        }
    }
}

private struct ExploreCard: View {
    let title: String
    let summary: String
    let metadata: String
    var systemImage: String? = nil
    var match: ExploreDiscoveryIndex.SearchMatch? = nil
    var query: String = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .frame(width: 24)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(summary)
                    .font(.subheadline)
                Text(metadata)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let match {
                    Text("Matched \(match.field.label)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ExploreHighlightedExcerpt(
                        excerpt: match.excerpt,
                        query: query
                    )
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct ExploreHighlightedExcerpt: View {
    let excerpt: String
    let query: String

    var body: some View {
        highlightedText
            .font(.caption)
            .lineLimit(3)
            .accessibilityLabel(Text(excerpt))
    }

    private var highlightedText: Text {
        guard let range = ExploreSearchHighlight(excerpt: excerpt, query: query).range else {
            return Text(excerpt)
                .foregroundColor(.secondary)
        }

        let lowerBound = excerpt.index(excerpt.startIndex, offsetBy: range.lowerBound)
        let upperBound = excerpt.index(excerpt.startIndex, offsetBy: range.upperBound)
        let prefix = String(excerpt[..<lowerBound])
        let match = String(excerpt[lowerBound..<upperBound])
        let suffix = String(excerpt[upperBound...])

        return Text(prefix).foregroundColor(.secondary)
            + Text(match).bold().foregroundColor(.accentColor)
            + Text(suffix).foregroundColor(.secondary)
    }
}

private func exploreSystemImageName(for contentIcon: String) -> String {
    switch contentIcon {
    case "check-circle":
        return "checkmark.circle"
    default:
        return contentIcon
    }
}
#endif
