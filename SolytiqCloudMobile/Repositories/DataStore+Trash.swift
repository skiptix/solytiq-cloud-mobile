import Foundation
import SwiftData

// MARK: - Trash
//
// Local mode: trashed rows are ordinary PTask/PList/PFolder/PTimeline rows
// with `isTrashed = true` — the entry id *is* the item id, restore just
// flips the flag. Server mode: the backend keeps trash in separate tables
// with their own row id (`entryId`), returned alongside the original item.

extension DataStore {
    func trashEntries() async -> [AppTrashEntry] {
        if isServer {
            async let tasks = (try? trashAPI.tasks()) ?? []
            async let lists = (try? trashAPI.lists()) ?? []
            async let folders = (try? trashAPI.folders()) ?? []
            async let timelines = (try? trashAPI.timelines()) ?? []
            async let milestones = (try? trashAPI.milestones()) ?? []
            async let markdowns = (try? trashAPI.markdownListsTrash()) ?? []
            var out: [AppTrashEntry] = []
            out += (await tasks).map { AppTrashEntry(id: $0.entryId, kind: .task, title: $0.task.title, deletedAt: $0.deletedAt) }
            out += (await lists).map { AppTrashEntry(id: $0.entryId, kind: .list, title: $0.list.name, deletedAt: $0.deletedAt) }
            out += (await folders).map { AppTrashEntry(id: $0.entryId, kind: .folder, title: $0.folder.name, deletedAt: $0.deletedAt) }
            out += (await timelines).map { AppTrashEntry(id: $0.entryId, kind: .timeline, title: $0.timeline.name, deletedAt: $0.deletedAt) }
            out += (await milestones).map { AppTrashEntry(id: $0.entryId, kind: .milestone, title: $0.milestone.title, deletedAt: $0.deletedAt) }
            out += (await markdowns).map { AppTrashEntry(id: $0.entryId, kind: .markdownList, title: $0.doc.title, deletedAt: $0.deletedAt) }
            return out.sorted { $0.deletedAt > $1.deletedAt }
        }
        var out: [AppTrashEntry] = []
        out += fetchAll(PTask.self).filter(\.isTrashed).map { AppTrashEntry(id: $0.id, kind: .task, title: $0.title, deletedAt: $0.trashedAt ?? .now) }
        out += fetchAll(PList.self).filter(\.isTrashed).map { AppTrashEntry(id: $0.id, kind: .list, title: $0.name, deletedAt: $0.trashedAt ?? .now) }
        out += fetchAll(PFolder.self).filter(\.isTrashed).map { AppTrashEntry(id: $0.id, kind: .folder, title: $0.name, deletedAt: $0.trashedAt ?? .now) }
        out += fetchAll(PTimeline.self).filter(\.isTrashed).map { AppTrashEntry(id: $0.id, kind: .timeline, title: $0.name, deletedAt: $0.trashedAt ?? .now) }
        return out.sorted { $0.deletedAt > $1.deletedAt }
    }

    func restore(_ entry: AppTrashEntry) async {
        if isServer {
            switch entry.kind {
            case .task: try? await trashAPI.restoreTask(entryId: entry.id)
            case .list: try? await trashAPI.restoreList(entryId: entry.id)
            case .folder: try? await trashAPI.restoreFolder(entryId: entry.id)
            case .timeline: try? await trashAPI.restoreTimeline(entryId: entry.id)
            case .milestone: try? await trashAPI.restoreMilestone(entryId: entry.id)
            case .markdownList: try? await trashAPI.restoreMarkdownList(entryId: entry.id)
            }
            // The restored item comes back through the delta pull.
            sync.noteMutationSettled()
            return
        }
        switch entry.kind {
        case .task:
            if let p = fetchAll(PTask.self).first(where: { $0.id == entry.id }) { p.isTrashed = false; p.trashedAt = nil }
        case .list:
            if let p = fetchAll(PList.self).first(where: { $0.id == entry.id }) { p.isTrashed = false; p.trashedAt = nil }
        case .folder:
            if let p = fetchAll(PFolder.self).first(where: { $0.id == entry.id }) { p.isTrashed = false; p.trashedAt = nil }
        case .timeline:
            if let p = fetchAll(PTimeline.self).first(where: { $0.id == entry.id }) { p.isTrashed = false; p.trashedAt = nil }
        case .milestone, .markdownList: break
        }
        save()
    }

    func deleteForever(_ entry: AppTrashEntry) async {
        if isServer {
            switch entry.kind {
            case .task: try? await trashAPI.deleteTaskForever(entryId: entry.id)
            case .list: try? await trashAPI.deleteListForever(entryId: entry.id)
            case .folder: try? await trashAPI.deleteFolderForever(entryId: entry.id)
            case .timeline: try? await trashAPI.deleteTimelineForever(entryId: entry.id)
            case .milestone: try? await trashAPI.deleteMilestoneForever(entryId: entry.id)
            case .markdownList: try? await trashAPI.deleteMarkdownListForever(entryId: entry.id)
            }
            sync.noteMutationSettled()
            return
        }
        switch entry.kind {
        case .task:
            if let p = fetchAll(PTask.self).first(where: { $0.id == entry.id }) { modelContext.delete(p) }
        case .list:
            if let p = fetchAll(PList.self).first(where: { $0.id == entry.id }) { modelContext.delete(p) }
        case .folder:
            if let p = fetchAll(PFolder.self).first(where: { $0.id == entry.id }) { modelContext.delete(p) }
        case .timeline:
            if let p = fetchAll(PTimeline.self).first(where: { $0.id == entry.id }) { modelContext.delete(p) }
        case .milestone, .markdownList: break
        }
        save()
    }

    func emptyTrash() async {
        if isServer {
            try? await trashAPI.emptyAll()
            sync.noteMutationSettled()
            return
        }
        for e in await trashEntries() { await deleteForever(e) }
    }
}
