import Foundation
import SwiftUI

/// Which "home" the app's data currently lives in. This is the single
/// switch every screen and repository method branches on.
enum AppMode: String, Codable, Hashable {
    case local
    case server
}

@MainActor
final class AppState: ObservableObject {
    /// The delta-sync engine for server mode (bootstrap + SSE nudges + delta
    /// pulls, mirroring the web frontend's useSyncStore). Owned here because
    /// AppState owns the server session lifecycle; injected into the view
    /// tree as its own EnvironmentObject so screens observe it directly.
    let sync = SyncEngine()

    @Published var mode: AppMode?
    @Published var currentUser: AppUser?
    @Published var serverURL: URL?
    @Published var featureFlags: AuthAPI.FeatureFlags?
    /// Set by Settings when the user taps "Connect to Server" from local
    /// mode — presented as a full-screen cover regardless of current mode,
    /// separate from the `mode == .server && currentUser == nil` case that
    /// covers session-expiry re-login.
    @Published var showConnectFlow = false

    @Published var appearanceShape: AppearanceShape
    @Published var appearanceDensity: AppearanceDensity
    @Published var accentPaletteIndex: Int
    /// Theme preference (System / Light / Dark). Defaults to Light.
    @Published var colorSchemePref: SCColorSchemePreference
    @Published var localUsername: String
    @Published var localProfileImageBase64: String?

    @Published var isRestoringSession = true
    @Published var currentWorkspaceId: String? {
        didSet {
            guard mode == .server, currentWorkspaceId != oldValue else { return }
            sync.workspaceChanged(currentWorkspaceId)
        }
    }
    @Published var workspaces: [AppWorkspace] = []

    private let defaults = UserDefaults.standard
    private let modeKey = "sc.mode"

    init() {
        if let raw = defaults.string(forKey: modeKey), let m = AppMode(rawValue: raw) {
            mode = m
        }
        appearanceShape = AppearanceShape(rawValue: defaults.string(forKey: "sc.shape") ?? "") ?? .rounded
        appearanceDensity = AppearanceDensity(rawValue: defaults.string(forKey: "sc.density") ?? "") ?? .regular
        accentPaletteIndex = defaults.integer(forKey: "sc.palette")
        colorSchemePref = SCColorSchemePreference(rawValue: defaults.string(forKey: "sc.colorScheme") ?? "") ?? .light
        localUsername = defaults.string(forKey: "sc.localUsername") ?? "You"
        localProfileImageBase64 = defaults.string(forKey: "sc.localAvatar")

        // The server revoked this device (connection removed, or admin disabled
        // mobile access instance-wide) — sign out and return to the mode picker.
        NotificationCenter.default.addObserver(forName: .scSessionInvalidated, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.handleSessionInvalidated() }
        }

        // A `workspace` sync signal means membership/visibility changed — the
        // workspace list (and possibly access to the current one) is stale.
        sync.onWorkspacesChanged = { [weak self] in
            await self?.reloadWorkspaces()
        }
    }

    /// Refresh the workspace list; if the current workspace disappeared (we
    /// were removed / it was deleted), fall back to another one — the didSet
    /// on `currentWorkspaceId` re-bootstraps the sync engine.
    func reloadWorkspaces() async {
        guard mode == .server else { return }
        workspaces = (try? await WorkspacesAPI().list()) ?? workspaces
        if let current = currentWorkspaceId, !workspaces.contains(where: { $0.id == current }) {
            currentWorkspaceId = workspaces.first(where: { $0.role == "owner" })?.id ?? workspaces.first?.id
        }
    }

    private func handleSessionInvalidated() async {
        guard mode == .server, currentUser != nil else { return }
        await signOutOfServer()
    }

    var metrics: SCMetrics {
        var m: SCMetrics
        switch appearanceShape {
        case .sharp: m = .sharp
        case .rounded: m = .rounded
        case .bubbly: m = .bubbly
        }
        let d = SCMetrics.density(appearanceDensity)
        m.rowPadding = d.row
        m.cardPadding = d.card
        return m
    }

    static let accentPalettes: [[String]] = [
        ["#5e4dbb", "#9d8dff", "#F5F3FF"],
        ["#2563EB", "#60a5fa", "#eff6ff"],
        ["#059669", "#34d399", "#ecfdf5"],
        ["#db2777", "#f472b6", "#fdf2f8"],
    ]

    // MARK: - Bootstrapping

    /// Called once at launch: if we previously connected to a server, try to
    /// restore that session silently; otherwise (or on failure) fall back to
    /// whatever local/no-mode state was persisted.
    func restoreSession() async {
        defer { isRestoringSession = false }
        guard mode == .server,
              let urlString = KeychainStore.get(KeychainStore.Key.serverURL),
              let url = URL(string: urlString),
              let token = KeychainStore.get(KeychainStore.Key.authToken) else {
            return
        }
        serverURL = url
        await APIClient.shared.configure(baseURL: url, token: token)
        do {
            currentUser = try await AuthAPI().me()
            featureFlags = try? await AuthAPI().featureFlags()
            workspaces = (try? await WorkspacesAPI().list()) ?? []
            currentWorkspaceId = workspaces.first(where: { $0.role == "owner" })?.id ?? workspaces.first?.id
            sync.start(baseURL: url, token: token, workspaceId: currentWorkspaceId)
        } catch {
            // Token expired or server unreachable — drop back to the mode
            // picker rather than silently failing inside the shell.
            await signOutOfServer()
        }
    }

    func selectLocalMode() {
        mode = .local
        defaults.set(AppMode.local.rawValue, forKey: modeKey)
    }

    func didConnectToServer(url: URL, token: String, user: AppUser, connectionId: String? = nil) async {
        serverURL = url
        currentUser = user
        mode = .server
        showConnectFlow = false
        defaults.set(AppMode.server.rawValue, forKey: modeKey)
        KeychainStore.set(url.absoluteString, for: KeychainStore.Key.serverURL)
        KeychainStore.set(token, for: KeychainStore.Key.authToken)
        if let connectionId { KeychainStore.set(connectionId, for: KeychainStore.Key.connectionId) }
        await APIClient.shared.configure(baseURL: url, token: token)
        featureFlags = try? await AuthAPI().featureFlags()
        workspaces = (try? await WorkspacesAPI().list()) ?? []
        currentWorkspaceId = workspaces.first(where: { $0.role == "owner" })?.id ?? workspaces.first?.id
        sync.start(baseURL: url, token: token, workspaceId: currentWorkspaceId)
    }

    func signOutOfServer() async {
        sync.stop()
        KeychainStore.remove(KeychainStore.Key.authToken)
        KeychainStore.remove(KeychainStore.Key.serverURL)
        KeychainStore.remove(KeychainStore.Key.connectionId)
        await APIClient.shared.configure(baseURL: nil, token: nil)
        currentUser = nil
        serverURL = nil
        workspaces = []
        currentWorkspaceId = nil
        mode = nil
        defaults.removeObject(forKey: modeKey)
    }

    /// Switching from a connected server back to "On This Phone" (or vice
    /// versa) intentionally does **not** migrate data — the two stores are
    /// independent, matching the prototype's explicit "local data will not
    /// sync" warning shown before this call.
    func switchToLocalMode() async {
        await signOutOfServer()
        selectLocalMode()
    }

    func updateLocalProfile(username: String, avatarBase64: String?) {
        localUsername = username
        localProfileImageBase64 = avatarBase64
        defaults.set(username, forKey: "sc.localUsername")
        if let avatarBase64 { defaults.set(avatarBase64, forKey: "sc.localAvatar") } else { defaults.removeObject(forKey: "sc.localAvatar") }
    }

    func updateAppearance(shape: AppearanceShape? = nil, density: AppearanceDensity? = nil, paletteIndex: Int? = nil) {
        if let shape { appearanceShape = shape; defaults.set(shape.rawValue, forKey: "sc.shape") }
        if let density { appearanceDensity = density; defaults.set(density.rawValue, forKey: "sc.density") }
        if let paletteIndex { accentPaletteIndex = paletteIndex; defaults.set(paletteIndex, forKey: "sc.palette") }
    }

    func updateColorScheme(_ pref: SCColorSchemePreference) {
        colorSchemePref = pref
        defaults.set(pref.rawValue, forKey: "sc.colorScheme")
    }
}
