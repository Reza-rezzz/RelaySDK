import SwiftUI

/// "My Messages": every report sent from this device with its status and developer replies.
///
/// ```swift
/// NavigationLink("My Messages") { RelayMyMessagesView(embedded: true) }
/// .sheet(isPresented: $show) { RelayMyMessagesView() }
/// ```
public struct RelayMyMessagesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    @State private var model = RelayMessagesViewModel()

    private let embedded: Bool

    /// - Parameter embedded: Pass `true` when pushing inside an existing `NavigationStack`.
    public init(embedded: Bool = false) {
        self.embedded = embedded
    }

    public var body: some View {
        if embedded {
            content
        } else {
            NavigationStack {
                content
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(strings.text(.close)) { dismiss() }
                        }
                    }
            }
            .tint(theme.accentColor)
            .modifier(RelayLocalizedRoot())
        }
    }

    private var content: some View {
        List {
            if let error = model.error {
                Section {
                    Label(error.errorDescription ?? strings.text(.errorInvalidResponse), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            if model.reports.isEmpty && model.error == nil {
                ContentUnavailableView(
                    strings.text(.noMessages),
                    systemImage: "tray",
                    description: Text(strings.text(.noMessagesHint))
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(model.reports) { report in
                    NavigationLink {
                        RelayMessageDetailView(report: report, model: model)
                    } label: {
                        RelayMessageRow(report: report)
                    }
                }
                .onDelete { offsets in
                    let ids = offsets.map { model.reports[$0].id }
                    Task { for id in ids { await model.delete(id: id) } }
                }
            }
        }
        .navigationTitle(theme.messagesTitle ?? strings.text(.myMessages))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button {
                        Task { await model.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel(strings.text(.refresh))
                }
            }
        }
        .refreshable { await model.load() }
        .task { await model.load() }
    }
}

struct RelayMessageRow: View {
    @Environment(\.relayStrings) private var strings
    let report: RelayStoredReport

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(report.title ?? strings.text(for: report.type), systemImage: report.type.systemImage)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 8)
                RelayStatusBadge(status: report.lastKnownStatus.display)
            }
            Text(report.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            HStack(spacing: 12) {
                Text(report.createdAt, style: .date)
                if !report.replies.isEmpty {
                    Label("\(report.replies.count)", systemImage: "bubble.left.fill")
                        .accessibilityLabel("\(report.replies.count) \(strings.text(.a11yReplyCount))")
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct RelayMessageDetailView: View {
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    let report: RelayStoredReport
    let model: RelayMessagesViewModel

    private var current: RelayStoredReport {
        model.reports.first { $0.id == report.id } ?? report
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(strings.text(for: current.type), systemImage: current.type.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accentColor)
                        Spacer()
                        RelayStatusBadge(status: current.lastKnownStatus.display)
                    }
                    if let title = current.title {
                        Text(title).font(.headline)
                    }
                    Text(current.message)
                        .font(.body)
                        .textSelection(.enabled)
                    Text(current.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .accessibilityElement(children: .combine)
            }

            Section(strings.text(.developerReply)) {
                if current.replies.isEmpty {
                    Text(strings.text(.noReplies))
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(current.replies) { reply in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(reply.body)
                                .font(.body)
                                .textSelection(.enabled)
                            Text(reply.createdAt, style: .relative)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(strings.text(.developerReply)): \(reply.body)")
                    }
                }
            }

            if let synced = current.lastSyncedAt {
                Section {
                    HStack {
                        Text(strings.text(.lastUpdated))
                        Spacer()
                        Text(synced, style: .relative)
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(current.title ?? strings.text(for: current.type))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .refreshable { await model.refresh(id: report.id) }
        .task { await model.refresh(id: report.id) }
    }
}


