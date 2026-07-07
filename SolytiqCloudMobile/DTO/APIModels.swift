import Foundation

// MARK: - Wire DTOs
//
// These mirror the JSON actually emitted by github.com/skiptix/solytiq-cloud
// (`backend/src/routes/*.ts`, `sanitize*()` helpers) — camelCase, so no
// custom CodingKeys are needed for the response side. Request bodies below
// match the `req.body as {...}` shapes read on the server for each route.

struct APIUserDTO: Codable {
    var id: String
    var username: String
    var email: String?
    var fullName: String?
    var profileImage: String?
    var isAdmin: Bool
    var createdAt: String?
    var totpEnabled: Bool

    func toApp() -> AppUser {
        AppUser(id: id, username: username, email: email, fullName: fullName,
                 profileImageBase64: profileImage, isAdmin: isAdmin, totpEnabled: totpEnabled)
    }
}

struct APIAuthResponse: Codable {
    var token: String?
    var user: APIUserDTO?
    var requires2FA: Bool?
    var pendingToken: String?
}

struct APITaskDTO: Codable {
    var id: IntOrString
    var creatorId: String?
    var title: String
    var note: String?
    var checked: Bool
    var deadline: String?
    var time: String?
    var priority: String?
    var badge: String?
    var source: String?
    var listId: IntOrString?
    var sectionId: IntOrString?
    var workspaceId: String?
    var position: Int
    var createdAt: String?
    var updatedAt: String?
    var linkedListId: String?
    var linkedListType: String?

    func toApp(listName: String? = nil) -> AppTask {
        AppTask(id: id.stringValue, title: title, note: note, checked: checked,
                 deadline: deadline, time: time, priority: priority.flatMap(Priority.init(rawValue:)),
                 badge: badge, listId: listId?.stringValue, sectionId: sectionId?.stringValue,
                 workspaceId: workspaceId, position: position, subItems: [],
                 linkedListId: linkedListId,
                 createdAt: ServerDate.parse(createdAt) ?? .now, updatedAt: ServerDate.parse(updatedAt) ?? .now,
                 listName: listName)
    }
}

struct APISectionDTO: Codable {
    var id: IntOrString
    var listId: IntOrString?
    var label: String
    var emoji: String?
    var position: Int
    var tasks: [APITaskDTO]

    func toApp(listName: String?) -> AppSection {
        AppSection(id: id.stringValue, listId: listId?.stringValue ?? "", label: label, emoji: emoji,
                    position: position, tasks: tasks.map { $0.toApp(listName: listName) })
    }
}

struct APIListDTO: Codable {
    var id: IntOrString
    var name: String
    var emoji: String?
    var color: String?
    var subtitle: String?
    var isPublic: Bool
    var folderId: IntOrString?
    var workspaceId: String?
    var position: Int
    var shareEnabled: Bool?
    var shareToken: String?

    var sections: [APISectionDTO]?

    func toApp() -> AppList {
        AppList(id: id.stringValue, name: name, emoji: emoji, colorHex: color ?? "#5e4dbb",
                 subtitle: subtitle, folderId: folderId?.stringValue, workspaceId: workspaceId,
                 isPublic: isPublic, shareEnabled: shareEnabled ?? false, shareToken: shareToken,
                 position: position, sections: (sections ?? []).map { $0.toApp(listName: name) })
    }
}

struct APIFolderDTO: Codable {
    var id: IntOrString
    var name: String
    var emoji: String?
    var color: String?
    var position: Int
    var isPublic: Bool?

    func toApp() -> AppFolder {
        AppFolder(id: id.stringValue, name: name, emoji: emoji, colorHex: color ?? "#10B981", position: position)
    }
}

struct APIWorkspaceMemberDTO: Codable {
    var userId: String?
    var username: String
    var fullName: String?
    var role: String
}

struct APIWorkspaceDTO: Codable {
    var id: String
    var name: String
    var emoji: String?
    var description: String?
    var visibility: String
    var role: String?
    var memberCount: Int?
    var members: [APIWorkspaceMemberDTO]?

    func toApp() -> AppWorkspace {
        AppWorkspace(id: id, name: name, emoji: emoji, description: description,
                      visibility: visibility, role: role ?? "member",
                      members: (members ?? []).map {
                          AppWorkspaceMember(id: $0.userId ?? $0.username, username: $0.username, fullName: $0.fullName, role: $0.role)
                      })
    }
}

struct APIMeetingDTO: Codable {
    var id: IntOrString
    var title: String
    var description: String?
    var location: String?
    var date: String
    var startTime: String?
    var endTime: String?
    var allDay: Bool
    var color: String?

    func toApp() -> AppMeeting {
        AppMeeting(id: id.stringValue, title: title, date: date, allDay: allDay, startTime: startTime,
                    endTime: endTime, location: location, description: description, colorHex: color ?? "#3b82f6",
                    workspaceId: nil)
    }
}

struct APIMilestoneDTO: Codable {
    var id: IntOrString
    var timelineId: IntOrString?
    var title: String
    var description: String?
    var date: String?
    var time: String?
    var status: String
    var emoji: String?
    var color: String?
    var position: Int?

    func toApp() -> AppMilestone {
        AppMilestone(id: id.stringValue, title: title, summary: description, date: date, time: time,
                      status: MilestoneStatus(rawValue: status) ?? .upcoming, emoji: emoji, colorHex: color)
    }
}

struct APITimelineDTO: Codable {
    var id: IntOrString
    var name: String
    var emoji: String?
    var color: String?
    var subtitle: String?
    var isPublic: Bool
    var folderId: IntOrString?
    var workspaceId: String?
    var shareEnabled: Bool?
    var shareToken: String?
    var shareHasPassword: Bool?
    var shareExpiresAt: String?
    var milestones: [APIMilestoneDTO]?

    func toApp() -> AppTimeline {
        AppTimeline(id: id.stringValue, name: name, emoji: emoji, subtitle: subtitle, colorHex: color ?? "#5e4dbb",
                     isPublic: isPublic, shareEnabled: shareEnabled ?? false, shareToken: shareToken,
                     shareHasPassword: shareHasPassword ?? false, shareExpiresAt: shareExpiresAt,
                     folderId: folderId?.stringValue, workspaceId: workspaceId,
                     milestones: (milestones ?? []).map { $0.toApp() })
    }
}

struct APIFileDTO: Codable {
    var id: String
    var name: String
    var mimeType: String
    var size: Int
    var isPublic: Bool
    var hasPassword: Bool
    var expiresAt: String?
    var shareToken: String?
    var shareUrl: String?
    var createdAt: String?

    func toApp() -> AppFileItem {
        AppFileItem(id: id, name: name, mimeType: mimeType, size: size, isPublic: isPublic,
                     createdAt: ServerDate.parse(createdAt) ?? .now, shareUrl: shareUrl,
                     hasPassword: hasPassword, expiresAt: expiresAt)
    }
}

struct APIChatMessageDTO: Codable {
    var id: IntOrString?
    var role: String
    var content: String
}

/// The backend mixes numeric (`BIGINT` task/list ids) and string (`UUID`)
/// primary keys across tables; this lets one Codable model handle both
/// without the app needing to know which table a given id came from.
enum IntOrString: Codable, Hashable {
    case int(Int64)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let i = try? container.decode(Int64.self) { self = .int(i); return }
        let s = try container.decode(String.self)
        self = .string(s)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .int(let i): try container.encode(i)
        case .string(let s): try container.encode(s)
        }
    }

    var stringValue: String {
        switch self {
        case .int(let i): return String(i)
        case .string(let s): return s
        }
    }
}

enum ServerDate {
    static func parse(_ str: String?) -> Date? {
        guard let str else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: str) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: str)
    }
}

/// Generates a client-side id the same way the web/iOS prototype does
/// (`Date.now()` at millisecond resolution, widened so concurrent creates on
/// one device never collide).
enum ClientID {
    static func next() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000) * 1000 + Int64.random(in: 0..<1000)
    }
}
