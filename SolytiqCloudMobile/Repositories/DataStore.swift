import Foundation
import SwiftData

/// Single façade the UI talks to for every read/write. Internally it
/// branches on `AppState.mode`: local mode hits the on-device SwiftData
/// store directly, server mode is backed by the delta-sync engine's
/// in-memory cache (`SyncEngine`) with the REST APIs as mutation transport
/// and as a read fallback while the engine isn't live. Screens never need
/// to know which one is active — they just call `store.tasks()`,
/// `store.createTask(...)`, etc.
///
/// Server-mode write pattern: call the REST endpoint, optimistically apply
/// the response to the sync cache (instant UI), then `noteMutationSettled()`
/// schedules one debounced delta pull that makes the cache authoritative
/// again (positions, cascades, collaborator edits).
@MainActor
final class DataStore: ObservableObject {
    let modelContext: ModelContext
    let appState: AppState

    /// Local-mode counterpart of `SyncEngine.revision`: bumped on every
    /// SwiftData save so screens holding value-type copies reload after a
    /// sheet edits data they display. (Server mode bumps `sync.revision`
    /// through the optimistic cache appliers instead.)
    @Published private(set) var localRevision = 0

    let tasksAPI = TasksAPI()
    let listsAPI = ListsAPI()
    let foldersAPI = FoldersAPI()
    let meetingsAPI = MeetingsAPI()
    let timelinesAPI = TimelinesAPI()
    let trashAPI = TrashAPI()
    let workspacesAPI = WorkspacesAPI()
    let filesAPI = FilesAPI()
    let aiAPI = AIAPI()
    let templatesAPI = TemplatesAPI()

    init(modelContext: ModelContext, appState: AppState) {
        self.modelContext = modelContext
        self.appState = appState
    }

    var isServer: Bool { appState.mode == .server }
    var sync: SyncEngine { appState.sync }

    // MARK: - SwiftData helpers

    func fetchAll<T: PersistentModel>(_ type: T.Type, sortBy: [SortDescriptor<T>] = []) -> [T] {
        (try? modelContext.fetch(FetchDescriptor<T>(sortBy: sortBy))) ?? []
    }

    func save() {
        try? modelContext.save()
        localRevision += 1
    }

    // MARK: - Purge trash older than 30 days (mirrors backend's `expires_at`)

    func purgeExpiredLocalTrash() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        for t in fetchAll(PTask.self) where t.isTrashed && (t.trashedAt ?? .now) < cutoff { modelContext.delete(t) }
        for l in fetchAll(PList.self) where l.isTrashed && (l.trashedAt ?? .now) < cutoff { modelContext.delete(l) }
        for f in fetchAll(PFolder.self) where f.isTrashed && (f.trashedAt ?? .now) < cutoff { modelContext.delete(f) }
        for tl in fetchAll(PTimeline.self) where tl.isTrashed && (tl.trashedAt ?? .now) < cutoff { modelContext.delete(tl) }
        save()
    }
}

// MARK: - Tasks (dashboard-level, not attached to a list)

extension DataStore {
    /// All non-trashed tasks across the whole account/device: standalone
    /// "dashboard" tasks plus every task inside every list, flattened — used
    /// by Dashboard, Calendar and the Trash sheet.
    func allTasks() async -> [AppTask] {
        if isServer {
            if sync.isLive { return sync.cache.tasks }
            return (try? await tasksAPI.list(workspaceId: appState.currentWorkspaceId)) ?? []
        }
        return fetchAll(PTask.self, sortBy: [SortDescriptor(\.position)])
            .filter { !$0.isTrashed }
            .map { $0.toApp(listName: $0.section?.list?.name) }
    }

    /// Dashboard-only tasks (no section/list) — the standalone to-dos shown
    /// on Home before any list exists.
    func dashboardTasks() async -> [AppTask] {
        if isServer {
            return await allTasks().filter { $0.listId == nil }
        }
        return fetchAll(PTask.self, sortBy: [SortDescriptor(\.position)])
            .filter { !$0.isTrashed && $0.section == nil }
            .map { $0.toApp() }
    }

    @discardableResult
    func createDashboardTask(_ draft: AppTask) async -> AppTask? {
        if isServer {
            guard let created = try? await tasksAPI.create(draft) else { return nil }
            sync.applyLocal { $0.upsertTask(created) }
            sync.noteMutationSettled()
            return created
        }
        let maxPos = fetchAll(PTask.self).filter { $0.section == nil }.map(\.position).max() ?? -1
        let p = PTask(title: draft.title, note: draft.note, checked: draft.checked, deadline: draft.deadline,
                       time: draft.time, priorityRaw: draft.priority?.rawValue, badge: draft.badge, position: maxPos + 1)
        modelContext.insert(p)
        save()
        return p.toApp()
    }

    @discardableResult
    func updateTask(_ task: AppTask) async -> AppTask? {
        if isServer {
            let patch = TasksAPI.UpdateBody(title: task.title, note: task.note, checked: task.checked,
                                             deadline: task.deadline, time_val: task.time,
                                             priority: task.priority?.rawValue, badge: task.badge)
            let updated: AppTask?
            if let listId = task.listId {
                updated = try? await listsAPI.updateTask(listId: listId, taskId: task.id, patch)
            } else {
                updated = try? await tasksAPI.update(id: task.id, patch)
            }
            if let updated {
                sync.applyLocal { $0.upsertTask(updated) }
                sync.noteMutationSettled()
            }
            return updated
        }
        guard let p = fetchAll(PTask.self).first(where: { $0.id == task.id }) else { return nil }
        p.title = task.title; p.note = task.note; p.checked = task.checked; p.deadline = task.deadline
        p.time = task.time; p.priorityRaw = task.priority?.rawValue; p.badge = task.badge
        p.subItems = task.subItems; p.updatedAt = .now
        save()
        return p.toApp(listName: p.section?.list?.name)
    }

    func deleteTask(id: String, listId: String?) async {
        if isServer {
            if let listId { try? await listsAPI.deleteTask(listId: listId, taskId: id) }
            else { try? await tasksAPI.delete(id: id) }
            sync.applyLocal { $0.removeTask(id: id) }
            sync.noteMutationSettled()
            return
        }
        guard let p = fetchAll(PTask.self).first(where: { $0.id == id }) else { return }
        p.isTrashed = true; p.trashedAt = .now
        save()
    }
}

// MARK: - Lists, Sections, Folders

extension DataStore {
    func lists() async -> [AppList] {
        if isServer {
            if sync.isLive { return sync.cache.lists }
            return (try? await listsAPI.list(workspaceId: appState.currentWorkspaceId)) ?? []
        }
        return fetchAll(PList.self, sortBy: [SortDescriptor(\.position)])
            .filter { !$0.isTrashed }
            .map { $0.toApp() }
    }

    func folders() async -> [AppFolder] {
        if isServer {
            if sync.isLive { return sync.cache.folders }
            return (try? await foldersAPI.list(workspaceId: appState.currentWorkspaceId)) ?? []
        }
        return fetchAll(PFolder.self, sortBy: [SortDescriptor(\.position)])
            .filter { !$0.isTrashed }
            .map { $0.toApp() }
    }

    @discardableResult
    func createFolder(name: String, emoji: String?, colorHex: String) async -> AppFolder? {
        if isServer {
            let f = try? await foldersAPI.create(name: name, emoji: emoji, color: colorHex, workspaceId: appState.currentWorkspaceId)
            if let f {
                sync.applyLocal { $0.upsertFolder(f) }
                sync.noteMutationSettled()
            }
            return f
        }
        let maxPos = fetchAll(PFolder.self).map(\.position).max() ?? -1
        let f = PFolder(name: name, emoji: emoji, colorHex: colorHex, position: maxPos + 1)
        modelContext.insert(f); save()
        return f.toApp()
    }

    func deleteFolder(id: String) async {
        if isServer {
            try? await foldersAPI.delete(id: id)
            sync.applyLocal { cache in
                cache.removeFolder(id: id)
                // The backend moves the folder's lists to the top level.
                for i in cache.lists.indices where cache.lists[i].folderId == id {
                    cache.lists[i].folderId = nil
                }
            }
            sync.noteMutationSettled()
            return
        }
        guard let f = fetchAll(PFolder.self).first(where: { $0.id == id }) else { return }
        f.isTrashed = true; f.trashedAt = .now
        for l in fetchAll(PList.self) where l.folderId == id { l.folderId = nil }
        save()
    }

    @discardableResult
    func createList(name: String, emoji: String?, colorHex: String, folderId: String?, isPublic: Bool) async -> AppList? {
        if isServer {
            let l = try? await listsAPI.create(name: name, emoji: emoji, color: colorHex, isPublic: isPublic,
                                                folderId: folderId, workspaceId: appState.currentWorkspaceId)
            if let l {
                sync.applyLocal { $0.upsertList(l) }
                sync.noteMutationSettled()
            }
            return l
        }
        let maxPos = fetchAll(PList.self).map(\.position).max() ?? -1
        let l = PList(name: name, emoji: emoji, colorHex: colorHex, folderId: folderId, position: maxPos + 1, isPublic: false)
        let defaultSection = PSection(label: "Tasks", emoji: nil, position: 0)
        defaultSection.list = l
        l.sections = [defaultSection]
        modelContext.insert(l)
        save()
        return l.toApp()
    }

    func updateList(_ list: AppList) async {
        if isServer {
            let patch = ListsAPI.UpdateBody(name: list.name, emoji: list.emoji, color: list.colorHex,
                                             subtitle: list.subtitle, isPublic: list.isPublic, folderId: list.folderId)
            _ = try? await listsAPI.update(id: list.id, patch)
            // Patch metadata onto the cached copy, keeping its (authoritative)
            // sections — the update response doesn't carry nested tasks.
            sync.applyLocal { cache in
                guard let i = cache.lists.firstIndex(where: { $0.id == list.id }) else { return }
                cache.lists[i].name = list.name
                cache.lists[i].emoji = list.emoji
                cache.lists[i].colorHex = list.colorHex
                cache.lists[i].subtitle = list.subtitle
                cache.lists[i].isPublic = list.isPublic
                cache.lists[i].folderId = list.folderId
            }
            sync.noteMutationSettled()
            return
        }
        guard let l = fetchAll(PList.self).first(where: { $0.id == list.id }) else { return }
        l.name = list.name; l.emoji = list.emoji; l.colorHex = list.colorHex
        l.subtitle = list.subtitle; l.folderId = list.folderId
        save()
    }

    func deleteList(id: String) async {
        if isServer {
            try? await listsAPI.delete(id: id)
            sync.applyLocal { $0.removeList(id: id) }
            sync.noteMutationSettled()
            return
        }
        guard let l = fetchAll(PList.self).first(where: { $0.id == id }) else { return }
        l.isTrashed = true; l.trashedAt = .now
        save()
    }

    @discardableResult
    func addSection(listId: String, label: String, emoji: String?) async -> AppSection? {
        if isServer {
            let s = try? await listsAPI.addSection(listId: listId, label: label, emoji: emoji)
            if let s {
                sync.applyLocal { cache in
                    guard let i = cache.lists.firstIndex(where: { $0.id == listId }) else { return }
                    var section = s
                    section.listId = listId
                    cache.lists[i].sections.append(section)
                }
                sync.noteMutationSettled()
            }
            return s
        }
        guard let l = fetchAll(PList.self).first(where: { $0.id == listId }) else { return nil }
        let maxPos = l.sections.map(\.position).max() ?? -1
        let s = PSection(label: label, emoji: emoji, position: maxPos + 1)
        s.list = l
        l.sections.append(s)
        save()
        return AppSection(id: s.id, listId: listId, label: label, emoji: emoji, position: s.position, tasks: [])
    }

    func deleteSection(id: String, listId: String) async {
        if isServer {
            try? await listsAPI.deleteSection(id: id)
            sync.applyLocal { cache in
                guard let i = cache.lists.firstIndex(where: { $0.id == listId }) else { return }
                cache.lists[i].sections.removeAll { $0.id == id }
                cache.tasks.removeAll { $0.sectionId == id }
            }
            sync.noteMutationSettled()
            return
        }
        guard let l = fetchAll(PList.self).first(where: { $0.id == listId }),
              let s = l.sections.first(where: { $0.id == id }) else { return }
        modelContext.delete(s)
        save()
    }

    @discardableResult
    func addTask(listId: String, sectionId: String, draft: AppTask) async -> AppTask? {
        if isServer {
            guard let created = try? await listsAPI.addTask(listId: listId, sectionId: sectionId, task: draft) else { return nil }
            sync.applyLocal { $0.upsertTask(created) }
            sync.noteMutationSettled()
            return created
        }
        guard let l = fetchAll(PList.self).first(where: { $0.id == listId }),
              let s = l.sections.first(where: { $0.id == sectionId }) else { return nil }
        let maxPos = s.tasks.map(\.position).max() ?? -1
        let p = PTask(title: draft.title, note: draft.note, checked: draft.checked, deadline: draft.deadline,
                       time: draft.time, priorityRaw: draft.priority?.rawValue, badge: draft.badge, position: maxPos + 1)
        p.section = s
        s.tasks.append(p)
        save()
        return p.toApp(listName: l.name)
    }

    @discardableResult
    func createSublist(parentTask: AppTask, name: String, emoji: String?) async -> AppList? {
        guard let listId = parentTask.listId, let sectionId = parentTask.sectionId else { return nil }
        if isServer {
            let sub = try? await listsAPI.createSublist(listId: listId, sectionId: sectionId, parentTaskId: parentTask.id, name: name, emoji: emoji)
            if let sub {
                sync.applyLocal { cache in
                    cache.upsertList(sub)
                    var parent = parentTask
                    parent.linkedListId = sub.id
                    cache.upsertTask(parent)
                }
                sync.noteMutationSettled()
            }
            return sub
        }
        let sub = await createList(name: name, emoji: emoji ?? "🗂️", colorHex: "#5e4dbb", folderId: nil, isPublic: false)
        if let sub, let p = fetchAll(PTask.self).first(where: { $0.id == parentTask.id }) {
            p.linkedListId = sub.id
            save()
        }
        return sub
    }
}
