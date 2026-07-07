import Foundation
import SwiftData

// MARK: - SwiftData schema for "On This Phone" (local) mode.
//
// Local mode is intentionally single-user with no workspace concept — every
// row implicitly belongs to the one person using the device. Soft-delete
// mirrors the self-hosted backend's own trash model (isTrashed/trashedAt)
// so Trash/Restore behaves identically in both modes; a 30-day purge job
// runs at launch (see `TrashRepository`).

@Model
final class PFolder {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String?
    var colorHex: String
    var position: Int
    var isTrashed: Bool
    var trashedAt: Date?

    init(id: String = UUID().uuidString, name: String, emoji: String? = nil, colorHex: String = "#10B981",
         position: Int = 0, isTrashed: Bool = false, trashedAt: Date? = nil) {
        self.id = id; self.name = name; self.emoji = emoji; self.colorHex = colorHex
        self.position = position; self.isTrashed = isTrashed; self.trashedAt = trashedAt
    }
}

@Model
final class PList {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String?
    var colorHex: String
    var subtitle: String?
    var folderId: String?
    var position: Int
    var isPublic: Bool
    var isTrashed: Bool
    var trashedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PSection.list)
    var sections: [PSection] = []

    init(id: String = UUID().uuidString, name: String, emoji: String? = nil, colorHex: String = "#5e4dbb",
         subtitle: String? = nil, folderId: String? = nil, position: Int = 0, isPublic: Bool = false,
         isTrashed: Bool = false, trashedAt: Date? = nil) {
        self.id = id; self.name = name; self.emoji = emoji; self.colorHex = colorHex
        self.subtitle = subtitle; self.folderId = folderId; self.position = position
        self.isPublic = isPublic; self.isTrashed = isTrashed; self.trashedAt = trashedAt
    }
}

@Model
final class PSection {
    @Attribute(.unique) var id: String
    var label: String
    var emoji: String?
    var position: Int
    var list: PList?

    @Relationship(deleteRule: .cascade, inverse: \PTask.section)
    var tasks: [PTask] = []

    init(id: String = UUID().uuidString, label: String, emoji: String? = nil, position: Int = 0) {
        self.id = id; self.label = label; self.emoji = emoji; self.position = position
    }
}

@Model
final class PTask {
    @Attribute(.unique) var id: String
    var title: String
    var note: String?
    var checked: Bool
    var deadline: String?
    var time: String?
    var priorityRaw: String?
    var badge: String?
    var position: Int
    var subItems: [AppSubItem]
    var linkedListId: String?
    var createdAt: Date
    var updatedAt: Date
    var isTrashed: Bool
    var trashedAt: Date?
    var section: PSection?

    init(id: String = UUID().uuidString, title: String, note: String? = nil, checked: Bool = false,
         deadline: String? = nil, time: String? = nil, priorityRaw: String? = nil, badge: String? = nil,
         position: Int = 0, subItems: [AppSubItem] = [], linkedListId: String? = nil,
         createdAt: Date = .now, updatedAt: Date = .now, isTrashed: Bool = false, trashedAt: Date? = nil) {
        self.id = id; self.title = title; self.note = note; self.checked = checked
        self.deadline = deadline; self.time = time; self.priorityRaw = priorityRaw; self.badge = badge
        self.position = position; self.subItems = subItems; self.linkedListId = linkedListId
        self.createdAt = createdAt; self.updatedAt = updatedAt
        self.isTrashed = isTrashed; self.trashedAt = trashedAt
    }
}

@Model
final class PMeeting {
    @Attribute(.unique) var id: String
    var title: String
    var date: String
    var allDay: Bool
    var startTime: String?
    var endTime: String?
    var location: String?
    var note: String?
    var colorHex: String

    init(id: String = UUID().uuidString, title: String, date: String, allDay: Bool = false,
         startTime: String? = nil, endTime: String? = nil, location: String? = nil, note: String? = nil,
         colorHex: String = "#3b82f6") {
        self.id = id; self.title = title; self.date = date; self.allDay = allDay
        self.startTime = startTime; self.endTime = endTime; self.location = location
        self.note = note; self.colorHex = colorHex
    }
}

@Model
final class PTimeline {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String?
    var subtitle: String?
    var colorHex: String
    var folderId: String?
    var milestones: [AppMilestone]
    var isTrashed: Bool
    var trashedAt: Date?

    init(id: String = UUID().uuidString, name: String, emoji: String? = nil, subtitle: String? = nil,
         colorHex: String = "#5e4dbb", folderId: String? = nil, milestones: [AppMilestone] = [],
         isTrashed: Bool = false, trashedAt: Date? = nil) {
        self.id = id; self.name = name; self.emoji = emoji; self.subtitle = subtitle
        self.colorHex = colorHex; self.folderId = folderId; self.milestones = milestones
        self.isTrashed = isTrashed; self.trashedAt = trashedAt
    }
}

/// Local-mode profile — deliberately just a photo + display name (no
/// account, no email — those are server-only concepts per the design spec).
@Model
final class PProfile {
    @Attribute(.unique) var id: String
    var username: String
    var profileImageBase64: String?
    var appearanceShapeRaw: String
    var appearanceDensityRaw: String
    var accentPaletteIndex: Int

    init(id: String = "local-profile", username: String = "You", profileImageBase64: String? = nil,
         appearanceShapeRaw: String = AppearanceShape.rounded.rawValue,
         appearanceDensityRaw: String = AppearanceDensity.regular.rawValue,
         accentPaletteIndex: Int = 0) {
        self.id = id; self.username = username; self.profileImageBase64 = profileImageBase64
        self.appearanceShapeRaw = appearanceShapeRaw; self.appearanceDensityRaw = appearanceDensityRaw
        self.accentPaletteIndex = accentPaletteIndex
    }
}

enum LocalSchema {
    static var models: [any PersistentModel.Type] {
        [PFolder.self, PList.self, PSection.self, PTask.self, PMeeting.self, PTimeline.self, PProfile.self]
    }
}
