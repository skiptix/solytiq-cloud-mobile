import Foundation

/// §1.5 — task attachments (`taskAttachments.ts`). Uploads reuse the multipart
/// pattern from `FilesAPI.upload`; linking references an existing `shared_files`
/// row; download fetches the bytes with the bearer token into a temp file the
/// UI can preview or share.
struct TaskAttachmentsAPI {
    let client = APIClient.shared

    struct AttachmentDTO: Decodable {
        var id: IntOrString
        var taskId: IntOrString?
        var attachmentType: String?
        var type: String?
        var fileName: String?
        var name: String?
        var mimeType: String?
        var size: Int?
        var sharedFileId: String?

        func toApp(taskId fallbackTaskId: String) -> AppTaskAttachment {
            AppTaskAttachment(
                id: id.stringValue,
                taskId: taskId?.stringValue ?? fallbackTaskId,
                attachmentType: attachmentType ?? type ?? (sharedFileId != nil ? "linked" : "upload"),
                fileName: fileName ?? name ?? "Attachment",
                mimeType: mimeType ?? "application/octet-stream",
                size: size ?? 0,
                sharedFileId: sharedFileId)
        }
    }

    func list(taskId: String) async throws -> [AppTaskAttachment] {
        struct R: Decodable { var attachments: [AttachmentDTO] }
        return try await client.request("/tasks/\(taskId)/attachments", as: R.self).attachments.map { $0.toApp(taskId: taskId) }
    }

    /// Links an existing uploaded file (`shared_files` row) to the task.
    struct LinkBody: Encodable { var sharedFileId: String }
    @discardableResult
    func link(taskId: String, sharedFileId: String) async throws -> AppTaskAttachment {
        struct R: Decodable { var attachment: AttachmentDTO }
        return try await client.request("/tasks/\(taskId)/attachments/link", method: "POST",
                                         body: LinkBody(sharedFileId: sharedFileId), as: R.self).attachment.toApp(taskId: taskId)
    }

    func delete(attachmentId: String) async throws {
        _ = try await client.request("/tasks/attachments/\(attachmentId)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// Multipart upload of new bytes as a task attachment. Bypasses the shared
    /// JSON `APIClient` since it needs a different content type and a raw body.
    func upload(taskId: String, fileName: String, mimeType: String, data: Data, serverBaseURL: URL, token: String?) async throws -> AppTaskAttachment {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/tasks/\(taskId)/attachments"))
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
            let message = (try? JSONDecoder().decode([String: String].self, from: respData))?["error"] ?? "Upload failed."
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
        struct R: Decodable { var attachment: AttachmentDTO }
        return try JSONDecoder().decode(R.self, from: respData).attachment.toApp(taskId: taskId)
    }

    /// Authenticated download of an attachment's bytes into a scoped temp file.
    func download(attachmentId: String, fileName: String, serverBaseURL: URL, token: String?) async throws -> URL {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/tasks/attachments/\(attachmentId)/download"))
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Download failed."
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName.isEmpty ? "attachment" : fileName)
        try data.write(to: dest)
        return dest
    }
}
