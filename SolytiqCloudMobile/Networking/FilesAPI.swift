import Foundation

struct FilesAPI {
    let client = APIClient.shared

    func list() async throws -> [AppFileItem] {
        struct R: Decodable { var files: [APIFileDTO] }
        return try await client.request("/files", as: R.self).files.map { $0.toApp() }
    }

    struct ShareBody: Encodable { var isPublic: Bool?; var password: String?; var expiresAt: String? }
    func setShare(id: String, isPublic: Bool?, password: String?, expiresAt: String?) async throws -> AppFileItem {
        struct R: Decodable { var file: APIFileDTO }
        return try await client.request("/files/\(id)", method: "PUT",
                                         body: ShareBody(isPublic: isPublic, password: password, expiresAt: expiresAt), as: R.self).file.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/files/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// Uploads via `multipart/form-data`, bypassing the shared JSON
    /// `APIClient` since this one request needs a different content type and
    /// a raw byte body. Storage quota / max-size errors surface the same way
    /// as any other server error.
    func upload(fileName: String, mimeType: String, data: Data, serverBaseURL: URL, token: String?) async throws -> AppFileItem {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/files"))
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
        struct R: Decodable { var file: APIFileDTO }
        let decoded = try JSONDecoder().decode(R.self, from: respData)
        return decoded.file.toApp()
    }

    func downloadURL(id: String, serverBaseURL: URL) -> URL {
        serverBaseURL.appendingPathComponent("api/files/\(id)/download")
    }
}
