import Foundation

// MARK: - Server-only surfaces: Workspaces, Files, AI assistant.
//
// These features fundamentally require a multi-user, always-on server
// (per the design spec: "AI, files and workspaces only make sense when
// connected to a self-hosted instance") — local mode implicitly has exactly
// one, unnamed personal workspace and no files/AI at all.

extension DataStore {
    func refreshWorkspaces() async {
        guard isServer else { return }
        appState.workspaces = (try? await workspacesAPI.list()) ?? []
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
        return try await filesAPI.upload(fileName: name, mimeType: mimeType, data: data, serverBaseURL: url, token: token)
    }

    func deleteFile(id: String) async {
        guard isServer else { return }
        try? await filesAPI.delete(id: id)
    }

    func setFileShare(id: String, isPublic: Bool?, password: String?, expiresAt: String?) async -> AppFileItem? {
        guard isServer else { return nil }
        return try? await filesAPI.setShare(id: id, isPublic: isPublic, password: password, expiresAt: expiresAt)
    }

    func fileDownloadURL(id: String) -> URL? {
        guard isServer, let url = appState.serverURL else { return nil }
        return filesAPI.downloadURL(id: id, serverBaseURL: url)
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
