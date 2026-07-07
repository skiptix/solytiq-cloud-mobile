import Foundation

struct TimelinesAPI {
    let client = APIClient.shared

    func list(workspaceId: String? = nil) async throws -> [AppTimeline] {
        struct R: Decodable { var timelines: [APITimelineDTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/timelines", query: q, as: R.self).timelines.map { $0.toApp() }
    }

    struct CreateBody: Encodable {
        var name: String; var emoji: String?; var color: String?; var subtitle: String?
        var isPublic: Bool?; var folderId: String?; var workspaceId: String?
    }
    func create(name: String, emoji: String?, color: String?, subtitle: String?, folderId: String?, workspaceId: String?) async throws -> AppTimeline {
        struct R: Decodable { var timeline: APITimelineDTO }
        let body = CreateBody(name: name, emoji: emoji, color: color, subtitle: subtitle, isPublic: false, folderId: folderId, workspaceId: workspaceId)
        return try await client.request("/timelines", method: "POST", body: body, as: R.self).timeline.toApp()
    }

    struct UpdateBody: Encodable { var name: String?; var emoji: String?; var color: String?; var subtitle: String? }
    func update(id: String, _ patch: UpdateBody) async throws -> AppTimeline {
        struct R: Decodable { var timeline: APITimelineDTO }
        return try await client.request("/timelines/\(id)", method: "PUT", body: patch, as: R.self).timeline.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/timelines/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    struct ShareBody: Encodable { var shareEnabled: Bool; var password: String?; var expiresAt: String? }
    func setShare(id: String, enabled: Bool, password: String?, expiresAt: String?) async throws -> AppTimeline {
        struct R: Decodable { var timeline: APITimelineDTO }
        return try await client.request("/timelines/\(id)/share", method: "PUT",
                                         body: ShareBody(shareEnabled: enabled, password: password, expiresAt: expiresAt), as: R.self).timeline.toApp()
    }

    struct MilestoneBody: Encodable { var title: String; var description: String?; var date: String?; var time: String?; var status: String?; var emoji: String?; var color: String? }
    func addMilestone(timelineId: String, _ m: AppMilestone) async throws -> AppMilestone {
        struct R: Decodable { var milestone: APIMilestoneDTO }
        let body = MilestoneBody(title: m.title, description: m.summary, date: m.date, time: m.time, status: m.status.rawValue, emoji: m.emoji, color: m.colorHex)
        return try await client.request("/timelines/\(timelineId)/milestones", method: "POST", body: body, as: R.self).milestone.toApp()
    }

    func updateMilestone(id: String, _ m: AppMilestone) async throws -> AppMilestone {
        struct R: Decodable { var milestone: APIMilestoneDTO }
        let body = MilestoneBody(title: m.title, description: m.summary, date: m.date, time: m.time, status: m.status.rawValue, emoji: m.emoji, color: m.colorHex)
        return try await client.request("/milestones/\(id)", method: "PUT", body: body, as: R.self).milestone.toApp()
    }

    func deleteMilestone(id: String) async throws {
        _ = try await client.request("/milestones/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}

/// Backend trash is split by entity kind (`/trash`, `/trash/lists`,
/// `/trash/folders`, `/trash/timelines`, `/trash/milestones`) — this wraps
/// all four behind one Swift-friendly surface + a unified `AppTrashEntry`
/// list for the Trash sheet.
struct TrashAPI {
    let client = APIClient.shared

    struct TaskTrashRow: Decodable { var id: Int; var task: APITaskDTO; var deletedAt: String }
    struct ListTrashRow: Decodable { var id: Int; var list: APIListDTO; var deletedAt: String }
    struct FolderTrashRow: Decodable { var id: Int; var folder: APIFolderDTO; var deletedAt: String }
    struct TimelineTrashRow: Decodable { var id: Int; var timeline: APITimelineDTO; var deletedAt: String }

    func tasks() async throws -> [(entryId: String, task: AppTask, deletedAt: Date)] {
        struct R: Decodable { var trash: [TaskTrashRow] }
        let rows = try await client.request("/trash", as: R.self).trash
        return rows.map { (String($0.id), $0.task.toApp(), ServerDate.parse($0.deletedAt) ?? .now) }
    }
    func restoreTask(entryId: String) async throws {
        _ = try await client.request("/trash/\(entryId)/restore", method: "POST", as: APIClient.EmptyResponse.self)
    }
    func deleteTaskForever(entryId: String) async throws {
        _ = try await client.request("/trash/\(entryId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    func lists() async throws -> [(entryId: String, list: AppList, deletedAt: Date)] {
        struct R: Decodable { var trash: [ListTrashRow] }
        let rows = try await client.request("/trash/lists", as: R.self).trash
        return rows.map { (String($0.id), $0.list.toApp(), ServerDate.parse($0.deletedAt) ?? .now) }
    }
    func restoreList(entryId: String) async throws {
        _ = try await client.request("/trash/lists/\(entryId)/restore", method: "POST", as: APIClient.EmptyResponse.self)
    }
    func deleteListForever(entryId: String) async throws {
        _ = try await client.request("/trash/lists/\(entryId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    func folders() async throws -> [(entryId: String, folder: AppFolder, deletedAt: Date)] {
        struct R: Decodable { var trash: [FolderTrashRow] }
        let rows = try await client.request("/trash/folders", as: R.self).trash
        return rows.map { (String($0.id), $0.folder.toApp(), ServerDate.parse($0.deletedAt) ?? .now) }
    }
    func restoreFolder(entryId: String) async throws {
        _ = try await client.request("/trash/folders/\(entryId)/restore", method: "POST", as: APIClient.EmptyResponse.self)
    }
    func deleteFolderForever(entryId: String) async throws {
        _ = try await client.request("/trash/folders/\(entryId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    func timelines() async throws -> [(entryId: String, timeline: AppTimeline, deletedAt: Date)] {
        struct R: Decodable { var trash: [TimelineTrashRow] }
        let rows = try await client.request("/trash/timelines", as: R.self).trash
        return rows.map { (String($0.id), $0.timeline.toApp(), ServerDate.parse($0.deletedAt) ?? .now) }
    }
    func restoreTimeline(entryId: String) async throws {
        _ = try await client.request("/trash/timelines/\(entryId)/restore", method: "POST", as: APIClient.EmptyResponse.self)
    }
    func deleteTimelineForever(entryId: String) async throws {
        _ = try await client.request("/trash/timelines/\(entryId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    func emptyAll() async throws {
        _ = try await client.request("/trash/empty", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}
