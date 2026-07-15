import Foundation

// MARK: - Feature-parity server surfaces
//
// Additional server-mode operations closing gaps against the web app (see
// implementation.md §1–§17). These are server-only conveniences; local mode
// either no-ops or isn't reachable from the surfaces that call them.

extension DataStore {
    // MARK: §1.7 Move a task between lists/sections

    @discardableResult
    func moveTask(id: String, toListId: String?, toSectionId: String?) async -> AppTask? {
        guard isServer else { return nil }
        guard let moved = try? await tasksAPI.move(id: id, toListId: toListId, toSectionId: toSectionId) else { return nil }
        sync.applyLocal { cache in
            cache.removeTask(id: id)   // drop from its old list/section first
            cache.upsertTask(moved)    // re-file under the new one
        }
        sync.noteMutationSettled()
        return moved
    }

    // MARK: §1.3 Link an existing standalone list into a task

    @discardableResult
    func linkExistingList(parentTask: AppTask, targetListId: String) async -> AppTask? {
        guard isServer, let listId = parentTask.listId, let sectionId = parentTask.sectionId else { return nil }
        guard let updated = try? await listsAPI.linkList(listId: listId, sectionId: sectionId,
                                                         parentTaskId: parentTask.id, targetListId: targetListId) else { return nil }
        sync.applyLocal { $0.upsertTask(updated) }
        sync.noteMutationSettled()
        return updated
    }

    // MARK: §1.1 Persist a list's view mode

    func setListViewMode(listId: String, mode: ListViewMode) async {
        guard isServer else {
            // Local mode has no server field; view mode is transient there.
            return
        }
        _ = try? await listsAPI.update(id: listId, .init(name: nil, emoji: nil, color: nil, subtitle: nil,
                                                          isPublic: nil, folderId: nil, viewMode: mode.rawValue))
        sync.applyLocal { cache in
            guard let i = cache.lists.firstIndex(where: { $0.id == listId }) else { return }
            cache.lists[i].viewMode = mode.rawValue
        }
        sync.noteMutationSettled()
    }

    // MARK: §1.6 Archived lists (read + restore)

    func archivedLists() async -> [AppList] {
        guard isServer else { return [] }
        return (try? await listsAPI.archived()) ?? []
    }

    func unarchiveList(id: String) async {
        guard isServer else { return }
        try? await listsAPI.unarchive(id: id)
        sync.noteMutationSettled()
    }

    // MARK: §2.2 Leave a meeting

    func leaveMeeting(id: String) async {
        guard isServer else { return }
        try? await meetingsAPI.leave(id: id)
        sync.noteMutationSettled()
    }

    // MARK: §3 Move a folder to another workspace

    func moveFolderToWorkspace(id: String, workspaceId: String?) async {
        guard isServer else { return }
        try? await foldersAPI.moveToWorkspace(id: id, workspaceId: workspaceId)
        sync.applyLocal { $0.removeFolder(id: id) }   // leaves the current workspace view
        sync.noteMutationSettled()
    }

    // MARK: §4 Workspace update / member removal

    @discardableResult
    func updateWorkspace(id: String, name: String?, description: String?, emoji: String?, visibility: String?) async -> AppWorkspace? {
        guard isServer else { return nil }
        let ws = try? await workspacesAPI.update(id: id, name: name, description: description, emoji: emoji, visibility: visibility)
        await refreshWorkspaces()
        return ws
    }

    func removeWorkspaceMember(workspaceId: String, userId: String) async {
        guard isServer else { return }
        try? await workspacesAPI.removeMember(workspaceId: workspaceId, userId: userId)
        await refreshWorkspaces()
    }

    // MARK: §5.1 Authoritative storage quota

    func storageInfo() async -> (used: Int, quota: Int)? {
        guard isServer else { return nil }
        guard let s = try? await filesAPI.storage() else { return nil }
        return (s.used, s.quota)
    }

    // MARK: §11 App directory installed state

    func installedApps() async -> [AppInstalledApp] {
        guard isServer else { return [] }
        return (try? await AppsAPI().list()) ?? []
    }

    func isAppInstalled(_ appId: String) async -> Bool {
        await installedApps().first { $0.id == appId }?.installed ?? false
    }

    // MARK: §14 Connected external agents / tokens

    func connectedTokens() async -> [AppConnectedToken] {
        guard isServer else { return [] }
        return (try? await TokensAPI().list()) ?? []
    }

    func revokeToken(id: String) async {
        guard isServer else { return }
        try? await TokensAPI().revoke(id: id)
    }

    // MARK: §15 Global search

    func search(query: String) async -> [AppSearchResult] {
        guard isServer else { return [] }
        return (try? await SearchAPI().search(query: query)) ?? []
    }

    // MARK: §17 Mobile connections (this account's devices)

    func mobileConnections() async -> [AppMobileConnection] {
        guard isServer else { return [] }
        let currentId = KeychainStore.get(KeychainStore.Key.connectionId)
        return (try? await AuthAPI().mobileConnections(currentId: currentId)) ?? []
    }

    func revokeMobileConnection(id: String) async {
        guard isServer else { return }
        try? await AuthAPI().revokeMobileConnection(id: id)
    }

    // MARK: §6.1 Milestone trash

    func trashedMilestones() async -> [(entryId: String, milestone: AppMilestone, deletedAt: Date)] {
        guard isServer else { return [] }
        return (try? await trashAPI.milestones()) ?? []
    }

    func restoreMilestone(entryId: String) async {
        guard isServer else { return }
        try? await trashAPI.restoreMilestone(entryId: entryId)
        sync.noteMutationSettled()
    }

    func deleteMilestoneForever(entryId: String) async {
        guard isServer else { return }
        try? await trashAPI.deleteMilestoneForever(entryId: entryId)
    }
}
