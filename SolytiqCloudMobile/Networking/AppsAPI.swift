import Foundation

/// §11 — the App Directory (`apps.ts`). Mobile mainly *reads* installed state to
/// gate optional surfaces (GPS, Automations, MCP token screen); install/
/// uninstall are instance-wide admin actions but exposed here for completeness.
struct AppsAPI {
    let client = APIClient.shared

    struct AppDTO: Decodable {
        var id: String
        var name: String?
        var description: String?
        var installed: Bool?
        func toApp() -> AppInstalledApp {
            AppInstalledApp(id: id, name: name ?? id.capitalized, description: description, installed: installed ?? false)
        }
    }

    func list() async throws -> [AppInstalledApp] {
        struct R: Decodable { var apps: [AppDTO] }
        return try await client.request("/apps", as: R.self).apps.map { $0.toApp() }
    }

    func install(appId: String) async throws {
        _ = try await client.request("/apps/\(appId)/install", method: "POST", as: APIClient.EmptyResponse.self)
    }

    func uninstall(appId: String) async throws {
        _ = try await client.request("/apps/\(appId)/uninstall", method: "POST", as: APIClient.EmptyResponse.self)
    }
}
