import Foundation

/// Tasks, lists/sections, folders, workspaces and meetings — the "everyday"
/// CRUD surface of the backend. One struct per resource keeps each call site
/// short; they all just funnel through the shared `APIClient`.

struct TasksAPI {
    let client = APIClient.shared

    func list(workspaceId: String? = nil) async throws -> [AppTask] {
        struct R: Decodable { var tasks: [APITaskDTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/tasks", query: q, as: R.self).tasks.map { $0.toApp() }
    }

    struct CreateBody: Encodable {
        var id: Int64; var title: String; var note: String?; var deadline: String?
        var time_val: String?; var priority: String?; var badge: String?
        var linked_list_id: String?; var linked_list_type: String?; var workspaceId: String?
    }
    func create(_ t: AppTask) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        let body = CreateBody(id: ClientID.next(), title: t.title, note: t.note, deadline: t.deadline,
                               time_val: t.time, priority: t.priority?.rawValue, badge: t.badge,
                               linked_list_id: t.linkedListId, linked_list_type: t.linkedListId != nil ? "sublist" : nil,
                               workspaceId: t.workspaceId)
        return try await client.request("/tasks", method: "POST", body: body, as: R.self).task.toApp()
    }

    struct UpdateBody: Encodable {
        var title: String?; var note: String?; var checked: Bool?; var deadline: String?
        var time_val: String?; var priority: String?; var badge: String?
    }
    func update(id: String, _ patch: UpdateBody) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        return try await client.request("/tasks/\(id)", method: "PUT", body: patch, as: R.self).task.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/tasks/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §1.7 — move a task to another list/section. `PUT /api/tasks/:id/move`.
    struct MoveBody: Encodable { var listId: String?; var sectionId: String? }
    @discardableResult
    func move(id: String, toListId: String?, toSectionId: String?) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        return try await client.request("/tasks/\(id)/move", method: "PUT",
                                         body: MoveBody(listId: toListId, sectionId: toSectionId), as: R.self).task.toApp()
    }

    /// §1.2 — persist a new ordering of dashboard tasks. `PUT /api/tasks/reorder`.
    struct ReorderBody: Encodable { var orderedIds: [String] }
    func reorder(orderedIds: [String]) async throws {
        _ = try await client.request("/tasks/reorder", method: "PUT", body: ReorderBody(orderedIds: orderedIds), as: APIClient.EmptyResponse.self)
    }
}

struct ListsAPI {
    let client = APIClient.shared

    func list(workspaceId: String? = nil) async throws -> [AppList] {
        struct R: Decodable { var lists: [APIListDTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/lists", query: q, as: R.self).lists.map { $0.toApp() }
    }

    struct CreateBody: Encodable {
        var id: String; var name: String; var emoji: String?; var color: String?
        var isPublic: Bool?; var folderId: String?; var workspaceId: String?
    }
    func create(name: String, emoji: String?, color: String?, isPublic: Bool, folderId: String?, workspaceId: String?) async throws -> AppList {
        struct R: Decodable { var list: APIListDTO }
        let body = CreateBody(id: "list_\(ClientID.next())", name: name, emoji: emoji, color: color,
                               isPublic: isPublic, folderId: folderId, workspaceId: workspaceId)
        return try await client.request("/lists", method: "POST", body: body, as: R.self).list.toApp()
    }

    struct UpdateBody: Encodable {
        var name: String?; var emoji: String?; var color: String?; var subtitle: String?
        var isPublic: Bool?; var folderId: String?; var viewMode: String? = nil
    }
    func update(id: String, _ patch: UpdateBody) async throws -> AppList {
        struct R: Decodable { var list: APIListDTO }
        return try await client.request("/lists/\(id)", method: "PUT", body: patch, as: R.self).list.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/lists/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §1.6 — lists archived on the web; fetch/restore them here.
    func archived() async throws -> [AppList] {
        struct R: Decodable { var lists: [APIListDTO] }
        return try await client.request("/lists", query: ["archived": "true"], as: R.self).lists.map { $0.toApp() }
    }
    func unarchive(id: String) async throws {
        _ = try await client.request("/lists/\(id)/unarchive", method: "PUT", as: APIClient.EmptyResponse.self)
    }

    /// §1.2 — reorder sections within a list, or tasks within a section.
    struct ReorderBody: Encodable { var orderedIds: [String] }
    func reorderSections(listId: String, orderedIds: [String]) async throws {
        _ = try await client.request("/lists/\(listId)/sections/reorder", method: "PUT", body: ReorderBody(orderedIds: orderedIds), as: APIClient.EmptyResponse.self)
    }
    func reorderTasks(listId: String, sectionId: String, orderedIds: [String]) async throws {
        _ = try await client.request("/lists/\(listId)/sections/\(sectionId)/tasks/reorder", method: "PUT", body: ReorderBody(orderedIds: orderedIds), as: APIClient.EmptyResponse.self)
    }

    /// §1.3 — link an existing standalone list into a section as a `'link'`
    /// reference (distinct from `createSublist`'s owned child).
    struct LinkBody: Encodable { var targetListId: String }
    func linkList(listId: String, sectionId: String, parentTaskId: String, targetListId: String) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        return try await client.request("/lists/\(listId)/sections/\(sectionId)/tasks/link", method: "POST",
                                         query: ["taskId": parentTaskId], body: LinkBody(targetListId: targetListId), as: R.self).task.toApp()
    }

    struct ShareBody: Encodable { var shareEnabled: Bool; var password: String?; var expiresAt: String? }
    func setShare(id: String, enabled: Bool, password: String?, expiresAt: String?) async throws -> AppList {
        struct R: Decodable { var list: APIListDTO }
        return try await client.request("/lists/\(id)/share", method: "PUT",
                                         body: ShareBody(shareEnabled: enabled, password: password, expiresAt: expiresAt), as: R.self).list.toApp()
    }

    // Sections
    struct SectionBody: Encodable { var id: String?; var label: String; var emoji: String? }
    func addSection(listId: String, label: String, emoji: String?) async throws -> AppSection {
        struct R: Decodable { var section: APISectionDTO }
        return try await client.request("/lists/\(listId)/sections", method: "POST",
                                         body: SectionBody(id: nil, label: label, emoji: emoji), as: R.self).section.toApp(listName: nil)
    }

    func deleteSection(id: String) async throws {
        _ = try await client.request("/lists/sections/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    // Tasks nested inside a list section
    struct ListTaskBody: Encodable {
        var id: Int64; var title: String; var note: String?; var deadline: String?
        var time_val: String?; var priority: String?; var badge: String?
    }
    func addTask(listId: String, sectionId: String, task: AppTask) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        let body = ListTaskBody(id: ClientID.next(), title: task.title, note: task.note, deadline: task.deadline,
                                 time_val: task.time, priority: task.priority?.rawValue, badge: task.badge)
        return try await client.request("/lists/\(listId)/sections/\(sectionId)/tasks", method: "POST", body: body, as: R.self).task.toApp()
    }

    func updateTask(listId: String, taskId: String, _ patch: TasksAPI.UpdateBody) async throws -> AppTask {
        struct R: Decodable { var task: APITaskDTO }
        return try await client.request("/lists/\(listId)/tasks/\(taskId)", method: "PUT", body: patch, as: R.self).task.toApp()
    }

    func deleteTask(listId: String, taskId: String) async throws {
        _ = try await client.request("/lists/\(listId)/tasks/\(taskId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    struct SublistBody: Encodable { var name: String; var emoji: String? }
    func createSublist(listId: String, sectionId: String, parentTaskId: String, name: String, emoji: String?) async throws -> AppList {
        struct R: Decodable { var list: APIListDTO }
        return try await client.request("/lists/\(listId)/sections/\(sectionId)/tasks/sublist", method: "POST",
                                         query: ["taskId": parentTaskId], body: SublistBody(name: name, emoji: emoji), as: R.self).list.toApp()
    }
}

struct FoldersAPI {
    let client = APIClient.shared

    func list(workspaceId: String? = nil) async throws -> [AppFolder] {
        struct R: Decodable { var folders: [APIFolderDTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/folders", query: q, as: R.self).folders.map { $0.toApp() }
    }

    struct CreateBody: Encodable { var name: String; var emoji: String?; var color: String?; var isPublic: Bool?; var workspaceId: String? }
    func create(name: String, emoji: String?, color: String?, workspaceId: String?) async throws -> AppFolder {
        struct R: Decodable { var folder: APIFolderDTO }
        return try await client.request("/folders", method: "POST",
                                         body: CreateBody(name: name, emoji: emoji, color: color, isPublic: false, workspaceId: workspaceId), as: R.self).folder.toApp()
    }

    struct UpdateBody: Encodable {
        var name: String?; var emoji: String?; var color: String?; var position: Int?
        var isPublic: Bool?; var collapsed: Bool?
    }
    func update(id: String, _ patch: UpdateBody) async throws -> AppFolder {
        struct R: Decodable { var folder: APIFolderDTO }
        return try await client.request("/folders/\(id)", method: "PUT", body: patch, as: R.self).folder.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/folders/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §3 — move a folder (and its lists) into another workspace.
    struct WorkspaceBody: Encodable { var workspaceId: String? }
    func moveToWorkspace(id: String, workspaceId: String?) async throws {
        _ = try await client.request("/folders/\(id)/workspace", method: "PUT", body: WorkspaceBody(workspaceId: workspaceId), as: APIClient.EmptyResponse.self)
    }
}

struct WorkspacesAPI {
    let client = APIClient.shared

    func list() async throws -> [AppWorkspace] {
        struct R: Decodable { var workspaces: [APIWorkspaceDTO] }
        return try await client.request("/workspaces", as: R.self).workspaces.map { $0.toApp() }
    }

    struct CreateBody: Encodable { var name: String; var description: String?; var emoji: String?; var visibility: String }
    func create(name: String, description: String?, emoji: String?, visibility: String) async throws -> AppWorkspace {
        struct R: Decodable { var workspace: APIWorkspaceDTO }
        return try await client.request("/workspaces", method: "POST",
                                         body: CreateBody(name: name, description: description, emoji: emoji, visibility: visibility), as: R.self).workspace.toApp()
    }

    func addMember(workspaceId: String, username: String) async throws {
        struct Body: Encodable { var username: String }
        _ = try await client.request("/workspaces/\(workspaceId)/members", method: "POST", body: Body(username: username), as: APIClient.EmptyResponse.self)
    }

    /// §4.2 — remove a member. `DELETE /api/workspaces/:id/members/:userId`.
    func removeMember(workspaceId: String, userId: String) async throws {
        _ = try await client.request("/workspaces/\(workspaceId)/members/\(userId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §4.1 — update workspace metadata. `PUT /api/workspaces/:id`.
    struct UpdateBody: Encodable { var name: String?; var description: String?; var emoji: String?; var visibility: String? }
    @discardableResult
    func update(id: String, name: String?, description: String?, emoji: String?, visibility: String?) async throws -> AppWorkspace {
        struct R: Decodable { var workspace: APIWorkspaceDTO }
        return try await client.request("/workspaces/\(id)", method: "PUT",
                                         body: UpdateBody(name: name, description: description, emoji: emoji, visibility: visibility), as: R.self).workspace.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/workspaces/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}

struct MeetingsAPI {
    let client = APIClient.shared

    func list(from: String? = nil, to: String? = nil) async throws -> [AppMeeting] {
        struct R: Decodable { var meetings: [APIMeetingDTO] }
        var q: [String: String] = [:]
        if let from { q["from"] = from }
        if let to { q["to"] = to }
        return try await client.request("/meetings", query: q, as: R.self).meetings.map { $0.toApp() }
    }

    /// §2.1 recurrence rule shape the server expects on create (matches the
    /// `repeat: {freq, interval, count}` payload the assistant tool uses).
    struct RepeatBody: Encodable { var freq: String; var interval: Int; var count: Int }

    struct Body: Encodable {
        var id: String?; var title: String; var description: String?; var location: String?
        var date: String; var startTime: String?; var endTime: String?; var allDay: Bool; var color: String?
        var `repeat`: RepeatBody? = nil            // §2.1 — omitted for one-off meetings
        var inviteeUsernames: [String]? = nil      // §2.2 — omitted when no attendees
    }
    func create(_ m: AppMeeting, recurrence: MeetingRecurrence? = nil, inviteeUsernames: [String] = []) async throws -> AppMeeting {
        struct R: Decodable { var meeting: APIMeetingDTO }
        let body = Body(id: nil, title: m.title, description: m.description, location: m.location,
                         date: m.date, startTime: m.startTime, endTime: m.endTime, allDay: m.allDay, color: m.colorHex,
                         repeat: recurrence.map { RepeatBody(freq: $0.freq.rawValue, interval: $0.interval, count: $0.count) },
                         inviteeUsernames: inviteeUsernames.isEmpty ? nil : inviteeUsernames)
        return try await client.request("/meetings", method: "POST", body: body, as: R.self).meeting.toApp()
    }

    func update(id: String, _ m: AppMeeting) async throws -> AppMeeting {
        struct R: Decodable { var meeting: APIMeetingDTO }
        let body = Body(id: nil, title: m.title, description: m.description, location: m.location,
                         date: m.date, startTime: m.startTime, endTime: m.endTime, allDay: m.allDay, color: m.colorHex)
        return try await client.request("/meetings/\(id)", method: "PUT", body: body, as: R.self).meeting.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/meetings/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §2.2 — leave a meeting you were invited to (removes yourself as an
    /// attendee). `POST /api/meetings/:id/leave`.
    func leave(id: String) async throws {
        _ = try await client.request("/meetings/\(id)/leave", method: "POST", as: APIClient.EmptyResponse.self)
    }
}
