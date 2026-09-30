import SwiftUI

/// Visual customization for the built-in SwiftUI screens.
public struct RelayTheme: Sendable {
    /// Primary/accent color used for buttons, selection and badges.
    public var accentColor: Color
    /// Custom form title. `nil` uses the localized default ("Send Feedback" / "ارسال بازخورد").
    public var formTitle: String?
    /// Custom title for the "My Messages" screen. `nil` uses the localized default.
    public var messagesTitle: String?
    /// Corner radius for cards and buttons.
    public var cornerRadius: CGFloat

    public init(
        accentColor: Color = .accentColor,
        formTitle: String? = nil,
        messagesTitle: String? = nil,
        cornerRadius: CGFloat = 12
    ) {
        self.accentColor = accentColor
        self.formTitle = formTitle
        self.messagesTitle = messagesTitle
        self.cornerRadius = cornerRadius
    }

    /// Color for a normalized status.
    public func color(for status: RelayDisplayStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .inReview: return .blue
        case .planned: return .purple
        case .inProgress: return .orange
        case .completed: return .green
        case .rejected: return .red
        case .unknown: return .secondary
        }
    }
}

/// Environment key so nested views pick up the theme.
struct RelayThemeKey: EnvironmentKey {
    static let defaultValue: RelayTheme = Relay.theme
}

struct RelayStringsKey: EnvironmentKey {
    static let defaultValue: RelayStrings = RelayStrings.current
}

extension EnvironmentValues {
    var relayTheme: RelayTheme {
        get { self[RelayThemeKey.self] }
        set { self[RelayThemeKey.self] = newValue }
    }

    var relayStrings: RelayStrings {
        get { self[RelayStringsKey.self] }
        set { self[RelayStringsKey.self] = newValue }
    }
}

public extension View {
    /// Overrides the theme for this view hierarchy.
    func relayTheme(_ theme: RelayTheme) -> some View {
        environment(\.relayTheme, theme)
    }

    /// Overrides the language (and layout direction) for this view hierarchy.
    func relayLanguage(_ language: RelayLanguage) -> some View {
        environment(\.relayStrings, RelayStrings(language: language))
            .environment(\.layoutDirection, language.isRightToLeft ? .rightToLeft : .leftToRight)
            .environment(\.locale, Locale(identifier: language.rawValue))
    }
}

/// Applies the configured language's layout direction.
struct RelayLocalizedRoot: ViewModifier {
    @Environment(\.relayStrings) private var strings

    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, strings.language.isRightToLeft ? .rightToLeft : .leftToRight)
    }
}

/// Small colored capsule showing a status.
public struct RelayStatusBadge: View {
    @Environment(\.relayTheme) private var theme
    @Environment(\.relayStrings) private var strings

    private let status: RelayDisplayStatus

    public init(status: RelayDisplayStatus) {
        self.status = status
    }

    public var body: some View {
        Label(strings.text(for: status), systemImage: status.systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.color(for: status).opacity(0.15), in: Capsule())
            .foregroundStyle(theme.color(for: status))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(strings.text(.a11yStatusBadge)): \(strings.text(for: status))")
    }
}
