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

    struct SendBody: Encodable { var content: String }
    func send(sessionId: String, content: String) async throws -> AppChatMessage {
        struct R: Decodable { var message: APIChatMessageDTO }
        let reply = try await client.request("/ai/sessions/\(sessionId)/messages", method: "POST", body: SendBody(content: content), as: R.self).message
        return AppChatMessage(id: reply.id?.stringValue ?? UUID().uuidString, role: reply.role, content: reply.content)
    }
}
