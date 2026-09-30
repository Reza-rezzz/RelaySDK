import XCTest
@testable import RelaySDK

final class ResponseDecodingTests: XCTestCase {
    func testDecodesSubmitResponse() async throws {
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(Fixtures.submitSuccess))])
        let report = try await client.submit(type: .feedback, message: "Hi")

        XCTAssertEqual(report.id, "fbk_123")
        XCTAssertEqual(report.status, .new)
        XCTAssertEqual(report.feedbackToken, "tok_secret")
        XCTAssertEqual(report.uploadToken, "up_abc")
        XCTAssertEqual(report.uploadExpiresIn, 900)
        XCTAssertEqual(report.createdAt.timeIntervalSince1970, 1_736_936_430.456, accuracy: 0.001)
    }

    func testDecodesThreadWithReplies() async throws {
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(Fixtures.threadSuccess))])
        let thread = try await client.fetchThread(id: "fbk_123", feedbackToken: "tok")

        XCTAssertEqual(thread.id, "fbk_123")
        XCTAssertEqual(thread.status, .reviewing)
        XCTAssertEqual(thread.replies.count, 1)
        XCTAssertEqual(thread.replies.first?.body, "Thanks, we are looking into it.")
        let updatedAt = try XCTUnwrap(thread.updatedAt)
        XCTAssertEqual(updatedAt.timeIntervalSince1970, 1_737_014_400, accuracy: 0.001)
    }

    func testThreadWithoutRepliesDecodesToEmptyArray() throws {
        let json = #"{"success":true,"data":{"id":"fbk_1","status":"planned"}}"#
        let envelope = try RelayJSON.makeDecoder().decode(RelayAPIEnvelope<RelayThread>.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.data?.replies, [])
        XCTAssertNil(envelope.data?.updatedAt)
    }

    func testUnknownStatusDoesNotFail() throws {
        let json = #"{"success":true,"data":{"id":"fbk_1","status":"archived","replies":[]}}"#
        let envelope = try RelayJSON.makeDecoder().decode(RelayAPIEnvelope<RelayThread>.self, from: Data(json.utf8))
        XCTAssertEqual(envelope.data?.status, .unknown)
        XCTAssertEqual(envelope.data?.status.display, .unknown)
    }

    func testMissingRequiredFieldProducesDecodingError() async throws {
        let json = #"{"success":true,"data":{"status":"new"}}"#
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(json))], retryPolicy: .none)
        do {
            _ = try await client.submit(type: .feedback, message: "Hi")
            XCTFail("Expected decoding error")
        } catch let error as RelayError {
            guard case let .decoding(detail) = error else { return XCTFail("Unexpected \(error)") }
            XCTAssertTrue(detail.contains("id"))
            XCTAssertFalse(error.isRetryable)
        }
    }

    func testEmptyBodyOn200IsInvalidResponse() async throws {
        let (client, _) = try Fixtures.makeClient(steps: [.response(RelayHTTPResponse(statusCode: 200))], retryPolicy: .none)
        do {
            _ = try await client.fetchThread(id: "x", feedbackToken: "y")
            XCTFail("Expected invalidResponse")
        } catch let error as RelayError {
            XCTAssertEqual(error, .invalidResponse)
        }
    }
}

final class ISO8601DateTests: XCTestCase {
    func testParsesFractionalSeconds() throws {
        let date = try XCTUnwrap(RelayISO8601.date(from: "2025-01-15T10:20:30.456Z"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_736_936_430.456, accuracy: 0.001)
    }

    func testParsesWithoutFractionalSeconds() throws {
        let date = try XCTUnwrap(RelayISO8601.date(from: "2025-01-15T10:20:30Z"))
        XCTAssertEqual(date.timeIntervalSince1970, 1_736_936_430, accuracy: 0.001)
    }

    func testParsesTimezoneOffsets() throws {
        let withOffset = try XCTUnwrap(RelayISO8601.date(from: "2025-01-15T13:50:30+03:30"))
        let utc = try XCTUnwrap(RelayISO8601.date(from: "2025-01-15T10:20:30Z"))
        XCTAssertEqual(withOffset, utc)
    }

    func testParsesMicrosecondsAndMissingZone() throws {
        XCTAssertNotNil(RelayISO8601.date(from: "2025-01-15T10:20:30.123456Z"))
        XCTAssertNotNil(RelayISO8601.date(from: "2025-01-15T10:20:30"))
        XCTAssertNotNil(RelayISO8601.date(from: "2025-01-15 10:20:30.5"))
        XCTAssertNotNil(RelayISO8601.date(from: "2025-01-15"))
    }

    func testRejectsGarbage() {
        XCTAssertNil(RelayISO8601.date(from: "not a date"))
        XCTAssertNil(RelayISO8601.date(from: ""))
    }

    func testDecoderHandlesBothFormatsInOnePayload() throws {
        let json = """
        {"success":true,"data":{"id":"fbk_1","status":"new","updated_at":"2025-01-15T10:20:30Z",
         "replies":[{"id":"r","body":"x","created_at":"2025-01-15T10:20:30.999Z"}]}}
        """
        let envelope = try RelayJSON.makeDecoder().decode(RelayAPIEnvelope<RelayThread>.self, from: Data(json.utf8))
        let thread = try XCTUnwrap(envelope.data)
        let updatedAt = try XCTUnwrap(thread.updatedAt)
        XCTAssertEqual(updatedAt.timeIntervalSince1970, 1_736_936_430, accuracy: 0.001)
        XCTAssertEqual(thread.replies[0].createdAt.timeIntervalSince1970, 1_736_936_430.999, accuracy: 0.001)
    }

    func testEncoderRoundTrips() throws {
        let original = Date(timeIntervalSince1970: 1_736_936_430.25)
        let data = try RelayJSON.makeEncoder().encode(["d": original])
        let decoded = try RelayJSON.makeDecoder().decode([String: Date].self, from: data)
        XCTAssertEqual(decoded["d"]?.timeIntervalSince1970 ?? 0, original.timeIntervalSince1970, accuracy: 0.001)
    }
}
