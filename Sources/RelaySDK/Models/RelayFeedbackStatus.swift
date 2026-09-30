import Foundation

/// Raw status values returned by the Relay backend.
///
/// Unknown values decode to ``unknown`` so that new server statuses never break clients.
public enum RelayFeedbackStatus: String, Codable, Sendable, Hashable, CaseIterable {
    case new
    case reviewing
    case planned
    case inProgress = "in_progress"
    case resolved
    case closed
    case rejected
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        self = RelayFeedbackStatus(rawValue: raw) ?? .unknown
    }

    /// User-facing, normalized status.
    public var display: RelayDisplayStatus {
        switch self {
        case .new: return .pending
        case .reviewing: return .inReview
        case .planned: return .planned
        case .inProgress: return .inProgress
        case .resolved, .closed: return .completed
        case .rejected: return .rejected
        case .unknown: return .unknown
        }
    }
}

/// Normalized, user-facing status of a report.
///
/// | Server value           | Display     |
/// |------------------------|-------------|
/// | `new`                  | Pending     |
/// | `reviewing`            | In Review   |
/// | `planned`              | Planned     |
/// | `in_progress`          | In Progress |
/// | `resolved` / `closed`  | Completed   |
/// | `rejected`             | Rejected    |
public enum RelayDisplayStatus: String, Sendable, Hashable, CaseIterable {
    case pending
    case inReview
    case planned
    case inProgress
    case completed
    case rejected
    case unknown

    /// SF Symbol used by the built-in UI.
    public var systemImage: String {
        switch self {
        case .pending: return "clock"
        case .inReview: return "eye"
        case .planned: return "calendar"
        case .inProgress: return "hammer"
        case .completed: return "checkmark.circle"
        case .rejected: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }
}
