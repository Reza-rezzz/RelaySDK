import Foundation

/// A transport-agnostic HTTP request.
public struct RelayHTTPRequest: Sendable, Equatable {
    public enum Method: String, Sendable { case get = "GET", post = "POST" }

    public var method: Method
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    public var timeout: TimeInterval

    public init(method: Method, url: URL, headers: [String: String] = [:], body: Data? = nil, timeout: TimeInterval = 30) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }
}

/// A transport-agnostic HTTP response.
public struct RelayHTTPResponse: Sendable, Equatable {
    public var statusCode: Int
    public var headers: [String: String]
    public var body: Data

    public init(statusCode: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }

    /// Case-insensitive header lookup.
    public func header(_ name: String) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }
}

/// Injectable transport used by ``RelayClient``.
///
/// Implement this protocol to stub networking in tests. Throw ``RelayError/network(_:)``
/// for transport failures so that the retry policy can classify them.
public protocol RelayHTTPClient: Sendable {
    func send(_ request: RelayHTTPRequest) async throws -> RelayHTTPResponse
}

/// Default `URLSession`-backed transport.
public struct RelayURLSessionHTTPClient: RelayHTTPClient {
    private let session: URLSession

    public init(session: URLSession = RelayURLSessionHTTPClient.makeDefaultSession()) {
        self.session = session
    }

    /// Ephemeral session: no cookies, no cache, no persisted credentials.
    public static func makeDefaultSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        return URLSession(configuration: config)
    }

    public func send(_ request: RelayHTTPRequest) async throws -> RelayHTTPResponse {
        var urlRequest = URLRequest(url: request.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: request.timeout)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else { throw RelayError.invalidResponse }
            var headers: [String: String] = [:]
            for (key, value) in http.allHeaderFields {
                if let k = key as? String, let v = value as? String { headers[k] = v }
            }
            return RelayHTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
        } catch let error as RelayError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw RelayError.cancelled
        } catch is CancellationError {
            throw RelayError.cancelled
        } catch let error as URLError {
            // Only the code is surfaced, never the URL or body.
            throw RelayError.network("URLError \(error.code.rawValue)")
        } catch {
            throw RelayError.network(String(describing: Swift.type(of: error)))
        }
    }
}
