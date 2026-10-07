import SwiftUI

/// Public, moderated feedback board with voting and shipped-version badges.
public struct RelayBoardView: View {
    @Environment(\.relayStrings) private var strings
    @State private var items: [RelayBoardItem] = []
    @State private var loading = true
    @State private var error: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if loading { ProgressView() }
                else if let error { ContentUnavailableView(strings.text(.unableToLoad), systemImage: "exclamationmark.triangle", description: Text(error)) }
                else { List(items) { item in row(item) } }
            }
            .navigationTitle(strings.text(.feedbackBoard))
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func row(_ item: RelayBoardItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Button { Task { await vote(item) } } label: {
                VStack(spacing: 2) { Image(systemName: "arrowtriangle.up.fill"); Text("\(item.votes)").font(.caption.monospacedDigit()) }
            }.buttonStyle(.bordered).accessibilityLabel("\(strings.text(.vote)), \(item.votes) \(strings.text(.votes))")
            VStack(alignment: .leading, spacing: 6) {
                Text(item.title ?? item.message).font(.headline).lineLimit(2)
                if item.title != nil { Text(item.message).font(.subheadline).foregroundStyle(.secondary).lineLimit(3) }
                HStack { RelayStatusBadge(status: item.status.display); if let version=item.releasedVersion { Text("\(strings.text(.shippedIn)) \(version)").font(.caption.weight(.semibold)).foregroundStyle(.green) } }
            }
        }.padding(.vertical, 4).modifier(RelayLocalizedRoot())
    }
    @MainActor private func load() async { loading=true;defer{loading=false};do{items=try await Relay.board().items;error=nil}catch{self.error=error.localizedDescription} }
    @MainActor private func vote(_ item:RelayBoardItem) async { do{_ = try await Relay.setVote(feedbackId:item.id,voted:true);await load()}catch{self.error=error.localizedDescription} }
}
