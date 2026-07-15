import Foundation
import UIKit

/// Descriptor sent to the server on login so a signed-in device can be shown
/// and revoked from the web (Account Settings → Mobile). Matches the `device`
/// shape read by `backend/src/routes/auth.ts`.
struct DeviceInfo: Encodable {
    var name: String
    var model: String
    var osVersion: String
    var appVersion: String

    static func current() -> DeviceInfo {
        let d = UIDevice.current
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        let version = (build?.isEmpty == false) ? "\(short) (\(build!))" : short
        return DeviceInfo(
            name: d.name,
            model: d.model,
            osVersion: "\(d.systemName) \(d.systemVersion)",
            appVersion: version
        )
    }
}

struct AuthAPI {
    let client = APIClient.shared

    /// Marks a request as coming from the mobile app so the server registers a
    /// revocable `mobile_connections` row and gates it behind the admin's
    /// instance-wide "allow mobile app" setting.
    static let clientTag = "mobile"

    struct RegisterBody: Encodable { var username, email, password: String; var fullName: String?; var setupToken: String? }
    struct LoginBody: Encodable { var username: String?; var email: String?; var password: String; var client: String?; var device: DeviceInfo? }
    struct TwoFAVerifyBody: Encodable { var pendingToken: String; var code: String; var client: String?; var device: DeviceInfo? }
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
        try await client.request("/auth/login", method: "POST",
                                  body: LoginBody(username: username, email: nil, password: password,
                                                  client: AuthAPI.clientTag, device: DeviceInfo.current()))
    }

    func verify2FA(pendingToken: String, code: String) async throws -> APIAuthResponse {
        try await client.request("/auth/2fa/verify", method: "POST",
                                  body: TwoFAVerifyBody(pendingToken: pendingToken, code: code,
                                                        client: AuthAPI.clientTag, device: DeviceInfo.current()))
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
        return try await client.request("/auth/members/basic", as: R.self).members
    }

    struct FeatureFlags: Decodable { var twoFAEnabled: Bool; var mcpEnabled: Bool }
    func featureFlags() async throws -> FeatureFlags {
        try await client.request("/auth/feature-flags")
    }

    // MARK: §17 — this account's mobile app sessions (`mobile_connections`).

    struct MobileConnectionDTO: Decodable {
        var id: IntOrString
        var deviceName: String?
        var deviceModel: String?
        var osVersion: String?
        var appVersion: String?
        var lastSeenAt: String?
        var createdAt: String?
        func toApp(currentId: String?) -> AppMobileConnection {
            let idStr = id.stringValue
            return AppMobileConnection(id: idStr, deviceName: deviceName, deviceModel: deviceModel,
                                        osVersion: osVersion, appVersion: appVersion,
                                        lastSeenAt: ServerDate.parse(lastSeenAt), createdAt: ServerDate.parse(createdAt),
                                        isCurrent: currentId != nil && idStr == currentId)
        }
    }

    func mobileConnections(currentId: String?) async throws -> [AppMobileConnection] {
        struct R: Decodable { var connections: [MobileConnectionDTO] }
        return try await client.request("/auth/mobile-connections", as: R.self).connections.map { $0.toApp(currentId: currentId) }
    }

    func revokeMobileConnection(id: String) async throws {
        _ = try await client.request("/auth/mobile-connections/\(id)", method: "DELETE", as: APIClient.EmptyResponse.self)
    }
}
