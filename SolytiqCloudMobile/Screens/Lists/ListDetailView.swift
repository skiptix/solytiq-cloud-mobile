import SwiftUI

struct ListDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss

    var listId: String
    @State private var list: AppList?
    @State private var showAddSection = false
    @State private var newSectionName = ""
    @State private var confirmDelete = false
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            if let list {
                VStack(spacing: 16) {
                    hero(list)
                    ForEach(list.sections) { section in
                        sectionBlock(section)
                    }
                    Button {
                        showAddSection = true
                    } label: {
                        Label("Add Section", systemImage: "plus").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.top, 4)
                }
                .padding(.bottom, 100)
                .padding(.top, 8)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(SCColor.page)
        .navigationTitle(list?.name ?? "List")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit List", systemImage: "pencil") { showEdit = true }
                    Button("Delete List", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .alert("New Section", isPresented: $showAddSection) {
            TextField("Section name", text: $newSectionName)
            Button("Add") { Task { await addSection() } }
            Button("Cancel", role: .cancel) { newSectionName = "" }
        }
        .sheet(isPresented: $showEdit) {
            if let list { EditListSheet(list: list) { await reload() } }
        }
        .confirmDelete(isPresented: $confirmDelete, title: "Delete List?", message: "\"\(list?.name ?? "")\" and everything in it will move to Trash.") {
            Task { await store.deleteList(id: listId); dismiss() }
        }
        .task { await reload() }
        .refreshable { await reload() }
    }

    private func hero(_ list: AppList) -> some View {
        VStack(spacing: 10) {
            Text(list.emoji ?? "📋").font(.system(size: 40))
            Text(list.name).font(.system(size: 22, weight: .bold))
            if let subtitle = list.subtitle, !subtitle.isEmpty {
                Text(subtitle).font(.system(size: 13)).foregroundStyle(SCColor.text3)
            }
            HStack {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SCColor.hover)
                        Capsule().fill(Color(hex: list.colorHex)).frame(width: geo.size.width * list.progress)
                    }
                }
                .frame(height: 8)
                Text("\(Int(list.progress * 100))%").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: list.colorHex))
            }
            .padding(.horizontal, 24)
            Text("\(list.doneTasks) of \(list.totalTasks) complete").font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
        }
        .padding(.vertical, 20)
    }

    private func sectionBlock(_ section: AppSection) -> some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "\(section.emoji.map { "\($0) " } ?? "")\(section.label)", rightText: "\(section.tasks.count)")
            if section.tasks.isEmpty {
                Card { EmptyRowView(text: "No tasks yet.") }
            } else {
                Card {
                    ForEach(Array(section.tasks.enumerated()), id: \.element.id) { idx, task in
                        TaskRowView(task: task, showDivider: idx < section.tasks.count - 1) {
                            Task { await toggle(task) }
                        } onTap: {
                            router.sheet = .editTask(task)
                        }
                    }
                }
            }
            Button {
                router.sheet = .addTask(listId: listId, sectionId: section.id, presetDeadline: nil)
            } label: {
                Label("Add Task", systemImage: "plus").font(.system(size: 12.5, weight: .semibold))
            }
            .padding(.top, 8)
        }
    }

    private func toggle(_ task: AppTask) async {
        var updated = task
        updated.checked.toggle()
        await store.updateTask(updated)
        await reload()
    }

    private func addSection() async {
        let name = newSectionName.trimmingCharacters(in: .whitespaces)
        newSectionName = ""
        guard !name.isEmpty else { return }
        await store.addSection(listId: listId, label: name, emoji: nil)
        await reload()
    }

    private func reload() async {
        list = await store.lists().first { $0.id == listId }
    }
}

struct EditListSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var list: AppList
    var onSave: () async -> Void

    @State private var name: String
    @State private var subtitle: String
    @State private var emoji: String
    @State private var colorHex: String

    init(list: AppList, onSave: @escaping () async -> Void) {
        self.list = list
        self.onSave = onSave
        _name = State(initialValue: list.name)
        _subtitle = State(initialValue: list.subtitle ?? "")
        _emoji = State(initialValue: list.emoji ?? "📋")
        _colorHex = State(initialValue: list.colorHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                    TextField("Name", text: $name)
                    TextField("Subtitle", text: $subtitle)
                }
                Section("Color") {
                    HStack(spacing: 10) {
                        ForEach(["#5e4dbb", "#10B981", "#ea580c", "#2563EB", "#db2777"], id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            var updated = list
                            updated.name = name; updated.subtitle = subtitle.isEmpty ? nil : subtitle
                            updated.emoji = emoji; updated.colorHex = colorHex
                            await store.updateList(updated)
                            await onSave()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
