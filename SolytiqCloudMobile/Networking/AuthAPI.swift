import Foundation

struct AuthAPI {
    let client = APIClient.shared

    struct RegisterBody: Encodable { var username, email, password: String; var fullName: String?; var setupToken: String? }
    struct LoginBody: Encodable { var username: String?; var email: String?; var password: String }
    struct TwoFAVerifyBody: Encodable { var pendingToken: String; var code: String }
    struct ChangePasswordBody: Encodable { var currentPassword: String; var newPassword: String }
    struct TwoFACodeBody: Encodable { var code: String }

    /// `GET /api/auth/setup-required` — true when no admin account exists yet
    /// on a brand-new self-hosted instance (first run).
    func setupRequired() async throws -> Bool {
        struct R: Decodable { var required: Bool }
        return try await client.request("/auth/setup-required", as: R.self).required
    }

    func register(username: String, email: String, password: String, fullName: String?, setupToken: String?) async throws -> APIAuthResponse {
        try await client.request("/auth/register", method: "POST",
                                  body: RegisterBody(username: username, email: email, password: password, fullName: fullName, setupToken: setupToken))
    }

    func login(username: String, password: String) async throws -> APIAuthResponse {
        try await client.request("/auth/login", method: "POST", body: LoginBody(username: username, email: nil, password: password))
    }

    func verify2FA(pendingToken: String, code: String) async throws -> APIAuthResponse {
        try await client.request("/auth/2fa/verify", method: "POST", body: TwoFAVerifyBody(pendingToken: pendingToken, code: code))
    }

    func me() async throws -> AppUser {
        struct R: Decodable { var user: APIUserDTO }
        return try await client.request("/auth/me", as: R.self).user.toApp()
    }

    struct Setup2FAResponse: Decodable { var secret: String; var qrCode: String }
    func setup2FA() async throws -> Setup2FAResponse {
        try await client.request("/auth/2fa/setup", method: "POST")
    }

    func enable2FA(code: String) async throws {
        _ = try await client.request("/auth/2fa/enable", method: "POST", body: TwoFACodeBody(code: code), as: APIClient.EmptyResponse.self)
    }

    func disable2FA(code: String) async throws {
        _ = try await client.request("/auth/2fa/disable", method: "POST", body: TwoFACodeBody(code: code), as: APIClient.EmptyResponse.self)
    }

    func changePassword(current: String, new: String) async throws {
        _ = try await client.request("/auth/password", method: "PUT",
                                      body: ChangePasswordBody(currentPassword: current, newPassword: new), as: APIClient.EmptyResponse.self)
    }

    struct UpdateProfileBody: Encodable { var fullName: String?; var email: String? }
    func updateProfile(fullName: String?, email: String?) async throws -> AppUser {
        struct R: Decodable { var user: APIUserDTO }
        return try await client.request("/auth/profile", method: "PUT", body: UpdateProfileBody(fullName: fullName, email: email), as: R.self).user.toApp()
    }

    struct UpdateAvatarBody: Encodable { var imageData: String? }
    func updateAvatar(base64DataURL: String?) async throws -> AppUser {
        struct R: Decodable { var user: APIUserDTO }
        return try await client.request("/auth/profile-image", method: "PUT", body: UpdateAvatarBody(imageData: base64DataURL), as: R.self).user.toApp()
    }

    struct MemberBasic: Decodable, Identifiable {
        var id: String; var username: String; var fullName: String?; var isAdmin: Bool
    }
    func members() async throws -> [MemberBasic] {
        struct R: Decodable { var members: [MemberBasic] }
        return try await client.request("/auth/members/basic").members
    }

    struct FeatureFlags: Decodable { var twoFAEnabled: Bool; var mcpEnabled: Bool }
    func featureFlags() async throws -> FeatureFlags {
        try await client.request("/auth/feature-flags")
    }
}
