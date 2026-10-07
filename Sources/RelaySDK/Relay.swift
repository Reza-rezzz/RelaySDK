import Foundation

/// Entry point of RelaySDK.
///
/// ```swift
/// import RelaySDK
///
/// Relay.configure(
///     projectKey: "pk_live_...",
///     baseURL: URL(string: "https://relay-wishkit.reza-rzny.workers.dev")!
/// )
///
/// let report = try await Relay.submit(type: .bug, title: "Login problem", message: "The login button does not work.")
/// let thread = try await Relay.fetchThread(id: report.id)
/// ```
public enum Relay {
    private static let state = RelayState()

    // MARK: - Configuration

    /// Configures the shared client. Call once at app launch (safe to call again to reconfigure).
    ///
    /// - Parameters:
    ///   - projectKey: Publishable key beginning with `pk_`. Secret keys are rejected.
    ///   - baseURL: Relay API base URL.
    ///   - timeout: Per-request timeout in seconds (default 30).
    ///   - retryPolicy: Backoff policy for transient failures (default 3 retries).
    ///   - collectsDeviceContext: Set `false` to omit app/device metadata.
    ///   - language: Force `.english` or `.persian`; defaults to the host app's active language with English fallback.
    ///   - theme: Accent color and form title customization.
    ///   - httpClient: Custom transport (tests / custom URLSession).
    ///   - secureStore: Custom secret storage (defaults to Keychain).
    /// - Returns: `true` when configuration succeeded. Fails only for an invalid key, in which case
    ///   subsequent calls throw ``RelayError/invalidProjectKey``.
    @discardableResult
    public static func configure(
        projectKey: String,
        baseURL: URL,
        timeout: TimeInterval = 30,
        retryPolicy: RelayRetryPolicy = .default,
        collectsDeviceContext: Bool = true,
        language: RelayLanguage? = nil,
        theme: RelayTheme = RelayTheme(),
        httpClient: (any RelayHTTPClient)? = nil,
        secureStore: (any RelaySecureStore)? = nil
    ) -> Bool {
        do {
            let configuration = try RelayConfiguration(
                projectKey: projectKey,
                baseURL: baseURL,
                timeout: timeout,
                retryPolicy: retryPolicy,
                collectsDeviceContext: collectsDeviceContext,
                language: language,
                theme: theme,
                httpClient: httpClient,
                secureStore: secureStore
            )
            configure(with: configuration)
            return true
        } catch {
            state.setInvalidKey()
            return false
        }
    }

    /// Configures the shared client with a prebuilt configuration.
    public static func configure(with configuration: RelayConfiguration) {
        state.set(RelayClient(configuration: configuration))
    }

    /// Removes the shared configuration (mainly for tests).
    public static func reset() {
        state.clear()
    }

    /// Whether ``configure(projectKey:baseURL:timeout:retryPolicy:collectsDeviceContext:language:theme:httpClient:secureStore:)`` succeeded.
    public static var isConfigured: Bool { state.client != nil }

    /// Active configuration, or `nil` when not configured.
    public static var configurationIfAvailable: RelayConfiguration? { state.client?.configuration }

    /// The active theme (default theme when not configured).
    public static var theme: RelayTheme { configurationIfAvailable?.theme ?? RelayTheme() }

    /// Shared client. Throws when not configured.
    public static func client() throws -> RelayClient {
        if let client = state.client { return client }
        throw state.invalidKey ? RelayError.invalidProjectKey : RelayError.notConfigured
    }

    // MARK: - Convenience API

    /// Submits a report. See ``RelayClient/submit(type:title:message:)``.
    public static func submit(type: RelayFeedbackType, title: String? = nil, message: String) async throws -> RelayReport {
        try await client().submit(type: type, title: title, message: message)
    }

    /// Fetches status and developer replies. See ``RelayClient/fetchThread(id:)``.
    public static func fetchThread(id: String) async throws -> RelayThread {
        try await client().fetchThread(id: id)
    }

    /// Locally stored reports, newest first.
    public static func storedReports() async throws -> [RelayStoredReport] {
        try await client().storedReports()
    }

    /// Refreshes all stored reports from the server.
    @discardableResult
    public static func refreshAllThreads() async throws -> [RelayStoredReport] {
        try await client().refreshAllThreads()
    }

    /// Persistent random installation identifier.
    public static func installationId() async throws -> String {
        try await client().installationId()
    }

    public static func board() async throws -> RelayBoard { try await client().board() }
    @discardableResult public static func setVote(feedbackId: String, voted: Bool) async throws -> RelayVoteResult { try await client().setVote(feedbackId: feedbackId, voted: voted) }
    public static func changelog() async throws -> RelayChangelog { try await client().changelog() }

    /// Deletes every locally stored report and token.
    public static func clearStoredReports() async throws {
        try await client().reportStore.removeAll()
    }
}

/// Lock-protected holder for the shared client.
final class RelayState: @unchecked Sendable {
    private let lock = NSLock()
    private var _client: RelayClient?
    private var _invalidKey = false

    var client: RelayClient? {
        lock.lock(); defer { lock.unlock() }
        return _client
    }

    var invalidKey: Bool {
        lock.lock(); defer { lock.unlock() }
        return _invalidKey
    }

    func set(_ client: RelayClient) {
        lock.lock(); defer { lock.unlock() }
        _client = client
        _invalidKey = false
    }

    func setInvalidKey() {
        lock.lock(); defer { lock.unlock() }
        _client = nil
        _invalidKey = true
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        _client = nil
        _invalidKey = false
    }
}
