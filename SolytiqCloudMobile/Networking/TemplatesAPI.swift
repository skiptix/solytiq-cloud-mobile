import Foundation

/// `/api/templates` — user-owned, workspace-agnostic snapshots of a full
/// list/timeline structure (see `backend/src/routes/templates.ts` +
/// `templateUtil.ts`). Captured dates are stored as day-offsets and resolved
/// against "today" on use, so a template stays meaningful indefinitely.
struct TemplatesAPI {
    let client = APIClient.shared

    /// Own templates + every shared (`isShared`) template on the instance.
    func list(type: String? = nil) async throws -> [AppTemplate] {
        struct R: Decodable { var templates: [APITemplateDTO] }
        var q: [String: String] = [:]
        if let type { q["type"] = type }
        return try await client.request("/templates", query: q, as: R.self).templates.map { $0.toApp() }
    }

    struct CreateBody: Encodable {
        var type: String; var sourceId: String
        var name: String?; var description: String?; var isShared: Bool
    }
    /// Capture an existing list/timeline you own into a new template.
    func create(type: String, sourceId: String, name: String?, description: String?, isShared: Bool) async throws -> AppTemplate {
        struct R: Decodable { var template: APITemplateDTO }
        let body = CreateBody(type: type, sourceId: sourceId, name: name, description: description, isShared: isShared)
        return try await client.request("/templates", method: "POST", body: body, as: R.self).template.toApp()
    }

    struct UpdateBody: Encodable { var name: String?; var description: String?; var isShared: Bool? }
    func update(id: String, name: String?, description: String?, isShared: Bool?) async throws -> AppTemplate {
        struct R: Decodable { var template: APITemplateDTO }
        return try await client.request("/templates/\(id)", method: "PUT",
                                         body: UpdateBody(name: name, description: description, isShared: isShared),
                                         as: R.self).template.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/templates/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// What `POST /:id/use` materialized — a list or a timeline, depending on
    /// the template's type.
    enum CreatedFromTemplate {
        case list(AppList)
        case timeline(AppTimeline)
    }

    struct UseBody: Encodable { var name: String?; var isPublic: Bool?; var workspaceId: String?; var folderId: String? }
    func use(id: String, name: String?, workspaceId: String?, folderId: String? = nil, isPublic: Bool? = nil) async throws -> CreatedFromTemplate {
        struct R: Decodable { var list: APIListDTO?; var timeline: APITimelineDTO? }
        let r = try await client.request("/templates/\(id)/use", method: "POST",
                                          body: UseBody(name: name, isPublic: isPublic, workspaceId: workspaceId, folderId: folderId),
                                          as: R.self)
        if let list = r.list { return .list(list.toApp()) }
        if let timeline = r.timeline { return .timeline(timeline.toApp()) }
        throw APIError.decoding(DecodingError.valueNotFound(
            CreatedFromTemplate.self,
            .init(codingPath: [], debugDescription: "Neither list nor timeline in /use response")))
    }
}
