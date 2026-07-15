import SwiftUI

/// §4.1 / §4.2 — edit a workspace's metadata and manage its members. Mirrors
/// web's `WorkspaceSettingsModal`. Member removal is gated to owner/admin.
struct WorkspaceSettingsSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var workspace: AppWorkspace

    @State private var name: String
    @State private var description: String
    @State private var emoji: String
    @State private var visibility: String
    @State private var members: [AppWorkspaceMember]
    @State private var newMemberUsername = ""
    @State private var pendingRemoval: AppWorkspaceMember?
    @State private var isSaving = false

    init(workspace: AppWorkspace) {
        self.workspace = workspace
        _name = State(initialValue: workspace.name)
        _description = State(initialValue: workspace.description ?? "")
        _emoji = State(initialValue: workspace.emoji ?? "🏠")
        _visibility = State(initialValue: workspace.visibility)
        _members = State(initialValue: workspace.members)
    }

    private var canManage: Bool { workspace.role == "owner" || workspace.role == "admin" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }
                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                    }
                    .pickerStyle(.segmented)
                    .disabled(!canManage)
                }

                Section("Members") {
                    ForEach(members) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.fullName ?? member.username).font(.system(size: 14))
                                Text(member.role).font(.system(size: 11)).foregroundStyle(SCColor.text4)
                            }
                            Spacer()
                            if member.role == "owner" {
                                Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(SCColor.primary)
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            if canManage && member.role != "owner" {
                                Button("Remove", role: .destructive) { pendingRemoval = member }
                            }
                        }
                    }
                    if canManage {
                        HStack {
                            TextField("Add member by username", text: $newMemberUsername)
                                .textInputAutocapitalization(.never).autocorrectionDisabled()
                            Button("Add") { Task { await addMember() } }
                                .disabled(newMemberUsername.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Workspace Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!canManage || isSaving || name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmDelete(isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
                           title: "Remove Member?",
                           message: "\(pendingRemoval?.fullName ?? pendingRemoval?.username ?? "This member") will lose access to \"\(workspace.name)\".",
                           confirmLabel: "Remove") {
                guard let member = pendingRemoval else { return }
                Task { await removeMember(member) }
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        _ = await store.updateWorkspace(id: workspace.id, name: name.trimmingCharacters(in: .whitespaces),
                                         description: description.isEmpty ? nil : description,
                                         emoji: emoji, visibility: visibility)
        dismiss()
    }

    private func addMember() async {
        let u = newMemberUsername.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty else { return }
        try? await store.addWorkspaceMember(workspaceId: workspace.id, username: u)
        newMemberUsername = ""
        members = appState.workspaces.first { $0.id == workspace.id }?.members ?? members
    }

    private func removeMember(_ member: AppWorkspaceMember) async {
        await store.removeWorkspaceMember(workspaceId: workspace.id, userId: member.id)
        members.removeAll { $0.id == member.id }
    }
}
