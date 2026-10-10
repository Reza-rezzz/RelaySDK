import SwiftUI

/// Complete customer-facing feedback center: submit, replies, public board, voting and changelog.
public struct RelayFeedbackCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    @State private var selectedTab: Tab = .submit

    private enum Tab: Hashable {
        case submit, board, messages, changelog
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    tabButton(.submit, title: strings.text(.sendFeedback), icon: "square.and.pencil")
                    tabButton(.board, title: strings.text(.feedbackBoard), icon: "person.3.sequence")
                    tabButton(.messages, title: strings.text(.myMessages), icon: "tray.full")
                    tabButton(.changelog, title: strings.text(.changelog), icon: "sparkles")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar)

                tabContent
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

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .submit:
            RelayFeedbackView(showsMyMessagesLink: false, embedded: true)
        case .board:
            RelayBoardView(embedded: true)
        case .messages:
            RelayMyMessagesView(embedded: true)
        case .changelog:
            RelayChangelogView()
        }
    }

    private func tabButton(_ tab: Tab, title: String, icon: String) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(selectedTab == tab ? Color.white : theme.accentColor)
            .background(selectedTab == tab ? theme.accentColor : theme.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
    }
}
