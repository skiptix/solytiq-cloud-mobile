import SwiftUI
import PhotosUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var fullName: String = ""
    @State private var email: String = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var members: [AuthAPI.MemberBasic] = []
    @State private var showSwitchWarning = false
    @State private var showChangePassword = false
    @State private var confirmSignOut = false

    // §14 connected agents/tokens · §17 device sessions · §12 CalDAV
    @State private var tokens: [AppConnectedToken] = []
    @State private var connections: [AppMobileConnection] = []
    @State private var pendingTokenRevoke: AppConnectedToken?
    @State private var pendingConnectionRevoke: AppMobileConnection?
    @State private var caldavStatus: CalDAVAPI.Status?
    @State private var caldavPassword: String?
    @State private var caldavURL: String?
    @State private var caldavUsername: String?
    @State private var showOpenSharedLink = false

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appearanceSection
                if appState.mode == .server {
                    securitySection
                    Section {
                        Button { showOpenSharedLink = true } label: {
                            Label("Open a Shared Link", systemImage: "link")
                        }
                    }
                    devicesSection
                    connectedAppsSection
                    calDAVSection
                    usersSection
                    Section {
                        Text("More settings are available in the web interface of your self-hosted instance — storage quotas, server config, SMTP and danger zone.")
                            .font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
                    }
                }
                storageSection
                if appState.mode == .server {
                    Section {
                        Button("Sign Out", role: .destructive) { confirmSignOut = true }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .onAppear(perform: populate)
            .onChange(of: photoItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
            .sheet(isPresented: $showChangePassword) { ChangePasswordSheet() }
            .sheet(isPresented: $showOpenSharedLink) { OpenSharedLinkSheet() }
            .confirmDelete(isPresented: $confirmSignOut, title: "Sign Out?", message: "You'll need to sign in again to reconnect to this server.", confirmLabel: "Sign Out") {
                Task { await appState.signOutOfServer() }
            }
            .confirmDelete(isPresented: $showSwitchWarning, title: "Local data will not sync", message: "Switching modes does not migrate data between \"On This Phone\" and a server. Your current data stays where it is.", confirmLabel: "Continue") {
                Task { await appState.switchToLocalMode(); dismiss() }
            }
            .confirmDelete(isPresented: Binding(get: { pendingTokenRevoke != nil }, set: { if !$0 { pendingTokenRevoke = nil } }),
                           title: "Disconnect App?",
                           message: "\(pendingTokenRevoke?.name ?? "This app") will lose access to your account.",
                           confirmLabel: "Disconnect") {
                guard let token = pendingTokenRevoke else { return }
                Task { await store.revokeToken(id: token.id); tokens.removeAll { $0.id == token.id } }
            }
            .confirmDelete(isPresented: Binding(get: { pendingConnectionRevoke != nil }, set: { if !$0 { pendingConnectionRevoke = nil } }),
                           title: "Sign Out Device?",
                           message: "\(pendingConnectionRevoke?.deviceName ?? "That device") will be signed out of this account.",
                           confirmLabel: "Sign Out") {
                guard let conn = pendingConnectionRevoke else { return }
                Task { await store.revokeMobileConnection(id: conn.id); connections.removeAll { $0.id == conn.id } }
            }
            .task {
                guard appState.mode == .server else { return }
                members = (try? await AuthAPI().members()) ?? []
                connections = await store.mobileConnections()
                tokens = await store.connectedTokens()
                caldavStatus = try? await CalDAVAPI().status()
                caldavURL = caldavStatus?.url
                caldavUsername = caldavStatus?.username
            }
        }
    }

    // MARK: §17 — device sessions

    private var devicesSection: some View {
        Section("Devices") {
            if connections.isEmpty {
                Text("No other active sessions.").font(.system(size: 12.5)).foregroundStyle(SCColor.text4)
            }
            ForEach(connections) { conn in
                HStack {
                    Image(systemName: conn.isCurrent ? "iphone.gen3.circle.fill" : "iphone.gen3")
                        .foregroundStyle(conn.isCurrent ? SCColor.primary : SCColor.text4)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conn.deviceName ?? conn.deviceModel ?? "Unknown device").font(.system(size: 14))
                        Text(deviceSubtitle(conn)).font(.system(size: 11)).foregroundStyle(SCColor.text4)
                    }
                    Spacer()
                    if conn.isCurrent {
                        Text("This device").font(.system(size: 10, weight: .bold)).foregroundStyle(SCColor.primary)
                    }
                }
                .swipeActions(edge: .trailing) {
                    if !conn.isCurrent {
                        Button("Sign Out", role: .destructive) { pendingConnectionRevoke = conn }
                    }
                }
            }
        }
    }

    private func deviceSubtitle(_ conn: AppMobileConnection) -> String {
        var parts: [String] = []
        if let os = conn.osVersion { parts.append(os) }
        if let v = conn.appVersion { parts.append("v\(v)") }
        if let seen = conn.lastSeenAt {
            let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
            parts.append(f.localizedString(for: seen, relativeTo: .now))
        }
        return parts.joined(separator: " · ")
    }

    // MARK: §14 — connected external apps (MCP tokens)

    private var connectedAppsSection: some View {
        Section {
            if tokens.isEmpty {
                Text("No external apps connected. Connect Claude (or another MCP client) from the web to see it here.")
                    .font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
            }
            ForEach(tokens) { token in
                HStack {
                    Image(systemName: "app.connected.to.app.below.fill").foregroundStyle(SCColor.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(token.name).font(.system(size: 14))
                        if let created = token.createdAt {
                            Text("Connected \(created.formatted(date: .abbreviated, time: .omitted))")
                                .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                        }
                    }
                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button("Revoke", role: .destructive) { pendingTokenRevoke = token }
                }
            }
        } header: {
            Text("Connected Apps")
        }
    }

    // MARK: §12 — CalDAV credential management

    private var calDAVSection: some View {
        Section {
            if let password = caldavPassword {
                VStack(alignment: .leading, spacing: 6) {
                    Text("App password (shown once — copy it now):")
                        .font(.system(size: 11.5)).foregroundStyle(SCColor.text3)
                    HStack {
                        Text(password).font(.system(size: 13, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Button { UIPasteboard.general.string = password } label: { Image(systemName: "doc.on.doc") }
                    }
                }
            }
            if let url = caldavURL, !url.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CalDAV URL").font(.system(size: 12, weight: .medium))
                        Text(url).font(.system(size: 11, design: .monospaced)).foregroundStyle(SCColor.text4).lineLimit(1)
                    }
                    Spacer()
                    Button { UIPasteboard.general.string = url } label: { Image(systemName: "doc.on.doc") }
                }
            }
            Button("Generate App Password") { Task { await generateCalDAVPassword() } }
            if caldavStatus?.configured == true {
                Button("Revoke CalDAV Access", role: .destructive) {
                    Task { try? await CalDAVAPI().revoke(); caldavStatus = try? await CalDAVAPI().status(); caldavPassword = nil }
                }
            }
            Text("Add this as a CalDAV account in iOS Settings → Calendar → Accounts to sync your Solytiq calendar into the native Calendar app.")
                .font(.system(size: 11)).foregroundStyle(SCColor.text4)
        } header: {
            Text("Calendar Sync (CalDAV)")
        }
    }

    private func generateCalDAVPassword() async {
        guard let generated = try? await CalDAVAPI().generatePassword() else { return }
        caldavPassword = generated.password
        if let url = generated.url { caldavURL = url }
        if let user = generated.username { caldavUsername = user }
        caldavStatus = try? await CalDAVAPI().status()
    }

    private var profileSection: some View {
        Section("Profile") {
            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    ZStack {
                        if let avatarImage {
                            Circle().fill(LinearGradient(colors: [Color(hex: "#b59cff"), SCColor.primary], startPoint: .topLeading, endPoint: .bottomTrailing))
                            avatarImage.resizable().scaledToFill().clipShape(Circle())
                        } else {
                            ProfileAvatarView(base64DataURL: storedAvatar, initials: initials, size: 64, fontSize: 20)
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                VStack(alignment: .leading, spacing: 6) {
                    if appState.mode == .server {
                        TextField("Full name", text: $fullName).font(.system(size: 15, weight: .semibold))
                        TextField("Email", text: $email).font(.system(size: 13)).foregroundStyle(SCColor.text3)
                    } else {
                        TextField("Your name", text: $username).font(.system(size: 15, weight: .semibold))
                    }
                }
                .padding(.leading, 8)
            }
            Button("Save Profile") { Task { await saveProfile() } }
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: Binding(get: { appState.colorSchemePref }, set: { appState.updateColorScheme($0) })) {
                ForEach(SCColorSchemePreference.allCases, id: \.self) { pref in
                    Text(pref.label).tag(pref)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Button { router.sheet = .twoFASetup } label: {
                HStack {
                    Label("Two-Factor Authentication", systemImage: "lock.shield")
                    Spacer()
                    Text(appState.currentUser?.totpEnabled == true ? "On" : "Off").foregroundStyle(SCColor.text4)
                }
            }
            Button("Change Password") { showChangePassword = true }
        }
    }

    private var usersSection: some View {
        Section("Users") {
            ForEach(members) { m in
                HStack {
                    Text(m.fullName ?? m.username).font(.system(size: 14))
                    Spacer()
                    if m.isAdmin { Text("Admin").font(.system(size: 11)).foregroundStyle(SCColor.primary) }
                }
            }
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            HStack {
                Label("On This Phone", systemImage: "iphone")
                Spacer()
                if appState.mode == .local { Image(systemName: "checkmark").foregroundStyle(SCColor.primary) }
            }
            .contentShape(Rectangle())
            .onTapGesture { if appState.mode != .local { showSwitchWarning = true } }

            HStack {
                Label("Connect to Server", systemImage: "icloud")
                Spacer()
                if appState.mode == .server { Image(systemName: "checkmark").foregroundStyle(SCColor.primary) }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if appState.mode != .server {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        appState.showConnectFlow = true
                    }
                }
            }
        }
    }

    private var initials: String {
        let name = appState.mode == .server ? (appState.currentUser?.fullName ?? appState.currentUser?.username ?? "U") : appState.localUsername
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap { $0.first }).uppercased()
    }

    /// The persisted avatar for the active mode — the server profile image when
    /// connected, the local avatar otherwise. Shown until a new pick replaces it.
    private var storedAvatar: String? {
        appState.mode == .server ? appState.currentUser?.profileImageBase64 : appState.localProfileImageBase64
    }

    private func populate() {
        username = appState.localUsername
        fullName = appState.currentUser?.fullName ?? ""
        email = appState.currentUser?.email ?? ""
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        if let uiImage = UIImage(data: data) { avatarImage = Image(uiImage: uiImage) }
        let base64 = "data:image/jpeg;base64," + data.base64EncodedString()
        if appState.mode == .server {
            if let user = try? await AuthAPI().updateAvatar(base64DataURL: base64) { appState.currentUser = user }
        } else {
            appState.updateLocalProfile(username: username, avatarBase64: base64)
        }
    }

    private func saveProfile() async {
        if appState.mode == .server {
            if let user = try? await AuthAPI().updateProfile(fullName: fullName, email: email) { appState.currentUser = user }
        } else {
            appState.updateLocalProfile(username: username, avatarBase64: appState.localProfileImageBase64)
        }
    }
}

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new = ""
    @State private var confirm = ""
    @State private var errorMessage: String?

    private var canSave: Bool { !current.isEmpty && new.count >= 8 && new == confirm }

    var body: some View {
        NavigationStack {
            Form {
                SecureField("Current password", text: $current)
                SecureField("New password", text: $new)
                SecureField("Confirm new password", text: $confirm)
                if let errorMessage {
                    Text(errorMessage).font(.system(size: 12)).foregroundStyle(SCColor.danger)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
        }
    }

    private func save() async {
        do {
            try await AuthAPI().changePassword(current: current, new: new)
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Couldn't change password."
        }
    }
}
