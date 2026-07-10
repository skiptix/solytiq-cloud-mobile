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

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                appearanceSection
                if appState.mode == .server {
                    securitySection
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
            .confirmDelete(isPresented: $confirmSignOut, title: "Sign Out?", message: "You'll need to sign in again to reconnect to this server.", confirmLabel: "Sign Out") {
                Task { await appState.signOutOfServer() }
            }
            .confirmDelete(isPresented: $showSwitchWarning, title: "Local data will not sync", message: "Switching modes does not migrate data between \"On This Phone\" and a server. Your current data stays where it is.", confirmLabel: "Continue") {
                Task { await appState.switchToLocalMode(); dismiss() }
            }
            .task { if appState.mode == .server { members = (try? await AuthAPI().members()) ?? [] } }
        }
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
