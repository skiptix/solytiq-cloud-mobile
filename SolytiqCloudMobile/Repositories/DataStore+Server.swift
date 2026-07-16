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

    func setFileShare(id: String, isPublic: Bool?, password: String?, expiresAt: String?, clearExpiry: Bool = false) async -> AppFileItem? {
        guard isServer else { return nil }
        let file = try? await filesAPI.setShare(id: id, isPublic: isPublic, password: password, expiresAt: expiresAt, clearExpiry: clearExpiry)
        sync.noteMutationSettled()
        return file
    }

    /// Downloads a file's bytes (authenticated) into a local temp file the UI
    /// can hand to a share sheet or QuickLook. Returns nil if not connected.
    func downloadFile(_ file: AppFileItem) async throws -> URL {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        return try await filesAPI.download(id: file.id, fileName: file.name, serverBaseURL: url, token: token)
    }

    /// §5.2 — server-side zip of several files, returned as a local temp file.
    func bundleFiles(ids: [String]) async throws -> URL {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        return try await filesAPI.bundle(ids: ids, serverBaseURL: url, token: token)
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

    /// The one-line persona the web client also seeds the conversation with, so
    /// Sol behaves the same on both surfaces.
    private var aiSystemPrompt: String {
        "You are Sol, the helpful AI assistant built into Solytiq Cloud, a self-hosted productivity suite. Help the user with their tasks, lists, timelines and schedule. Be concise and friendly."
    }

    /// §7 — uploads a file into the chat session for context, creating the
    /// session first if one doesn't exist yet. Returns the session id used.
    func uploadAIFile(sessionId: String?, fileName: String, mimeType: String, data: Data) async throws -> String {
        guard isServer, let url = appState.serverURL else { throw APIError.notConnected }
        let sid: String
        if let sessionId { sid = sessionId } else { sid = try await aiAPI.createSession() }
        let token = KeychainStore.get(KeychainStore.Key.authToken)
        try await aiAPI.uploadFile(sessionId: sid, fileName: fileName, mimeType: mimeType, data: data,
                                   serverBaseURL: url, token: token)
        return sid
    }

    /// Loads a session's persisted transcript (used when reopening the chat).
    func aiHistory(sessionId: String) async -> [AppChatMessage] {
        guard isServer else { return [] }
        return (try? await aiAPI.history(sessionId: sessionId)) ?? []
    }

    /// Sends `content` as the next user turn. `priorMessages` is the visible
    /// conversation (excluding the just-typed message) so the model has context.
    /// Returns the (possibly newly created) session id and the assistant reply.
    func sendAIMessage(sessionId: String?, priorMessages: [AppChatMessage], content: String) async -> (sessionId: String, reply: AppChatMessage)? {
        guard isServer else { return nil }
        do {
            let sid: String
            if let sessionId {
                sid = sessionId
            } else {
                sid = try await aiAPI.createSession()
            }

            var wire: [AIAPI.ChatMessage] = [AIAPI.ChatMessage(role: "system", content: aiSystemPrompt)]
            wire += priorMessages
                .filter { $0.role == "user" || $0.role == "assistant" }
                .map { AIAPI.ChatMessage(role: $0.role, content: $0.content) }
            wire.append(AIAPI.ChatMessage(role: "user", content: content))

            // Persist the user turn, then run the request/execute/respond loop.
            await aiAPI.saveMessage(sessionId: sid, role: "user", content: content)

            // §7 — fetch the server-side data-tool registry (empty when the
            // instance doesn't expose one, in which case this behaves exactly
            // like a plain chat).
            let tools = await aiAPI.tools()

            var replyText = ""
            // Bounded so a misbehaving model can't loop forever.
            for _ in 0..<6 {
                let result = try await aiAPI.chat(sessionId: sid, messages: wire, tools: tools)
                if result.toolCalls.isEmpty {
                    replyText = result.content
                    break
                }
                // Record the assistant's tool-call turn, then execute each tool
                // server-side and feed the results back in.
                wire.append(AIAPI.ChatMessage(role: "assistant", content: result.content, toolCalls: result.toolCalls))
                for call in result.toolCalls {
                    let output = await aiAPI.execute(toolName: call.function.name, argumentsJSON: call.function.arguments)
                    wire.append(AIAPI.ChatMessage(role: "tool", content: output,
                                                  name: call.function.name, toolCallId: call.id))
                }
            }
            if replyText.isEmpty { replyText = "…" }
            await aiAPI.saveMessage(sessionId: sid, role: "assistant", content: replyText)

            return (sid, AppChatMessage(role: "assistant", content: replyText))
        } catch {
            let message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            return (sessionId ?? "", AppChatMessage(role: "assistant", content: "Sorry — I couldn't reach the AI assistant: \(message)"))
        }
    }
}
