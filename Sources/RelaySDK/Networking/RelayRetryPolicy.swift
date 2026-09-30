import Foundation

/// Async sleep function used between retries. Injected so tests run instantly.
public typealias RelaySleeper = @Sendable (_ seconds: TimeInterval) async throws -> Void

/// Bounded exponential-backoff policy.
///
/// Retries are attempted only for transient failures: transport errors,
/// HTTP `429` and HTTP `5xx`. All other failures surface immediately.
public struct RelayRetryPolicy: Sendable, Equatable {
    /// Number of retries after the initial attempt. `0` disables retrying.
    public var maxRetries: Int
    /// Delay before the first retry.
    public var baseDelay: TimeInterval
    /// Upper bound for a single delay.
    public var maxDelay: TimeInterval
    /// Multiplier applied per attempt.
    public var multiplier: Double
    /// Random jitter added as a fraction of the delay (0...1).
    public var jitterFraction: Double

    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 8,
        multiplier: Double = 2,
        jitterFraction: Double = 0.2
    ) {
        self.maxRetries = max(0, maxRetries)
        self.baseDelay = max(0, baseDelay)
        self.maxDelay = max(0, maxDelay)
        self.multiplier = max(1, multiplier)
        self.jitterFraction = min(max(0, jitterFraction), 1)
    }

    /// Default policy (3 retries: ~0.5s, 1s, 2s).
    public static let `default` = RelayRetryPolicy()
    /// No retries.
    public static let none = RelayRetryPolicy(maxRetries: 0)

    /// Deterministic delay for a given retry index (0-based), excluding jitter.
    public func baseDelay(forRetry index: Int) -> TimeInterval {
        min(maxDelay, baseDelay * pow(multiplier, Double(index)))
    }

    /// Delay including jitter, honoring an optional server `Retry-After` hint.
    public func delay(forRetry index: Int, retryAfter: TimeInterval? = nil) -> TimeInterval {
        if let retryAfter, retryAfter > 0 { return min(maxDelay, retryAfter) }
        let base = baseDelay(forRetry: index)
        guard jitterFraction > 0, base > 0 else { return base }
        let jitter = Double.random(in: 0...(base * jitterFraction))
        return min(maxDelay, base + jitter)
    }

    /// Whether the given HTTP status is transient.
    public static func isRetryableStatus(_ status: Int) -> Bool {
        status == 429 || (500...599).contains(status)
    }

    /// Parses a `Retry-After` header (seconds only; HTTP-date is ignored).
    public static func retryAfterSeconds(from header: String?) -> TimeInterval? {
        guard let header, let seconds = TimeInterval(header.trimmingCharacters(in: .whitespaces)) else { return nil }
        return seconds
    }
}
