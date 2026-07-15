import Foundation

/// §14 — view/revoke connected external agents (personal-access tokens issued
/// through the MCP OAuth flow). The connect handshake itself stays web-only;
/// mobile just surfaces the token list with a per-row revoke.
struct TokensAPI {
    let client = APIClient.shared

    struct TokenDTO: Decodable {
        var id: IntOrString
        var name: String?
        var clientName: String?
        var createdAt: String?
        var lastUsedAt: String?
        func toApp() -> AppConnectedToken {
            AppConnectedToken(id: id.stringValue, name: name ?? clientName ?? "Connected app",
                               clientName: clientName, createdAt: ServerDate.parse(createdAt),
                               lastUsedAt: ServerDate.parse(lastUsedAt))
        }
    }

    func list() async throws -> [AppConnectedToken] {
        struct R: Decodable { var tokens: [TokenDTO] }
        return try await client.request("/tokens", as: R.self).tokens.map { $0.toApp() }
    }

    func revoke(id: String) async throws {
        _ = try await client.request("/tokens/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}
