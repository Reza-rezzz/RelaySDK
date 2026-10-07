import SwiftUI

/// Complete customer-facing feedback center: submit, replies, public board, voting and changelog.
public struct RelayFeedbackCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    topLink(strings.text(.myMessages), icon: "tray.full") {
                        RelayMyMessagesView(embedded: true)
                    }
                    topLink(strings.text(.feedbackBoard), icon: "person.3.sequence") {
                        RelayBoardView(embedded: true)
                    }
                    topLink(strings.text(.changelog), icon: "sparkles") {
                        RelayChangelogView()
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)

                RelayFeedbackView(showsMyMessagesLink: false, embedded: true)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.text(.close)) { dismiss() }
                }
            }
        }
        .tint(theme.accentColor)
        .modifier(RelayLocalizedRoot())
    }

    private func topLink<Destination: View>(
        _ title: String,
        icon: String,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination()) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(theme.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
