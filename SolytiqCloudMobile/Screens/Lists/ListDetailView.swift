import SwiftUI

struct ListDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    var listId: String
    @State private var list: AppList?
    @State private var mode: ListViewMode = .list
    @State private var didInitMode = false
    @State private var showAddSection = false
    @State private var newSectionName = ""
    @State private var confirmDelete = false
    @State private var showEdit = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var templateSavedBanner = false

    var body: some View {
        Group {
            if let list {
                if mode == .kanban {
                    VStack(spacing: 12) {
                        hero(list).padding(.top, 8)
                        modePicker(list)
                        KanbanListView(list: list,
                                       onToggle: { task in Task { await toggle(task) } },
                                       onTapTask: { task in router.sheet = .editTask(task) },
                                       onAddTask: { sectionId in router.sheet = .addTask(listId: listId, sectionId: sectionId, presetDeadline: nil) })
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            hero(list)
                            modePicker(list)
                            if mode == .timeline {
                                timelinePlaceholder
                            } else {
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
                        }
                        .padding(.bottom, 100)
                        .padding(.top, 8)
                    }
                }
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
                    if appState.mode == .server {
                        Button("Save as Template", systemImage: "square.on.square") {
                            templateName = list?.name ?? ""
                            showSaveTemplate = true
                        }
                    }
                    Button("Delete List", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .alert("New Section", isPresented: $showAddSection) {
            TextField("Section name", text: $newSectionName)
            Button("Add") { Task { await addSection() } }
            Button("Cancel", role: .cancel) { newSectionName = "" }
        }
        .alert("Save as Template", isPresented: $showSaveTemplate) {
            TextField("Template name", text: $templateName)
            Button("Save") {
                Task {
                    let name = templateName.trimmingCharacters(in: .whitespaces)
                    if (try? await store.saveAsTemplate(type: "list", sourceId: listId,
                                                         name: name.isEmpty ? nil : name,
                                                         description: nil, isShared: false)) != nil {
                        templateSavedBanner = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Snapshots this list's sections and tasks (dates become relative) so you can reuse it from Add → From Template.")
        }
        .alert("Template saved", isPresented: $templateSavedBanner) {
            Button("OK") {}
        }
        .sheet(isPresented: $showEdit) {
            if let list { EditListSheet(list: list) { await reload() } }
        }
        .confirmDelete(isPresented: $confirmDelete, title: "Delete List?", message: "\"\(list?.name ?? "")\" and everything in it will move to Trash.") {
            Task { await store.deleteList(id: listId); dismiss() }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .onChange(of: sync.revision) { _, _ in
            Task { await reload() }
        }
        .onChange(of: store.localRevision) { _, _ in
            Task { await reload() }
        }
    }

    /// Gradient hero card matching the prototype's ListScreen: emoji + name +
    /// subtitle on the left, a large colored completion percentage on the right,
    /// a progress bar and a completed/remaining footer.
    private func hero(_ list: AppList) -> some View {
        let color = Color(hex: list.colorHex)
        let pct = Int((list.progress * 100).rounded())
        return VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(list.emoji ?? "📋").font(.system(size: 36)).padding(.bottom, 8)
                    Text(list.name).font(.system(size: 22, weight: .bold)).foregroundStyle(SCColor.text)
                    if let subtitle = list.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(SCColor.text3).padding(.top, 3)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(pct)%")
                        .font(.system(size: 36, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(color)
                    Text("COMPLETE").font(.system(size: 10, weight: .bold)).tracking(0.7).foregroundStyle(SCColor.text3)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#ebe6f0"))
                    Capsule().fill(color).frame(width: geo.size.width * list.progress)
                }
            }
            .frame(height: 6)
            .padding(.top, 16)
            HStack {
                Text("\(list.doneTasks) completed").monospacedDigit()
                Spacer()
                Text("\(list.totalTasks - list.doneTasks) remaining").monospacedDigit()
            }
            .font(.system(size: 11)).foregroundStyle(SCColor.text3)
            .padding(.top, 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.14), SCColor.card], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 22)
    }

    private func sectionBlock(_ section: AppSection) -> some View {
        VStack(spacing: 0) {
            sectionHeader(section)
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

    /// Section label row matching the prototype: emoji + uppercase label, a
    /// thin trailing hairline, and the task count.
    private func sectionHeader(_ section: AppSection) -> some View {
        HStack(spacing: 7) {
            if let emoji = section.emoji { Text(emoji).font(.system(size: 13)) }
            Text(section.label.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(0.9)
                .foregroundStyle(SCColor.text3)
            Rectangle().fill(SCColor.separator).frame(height: 0.5).padding(.leading, 6)
            Text("\(section.tasks.count)").font(.system(size: 11)).foregroundStyle(SCColor.text4)
        }
        .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 6)
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
        if !didInitMode, let list { mode = list.mode; didInitMode = true }
    }

    /// Segmented List / Kanban / Timeline switcher; persists the choice.
    private func modePicker(_ list: AppList) -> some View {
        Picker("View", selection: Binding(get: { mode }, set: { newMode in
            mode = newMode
            Task { await store.setListViewMode(listId: listId, mode: newMode) }
        })) {
            ForEach(ListViewMode.allCases) { m in
                Label(m.label, systemImage: m.symbol).tag(m)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 22)
    }

    /// The Gantt/Timeline view is the section's highest-effort sub-item and is
    /// tracked as a follow-up; for now this explains where it will live.
    private var timelinePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis").font(.system(size: 34)).foregroundStyle(SCColor.text4)
            Text("Timeline view").font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text2)
            Text("A Gantt-style timeline of this list's tasks is coming soon. Switch to List or Kanban to work with tasks.")
                .font(.system(size: 12.5)).foregroundStyle(SCColor.text4)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
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
