import SwiftUI

/// Complete customer-facing feedback center: submit, replies, public board, voting and changelog.
public struct RelayFeedbackCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    @State private var showsComposer = false

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Button { showsComposer = true } label: {
                    Label(strings.text(.sendFeedback), systemImage: "square.and.pencil")
                }
                NavigationLink {
                    RelayMyMessagesView(embedded: true)
                } label: {
                    Label(strings.text(.myMessages), systemImage: "tray.full")
                }
                NavigationLink {
                    RelayBoardView(embedded: true)
                } label: {
                    Label(strings.text(.feedbackBoard), systemImage: "person.3.sequence")
                }
                NavigationLink {
                    RelayChangelogView()
                } label: {
                    Label(strings.text(.changelog), systemImage: "sparkles")
                }
            }
            .navigationTitle(strings.text(.feedbackCenter))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(strings.text(.close)) { dismiss() }
                }
            }
            .sheet(isPresented: $showsComposer) {
                RelayFeedbackView()
            }
        }
        .tint(theme.accentColor)
        .modifier(RelayLocalizedRoot())
    }
}
