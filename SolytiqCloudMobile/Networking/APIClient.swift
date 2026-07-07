import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case notConnected
    case server(status: Int, message: String)
    case decoding(Error)
    case transport(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "That server address doesn't look like a valid URL."
        case .notConnected: return "Not connected to a server."
        case .server(_, let message): return message
        case .decoding: return "The server sent back something this app couldn't understand."
        case .transport(let err): return err.localizedDescription
        case .unauthorized: return "Your session expired — please sign in again."
        }
    }
}

/// Thin REST client for a self-hosted Solytiq Cloud instance
/// (github.com/skiptix/solytiq-cloud, `backend/src/routes/*`). Auth is a
/// bearer JWT (not a cookie — the backend's `authenticate` middleware reads
/// `Authorization: Bearer <token>`), which is exactly what a native client
/// wants: the token lives in the Keychain, not a cookie jar.
actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private var baseURL: URL?
    private var token: String?

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    func configure(baseURL: URL?, token: String?) {
        self.baseURL = baseURL
        self.token = token
    }

    /// Posts `.scSessionInvalidated` so `AppState` can sign out of the server,
    /// but only when a token is actually set — i.e. an established session was
    /// revoked/disabled, not a failed sign-in attempt during the connect flow.
    private func notifySessionInvalidated() {
        guard token != nil else { return }
        NotificationCenter.default.post(name: .scSessionInvalidated, object: nil)
    }

    /// Normalizes whatever the user typed ("myhost", "myhost:8080", full URL)
    /// into a proper base URL with an `/api` suffix stripped (each call adds
    /// its own path), defaulting to https when no scheme is given.
    static func normalize(serverInput: String) -> URL? {
        var trimmed = serverInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") { trimmed = "https://" + trimmed }
        guard var comps = URLComponents(string: trimmed) else { return nil }
        comps.path = ""
        return comps.url
    }

    struct EmptyBody: Encodable {}
    struct EmptyResponse: Decodable {}

    func request<Response: Decodable>(
        _ path: String,
        method: String = "GET",
        query: [String: String] = [:],
        body: (any Encodable)? = nil,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        guard let baseURL else { throw APIError.notConnected }
        guard var comps = URLComponents(url: baseURL.appendingPathComponent("api" + path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        if !query.isEmpty {
            comps.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = comps.url else { throw APIError.invalidURL }

        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            req.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.transport(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.server(status: 0, message: "No response from server.")
        }

        if http.statusCode == 401 {
            notifySessionInvalidated()
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ServerErrorEnvelope.self, from: data))?.error
                ?? String(data: data, encoding: .utf8)
                ?? "Server returned status \(http.statusCode)."
            // 403 during an active session means the admin disabled the mobile
            // app instance-wide — drop back to the mode picker like a revoke.
            if http.statusCode == 403 && message.range(of: "mobile access", options: .caseInsensitive) != nil {
                notifySessionInvalidated()
            }
            throw APIError.server(status: http.statusCode, message: message)
        }

        if Response.self == EmptyResponse.self, data.isEmpty {
            return EmptyResponse() as! Response
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601FlexibleOrTimestamp
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

private struct ServerErrorEnvelope: Decodable { let error: String }

extension Notification.Name {
    /// Fired when the server rejects an authenticated request because the
    /// device connection was revoked (401) or mobile access was disabled
    /// instance-wide (403). `AppState` observes this to sign out.
    static let scSessionInvalidated = Notification.Name("sc.sessionInvalidated")
}

/// Type-erasing wrapper so `request(body:)` can accept any Encodable.
private struct AnyEncodable: Encodable {
    private let encodeClosure: (Encoder) throws -> Void
    init(_ wrapped: any Encodable) { encodeClosure = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeClosure(encoder) }
}

extension JSONDecoder.DateDecodingStrategy {
    /// The backend emits ISO-8601 timestamps (with fractional seconds) for
    /// most fields; this tries a couple of common shapes before giving up.
    static var iso8601FlexibleOrTimestamp: JSONDecoder.DateDecodingStrategy {
        .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let str = try? container.decode(String.self) {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let d = f1.date(from: str) { return d }
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                if let d = f2.date(from: str) { return d }
            }
            if let millis = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: millis / 1000)
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date format")
        }
    }
}
