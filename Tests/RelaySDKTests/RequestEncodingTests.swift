import XCTest
@testable import RelaySDK

final class RequestEncodingTests: XCTestCase {
    func testSubmitBuildsCorrectRequest() async throws {
        let (client, http) = try Fixtures.makeClient(steps: [.response(Fixtures.json(Fixtures.submitSuccess))])

        _ = try await client.submit(type: .bug, title: "  Login problem  ", message: "The login button does not work.")

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url.absoluteString, "https://relay-wishkit.reza-rzny.workers.dev/v1/feedback")
        XCTAssertEqual(request.headers["X-Project-Key"], "pk_test_123")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        XCTAssertNil(request.headers["X-Feedback-Token"])
        XCTAssertEqual(request.timeout, 5)

        let body = try XCTUnwrap(request.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "bug")
        XCTAssertEqual(json["title"] as? String, "Login problem")
        XCTAssertEqual(json["message"] as? String, "The login button does not work.")
        let installationId = try XCTUnwrap(json["installation_id"] as? String)
        XCTAssertFalse(installationId.isEmpty)

        let context = try XCTUnwrap(json["context"] as? [String: Any])
        for key in ["platform", "app_version", "build", "os", "os_version", "device_type", "locale", "language", "sdk_version"] {
            XCTAssertNotNil(context[key], "missing context key \(key)")
        }
        XCTAssertEqual(context["sdk_version"] as? String, "relay-swift-1.0.1")
    }

    func testFeatureRequestUsesSnakeCaseRawValue() throws {
        let submission = RelayFeedbackSubmission(type: .featureRequest, title: nil, message: "Dark mode", installationId: "abc", context: nil)
        let data = try RelayJSON.makeEncoder().encode(submission)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["type"] as? String, "feature_request")
        XCTAssertNil(json["title"])
        XCTAssertNil(json["context"])
        XCTAssertEqual(json["installation_id"] as? String, "abc")
    }

    func testDeviceContextCanBeDisabled() async throws {
        let (client, http) = try Fixtures.makeClient(
            steps: [.response(Fixtures.json(Fixtures.submitSuccess))],
            collectsDeviceContext: false
        )
        _ = try await client.submit(type: .feedback, message: "Hello")
        let body = try XCTUnwrap(http.requests.first?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNil(json["context"])
    }

    func testEmptyMessageIsRejectedBeforeNetworking() async throws {
        let (client, http) = try Fixtures.makeClient(steps: [])
        do {
            _ = try await client.submit(type: .feedback, message: "   \n ")
            XCTFail("Expected emptyMessage")
        } catch let error as RelayError {
            XCTAssertEqual(error, .emptyMessage)
        }
        XCTAssertEqual(http.callCount, 0)
    }

    func testFetchThreadRequestIncludesFeedbackToken() async throws {
        let (client, http) = try Fixtures.makeClient(steps: [.response(Fixtures.json(Fixtures.threadSuccess))])
        _ = try await client.fetchThread(id: "fbk_123", feedbackToken: "tok_secret")
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url.absoluteString, "https://relay-wishkit.reza-rzny.workers.dev/v1/feedback/fbk_123")
        XCTAssertEqual(request.headers["X-Feedback-Token"], "tok_secret")
        XCTAssertEqual(request.headers["X-Project-Key"], "pk_test_123")
        XCTAssertNil(request.body)
    }

    func testBaseURLWithTrailingSlashAndPathIsHandled() throws {
        let http = MockHTTPClient(steps: [])
        let config = try RelayConfiguration(
            projectKey: "pk_x",
            baseURL: URL(string: "https://example.com/api/")!,
            httpClient: http,
            secureStore: RelayInMemorySecureStore()
        )
        let client = RelayClient(configuration: config)
        let request = try client.makeRequest(method: .get, path: "/v1/feedback/abc", body: Optional<RelayFeedbackSubmission>.none)
        XCTAssertEqual(request.url.absoluteString, "https://example.com/api/v1/feedback/abc")
    }

    func testSecretKeysAreRejected() {
        XCTAssertThrowsError(try RelayConfiguration(projectKey: "sk_live_abc", baseURL: Fixtures.baseURL)) { error in
            XCTAssertEqual(error as? RelayError, .invalidProjectKey)
        }
        XCTAssertThrowsError(try RelayConfiguration(projectKey: "", baseURL: Fixtures.baseURL))
        XCTAssertNoThrow(try RelayConfiguration(projectKey: "pk_live_abc", baseURL: Fixtures.baseURL, secureStore: RelayInMemorySecureStore()))
    }
}
