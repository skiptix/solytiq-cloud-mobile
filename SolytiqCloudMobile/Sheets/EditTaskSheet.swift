import SwiftUI

enum EditTaskMode {
    case create(listId: String?, sectionId: String?, presetDeadline: String?)
    case edit(AppTask)
}

struct EditTaskSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss

    var mode: EditTaskMode

    @State private var title: String = ""
    @State private var note: String = ""
    @State private var hasDeadline = false
    @State private var deadline: Date = .now
    @State private var hasTime = false
    @State private var time: Date = .now
    @State private var priority: Priority?
    @State private var badge: String = ""
    @State private var subItems: [AppSubItem] = []
    @State private var newSubItem = ""
    @State private var confirmDelete = false
    @State private var sublistName = ""
    @State private var showSublistPrompt = false
    @FocusState private var titleFocused: Bool

    private static let badges = ["Work", "Personal", "Urgent", "Tip"]

    private var existingTask: AppTask? {
        if case .edit(let t) = mode { return t }
        return nil
    }
    private var isCreating: Bool { existingTask == nil }
    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .font(.system(size: 17, weight: .semibold))
                        .focused($titleFocused)
                    TextField("Notes", text: $note, axis: .vertical).lineLimit(2...5)
                }

                Section {
                    Toggle("Deadline", isOn: $hasDeadline.animation())
                    if hasDeadline {
                        DatePicker("Date", selection: $deadline, displayedComponents: .date)
                        Toggle("Specific time", isOn: $hasTime.animation())
                        if hasTime { DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute) }
                    }
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("None").tag(Priority?.none)
                        ForEach(Priority.allCases) { p in Text(p.rawValue).tag(Priority?.some(p)) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Tag") {
                    HStack(spacing: 8) {
                        ForEach(Self.badges, id: \.self) { b in
                            let c = SCBadgeColor.colors(for: b)
                            Text(b)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(badge == b ? .white : c.fg)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(badge == b ? Color(hex: "#5e4dbb") : c.bg))
                                .onTapGesture { badge = (badge == b) ? "" : b }
                        }
                    }
                }

                Section("Subitems") {
                    ForEach(subItems) { item in
                        HStack {
                            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.checked ? SCColor.success : SCColor.text4)
                                .onTapGesture { toggleSub(item.id) }
                            Text(item.title).strikethrough(item.checked).foregroundStyle(item.checked ? SCColor.text4 : SCColor.text)
                        }
                    }
                    .onDelete { idx in subItems.remove(atOffsets: idx) }
                    HStack {
                        TextField("Add a subitem…", text: $newSubItem)
                        Button("Add") { addSubItem() }.disabled(newSubItem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }

                if let existingTask, existingTask.linkedListId == nil, existingTask.listId != nil {
                    Section {
                        Button { showSublistPrompt = true } label: {
                            Label("Turn into Sublist", systemImage: "arrow.triangle.branch")
                        }
                    }
                } else if let existingTask, let linkedId = existingTask.linkedListId {
                    Section {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                router.listsPath.append(.list(id: linkedId))
                            }
                        } label: { Label("Open Sublist", systemImage: "arrow.triangle.branch") }
                    }
                }

                if !isCreating {
                    Section {
                        Button("Delete Task", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(isCreating ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(!canSave)
                }
            }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete Task?", message: "\"\(title)\" will move to Trash.") {
                Task {
                    if let existingTask { await store.deleteTask(id: existingTask.id, listId: existingTask.listId) }
                    dismiss()
                }
            }
            .alert("Turn into Sublist", isPresented: $showSublistPrompt) {
                TextField("Sublist name", text: $sublistName)
                Button("Create") { Task { await makeSublist() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This creates a new list linked to this task.")
            }
        }
        .onAppear(perform: populate)
    }

    private func populate() {
        guard let existingTask else {
            titleFocused = true
            if case .create(_, _, let presetDeadline) = mode, let presetDeadline, let d = SCDate.date(fromISO: presetDeadline) {
                hasDeadline = true; deadline = d
            }
            return
        }
        title = existingTask.title
        note = existingTask.note ?? ""
        if let d = existingTask.deadline, let date = SCDate.date(fromISO: d) { hasDeadline = true; deadline = date }
        if let t = existingTask.time {
            let f = DateFormatter(); f.dateFormat = "h:mm a"
            if let parsed = f.date(from: t) { hasTime = true; time = parsed }
        }
        priority = existingTask.priority
        badge = existingTask.badge ?? ""
        subItems = existingTask.subItems
        sublistName = "\(existingTask.title) — Sublist"
    }

    private func toggleSub(_ id: String) {
        if let idx = subItems.firstIndex(where: { $0.id == id }) { subItems[idx].checked.toggle() }
    }

    private func addSubItem() {
        let t = newSubItem.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        subItems.append(AppSubItem(id: UUID().uuidString, title: t, checked: false, position: subItems.count))
        newSubItem = ""
    }

    private func timeLabel() -> String? {
        guard hasTime else { return nil }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: time)
    }

    private func save() async {
        let deadlineISO = hasDeadline ? SCDate.iso(deadline) : nil
        if let existingTask {
            var updated = existingTask
            updated.title = title; updated.note = note.isEmpty ? nil : note
            updated.deadline = deadlineISO; updated.time = timeLabel()
            updated.priority = priority; updated.badge = badge.isEmpty ? nil : badge
            updated.subItems = subItems
            await store.updateTask(updated)
        } else if case .create(let listId, let sectionId, _) = mode {
            let draft = AppTask(title: title, note: note.isEmpty ? nil : note, deadline: deadlineISO, time: timeLabel(),
                                 priority: priority, badge: badge.isEmpty ? nil : badge, listId: listId, sectionId: sectionId,
                                 subItems: subItems)
            if let listId, let sectionId {
                await store.addTask(listId: listId, sectionId: sectionId, draft: draft)
            } else {
                await store.createDashboardTask(draft)
            }
        }
        dismiss()
    }

    private func makeSublist() async {
        guard let existingTask else { return }
        let name = sublistName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        _ = await store.createSublist(parentTask: existingTask, name: name, emoji: "🗂️")
        dismiss()
    }
}
