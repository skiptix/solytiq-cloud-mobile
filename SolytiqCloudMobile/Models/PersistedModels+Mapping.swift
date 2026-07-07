import Foundation

// MARK: - SwiftData model → domain struct mapping (local mode only).

extension PTask {
    func toApp(listName: String? = nil) -> AppTask {
        AppTask(id: id, title: title, note: note, checked: checked, deadline: deadline, time: time,
                 priority: priorityRaw.flatMap(Priority.init(rawValue:)), badge: badge,
                 listId: section?.list?.id, sectionId: section?.id, workspaceId: nil, position: position,
                 subItems: subItems, linkedListId: linkedListId, createdAt: createdAt, updatedAt: updatedAt,
                 listName: listName)
    }
}

extension PSection {
    func toApp() -> AppSection {
        AppSection(id: id, listId: list?.id ?? "", label: label, emoji: emoji, position: position,
                    tasks: tasks.sorted { $0.position < $1.position }.map { $0.toApp() })
    }
}

extension PList {
    func toApp() -> AppList {
        AppList(id: id, name: name, emoji: emoji, colorHex: colorHex, subtitle: subtitle, folderId: folderId,
                 workspaceId: nil, isPublic: isPublic, shareEnabled: false, shareToken: nil, position: position,
                 sections: sections.sorted { $0.position < $1.position }.map { $0.toApp() })
    }
}

extension PFolder {
    func toApp() -> AppFolder {
        AppFolder(id: id, name: name, emoji: emoji, colorHex: colorHex, position: position)
    }
}

extension PMeeting {
    func toApp() -> AppMeeting {
        AppMeeting(id: id, title: title, date: date, allDay: allDay, startTime: startTime, endTime: endTime,
                    location: location, description: note, colorHex: colorHex, workspaceId: nil)
    }
}

extension PTimeline {
    func toApp() -> AppTimeline {
        AppTimeline(id: id, name: name, emoji: emoji, subtitle: subtitle, colorHex: colorHex, isPublic: false,
                     shareEnabled: false, shareToken: nil, shareHasPassword: false, shareExpiresAt: nil,
                     folderId: folderId, workspaceId: nil, milestones: milestones)
    }
}
