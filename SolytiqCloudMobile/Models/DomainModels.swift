import Foundation

// MARK: - Domain models
//
// Plain value types the UI layer works with, regardless of whether the data
// actually lives in the on-device SwiftData store (local mode) or came back
// from a self-hosted Solytiq Cloud server (server mode). Repositories are
// responsible for mapping SwiftData models / API DTOs into these.

enum Priority: String, Codable, CaseIterable, Identifiable, Hashable {
    case high = "High", medium = "Medium", low = "Low"
    var id: String { rawValue }
}

struct AppSubItem: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var checked: Bool
    var position: Int
}

struct AppTask: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var note: String?
    var checked: Bool
    var deadline: String?      // yyyy-MM-dd
    var time: String?          // "2:00 PM" style label
    var priority: Priority?
    var badge: String?
    var listId: String?
    var sectionId: String?
    var workspaceId: String?
    var position: Int
    var subItems: [AppSubItem]
    var linkedListId: String?
    /// `"sublist"` (a child list owned by this task) vs `"link"` (a reference to
    /// an existing standalone list). Nil when `linkedListId` is nil. — §1.3
    var linkedListType: String?
    var createdAt: Date
    var updatedAt: Date
    /// Set server-side when `checked` flips true; cleared when it flips back.
    /// Read-only on the client, used for the completion strip and Gantt bars. — §1.4
    var completedAt: Date?

    var listName: String?      // populated for cross-list views (Dashboard/Calendar)

    init(id: String = UUID().uuidString, title: String, note: String? = nil, checked: Bool = false,
         deadline: String? = nil, time: String? = nil, priority: Priority? = nil, badge: String? = nil,
         listId: String? = nil, sectionId: String? = nil, workspaceId: String? = nil, position: Int = 0,
         subItems: [AppSubItem] = [], linkedListId: String? = nil, linkedListType: String? = nil,
         createdAt: Date = .now, updatedAt: Date = .now, completedAt: Date? = nil,
         listName: String? = nil) {
        self.id = id; self.title = title; self.note = note; self.checked = checked
        self.deadline = deadline; self.time = time; self.priority = priority; self.badge = badge
        self.listId = listId; self.sectionId = sectionId; self.workspaceId = workspaceId; self.position = position
        self.subItems = subItems; self.linkedListId = linkedListId; self.linkedListType = linkedListType
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.completedAt = completedAt
        self.listName = listName
    }
}

/// The three ways a list can render its sections/tasks (persisted server-side
/// as `lists.view_mode`). — §1.1
enum ListViewMode: String, Codable, CaseIterable, Hashable, Identifiable {
    case list, kanban, timeline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .list: return "List"
        case .kanban: return "Kanban"
        case .timeline: return "Timeline"
        }
    }
    var symbol: String {
        switch self {
        case .list: return "list.bullet"
        case .kanban: return "rectangle.split.3x1"
        case .timeline: return "chart.bar.xaxis"
        }
    }
}

struct AppSection: Identifiable, Codable, Hashable {
    var id: String
    var listId: String
    var label: String
    var emoji: String?
    var position: Int
    var tasks: [AppTask]
}

struct AppList: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var emoji: String?
    var colorHex: String
    var subtitle: String?
    var folderId: String?
    var workspaceId: String?
    var isPublic: Bool
    var shareEnabled: Bool
    var shareToken: String?
    var position: Int
    var sections: [AppSection]
    /// `"list" | "kanban" | "timeline"` — persisted view mode. — §1.1
    var viewMode: String = ListViewMode.list.rawValue
    /// Archived lists are hidden from the normal index; restore via unarchive. — §1.6
    var isArchived: Bool = false

    var mode: ListViewMode { ListViewMode(rawValue: viewMode) ?? .list }

    var totalTasks: Int { sections.reduce(0) { $0 + $1.tasks.count } }
    var doneTasks: Int { sections.reduce(0) { $0 + $1.tasks.filter(\.checked).count } }
    var progress: Double { totalTasks == 0 ? 0 : Double(doneTasks) / Double(totalTasks) }
}

struct AppFolder: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var emoji: String?
    var colorHex: String
    var position: Int
    /// §3 — folder visibility / collapse state / owning workspace.
    var isPublic: Bool = false
    var collapsed: Bool = false
    var workspaceId: String? = nil
}

struct AppMeetingAttendee: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var fullName: String?
}

struct AppMeeting: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var date: String            // yyyy-MM-dd
    var allDay: Bool
    var startTime: String?
    var endTime: String?
    var location: String?
    var description: String?
    var colorHex: String
    var workspaceId: String?
    /// §2.1 — non-nil when this occurrence belongs to a repeating series.
    var recurrenceId: String? = nil
    /// §2.2 — user id of the organizer (nil when unknown / self).
    var organizerId: String? = nil
    var attendees: [AppMeetingAttendee] = []
}

/// §2.1 — a recurrence rule for creating a repeating meeting series in one call.
struct MeetingRecurrence: Hashable {
    enum Freq: String, CaseIterable, Identifiable, Hashable {
        case daily, weekly, monthly, yearly
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    var freq: Freq
    var interval: Int = 1
    var count: Int          // total occurrences including the first (2–104)
}

enum MilestoneStatus: String, Codable, CaseIterable, Hashable { case done, inProgress = "in-progress", upcoming }

struct AppMilestone: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var summary: String?
    var date: String?
    var time: String?
    var status: MilestoneStatus
    var emoji: String?
    var colorHex: String?
}

struct AppTimeline: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var emoji: String?
    var subtitle: String?
    var colorHex: String
    var isPublic: Bool
    var shareEnabled: Bool
    var shareToken: String?
    var shareHasPassword: Bool
    var shareExpiresAt: String?
    var folderId: String?
    var workspaceId: String?
    var milestones: [AppMilestone]
}

enum TrashKind: String, Codable, Hashable { case task, list, folder, timeline, milestone, markdownList }

struct AppTrashEntry: Identifiable, Codable, Hashable {
    var id: String
    var kind: TrashKind
    var title: String
    var deletedAt: Date
    var payload: Data?          // opaque serialized snapshot for restore
}

struct AppWorkspaceMember: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var fullName: String?
    var role: String
}

struct AppWorkspace: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var emoji: String?
    var description: String?
    var visibility: String
    var role: String
    var members: [AppWorkspaceMember]
}

struct AppFileItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var mimeType: String
    var size: Int
    var isPublic: Bool
    var createdAt: Date
    var shareUrl: String?
    var hasPassword: Bool
    var expiresAt: String?
}

/// §10 — one node in an automation's graph (a trigger or an action).
struct AppAutomationNode: Identifiable, Codable, Hashable {
    var id: String
    var type: String
    var params: [String: JSONValue]

    init(id: String = UUID().uuidString, type: String, params: [String: JSONValue] = [:]) {
        self.id = id; self.type = type; self.params = params
    }
}

/// §10 — an automation: an ordered graph of one trigger followed by N actions.
struct AppAutomation: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var enabled: Bool
    var graph: [AppAutomationNode]

    var trigger: AppAutomationNode? { graph.first }
    var actions: [AppAutomationNode] { Array(graph.dropFirst()) }
}

/// §10 — a schema for a node type, used to render its param form.
struct AppAutomationNodeType: Identifiable, Codable, Hashable {
    struct Param: Codable, Hashable {
        var key: String
        var label: String?
        var type: String?          // "string" | "number" | "boolean" | "code" | "isListId" | …
        var options: [String]?
    }
    var id: String                 // the node `type`
    var label: String
    var category: String?          // "trigger" | "action"
    var params: [Param]

    var isTrigger: Bool { category == "trigger" }
}

/// §10 — one run of an automation (test or live).
struct AppAutomationRun: Identifiable, Codable, Hashable {
    struct Step: Codable, Hashable {
        var nodeId: String?
        var type: String?
        var status: String?
        var input: JSONValue?
        var output: JSONValue?
        var error: String?
    }
    var id: String
    var status: String
    var isTest: Bool
    var error: String?
    var steps: [Step]
    var createdAt: Date?
}

/// §9 — a free-form markdown document (`markdown_lists`). Server mode only.
struct AppMarkdownList: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var content: String
    var emoji: String?
    var folderId: String?
    var workspaceId: String?
    var isPublic: Bool = false
    var shareEnabled: Bool = false
    var shareToken: String?
    var updatedAt: Date = .now
}

/// A server-side snapshot of a list's or timeline's full structure that can
/// be materialized into a fresh copy at any time. Server mode only.
struct AppTemplate: Identifiable, Codable, Hashable {
    enum Kind: String, Codable { case list, timeline }

    var id: String
    var type: Kind
    var name: String
    var description: String?
    var emoji: String?
    var colorHex: String
    /// Visible read-only to every other user of the instance (a public
    /// toggle, not a share link).
    var isShared: Bool
    var isOwner: Bool
    var ownerName: String?
    var sectionCount: Int
    var taskCount: Int
    var milestoneCount: Int
    var createdAt: Date
}

struct AppUser: Identifiable, Codable, Hashable {
    var id: String
    var username: String
    var email: String?
    var fullName: String?
    var profileImageBase64: String?
    var isAdmin: Bool
    var totpEnabled: Bool
}

struct AppChatMessage: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var role: String   // "user" | "assistant"
    var content: String
}

/// §17 — one of this account's mobile app logins (`mobile_connections`).
struct AppMobileConnection: Identifiable, Codable, Hashable {
    var id: String
    var deviceName: String?
    var deviceModel: String?
    var osVersion: String?
    var appVersion: String?
    var lastSeenAt: Date?
    var createdAt: Date?
    /// True when this row is the device the app is currently running on.
    var isCurrent: Bool = false
}

/// §14 — an external agent / personal-access token connected to the account
/// (the token half of web's "Claude MCP" settings section).
struct AppConnectedToken: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var clientName: String?
    var createdAt: Date?
    var lastUsedAt: Date?
}

/// §11 — an installable instance-wide app from the App Directory, with its
/// current installed state (used to gate GPS/Automations/MCP surfaces).
struct AppInstalledApp: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var description: String?
    var installed: Bool
}

/// §1.5 — a file attached to a task, either uploaded directly or linked from
/// an existing `shared_files` row.
struct AppTaskAttachment: Identifiable, Codable, Hashable {
    var id: String
    var taskId: String
    /// `"upload"` (bytes stored against the task) vs `"linked"` (a reference to
    /// a file that also lives in Files).
    var attachmentType: String
    var fileName: String
    var mimeType: String
    var size: Int
    var sharedFileId: String?

    var isLinked: Bool { attachmentType == "linked" }
}

/// §15 — one cross-entity global-search hit.
struct AppSearchResult: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case task, list, timeline, milestone, meeting, workspace, file, folder
        var symbol: String {
            switch self {
            case .task: return "checkmark.circle"
            case .list: return "list.bullet"
            case .timeline: return "chart.bar.xaxis"
            case .milestone: return "flag"
            case .meeting: return "calendar"
            case .workspace: return "square.stack.3d.up"
            case .file: return "doc"
            case .folder: return "folder"
            }
        }
    }
    var id: String
    var kind: Kind
    var title: String
    var subtitle: String?
    /// For a task/milestone hit, the id of the parent list/timeline to open.
    var parentId: String?
}

// MARK: - Small date helpers shared by every screen

enum SCDate {
    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f
    }()

    static func iso(_ date: Date) -> String { isoFormatter.string(from: date) }
    static func date(fromISO iso: String) -> Date? { isoFormatter.date(from: String(iso.prefix(10))) }
    static func todayISO() -> String { iso(Date()) }

    static func addDays(_ n: Int, from date: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: n, to: date) ?? date
    }

    /// "Today" / "Tomorrow" / "Overdue" / "Jun 12" — matches `friendlyDate()` in components.jsx.
    static func friendly(_ iso: String?) -> (label: String, overdue: Bool)? {
        guard let iso, let date = date(fromISO: iso) else { return nil }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let startOfDate = cal.startOfDay(for: date)
        if startOfDate == startOfToday { return ("Today", false) }
        if startOfDate == cal.date(byAdding: .day, value: 1, to: startOfToday) { return ("Tomorrow", false) }
        if startOfDate < startOfToday { return ("Overdue", true) }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return (f.string(from: date), false)
    }

    static func to12h(_ time24: String?) -> String {
        guard let time24, let colonIdx = time24.firstIndex(of: ":") else { return "" }
        let hourStr = time24[time24.startIndex..<colonIdx]
        let rest = time24[time24.index(after: colonIdx)...]
        guard var hour = Int(hourStr) else { return time24 }
        let minute = String(rest.prefix(2))
        let ampm = hour >= 12 ? "PM" : "AM"
        hour = hour % 12
        if hour == 0 { hour = 12 }
        return "\(hour):\(minute) \(ampm)"
    }
}
