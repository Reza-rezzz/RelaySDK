import Foundation

/// Immutable configuration for the SDK.
///
/// Create it via ``Relay/configure(projectKey:baseURL:timeout:retryPolicy:collectsDeviceContext:language:theme:httpClient:secureStore:)``
/// or construct it directly and pass to ``RelayClient``.
public struct RelayConfiguration: @unchecked Sendable {
    /// Publishable project key (`pk_live_...` / `pk_test_...`). Secret keys are rejected.
    public let projectKey: String
    /// API base URL (no trailing slash required).
    public let baseURL: URL
    /// Per-request timeout in seconds.
    public var timeout: TimeInterval
    /// Retry policy for transient failures.
    public var retryPolicy: RelayRetryPolicy
    /// Whether device/app metadata is attached to reports.
    public var collectsDeviceContext: Bool
    /// UI language. Defaults to the system language (English or Persian).
    public var language: RelayLanguage
    /// Visual customization for the built-in UI.
    public var theme: RelayTheme
    /// Injected transport.
    public var httpClient: any RelayHTTPClient
    /// Injected secure storage.
    public var secureStore: any RelaySecureStore
    /// Bundle used to read app version/build. Defaults to `.main`.
    public var bundle: Bundle

    /// Creates a configuration.
    /// - Throws: ``RelayError/invalidProjectKey`` if the key is not a publishable key.
    public init(
        projectKey: String,
        baseURL: URL,
        timeout: TimeInterval = 30,
        retryPolicy: RelayRetryPolicy = .default,
        collectsDeviceContext: Bool = true,
        language: RelayLanguage? = nil,
        theme: RelayTheme = RelayTheme(),
        httpClient: (any RelayHTTPClient)? = nil,
        secureStore: (any RelaySecureStore)? = nil,
        bundle: Bundle = .main
    ) throws {
        let key = projectKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RelayConfiguration.isPublishableKey(key) else { throw RelayError.invalidProjectKey }
        self.projectKey = key
        self.baseURL = baseURL
        self.timeout = max(1, timeout)
        self.retryPolicy = retryPolicy
        self.collectsDeviceContext = collectsDeviceContext
        self.language = language ?? RelayLanguage.best()
        self.theme = theme
        self.httpClient = httpClient ?? RelayURLSessionHTTPClient()
        self.secureStore = secureStore ?? RelayKeychainStore()
        self.bundle = bundle
    }

    /// Only `pk_` prefixed keys are accepted; anything that looks like a secret (`sk_`) is refused.
    public static func isPublishableKey(_ key: String) -> Bool {
        key.hasPrefix("pk_") && key.count > 3 && !key.contains(where: { $0.isWhitespace })
    }
}
