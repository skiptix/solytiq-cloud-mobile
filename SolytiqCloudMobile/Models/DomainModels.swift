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
    var createdAt: Date
    var updatedAt: Date

    var listName: String?      // populated for cross-list views (Dashboard/Calendar)

    init(id: String = UUID().uuidString, title: String, note: String? = nil, checked: Bool = false,
         deadline: String? = nil, time: String? = nil, priority: Priority? = nil, badge: String? = nil,
         listId: String? = nil, sectionId: String? = nil, workspaceId: String? = nil, position: Int = 0,
         subItems: [AppSubItem] = [], linkedListId: String? = nil, createdAt: Date = .now, updatedAt: Date = .now,
         listName: String? = nil) {
        self.id = id; self.title = title; self.note = note; self.checked = checked
        self.deadline = deadline; self.time = time; self.priority = priority; self.badge = badge
        self.listId = listId; self.sectionId = sectionId; self.workspaceId = workspaceId; self.position = position
        self.subItems = subItems; self.linkedListId = linkedListId
        self.createdAt = createdAt; self.updatedAt = updatedAt; self.listName = listName
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

enum TrashKind: String, Codable, Hashable { case task, list, folder, timeline, milestone }

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
