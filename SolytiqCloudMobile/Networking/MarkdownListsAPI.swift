import Foundation

/// §9 — markdown lists (`markdownLists.ts`). A markdown document per row, with
/// share controls and inline image upload (multipart, same pattern as
/// `FilesAPI.upload`).
struct MarkdownListsAPI {
    let client = APIClient.shared

    struct DTO: Decodable {
        var id: IntOrString
        var title: String?
        var content: String?
        var emoji: String?
        var folderId: IntOrString?
        var workspaceId: String?
        var isPublic: Bool?
        var shareEnabled: Bool?
        var shareToken: String?
        var updatedAt: String?

        func toApp() -> AppMarkdownList {
            AppMarkdownList(id: id.stringValue, title: title ?? "Untitled", content: content ?? "",
                             emoji: emoji, folderId: folderId?.stringValue, workspaceId: workspaceId,
                             isPublic: isPublic ?? false, shareEnabled: shareEnabled ?? false, shareToken: shareToken,
                             updatedAt: ServerDate.parse(updatedAt) ?? .now)
        }
    }

    func list(workspaceId: String? = nil) async throws -> [AppMarkdownList] {
        struct R: Decodable { var markdownLists: [DTO] }
        var q: [String: String] = [:]
        if let workspaceId { q["workspaceId"] = workspaceId }
        return try await client.request("/markdown-lists", query: q, as: R.self).markdownLists.map { $0.toApp() }
    }

    func get(id: String) async throws -> AppMarkdownList {
        struct R: Decodable { var markdownList: DTO }
        return try await client.request("/markdown-lists/\(id)", as: R.self).markdownList.toApp()
    }

    struct CreateBody: Encodable { var title: String; var content: String; var emoji: String?; var folderId: String?; var workspaceId: String? }
    func create(title: String, content: String, emoji: String?, folderId: String?, workspaceId: String?) async throws -> AppMarkdownList {
        struct R: Decodable { var markdownList: DTO }
        return try await client.request("/markdown-lists", method: "POST",
                                         body: CreateBody(title: title, content: content, emoji: emoji, folderId: folderId, workspaceId: workspaceId), as: R.self).markdownList.toApp()
    }

    struct UpdateBody: Encodable { var title: String?; var content: String?; var emoji: String? }
    @discardableResult
    func update(id: String, title: String?, content: String?, emoji: String?) async throws -> AppMarkdownList {
        struct R: Decodable { var markdownList: DTO }
        return try await client.request("/markdown-lists/\(id)", method: "PUT",
                                         body: UpdateBody(title: title, content: content, emoji: emoji), as: R.self).markdownList.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/markdown-lists/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    struct ShareBody: Encodable { var shareEnabled: Bool; var password: String?; var expiresAt: String? }
    @discardableResult
    func setShare(id: String, enabled: Bool, password: String?, expiresAt: String?) async throws -> AppMarkdownList {
        struct R: Decodable { var markdownList: DTO }
        return try await client.request("/markdown-lists/\(id)/share", method: "PUT",
                                         body: ShareBody(shareEnabled: enabled, password: password, expiresAt: expiresAt), as: R.self).markdownList.toApp()
    }

    /// Uploads an image into the document; returns the reference the markdown
    /// should embed (`imageId`/`url`), same multipart shape as file upload.
    struct UploadedImage: Decodable { var imageId: String?; var id: String?; var url: String? }
    func uploadImage(id: String, fileName: String, mimeType: String, data: Data, serverBaseURL: URL, token: String?) async throws -> UploadedImage {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/markdown-lists/\(id)/images"))
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (respData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: respData))?["error"] ?? "Image upload failed."
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
        return try JSONDecoder().decode(UploadedImage.self, from: respData)
    }
}
