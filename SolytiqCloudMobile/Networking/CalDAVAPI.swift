import Foundation

/// §12 — CalDAV credential management (`caldavManage.ts`). The actual calendar
/// subscription is consumed by iOS's native Calendar app; this app's job is only
/// to expose the app-password lifecycle so a user can set that subscription up.
struct CalDAVAPI {
    let client = APIClient.shared

    struct Status: Decodable {
        var enabled: Bool?
        var configured: Bool?
        var url: String?
        var username: String?
    }

    func status() async throws -> Status {
        try await client.request("/caldav", as: Status.self)
    }

    /// Generates (or regenerates) the app password. Like the admin API key it is
    /// returned exactly once — the caller must surface it immediately.
    struct GeneratedPassword: Decodable {
        var password: String
        var url: String?
        var username: String?
    }
    func generatePassword() async throws -> GeneratedPassword {
        try await client.request("/caldav/password", method: "POST")
    }

    func revoke() async throws {
        _ = try await client.request("/caldav", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}
