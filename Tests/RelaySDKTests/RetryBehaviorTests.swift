import XCTest
@testable import RelaySDK

final class RetryBehaviorTests: XCTestCase {
    private let policy = RelayRetryPolicy(maxRetries: 3, baseDelay: 0.5, maxDelay: 8, multiplier: 2, jitterFraction: 0)

    func testRetriesOn5xxThenSucceeds() async throws {
        let recorder = SleepRecorder()
        let (client, http) = try Fixtures.makeClient(
            steps: [
                .response(Fixtures.json("{}", status: 500)),
                .response(Fixtures.json("{}", status: 503)),
                .response(Fixtures.json(Fixtures.threadSuccess))
            ],
            retryPolicy: policy,
            sleeper: recorder.sleeper
        )
        let thread = try await client.fetchThread(id: "fbk_123", feedbackToken: "t")
        XCTAssertEqual(thread.status, .reviewing)
        XCTAssertEqual(http.callCount, 3)
        XCTAssertEqual(recorder.delays, [0.5, 1.0])
    }

    func testRetriesOnNetworkErrorWithExponentialBackoff() async throws {
        let recorder = SleepRecorder()
        let (client, http) = try Fixtures.makeClient(
            steps: [
                .failure(.network("offline")),
                .failure(.network("offline")),
                .failure(.network("offline")),
                .failure(.network("offline"))
            ],
            retryPolicy: policy,
            sleeper: recorder.sleeper
        )
        await XCTAssertThrowsRelayError(.network("offline")) { _ = try await client.fetchThread(id: "a", feedbackToken: "b") }
        XCTAssertEqual(http.callCount, 4, "initial attempt + 3 retries")
        XCTAssertEqual(recorder.delays, [0.5, 1.0, 2.0])
    }

    func testRetryAfterHeaderOverridesBackoffFor429() async throws {
        let recorder = SleepRecorder()
        let (client, http) = try Fixtures.makeClient(
            steps: [
                .response(Fixtures.json("{}", status: 429, headers: ["Retry-After": "3"])),
                .response(Fixtures.json(Fixtures.threadSuccess))
            ],
            retryPolicy: policy,
            sleeper: recorder.sleeper
        )
        _ = try await client.fetchThread(id: "a", feedbackToken: "b")
        XCTAssertEqual(http.callCount, 2)
        XCTAssertEqual(recorder.delays, [3])
    }

    func testDoesNotRetryOn4xx() async throws {
        let recorder = SleepRecorder()
        let json = #"{"success":false,"error":{"code":"bad","message":"Bad"}}"#
        let (client, http) = try Fixtures.makeClient(
            steps: [.response(Fixtures.json(json, status: 400)), .response(Fixtures.json(Fixtures.threadSuccess))],
            retryPolicy: policy,
            sleeper: recorder.sleeper
        )
        await XCTAssertThrowsRelayError(.server(statusCode: 400, code: "bad", message: "Bad")) {
            _ = try await client.fetchThread(id: "a", feedbackToken: "b")
        }
        XCTAssertEqual(http.callCount, 1)
        XCTAssertTrue(recorder.delays.isEmpty)
    }

    func testDoesNotRetryUnauthorizedOrDecodingErrors() async throws {
        let (client401, http401) = try Fixtures.makeClient(steps: [.response(Fixtures.json("{}", status: 401))], retryPolicy: policy)
        await XCTAssertThrowsRelayError(.unauthorized) { _ = try await client401.fetchThread(id: "a", feedbackToken: "b") }
        XCTAssertEqual(http401.callCount, 1)

        let (clientBad, httpBad) = try Fixtures.makeClient(steps: [.response(Fixtures.json("{\"success\":true,\"data\":{}}"))], retryPolicy: policy)
        do {
            _ = try await clientBad.fetchThread(id: "a", feedbackToken: "b")
            XCTFail("Expected decoding error")
        } catch let error as RelayError {
            guard case .decoding = error else { return XCTFail("Unexpected \(error)") }
        }
        XCTAssertEqual(httpBad.callCount, 1)
    }

    func testNoRetryPolicyMakesSingleAttempt() async throws {
        let (client, http) = try Fixtures.makeClient(
            steps: [.response(Fixtures.json("{}", status: 500)), .response(Fixtures.json(Fixtures.threadSuccess))],
            retryPolicy: .none
        )
        await XCTAssertThrowsRelayError(.server(statusCode: 500, code: nil, message: nil)) {
            _ = try await client.fetchThread(id: "a", feedbackToken: "b")
        }
        XCTAssertEqual(http.callCount, 1)
    }

    func testPolicyDelaysAreCappedAndJittered() {
        let capped = RelayRetryPolicy(maxRetries: 5, baseDelay: 1, maxDelay: 3, multiplier: 2, jitterFraction: 0)
        XCTAssertEqual(capped.baseDelay(forRetry: 0), 1)
        XCTAssertEqual(capped.baseDelay(forRetry: 1), 2)
        XCTAssertEqual(capped.baseDelay(forRetry: 2), 3)
        XCTAssertEqual(capped.baseDelay(forRetry: 10), 3)

        let jittered = RelayRetryPolicy(maxRetries: 1, baseDelay: 1, maxDelay: 10, multiplier: 2, jitterFraction: 0.5)
        for _ in 0..<50 {
            let d = jittered.delay(forRetry: 0)
            XCTAssertGreaterThanOrEqual(d, 1)
            XCTAssertLessThanOrEqual(d, 1.5)
        }
        XCTAssertTrue(RelayRetryPolicy.isRetryableStatus(429))
        XCTAssertTrue(RelayRetryPolicy.isRetryableStatus(502))
        XCTAssertFalse(RelayRetryPolicy.isRetryableStatus(404))
        XCTAssertEqual(RelayRetryPolicy.retryAfterSeconds(from: " 12 "), 12)
        XCTAssertNil(RelayRetryPolicy.retryAfterSeconds(from: "Wed, 21 Oct 2015 07:28:00 GMT"))
    }
}
