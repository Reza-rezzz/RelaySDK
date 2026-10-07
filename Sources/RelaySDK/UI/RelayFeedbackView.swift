import SwiftUI

/// Ready-made feedback form. Present it in a sheet or push it onto a navigation stack.
///
/// ```swift
/// .sheet(isPresented: $showFeedback) {
///     RelayFeedbackView()
/// }
/// ```
public struct RelayFeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    @State private var model: RelayFeedbackViewModel
    @FocusState private var focusedField: Field?

    private let showsMyMessagesLink: Bool
    private let embedded: Bool
    private let onSent: (@MainActor (RelayReport) -> Void)?

    private enum Field { case title, message }

    /// - Parameters:
    ///   - initialType: Pre-selected report type.
    ///   - showsMyMessagesLink: Shows a toolbar link to ``RelayMyMessagesView``.
    ///   - onSent: Called after a successful submission.
    public init(
        initialType: RelayFeedbackType = .feedback,
        showsMyMessagesLink: Bool = true,
        embedded: Bool = false,
        onSent: (@MainActor (RelayReport) -> Void)? = nil
    ) {
        _model = State(initialValue: RelayFeedbackViewModel(type: initialType))
        self.showsMyMessagesLink = showsMyMessagesLink
        self.embedded = embedded
        self.onSent = onSent
    }

    public var body: some View {
        Group {
            if embedded { content } else { NavigationStack { content } }
        }
        .tint(theme.accentColor)
        .modifier(RelayLocalizedRoot())
    }

    private var content: some View {
        Group {
            if let report = model.sentReport {
                successView(report)
            } else {
                form
            }
        }
            .navigationTitle(theme.formTitle ?? strings.text(.formTitle))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                if !embedded {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(strings.text(model.sentReport == nil ? .cancel : .close)) { dismiss() }
                    }
                }
                if showsMyMessagesLink, model.sentReport == nil {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            RelayMyMessagesView(embedded: true)
                        } label: {
                            Image(systemName: "tray.full")
                        }
                        .accessibilityLabel(strings.text(.myMessages))
                    }
                }
            }
    }

    // MARK: Form

    private var form: some View {
        Form {
            Section {
                Picker(strings.text(.typeLabel), selection: $model.type) {
                    ForEach(RelayFeedbackType.allCases) { type in
                        Label(strings.text(for: type), systemImage: type.systemImage).tag(type)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel(strings.text(.a11yTypePicker))
                .disabled(model.isSending)
            }

            Section(strings.text(.titleLabel)) {
                TextField(strings.text(.titlePlaceholder), text: $model.title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .message }
                    .accessibilityLabel(strings.text(.a11yTitleField))
                    .disabled(model.isSending)
            }

            Section(strings.text(.messageLabel)) {
                ZStack(alignment: .topLeading) {
                    if model.message.isEmpty {
                        Text(strings.text(.messagePlaceholder))
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .accessibilityHidden(true)
                    }
                    TextEditor(text: $model.message)
                        .frame(minHeight: 140)
                        .focused($focusedField, equals: .message)
                        .accessibilityLabel(strings.text(.a11yMessageField))
                        .disabled(model.isSending)
                }
            }

            if let error = model.error {
                Section {
                    errorRow(error)
                }
            }

            Section {
                Button {
                    focusedField = nil
                    model.send()
                } label: {
                    HStack {
                        Spacer()
                        if model.isSending {
                            ProgressView().controlSize(.small)
                            Text(strings.text(.sending))
                        } else {
                            Label(strings.text(.send), systemImage: "paperplane.fill")
                        }
                        Spacer()
                    }
                    .font(.body.weight(.semibold))
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSend)
                .accessibilityLabel(strings.text(.a11ySendButton))
                .accessibilityHint(model.canSend ? "" : strings.text(.errorEmptyMessage))
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(model.isSending)
        .onChange(of: model.message) { _, _ in model.dismissError() }
        .onChange(of: model.title) { _, _ in model.dismissError() }
        .onChange(of: model.sentReport) { _, report in
            if let report { onSent?(report) }
        }
    }

    private func errorRow(_ error: RelayError) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(strings.text(.errorTitle), systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)
            Text(error.errorDescription ?? strings.text(.errorInvalidResponse))
                .font(.subheadline)
                .foregroundStyle(.primary)
            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if error.isRetryable {
                Button(strings.text(.retry)) { model.send() }
                    .font(.subheadline.weight(.semibold))
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Success

    private func successView(_ report: RelayReport) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.accentColor)
                .accessibilityHidden(true)
            Text(strings.text(.sentTitle))
                .font(.title2.weight(.bold))
            Text(strings.text(.sentBody))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            RelayStatusBadge(status: report.status.display)
            Spacer()
            if showsMyMessagesLink {
                NavigationLink {
                    RelayMyMessagesView(embedded: true)
                } label: {
                    Text(strings.text(.myMessages))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .padding(.horizontal, 24)
            }
            Button {
                dismiss()
            } label: {
                Text(strings.text(.done))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Button that opens ``RelayFeedbackView`` in a sheet.
///
/// ```swift
/// RelayFeedbackButton()
/// RelayFeedbackButton(initialType: .bug) { Label("Report a bug", systemImage: "ladybug") }
/// ```
public struct RelayFeedbackButton<Label: View>: View {
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings
    @State private var isPresented = false

    private let initialType: RelayFeedbackType
    private let label: () -> Label

    public init(initialType: RelayFeedbackType = .feedback, @ViewBuilder label: @escaping () -> Label) {
        self.initialType = initialType
        self.label = label
    }

    public var body: some View {
        Button {
            isPresented = true
        } label: {
            label()
        }
        .tint(theme.accentColor)
        .accessibilityLabel(strings.text(.a11yFeedbackButton))
        .sheet(isPresented: $isPresented) {
            RelayFeedbackView(initialType: initialType)
                .relayTheme(theme)
                .environment(\.relayStrings, strings)
        }
    }
}

public extension RelayFeedbackButton where Label == SwiftUI.Label<Text, Image> {
    /// Default labeled button ("Send Feedback" with an icon).
    init(initialType: RelayFeedbackType = .feedback) {
        let strings = RelayStrings.current
        self.init(initialType: initialType) {
            SwiftUI.Label(strings.text(.sendFeedback), systemImage: "bubble.left.and.text.bubble.right")
        }
    }
}

