import SwiftUI

/// Ready-made list of releases published from the project dashboard.
public struct RelayChangelogView: View {
    @Environment(\.relayStrings) private var strings
    @State private var items: [RelayChangelogItem] = []
    @State private var isLoading = true
    @State private var error: String?

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let error {
                ContentUnavailableView(strings.text(.unableToLoad), systemImage: "exclamationmark.triangle", description: Text(error))
            } else if items.isEmpty {
                ContentUnavailableView(strings.text(.noReleases), systemImage: "sparkles", description: Text(strings.text(.noReleasesHint)))
            } else {
                List(items) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(item.title).font(.headline)
                            Spacer()
                            Text(item.version).font(.caption.monospaced().weight(.semibold)).foregroundStyle(.tint)
                        }
                        Text(item.notes).font(.subheadline).foregroundStyle(.secondary)
                        if let date = item.publishedAt {
                            Text(date, style: .date).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
        }
        .navigationTitle(strings.text(.changelog))
        .task { await load() }
        .refreshable { await load() }
        .modifier(RelayLocalizedRoot())
    }

    @MainActor private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await Relay.changelog().items
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
