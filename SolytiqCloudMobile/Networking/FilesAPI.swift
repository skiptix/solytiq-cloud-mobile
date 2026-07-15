import Foundation

struct FilesAPI {
    let client = APIClient.shared

    func list() async throws -> [AppFileItem] {
        struct R: Decodable { var files: [APIFileDTO] }
        return try await client.request("/files", as: R.self).files.map { $0.toApp() }
    }

    /// The backend's `PUT /api/files/:id` distinguishes "field absent" (leave
    /// untouched) from "field present as null" (clear it). Swift's synthesized
    /// encoder omits nil optionals entirely, so a nil expiry could never *clear*
    /// an expiry. This manual encoder makes that difference explicit: pass
    /// `clearExpiry: true` to send `expiresAt: null` (remove), or an ISO string
    /// to set it; leave both nil to leave expiry as-is.
    struct ShareBody: Encodable {
        var isPublic: Bool?
        var password: String?
        var expiresAt: String?
        var clearExpiry: Bool = false

        enum CodingKeys: String, CodingKey { case isPublic, password, expiresAt }
        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encodeIfPresent(isPublic, forKey: .isPublic)
            try c.encodeIfPresent(password, forKey: .password)
            if clearExpiry {
                try c.encodeNil(forKey: .expiresAt)
            } else {
                try c.encodeIfPresent(expiresAt, forKey: .expiresAt)
            }
        }
    }

    func setShare(id: String, isPublic: Bool?, password: String?, expiresAt: String?, clearExpiry: Bool = false) async throws -> AppFileItem {
        struct R: Decodable { var file: APIFileDTO }
        return try await client.request("/files/\(id)", method: "PUT",
                                         body: ShareBody(isPublic: isPublic, password: password, expiresAt: expiresAt, clearExpiry: clearExpiry), as: R.self).file.toApp()
    }

    func delete(id: String) async throws {
        _ = try await client.request("/files/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }

    /// §5.1 — authoritative per-user quota from the server (`app_settings`),
    /// replacing the client-side sum of listed file sizes.
    struct Storage: Decodable { var used: Int; var quota: Int }
    func storage() async throws -> Storage {
        try await client.request("/files/storage", as: Storage.self)
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

    /// Authenticated owner download. The backend serves file bytes at
    /// `GET /api/files/:id/preview` behind the JWT middleware — there is no
    /// public `/download` route for an owner's own file (that only exists for
    /// share tokens), so opening a bare URL in Safari 404s / 401s. We fetch the
    /// bytes here with the bearer token and hand back a local temp file the UI
    /// can share or preview.
    func download(id: String, fileName: String, serverBaseURL: URL, token: String?) async throws -> URL {
        var request = URLRequest(url: serverBaseURL.appendingPathComponent("api/files/\(id)/preview"))
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? "Download failed."
            throw APIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0, message: message)
        }

        // Write to a uniquely-scoped temp dir so files with the same name don't
        // clobber each other, preserving the original filename for the share sheet.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let dest = dir.appendingPathComponent(fileName.isEmpty ? "download" : fileName)
        try data.write(to: dest)
        return dest
    }
}
