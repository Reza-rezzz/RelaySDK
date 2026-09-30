import Foundation

/// Typed errors thrown by RelaySDK.
public enum RelayError: Error, LocalizedError, Sendable, Equatable {
    /// `Relay.configure` has not been called.
    case notConfigured
    /// The provided key is not a publishable key (`pk_...`).
    case invalidProjectKey
    /// The message body is empty after trimming whitespace.
    case emptyMessage
    /// The request could not be built (e.g. invalid URL).
    case invalidRequest
    /// The server responded with something that is not valid JSON / expected shape.
    case invalidResponse
    /// JSON decoding failed. The associated value is a technical description (never user content).
    case decoding(String)
    /// The server returned a non-2xx status.
    case server(statusCode: Int, code: String?, message: String?)
    /// Authentication failed (401/403) - usually a wrong project key or feedback token.
    case unauthorized
    /// The report does not exist (404).
    case notFound
    /// Rate limited (429) and retries were exhausted.
    case rateLimited(retryAfter: TimeInterval?)
    /// A transport-level failure (offline, timeout, DNS...).
    case network(String)
    /// The task was cancelled.
    case cancelled
    /// Keychain operation failed with the given `OSStatus`.
    case keychain(OSStatus)
    /// No stored token exists for the given report id.
    case missingFeedbackToken(id: String)

    public var errorDescription: String? {
        let s = RelayStrings.current
        switch self {
        case .notConfigured: return s.text(.errorNotConfigured)
        case .invalidProjectKey: return s.text(.errorInvalidKey)
        case .emptyMessage: return s.text(.errorEmptyMessage)
        case .invalidRequest: return s.text(.errorInvalidRequest)
        case .invalidResponse: return s.text(.errorInvalidResponse)
        case .decoding: return s.text(.errorInvalidResponse)
        case let .server(status, _, message):
            if let message, !message.isEmpty { return message }
            return s.text(.errorServer).replacingOccurrences(of: "{code}", with: String(status))
        case .unauthorized: return s.text(.errorUnauthorized)
        case .notFound: return s.text(.errorNotFound)
        case .rateLimited: return s.text(.errorRateLimited)
        case .network: return s.text(.errorNetwork)
        case .cancelled: return s.text(.errorCancelled)
        case .keychain: return s.text(.errorKeychain)
        case .missingFeedbackToken: return s.text(.errorMissingToken)
        }
    }

    public var failureReason: String? {
        switch self {
        case let .decoding(detail): return detail
        case let .network(detail): return detail
        case let .server(status, code, _): return "HTTP \(status)\(code.map { " (\($0))" } ?? "")"
        case let .keychain(status): return "OSStatus \(status)"
        default: return nil
        }
    }

    public var recoverySuggestion: String? {
        let s = RelayStrings.current
        switch self {
        case .network, .rateLimited, .server: return s.text(.errorRetrySuggestion)
        case .notConfigured, .invalidProjectKey: return s.text(.errorConfigureSuggestion)
        default: return nil
        }
    }

    /// Whether the SDK considers this error transient and worth retrying.
    public var isRetryable: Bool {
        switch self {
        case .network: return true
        case .rateLimited: return true
        case let .server(status, _, _): return status >= 500
        default: return false
        }
    }
}
