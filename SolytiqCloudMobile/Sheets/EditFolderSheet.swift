import SwiftUI

/// §3 — edit a folder's name/emoji/color and its public/private visibility.
struct EditFolderSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var folder: AppFolder
    var onSave: () async -> Void

    @State private var name: String
    @State private var emoji: String
    @State private var colorHex: String
    @State private var isPublic: Bool

    init(folder: AppFolder, onSave: @escaping () async -> Void) {
        self.folder = folder
        self.onSave = onSave
        _name = State(initialValue: folder.name)
        _emoji = State(initialValue: folder.emoji ?? "📁")
        _colorHex = State(initialValue: folder.colorHex)
        _isPublic = State(initialValue: folder.isPublic)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                    TextField("Name", text: $name)
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(["#10B981", "#5e4dbb", "#ea580c", "#2563EB", "#db2777"], id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
                Section("Visibility") {
                    VisibilityToggle(isPublic: $isPublic)
                }
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await store.updateFolder(id: folder.id, name: name.trimmingCharacters(in: .whitespaces),
                                                     emoji: emoji, colorHex: colorHex, isPublic: isPublic)
                            await onSave()
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// §3 — the two-button lock/globe visibility selector, matching the web design
/// system. Reusable by folder/list/workspace settings.
struct VisibilityToggle: View {
    @Binding var isPublic: Bool

    var body: some View {
        HStack(spacing: 10) {
            option(title: "Private", systemImage: "lock.fill", active: !isPublic) { isPublic = false }
            option(title: "Public", systemImage: "globe", active: isPublic) { isPublic = true }
        }
    }

    private func option(title: String, systemImage: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title).font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(active ? SCColor.primaryBg : SCColor.hover))
            .foregroundStyle(active ? SCColor.primary : SCColor.text3)
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(active ? SCColor.primary : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// §3 — move a folder (and its lists) into another workspace.
struct MoveFolderSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var folder: AppFolder
    var onMoved: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(appState.workspaces) { ws in
                    if ws.id != appState.currentWorkspaceId {
                        Button {
                            Task {
                                await store.moveFolderToWorkspace(id: folder.id, workspaceId: ws.id)
                                dismiss()
                                onMoved()
                            }
                        } label: {
                            HStack {
                                Text(ws.emoji ?? "🏠")
                                Text(ws.name).foregroundStyle(SCColor.text)
                                Spacer()
                                Image(systemName: "arrow.right").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .presentationDetents([.medium])
    }
}
