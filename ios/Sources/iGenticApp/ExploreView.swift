#if canImport(SwiftUI)
import SwiftUI

public struct ExploreView: View {
    private let index: ExploreDiscoveryIndex
    @State private var searchText = ""

    public init(index: ExploreDiscoveryIndex = .sample) {
        self.index = index
    }

    public var body: some View {
        let results = index.search(searchText)

        List {
            Section("Local discovery") {
                LabeledContent("Index schema", value: "v\(index.schemaVersion)")
                Text("Searches only the bundled sample index. No network request, model call, or private user data is used.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Featured") {
                ForEach(index.resolvedFeaturedItems) { item in
                    ExploreCard(
                        title: item.title,
                        summary: item.summary,
                        metadata: item.kindLabel
                    )
                }
            }

            Section("Topics") {
                if results.topics.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results.topics) { topic in
                        ExploreCard(
                            title: topic.title,
                            summary: topic.summary,
                            metadata: "\(topic.difficulty.capitalized) · \(topic.tags.joined(separator: ", "))",
                            systemImage: topic.icon
                        )
                    }
                }
            }

            Section("Collections") {
                if results.collections.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(results.collections) { collection in
                        ExploreCard(
                            title: collection.title,
                            summary: collection.description,
                            metadata: "\(collection.topicSlugs.count) local topics",
                            systemImage: "square.grid.2x2"
                        )
                    }
                }
            }
        }
        .navigationTitle("Explore")
        .searchable(text: $searchText, prompt: "Search local Explore content")
    }
}

private struct ExploreCard: View {
    let title: String
    let summary: String
    let metadata: String
    var systemImage: String? = nil

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
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}
#endif
