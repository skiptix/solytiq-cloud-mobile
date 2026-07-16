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

    // MARK: §1.2 Reorder tasks within a section / sections within a list

    func reorderSectionTasks(listId: String, sectionId: String, orderedIds: [String]) async {
        guard isServer else { return }
        // Optimistically reorder the cached section so the UI settles instantly.
        sync.applyLocal { cache in
            guard let li = cache.lists.firstIndex(where: { $0.id == listId }),
                  let si = cache.lists[li].sections.firstIndex(where: { $0.id == sectionId }) else { return }
            let byId = Dictionary(uniqueKeysWithValues: cache.lists[li].sections[si].tasks.map { ($0.id, $0) })
            var reordered: [AppTask] = []
            for (pos, id) in orderedIds.enumerated() {
                if var t = byId[id] { t.position = pos; reordered.append(t) }
            }
            cache.lists[li].sections[si].tasks = reordered
            // Keep the flattened task list's positions in step.
            for id in orderedIds {
                if let ti = cache.tasks.firstIndex(where: { $0.id == id }),
                   let pos = orderedIds.firstIndex(of: id) { cache.tasks[ti].position = pos }
            }
        }
        try? await listsAPI.reorderTasks(listId: listId, sectionId: sectionId, orderedIds: orderedIds)
        sync.noteMutationSettled()
    }

    func reorderSections(listId: String, orderedIds: [String]) async {
        guard isServer else { return }
        sync.applyLocal { cache in
            guard let li = cache.lists.firstIndex(where: { $0.id == listId }) else { return }
            let byId = Dictionary(uniqueKeysWithValues: cache.lists[li].sections.map { ($0.id, $0) })
            var reordered: [AppSection] = []
            for (pos, id) in orderedIds.enumerated() {
                if var s = byId[id] { s.position = pos; reordered.append(s) }
            }
            if reordered.count == cache.lists[li].sections.count { cache.lists[li].sections = reordered }
        }
        try? await listsAPI.reorderSections(listId: listId, orderedIds: orderedIds)
        sync.noteMutationSettled()
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

    // MARK: §3 Update folder metadata / visibility / collapse

    func updateFolder(id: String, name: String?, emoji: String?, colorHex: String?, isPublic: Bool?) async {
        guard isServer else {
            if let f = fetchAll(PFolder.self).first(where: { $0.id == id }) {
                if let name { f.name = name }
                if let emoji { f.emoji = emoji }
                if let colorHex { f.colorHex = colorHex }
                save()
            }
            return
        }
        let updated = try? await foldersAPI.update(id: id, .init(name: name, emoji: emoji, color: colorHex,
                                                                 position: nil, isPublic: isPublic, collapsed: nil))
        if let updated { sync.applyLocal { $0.upsertFolder(updated) } }
        sync.noteMutationSettled()
    }

    /// §3 — persist a folder's collapse state so it syncs across devices.
    func setFolderCollapsed(id: String, collapsed: Bool) async {
        guard isServer else { return }
        _ = try? await foldersAPI.update(id: id, .init(name: nil, emoji: nil, color: nil, position: nil,
                                                       isPublic: nil, collapsed: collapsed))
        sync.applyLocal { cache in
            guard let i = cache.folders.firstIndex(where: { $0.id == id }) else { return }
            cache.folders[i].collapsed = collapsed
        }
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

    // MARK: §1.5 Task attachments

    func taskAttachments(taskId: String) async -> [AppTaskAttachment] {
        guard isServer else { return [] }
        return (try? await TaskAttachmentsAPI().list(taskId: taskId)) ?? []
    }

    @discardableResult
    func uploadTaskAttachment(taskId: String, fileName: String, mimeType: String, data: Data) async throws -> AppTaskAttachment {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        let attachment = try await TaskAttachmentsAPI().upload(taskId: taskId, fileName: fileName, mimeType: mimeType,
                                                               data: data, serverBaseURL: url, token: token)
        sync.noteMutationSettled()
        return attachment
    }

    @discardableResult
    func linkTaskAttachment(taskId: String, sharedFileId: String) async -> AppTaskAttachment? {
        guard isServer else { return nil }
        let attachment = try? await TaskAttachmentsAPI().link(taskId: taskId, sharedFileId: sharedFileId)
        sync.noteMutationSettled()
        return attachment
    }

    func deleteTaskAttachment(attachmentId: String) async {
        guard isServer else { return }
        try? await TaskAttachmentsAPI().delete(attachmentId: attachmentId)
        sync.noteMutationSettled()
    }

    func downloadTaskAttachment(_ attachment: AppTaskAttachment) async throws -> URL {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        return try await TaskAttachmentsAPI().download(attachmentId: attachment.id, fileName: attachment.fileName,
                                                       serverBaseURL: url, token: token)
    }

    // MARK: §9 Markdown lists

    func markdownLists() async -> [AppMarkdownList] {
        guard isServer else { return [] }
        return (try? await MarkdownListsAPI().list(workspaceId: appState.currentWorkspaceId)) ?? []
    }

    func markdownList(id: String) async -> AppMarkdownList? {
        guard isServer else { return nil }
        return try? await MarkdownListsAPI().get(id: id)
    }

    @discardableResult
    func createMarkdownList(title: String, content: String, emoji: String?) async -> AppMarkdownList? {
        guard isServer else { return nil }
        let created = try? await MarkdownListsAPI().create(title: title, content: content, emoji: emoji,
                                                           folderId: nil, workspaceId: appState.currentWorkspaceId)
        sync.noteMutationSettled()
        return created
    }

    @discardableResult
    func updateMarkdownList(id: String, title: String?, content: String?, emoji: String?) async -> AppMarkdownList? {
        guard isServer else { return nil }
        let updated = try? await MarkdownListsAPI().update(id: id, title: title, content: content, emoji: emoji)
        sync.noteMutationSettled()
        return updated
    }

    func deleteMarkdownList(id: String) async {
        guard isServer else { return }
        try? await MarkdownListsAPI().delete(id: id)
        sync.noteMutationSettled()
    }

    // MARK: §10 Automations

    func automations() async -> [AppAutomation] {
        guard isServer else { return [] }
        return (try? await AutomationsAPI().list(workspaceId: appState.currentWorkspaceId)) ?? []
    }

    func automation(id: String) async -> AppAutomation? {
        guard isServer else { return nil }
        return try? await AutomationsAPI().get(id: id)
    }

    func automationNodeTypes() async -> [AppAutomationNodeType] {
        guard isServer else { return [] }
        return (try? await AutomationsAPI().nodeTypes()) ?? []
    }

    @discardableResult
    func createAutomation(name: String) async -> AppAutomation? {
        guard isServer else { return nil }
        let created = try? await AutomationsAPI().create(name: name, workspaceId: appState.currentWorkspaceId)
        sync.noteMutationSettled()
        return created
    }

    @discardableResult
    func saveAutomation(id: String, name: String?, graph: [AppAutomationNode]?) async -> AppAutomation? {
        guard isServer else { return nil }
        let updated = try? await AutomationsAPI().update(id: id, name: name, graph: graph)
        sync.noteMutationSettled()
        return updated
    }

    func setAutomationEnabled(id: String, enabled: Bool) async {
        guard isServer else { return }
        try? await AutomationsAPI().setEnabled(id: id, enabled: enabled)
        sync.noteMutationSettled()
    }

    func deleteAutomation(id: String) async {
        guard isServer else { return }
        try? await AutomationsAPI().delete(id: id)
        sync.noteMutationSettled()
    }

    func automationRuns(id: String) async -> [AppAutomationRun] {
        guard isServer else { return [] }
        return (try? await AutomationsAPI().runs(id: id)) ?? []
    }

    func testAutomationNode(id: String, nodeId: String) async -> AppAutomationRun? {
        guard isServer else { return nil }
        return try? await AutomationsAPI().test(id: id, nodeId: nodeId)
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
