import Foundation

// MARK: - Server-only surfaces: Workspaces, Files, Templates, AI assistant.
//
// These features fundamentally require a multi-user, always-on server
// (per the design spec: "AI, files and workspaces only make sense when
// connected to a self-hosted instance") — local mode implicitly has exactly
// one, unnamed personal workspace and no files/templates/AI at all.

extension DataStore {
    func refreshWorkspaces() async {
        guard isServer else { return }
        await appState.reloadWorkspaces()
    }

    @discardableResult
    func createWorkspace(name: String, description: String?, emoji: String?, visibility: String) async -> AppWorkspace? {
        guard isServer else { return nil }
        let ws = try? await workspacesAPI.create(name: name, description: description, emoji: emoji, visibility: visibility)
        await refreshWorkspaces()
        return ws
    }

    func deleteWorkspace(id: String) async {
        guard isServer else { return }
        try? await workspacesAPI.delete(id: id)
        await refreshWorkspaces()
    }

    func addWorkspaceMember(workspaceId: String, username: String) async throws {
        guard isServer else { return }
        try await workspacesAPI.addMember(workspaceId: workspaceId, username: username)
        await refreshWorkspaces()
    }

    // MARK: Files

    func files() async -> [AppFileItem] {
        guard isServer else { return [] }
        return (try? await filesAPI.list()) ?? []
    }

    func uploadFile(name: String, mimeType: String, data: Data) async throws -> AppFileItem {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        let file = try await filesAPI.upload(fileName: name, mimeType: mimeType, data: data, serverBaseURL: url, token: token)
        sync.noteMutationSettled()
        return file
    }

    func deleteFile(id: String) async {
        guard isServer else { return }
        try? await filesAPI.delete(id: id)
        sync.noteMutationSettled()
    }

    func setFileShare(id: String, isPublic: Bool?, password: String?, expiresAt: String?) async -> AppFileItem? {
        guard isServer else { return nil }
        let file = try? await filesAPI.setShare(id: id, isPublic: isPublic, password: password, expiresAt: expiresAt)
        sync.noteMutationSettled()
        return file
    }

    func fileDownloadURL(id: String) -> URL? {
        guard isServer, let url = appState.serverURL else { return nil }
        return filesAPI.downloadURL(id: id, serverBaseURL: url)
    }

    // MARK: Templates
    //
    // Server-side snapshots of a full list/timeline structure (`/api/templates`).
    // Workspace-agnostic: a template can be instantiated into any workspace.

    func templates(type: String? = nil) async -> [AppTemplate] {
        guard isServer else { return [] }
        return (try? await templatesAPI.list(type: type)) ?? []
    }

    /// Snapshot an existing list or timeline you own into a reusable template.
    @discardableResult
    func saveAsTemplate(type: String, sourceId: String, name: String?, description: String?, isShared: Bool) async throws -> AppTemplate {
        guard isServer else { throw APIError.notConnected }
        let tpl = try await templatesAPI.create(type: type, sourceId: sourceId, name: name,
                                                 description: description, isShared: isShared)
        sync.noteMutationSettled()
        return tpl
    }

    /// Materialize a new list/timeline from a template into the current
    /// workspace. Returns what was created so the caller can navigate to it.
    func useTemplate(_ template: AppTemplate, name: String?) async throws -> TemplatesAPI.CreatedFromTemplate {
        guard isServer else { throw APIError.notConnected }
        let created = try await templatesAPI.use(id: template.id, name: name,
                                                  workspaceId: appState.currentWorkspaceId)
        switch created {
        case .list(let list): sync.applyLocal { $0.upsertList(list) }
        case .timeline(let timeline): sync.applyLocal { $0.upsertTimeline(timeline) }
        }
        sync.noteMutationSettled()
        return created
    }

    func setTemplateShared(_ template: AppTemplate, isShared: Bool) async -> AppTemplate? {
        guard isServer else { return nil }
        let updated = try? await templatesAPI.update(id: template.id, name: nil, description: nil, isShared: isShared)
        sync.noteMutationSettled()
        return updated
    }

    func deleteTemplate(id: String) async {
        guard isServer else { return }
        try? await templatesAPI.delete(id: id)
        sync.noteMutationSettled()
    }

    // MARK: AI assistant

    func sendAIMessage(sessionId: String?, content: String) async -> (sessionId: String, reply: AppChatMessage)? {
        guard isServer else { return nil }
        do {
            let sid = try await sessionId ?? aiAPI.createSession()
            let reply = try await aiAPI.send(sessionId: sid, content: content)
            return (sid, reply)
        } catch {
            return (sessionId ?? "", AppChatMessage(role: "assistant", content: "Sorry — I couldn't reach the AI assistant: \(error.localizedDescription)"))
        }
    }
}
