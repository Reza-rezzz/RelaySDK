import Foundation

/// The category of a feedback report sent to Relay.
public enum RelayFeedbackType: String, Codable, CaseIterable, Sendable, Identifiable, Hashable {
    /// General feedback about the app.
    case feedback
    /// A bug report.
    case bug
    /// A request for a new feature.
    case featureRequest = "feature_request"
    /// A general issue that is not necessarily a bug.
    case issue

    public var id: String { rawValue }

    /// SF Symbol name used by the built-in UI for this type.
    public var systemImage: String {
        switch self {
        case .feedback: return "bubble.left.and.bubble.right"
        case .bug: return "ladybug"
        case .featureRequest: return "lightbulb"
        case .issue: return "exclamationmark.triangle"
        }
    }
}
