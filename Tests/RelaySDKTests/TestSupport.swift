import Foundation
@testable import RelaySDK

/// Scripted transport: returns queued results in order and records every request.
final class MockHTTPClient: RelayHTTPClient, @unchecked Sendable {
    enum Step {
        case response(RelayHTTPResponse)
        case failure(RelayError)
    }

    private let lock = NSLock()
    private var steps: [Step]
    private(set) var requests: [RelayHTTPRequest] = []

    init(steps: [Step]) {
        self.steps = steps
    }

    var callCount: Int {
        lock.lock(); defer { lock.unlock() }
        return requests.count
    }

    func send(_ request: RelayHTTPRequest) async throws -> RelayHTTPResponse {
        lock.lock()
        requests.append(request)
        let step = steps.isEmpty ? nil : steps.removeFirst()
        lock.unlock()

        guard let step else { throw RelayError.network("Unexpected request") }
        switch step {
        case let .response(response): return response
        case let .failure(error): throw error
        }
    }
}

/// Records requested sleep durations without actually sleeping.
final class SleepRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var delays: [TimeInterval] = []

    var sleeper: RelaySleeper {
        { [self] seconds in
            lock.lock(); defer { lock.unlock() }
            delays.append(seconds)
        }
    }
}

enum Fixtures {
    static let baseURL = URL(string: "https://relay-wishkit.reza-rzny.workers.dev")!

    static let submitSuccess = """
    {
      "success": true,
      "data": {
        "id": "fbk_123",
        "status": "new",
        "created_at": "2025-01-15T10:20:30.456Z",
        "feedback_token": "tok_secret",
        "upload_token": "up_abc",
        "upload_expires_in": 900
      }
    }
    """

    static let threadSuccess = """
    {
      "success": true,
      "data": {
        "id": "fbk_123",
        "status": "reviewing",
        "updated_at": "2025-01-16T08:00:00Z",
        "replies": [
          { "id": "rpl_1", "body": "Thanks, we are looking into it.", "created_at": "2025-01-16T07:59:59.001Z" }
        ]
      }
    }
    """

    static func json(_ text: String, status: Int = 200, headers: [String: String] = [:]) -> RelayHTTPResponse {
        RelayHTTPResponse(statusCode: status, headers: headers, body: Data(text.utf8))
    }

    static func makeClient(
        steps: [MockHTTPClient.Step],
        retryPolicy: RelayRetryPolicy = .default,
        collectsDeviceContext: Bool = true,
        store: RelaySecureStore = RelayInMemorySecureStore(),
        sleeper: RelaySleeper? = nil
    ) throws -> (RelayClient, MockHTTPClient) {
        let http = MockHTTPClient(steps: steps)
        let configuration = try RelayConfiguration(
            projectKey: "pk_test_123",
            baseURL: baseURL,
            timeout: 5,
            retryPolicy: retryPolicy,
            collectsDeviceContext: collectsDeviceContext,
            language: .english,
            httpClient: http,
            secureStore: store
        )
        let client = RelayClient(configuration: configuration, sleeper: sleeper ?? { _ in })
        return (client, http)
    }
}
