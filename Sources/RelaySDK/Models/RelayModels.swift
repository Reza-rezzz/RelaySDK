import Foundation

// MARK: - Request models

/// The body sent to `POST /v1/feedback`.
public struct RelayFeedbackSubmission: Codable, Sendable, Equatable {
    public var type: RelayFeedbackType
    public var title: String?
    public var message: String
    public var installationId: String
    public var context: RelayDeviceContext?

    public init(
        type: RelayFeedbackType,
        title: String?,
        message: String,
        installationId: String,
        context: RelayDeviceContext?
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.installationId = installationId
        self.context = context
    }

    enum CodingKeys: String, CodingKey {
        case type, title, message, context
        case installationId = "installation_id"
    }
}

// MARK: - Response models

/// Result of successfully submitting a report.
public struct RelayReport: Codable, Sendable, Equatable, Identifiable {
    /// Server-assigned identifier (`fbk_...`).
    public let id: String
    /// Status at creation time (normally `new`).
    public let status: RelayFeedbackStatus
    /// Server creation timestamp.
    public let createdAt: Date
    /// Per-report token required to read the thread later. Stored securely by the SDK.
    public let feedbackToken: String
    /// Optional short-lived token for attachment uploads.
    public let uploadToken: String?
    /// Lifetime of ``uploadToken`` in seconds.
    public let uploadExpiresIn: Int?

    public init(
        id: String,
        status: RelayFeedbackStatus,
        createdAt: Date,
        feedbackToken: String,
        uploadToken: String? = nil,
        uploadExpiresIn: Int? = nil
    ) {
        self.id = id
        self.status = status
        self.createdAt = createdAt
        self.feedbackToken = feedbackToken
        self.uploadToken = uploadToken
        self.uploadExpiresIn = uploadExpiresIn
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case createdAt = "created_at"
        case feedbackToken = "feedback_token"
        case uploadToken = "upload_token"
        case uploadExpiresIn = "upload_expires_in"
    }
}

/// A developer reply attached to a report.
public struct RelayReply: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let body: String
    public let createdAt: Date

    public init(id: String, body: String, createdAt: Date) {
        self.id = id
        self.body = body
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, body
        case createdAt = "created_at"
    }
}

/// Current state of a report including developer replies.
public struct RelayThread: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let status: RelayFeedbackStatus
    public let updatedAt: Date?
    public let replies: [RelayReply]

    public init(id: String, status: RelayFeedbackStatus, updatedAt: Date?, replies: [RelayReply]) {
        self.id = id
        self.status = status
        self.updatedAt = updatedAt
        self.replies = replies
    }

    enum CodingKeys: String, CodingKey {
        case id, status, replies
        case updatedAt = "updated_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decode(RelayFeedbackStatus.self, forKey: .status)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
        replies = try c.decodeIfPresent([RelayReply].self, forKey: .replies) ?? []
    }
}

public struct RelayBoardItem: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let type: RelayFeedbackType
    public let title: String?
    public let message: String
    public let status: RelayFeedbackStatus
    public let votes: Int
    public let releasedVersion: String?
    public let createdAt: Date
    public let updatedAt: Date
}

public struct RelayBoard: Codable, Sendable, Equatable {
    public struct Project: Codable, Sendable, Equatable { public let id: String; public let name: String }
    public let project: Project
    public let items: [RelayBoardItem]
}

public struct RelayChangelogItem: Codable, Sendable, Equatable, Identifiable {
    public var id: String { version }
    public let version: String
    public let title: String
    public let notes: String
    public let publishedAt: Date?
}
public struct RelayChangelog: Codable, Sendable, Equatable { public let items: [RelayChangelogItem] }
struct RelayVoteRequest: Encodable, Sendable { let voter_id: String; let vote: Bool }
public struct RelayVoteResult: Codable, Sendable, Equatable { public let id: String; public let voted: Bool; public let votes: Int }

// MARK: - Envelope

/// Error payload returned by the server inside the envelope.
///
/// The backend may return `"error": "string"` or `"error": { "code": ..., "message": ... }`;
/// both shapes are supported.
public struct RelayAPIErrorPayload: Decodable, Sendable, Equatable {
    public let code: String?
    public let message: String?

    enum CodingKeys: String, CodingKey { case code, message, error }

    public init(code: String?, message: String?) {
        self.code = code
        self.message = message
    }

    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(), let text = try? single.decode(String.self) {
            code = nil
            message = text
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decodeIfPresent(String.self, forKey: .code)
        message = try c.decodeIfPresent(String.self, forKey: .message)
            ?? c.decodeIfPresent(String.self, forKey: .error)
    }
}

/// Generic `{ success, data, error }` envelope used by every Relay endpoint.
public struct RelayAPIEnvelope<Payload: Decodable & Sendable>: Decodable, Sendable {
    public let success: Bool
    public let data: Payload?
    public let error: RelayAPIErrorPayload?
    /// Top-level `message` some error responses include.
    public let message: String?

    enum CodingKeys: String, CodingKey { case success, data, error, message }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? false
        data = try c.decodeIfPresent(Payload.self, forKey: .data)
        error = try c.decodeIfPresent(RelayAPIErrorPayload.self, forKey: .error)
        message = try c.decodeIfPresent(String.self, forKey: .message)
    }
}

/// A report persisted locally so the user can revisit it in "My Messages".
///
/// Stored in the Keychain together with its `feedback_token`.
public struct RelayStoredReport: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let feedbackToken: String
    public let type: RelayFeedbackType
    public let title: String?
    public let message: String
    public let createdAt: Date
    public var lastKnownStatus: RelayFeedbackStatus
    public var replies: [RelayReply]
    public var lastSyncedAt: Date?

    public init(
        id: String,
        feedbackToken: String,
        type: RelayFeedbackType,
        title: String?,
        message: String,
        createdAt: Date,
        lastKnownStatus: RelayFeedbackStatus,
        replies: [RelayReply] = [],
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.feedbackToken = feedbackToken
        self.type = type
        self.title = title
        self.message = message
        self.createdAt = createdAt
        self.lastKnownStatus = lastKnownStatus
        self.replies = replies
        self.lastSyncedAt = lastSyncedAt
    }
}
