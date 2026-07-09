import Foundation

// MARK: - Delta-sync wire types
//
// Mirrors the cursor-based delta-sync engine in solytiq-cloud
// (`backend/src/routes/sync.ts` + `backend/src/syncLog.ts`):
//
//   GET /api/sync/bootstrap?workspaceId  → full state + cursor in one request
//   GET /api/sync/delta?since&workspaceId → net changes after the cursor
//
// Both endpoints reuse the exact serializers behind the classic GET
// /tasks|/lists|/folders|/timelines routes, so the payloads decode with the
// same DTOs the app already uses. The SSE frame from `/api/events` is only a
// *nudge*; these two endpoints are the authoritative source of truth.

struct SyncBootstrapResponse: Decodable {
    var cursor: Int64
    var workspaceId: String?
    var tasks: [APITaskDTO]
    var lists: [APIListDTO]
    var folders: [APIFolderDTO]
    var timelines: [APITimelineDTO]
}

/// One coalesced change from `/api/sync/delta`. Core entities (task, list,
/// folder, timeline) carry a full re-serialized payload; signal entities
/// (meeting, file, workspace, trash, template) carry none — the client
/// refetches that surface itself.
struct SyncDeltaChange: Decodable {
    var entity: String
    var entityId: String
    var op: String   // "upsert" | "delete"

    // Exactly one of these is set for a core-entity upsert.
    var task: APITaskDTO?
    var list: APIListDTO?
    var folder: APIFolderDTO?
    var timeline: APITimelineDTO?

    private enum CodingKeys: String, CodingKey { case entity, entityId, op, payload }

    init(entity: String, entityId: String, op: String,
         task: APITaskDTO? = nil, list: APIListDTO? = nil,
         folder: APIFolderDTO? = nil, timeline: APITimelineDTO? = nil) {
        self.entity = entity; self.entityId = entityId; self.op = op
        self.task = task; self.list = list; self.folder = folder; self.timeline = timeline
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entity = try c.decode(String.self, forKey: .entity)
        entityId = try c.decode(String.self, forKey: .entityId)
        op = try c.decode(String.self, forKey: .op)
        guard op == "upsert" else { return }
        // A payload that fails to decode is treated as absent rather than
        // failing the whole delta — the next pull/bootstrap heals it.
        switch entity {
        case "task": task = try? c.decode(APITaskDTO.self, forKey: .payload)
        case "list": list = try? c.decode(APIListDTO.self, forKey: .payload)
        case "folder": folder = try? c.decode(APIFolderDTO.self, forKey: .payload)
        case "timeline": timeline = try? c.decode(APITimelineDTO.self, forKey: .payload)
        default: break
        }
    }
}

struct SyncDeltaResponse: Decodable {
    var cursor: Int64
    var changes: [SyncDeltaChange]
    /// True when `since` fell behind the server's sync_log retention window —
    /// the client must drop local state and re-bootstrap.
    var reset: Bool?
}

struct SyncAPI {
    let client = APIClient.shared

    func bootstrap(workspaceId: String?) async throws -> SyncBootstrapResponse {
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/sync/bootstrap", query: q)
    }

    func delta(since: Int64, workspaceId: String?) async throws -> SyncDeltaResponse {
        var q: [String: String] = ["since": String(since)]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/sync/delta", query: q)
    }
}

// MARK: - Realtime frame (`event: sync` on /api/events)

/// The compact frame the sync dispatcher pushes over SSE. Advisory only:
/// `cursor` lets the client skip a pull it has already applied, `entities`
/// and `workspaceId` let it skip frames for content it isn't viewing.
/// A legacy `{type}` nudge (from older `broadcastToUser` call sites) has no
/// cursor and is always treated as "pull deltas now".
struct SyncFrame: Decodable {
    var cursor: Int64?
    var workspaceId: String?
    var entities: [Entity]?
    var type: String?

    struct Entity: Decodable {
        var entity: String
        var entityId: String
        var op: String
    }
}
