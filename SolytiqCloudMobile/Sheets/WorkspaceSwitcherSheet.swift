import SwiftUI

struct WorkspaceSwitcherSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: AppWorkspace?

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.workspaces) { ws in
                    Button {
                        appState.currentWorkspaceId = ws.id
                        dismiss()
                    } label: {
                        HStack {
                            Text(ws.emoji ?? "🏠")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ws.name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(SCColor.text)
                                Text("\(ws.members.count) member\(ws.members.count == 1 ? "" : "s") · \(ws.role)")
                                    .font(.system(size: 11.5)).foregroundStyle(SCColor.text3)
                            }
                            Spacer()
                            if ws.id == appState.currentWorkspaceId {
                                Image(systemName: "checkmark").foregroundStyle(SCColor.primary)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        if ws.role == "owner" {
                            Button("Delete", role: .destructive) { pendingDelete = ws }
                        }
                        if ws.role == "owner" || ws.role == "admin" {
                            Button("Settings") {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.sheet = .workspaceSettings(ws) }
                            }
                            .tint(SCColor.primary)
                        }
                    }
                }
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.sheet = .workspaceWizard }
                } label: {
                    Label("New Workspace", systemImage: "plus.circle.fill")
                }
            }
            .navigationTitle("Workspaces")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .confirmDelete(isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                           title: "Delete Workspace?", message: "\"\(pendingDelete?.name ?? "")\" and all its lists, folders and timelines are refused deletion while non-empty.") {
                guard let ws = pendingDelete else { return }
                Task { await store.deleteWorkspace(id: ws.id) }
            }
        }
        .presentationDetents([.medium])
    }
}

struct WorkspaceWizardSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var emoji = "🚀"
    @State private var visibility = "private"
    @State private var memberUsername = ""
    @State private var pendingMembers: [String] = []
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                    TextField("Workspace name", text: $name)
                    TextField("Description", text: $description)
                }
                Section("Visibility") {
                    Picker("Visibility", selection: $visibility) {
                        Text("Private").tag("private")
                        Text("Public").tag("public")
                    }
                    .pickerStyle(.segmented)
                }
                Section("Members") {
                    ForEach(pendingMembers, id: \.self) { username in
                        Text(username)
                    }
                    .onDelete { idx in pendingMembers.remove(atOffsets: idx) }
                    HStack {
                        TextField("Username", text: $memberUsername)
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                        Button("Add") {
                            let u = memberUsername.trimmingCharacters(in: .whitespaces)
                            guard !u.isEmpty, !pendingMembers.contains(u) else { return }
                            pendingMembers.append(u)
                            memberUsername = ""
                        }
                    }
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { Task { await create() } }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isCreating)
                }
            }
        }
    }

    private func create() async {
        isCreating = true
        defer { isCreating = false }
        guard let ws = await store.createWorkspace(name: name.trimmingCharacters(in: .whitespaces),
                                                     description: description.isEmpty ? nil : description,
                                                     emoji: emoji, visibility: visibility) else { return }
        for username in pendingMembers {
            try? await store.addWorkspaceMember(workspaceId: ws.id, username: username)
        }
        appState.currentWorkspaceId = ws.id
        dismiss()
    }
}
