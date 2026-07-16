import Foundation

/// Thin client for the backend's OpenRouter-backed AI assistant
/// (`backend/src/routes/ai.ts`). Only available in server mode, and only
/// when the instance admin has configured `OPENROUTER_API_KEY` — the app
/// surfaces the server's own error message when the feature is off rather
/// than guessing at a reason.
struct AIAPI {
    let client = APIClient.shared

    struct SessionDTO: Decodable { var id: String }
    func createSession() async throws -> String {
        struct R: Decodable { var session: SessionDTO }
        return try await client.request("/ai/sessions", method: "POST", as: R.self).session.id
    }

    func history(sessionId: String) async throws -> [AppChatMessage] {
        struct R: Decodable { var messages: [APIChatMessageDTO] }
        let rows = try await client.request("/ai/sessions/\(sessionId)", as: R.self).messages
        return rows.map { AppChatMessage(id: $0.id?.stringValue ?? UUID().uuidString, role: $0.role, content: $0.content) }
    }

    // MARK: §7 tool-calling types

    /// One tool call the model requested (OpenAI function-calling shape).
    struct ToolCall: Codable, Hashable {
        struct Function: Codable, Hashable { var name: String; var arguments: String }
        var id: String?
        var type: String?
        var function: Function
    }

    /// A single chat turn. `toolCalls` is set on an assistant message that
    /// requested tools; `name`/`toolCallId` are set on a tool-result message.
    struct ChatMessage: Encodable {
        var role: String
        var content: String
        var name: String? = nil
        var toolCallId: String? = nil
        var toolCalls: [ToolCall]? = nil

        enum CodingKeys: String, CodingKey { case role, content, name, toolCallId = "tool_call_id", toolCalls = "tool_calls" }
    }

    /// The parsed result of one `/ai/chat` turn.
    struct ChatResult { var content: String; var toolCalls: [ToolCall] }

    /// A server-side data tool definition (`GET /api/ai/tools`).
    struct ToolDef: Codable { var type: String?; var function: Function?
        struct Function: Codable { var name: String; var description: String?; var parameters: JSONValue? }
    }

    /// `GET /api/ai/tools` — the registry of server-side data tools. Best-effort:
    /// when the endpoint is absent the caller simply runs without tools.
    func tools() async -> [ToolDef] {
        struct R: Decodable { var tools: [ToolDef] }
        return (try? await client.request("/ai/tools", as: R.self).tools) ?? []
    }

    /// `POST /api/ai/execute` — run one server-side data tool and return its
    /// result as JSON text to feed back into the conversation.
    struct ExecuteBody: Encodable { var tool: String; var args: JSONValue }
    func execute(toolName: String, argumentsJSON: String) async -> String {
        let args: JSONValue = (try? JSONDecoder().decode(JSONValue.self, from: Data(argumentsJSON.utf8))) ?? .object([:])
        struct R: Decodable { var result: JSONValue? }
        do {
            let resp = try await client.request("/ai/execute", method: "POST",
                                                body: ExecuteBody(tool: toolName, args: args), as: R.self)
            return resp.result?.prettyJSON ?? "{}"
        } catch {
            return "{\"error\":\"\((error as? APIError)?.errorDescription ?? "tool failed")\"}"
        }
    }

    /// `POST /api/ai/files` — upload a file into a chat session for context.
    func uploadFile(sessionId: String?, fileName: String, mimeType: String, data: Data, serverBaseURL: URL, token: String?) async throws {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/ai/files"))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var body = Data()
        if let sessionId {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"sessionId\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(sessionId)\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: respData))?["error"] ?? "Upload failed."
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
    }

    /// `POST /api/ai/chat` is a thin proxy to OpenRouter, so it returns the raw
    /// completion shape (`choices[].message.content`) rather than a persisted
    /// row — persistence is a separate `/ai/history` call, mirroring the web
    /// client. When `tools` is non-empty the model may respond with tool calls
    /// instead of text; the caller runs them and calls back in.
    private struct ChatBody: Encodable { var messages: [ChatMessage]; var sessionId: String?; var tools: [ToolDef]? }
    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { var role: String?; var content: String?; var toolCalls: [ToolCall]?
                enum CodingKeys: String, CodingKey { case role, content, toolCalls = "tool_calls" }
            }
            var message: Msg
        }
        var choices: [Choice]
    }

    /// Sends the whole running conversation and returns the assistant's reply
    /// text plus any tool calls it requested. Throws `APIError.server` carrying
    /// the backend's own message when the assistant is disabled or
    /// `OPENROUTER_API_KEY` isn't configured.
    func chat(sessionId: String?, messages: [ChatMessage], tools: [ToolDef] = []) async throws -> ChatResult {
        let resp = try await client.request("/ai/chat", method: "POST",
                                            body: ChatBody(messages: messages, sessionId: sessionId,
                                                           tools: tools.isEmpty ? nil : tools),
                                            as: ChatResponse.self)
        let msg = resp.choices.first?.message
        let content = msg?.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return ChatResult(content: content, toolCalls: msg?.toolCalls ?? [])
    }

    /// Persists one message to the session so it survives app restarts and is
    /// visible on the web (`GET /api/ai/sessions/:id`). Best-effort — a failure
    /// here must not break the live reply the user just received.
    private struct HistoryBody: Encodable { var role: String; var content: String; var sessionId: String? }
    func saveMessage(sessionId: String?, role: String, content: String) async {
        _ = try? await client.request("/ai/history", method: "POST",
                                      body: HistoryBody(role: role, content: content, sessionId: sessionId),
                                      as: APIClient.EmptyResponse.self)
    }
}
