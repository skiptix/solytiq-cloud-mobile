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

    /// A single chat turn as OpenRouter (and the backend proxy) expect it.
    struct ChatMessage: Encodable { var role: String; var content: String }

    /// `POST /api/ai/chat` is a thin proxy to OpenRouter, so it returns the raw
    /// completion shape (`choices[].message.content`) rather than a persisted
    /// row — persistence is a separate `/ai/history` call, mirroring the web
    /// client. There is no `/ai/sessions/:id/messages` endpoint (the old mobile
    /// code called one that never existed, which is why chat did nothing).
    private struct ChatBody: Encodable { var messages: [ChatMessage]; var sessionId: String? }
    private struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Msg: Decodable { var role: String?; var content: String? }
            var message: Msg
        }
        var choices: [Choice]
    }

    /// Sends the whole running conversation and returns the assistant's reply
    /// text. Throws `APIError.server` carrying the backend's own message when
    /// the assistant is disabled or `OPENROUTER_API_KEY` isn't configured.
    func chat(sessionId: String?, messages: [ChatMessage]) async throws -> String {
        let resp = try await client.request("/ai/chat", method: "POST",
                                            body: ChatBody(messages: messages, sessionId: sessionId),
                                            as: ChatResponse.self)
        let content = resp.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return content.isEmpty ? "…" : content
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
