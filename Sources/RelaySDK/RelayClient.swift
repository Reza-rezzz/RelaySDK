import Foundation

/// Low-level API client. Runs entirely off the main actor.
///
/// Prefer the static ``Relay`` facade in apps; use this type directly when you need
/// multiple configurations or full control in tests.
public final class RelayClient: Sendable {
    public let configuration: RelayConfiguration
    public let reportStore: RelayReportStore
    private let sleeper: RelaySleeper

    /// - Parameters:
    ///   - configuration: Immutable configuration.
    ///   - sleeper: Backoff sleep implementation (tests inject a no-op).
    public init(
        configuration: RelayConfiguration,
        sleeper: @escaping RelaySleeper = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    ) {
        self.configuration = configuration
        self.reportStore = RelayReportStore(store: configuration.secureStore)
        self.sleeper = sleeper
    }

    // MARK: - Public API

    /// Submits a report and stores its id + token securely.
    public func submit(
        type: RelayFeedbackType,
        title: String? = nil,
        message: String
    ) async throws -> RelayReport {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { throw RelayError.emptyMessage }
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = (trimmedTitle?.isEmpty ?? true) ? nil : trimmedTitle

        let installationId = try await reportStore.installationId()
        let submission = RelayFeedbackSubmission(
            type: type,
            title: finalTitle,
            message: trimmedMessage,
            installationId: installationId,
            context: configuration.collectsDeviceContext ? RelayDeviceContext.current(bundle: configuration.bundle) : nil
        )

        let request = try makeRequest(method: .post, path: "/v1/feedback", body: submission)
        let report: RelayReport = try await perform(request)

        try await reportStore.save(
            RelayStoredReport(
                id: report.id,
                feedbackToken: report.feedbackToken,
                type: type,
                title: finalTitle,
                message: trimmedMessage,
                createdAt: report.createdAt,
                lastKnownStatus: report.status
            )
        )
        return report
    }

    /// Fetches the thread for a report using the securely stored token.
    public func fetchThread(id: String) async throws -> RelayThread {
        guard let stored = try await reportStore.report(id: id) else {
            throw RelayError.missingFeedbackToken(id: id)
        }
        return try await fetchThread(id: id, feedbackToken: stored.feedbackToken)
    }

    /// Fetches the thread with an explicit token (useful when you persist tokens yourself).
    public func fetchThread(id: String, feedbackToken: String) async throws -> RelayThread {
        guard !id.isEmpty, !feedbackToken.isEmpty else { throw RelayError.invalidRequest }
        let encodedId = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var request = try makeRequest(method: .get, path: "/v1/feedback/\(encodedId)", body: Optional<RelayFeedbackSubmission>.none)
        request.headers["X-Feedback-Token"] = feedbackToken
        let thread: RelayThread = try await perform(request)
        try? await reportStore.apply(thread)
        return thread
    }

    /// Locally stored reports, newest first.
    public func storedReports() async throws -> [RelayStoredReport] {
        try await reportStore.allReports()
    }

    /// Refreshes every stored report. Failures for individual reports are skipped.
    @discardableResult
    public func refreshAllThreads() async throws -> [RelayStoredReport] {
        let reports = try await reportStore.allReports()
        await withTaskGroup(of: Void.self) { group in
            for report in reports {
                group.addTask { [self] in
                    _ = try? await self.fetchThread(id: report.id, feedbackToken: report.feedbackToken)
                }
            }
        }
        return try await reportStore.allReports()
    }

    /// Persistent random installation id.
    public func installationId() async throws -> String {
        try await reportStore.installationId()
    }

    // MARK: - Request building

    func makeRequest<Body: Encodable>(method: RelayHTTPRequest.Method, path: String, body: Body?) throws -> RelayHTTPRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw RelayError.invalidRequest
        }
        let existing = components.percentEncodedPath
        let basePath = existing.hasSuffix("/") ? String(existing.dropLast()) : existing
        components.percentEncodedPath = basePath + path
        guard let url = components.url else { throw RelayError.invalidRequest }

        var headers: [String: String] = [
            "X-Project-Key": configuration.projectKey,
            "Accept": "application/json",
            "User-Agent": "RelaySDK/\(RelaySDKInfo.version) (swift)"
        ]
        var data: Data?
        if let body {
            headers["Content-Type"] = "application/json"
            do {
                data = try RelayJSON.makeEncoder().encode(body)
            } catch {
                throw RelayError.invalidRequest
            }
        }
        return RelayHTTPRequest(method: method, url: url, headers: headers, body: data, timeout: configuration.timeout)
    }

    // MARK: - Execution with retry

    func perform<Payload: Decodable & Sendable>(_ request: RelayHTTPRequest) async throws -> Payload {
        let policy = configuration.retryPolicy
        var attempt = 0

        while true {
            try Task.checkCancellation()
            do {
                let response = try await configuration.httpClient.send(request)
                return try decode(response)
            } catch let error as RelayError {
                guard error.isRetryable, attempt < policy.maxRetries else { throw error }
                let retryAfter: TimeInterval? = {
                    if case let .rateLimited(seconds) = error { return seconds }
                    return nil
                }()
                let delay = policy.delay(forRetry: attempt, retryAfter: retryAfter)
                attempt += 1
                do {
                    try await sleeper(delay)
                } catch {
                    throw RelayError.cancelled
                }
            } catch is CancellationError {
                throw RelayError.cancelled
            } catch {
                throw RelayError.network(String(describing: Swift.type(of: error)))
            }
        }
    }

    func decode<Payload: Decodable & Sendable>(_ response: RelayHTTPResponse) throws -> Payload {
        let decoder = RelayJSON.makeDecoder()
        var decodingFailure: String?
        let envelope: RelayAPIEnvelope<Payload>? = {
            do {
                return try decoder.decode(RelayAPIEnvelope<Payload>.self, from: response.body)
            } catch let error as DecodingError {
                decodingFailure = Self.describe(error)
                return nil
            } catch {
                decodingFailure = String(describing: Swift.type(of: error))
                return nil
            }
        }()

        switch response.statusCode {
        case 200...299:
            guard let envelope else {
                if response.body.isEmpty { throw RelayError.invalidResponse }
                throw RelayError.decoding(decodingFailure ?? "Unreadable response")
            }
            if envelope.success, let data = envelope.data { return data }
            if let data = envelope.data, envelope.error == nil { return data }
            throw RelayError.server(
                statusCode: response.statusCode,
                code: envelope.error?.code,
                message: envelope.error?.message ?? envelope.message
            )
        case 401, 403:
            throw RelayError.unauthorized
        case 404:
            throw RelayError.notFound
        case 429:
            throw RelayError.rateLimited(retryAfter: RelayRetryPolicy.retryAfterSeconds(from: response.header("Retry-After")))
        default:
            throw RelayError.server(
                statusCode: response.statusCode,
                code: envelope?.error?.code,
                message: envelope?.error?.message ?? envelope?.message
            )
        }
    }

    /// Produces a technical description of a decoding error that never includes payload values.
    private static func describe(_ error: DecodingError) -> String {
        func path(_ context: DecodingError.Context) -> String {
            context.codingPath.map(\.stringValue).joined(separator: ".")
        }
        switch error {
        case let .keyNotFound(key, context): return "Missing key '\(key.stringValue)' at '\(path(context))'"
        case let .typeMismatch(type, context): return "Type mismatch (\(type)) at '\(path(context))'"
        case let .valueNotFound(type, context): return "Missing value (\(type)) at '\(path(context))'"
        case let .dataCorrupted(context): return "Corrupted data at '\(path(context))'"
        @unknown default: return "Decoding error"
        }
    }
}
