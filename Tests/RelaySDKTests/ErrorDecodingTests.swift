import XCTest
@testable import RelaySDK

final class ErrorDecodingTests: XCTestCase {
    func testStructuredErrorObject() async throws {
        let json = #"{"success":false,"error":{"code":"validation_error","message":"message is required"}}"#
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(json, status: 400))], retryPolicy: .none)
        do {
            _ = try await client.submit(type: .feedback, message: "x")
            XCTFail("Expected server error")
        } catch let error as RelayError {
            XCTAssertEqual(error, .server(statusCode: 400, code: "validation_error", message: "message is required"))
            XCTAssertEqual(error.errorDescription, "message is required")
            XCTAssertEqual(error.failureReason, "HTTP 400 (validation_error)")
            XCTAssertFalse(error.isRetryable)
        }
    }

    func testStringErrorField() throws {
        let json = #"{"success":false,"error":"Bad request"}"#
        let envelope = try RelayJSON.makeDecoder().decode(RelayAPIEnvelope<RelayReport>.self, from: Data(json.utf8))
        XCTAssertFalse(envelope.success)
        XCTAssertNil(envelope.data)
        XCTAssertEqual(envelope.error?.message, "Bad request")
        XCTAssertNil(envelope.error?.code)
    }

    func testTopLevelMessageIsUsedWhenErrorMissing() async throws {
        let json = #"{"success":false,"message":"Project disabled"}"#
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(json, status: 422))], retryPolicy: .none)
        do {
            _ = try await client.submit(type: .feedback, message: "x")
            XCTFail("Expected server error")
        } catch let error as RelayError {
            XCTAssertEqual(error, .server(statusCode: 422, code: nil, message: "Project disabled"))
        }
    }

    func testSuccessFalseWith200IsAnError() async throws {
        let json = #"{"success":false,"error":{"code":"nope","message":"Not allowed"}}"#
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(json, status: 200))], retryPolicy: .none)
        do {
            _ = try await client.submit(type: .feedback, message: "x")
            XCTFail("Expected server error")
        } catch let error as RelayError {
            XCTAssertEqual(error, .server(statusCode: 200, code: "nope", message: "Not allowed"))
        }
    }

    func testUnauthorizedAndNotFoundMapping() async throws {
        let (client401, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json("{}", status: 401))], retryPolicy: .none)
        await XCTAssertThrowsRelayError(.unauthorized) { _ = try await client401.fetchThread(id: "a", feedbackToken: "b") }

        let (client403, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json("{}", status: 403))], retryPolicy: .none)
        await XCTAssertThrowsRelayError(.unauthorized) { _ = try await client403.fetchThread(id: "a", feedbackToken: "b") }

        let (client404, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json("{}", status: 404))], retryPolicy: .none)
        await XCTAssertThrowsRelayError(.notFound) { _ = try await client404.fetchThread(id: "a", feedbackToken: "b") }
    }

    func testRateLimitedIncludesRetryAfter() async throws {
        let response = Fixtures.json("{}", status: 429, headers: ["Retry-After": "7"])
        let (client, _) = try Fixtures.makeClient(steps: [.response(response)], retryPolicy: .none)
        await XCTAssertThrowsRelayError(.rateLimited(retryAfter: 7)) { _ = try await client.fetchThread(id: "a", feedbackToken: "b") }
    }

    func testLocalizedDescriptionsExistForEveryError() {
        let errors: [RelayError] = [
            .notConfigured, .invalidProjectKey, .emptyMessage, .invalidRequest, .invalidResponse,
            .decoding("x"), .server(statusCode: 500, code: nil, message: nil), .unauthorized, .notFound,
            .rateLimited(retryAfter: nil), .network("x"), .cancelled, .keychain(-25300), .missingFeedbackToken(id: "a")
        ]
        for error in errors {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty, "\(error) has no description")
            XCTAssertFalse(error.localizedDescription.isEmpty)
        }
        let persian = RelayStrings(language: .persian)
        XCTAssertNotEqual(persian.text(.errorNetwork), RelayStrings(language: .english).text(.errorNetwork))
    }

    func testServerErrorWithoutMessageInterpolatesStatus() {
        let error = RelayError.server(statusCode: 503, code: nil, message: nil)
        XCTAssertTrue(error.errorDescription?.contains("503") == true)
    }
}

func XCTAssertThrowsRelayError(
    _ expected: RelayError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: () async throws -> Void
) async {
    do {
        try await body()
        XCTFail("Expected \(expected) but no error was thrown", file: file, line: line)
    } catch let error as RelayError {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Unexpected error type \(error)", file: file, line: line)
    }
}
