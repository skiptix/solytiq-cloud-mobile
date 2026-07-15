import Foundation
import Security

/// Minimal Keychain wrapper for the two secrets a server connection needs:
/// the JWT and the server's base URL. Deliberately dependency-free (no
/// third-party keychain wrapper) to keep the app lean.
enum KeychainStore {
    private static let service = "cloud.solytiq.mobile"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }

    enum Key {
        static let authToken = "auth_token"
        static let serverURL = "server_url"
        static let username = "username"
        static let pendingTwoFAToken = "pending_2fa_token"
        /// Id of this device's `mobile_connections` row, so Settings → Devices
        /// can mark the current session. Set at login, cleared on sign-out.
        static let connectionId = "connection_id"
    }
}
