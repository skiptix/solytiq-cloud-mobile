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

    struct UpdateBody: Encodable { var name: String?; var emoji: String?; var color: String?; var subtitle: String?; var isPublic: Bool?; var folderId: String? }
    func update(id: String, _ patch: UpdateBody) async throws -> AppList {
        struct R: Decodable { var list: APIListDTO }
        return try await client.request("/lists/\(id)", method: "PUT", body: patch, as: R.self).list.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/lists/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
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

    struct UpdateBody: Encodable { var name: String?; var emoji: String?; var color: String?; var position: Int? }
    func update(id: String, _ patch: UpdateBody) async throws -> AppFolder {
        struct R: Decodable { var folder: APIFolderDTO }
        return try await client.request("/folders/\(id)", method: "PUT", body: patch, as: R.self).folder.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/folders/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
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

    struct Body: Encodable {
        var id: String?; var title: String; var description: String?; var location: String?
        var date: String; var startTime: String?; var endTime: String?; var allDay: Bool; var color: String?
    }
    func create(_ m: AppMeeting) async throws -> AppMeeting {
        struct R: Decodable { var meeting: APIMeetingDTO }
        let body = Body(id: nil, title: m.title, description: m.description, location: m.location,
                         date: m.date, startTime: m.startTime, endTime: m.endTime, allDay: m.allDay, color: m.colorHex)
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
}
