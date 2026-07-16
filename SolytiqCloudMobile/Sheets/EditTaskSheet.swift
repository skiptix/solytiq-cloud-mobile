import SwiftUI
import UniformTypeIdentifiers

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
    @State private var showLinkPicker = false
    // §1.5 attachments
    @State private var attachments: [AppTaskAttachment] = []
    @State private var showAttachmentImporter = false
    @State private var showFilesPicker = false
    @State private var uploadingAttachment = false
    @State private var attachmentShareURL: URL?
    @State private var showAttachmentShare = false
    @State private var attachmentError: String?
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

                if let existingTask, store.isServer {
                    attachmentsSection(existingTask)
                }

                if let existingTask, existingTask.checked, let completedAt = existingTask.completedAt {
                    Section {
                        completionStrip(created: existingTask.createdAt, completed: completedAt)
                    }
                }

                if let existingTask, existingTask.listId != nil {
                    Section {
                        Button {
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { router.sheet = .moveTask(existingTask) }
                        } label: { Label("Move to another list…", systemImage: "arrow.right.doc.on.clipboard") }
                    }
                }

                if let existingTask, existingTask.linkedListId == nil, existingTask.listId != nil {
                    Section {
                        Button { showSublistPrompt = true } label: {
                            Label("Turn into Sublist", systemImage: "arrow.triangle.branch")
                        }
                        Button { showLinkPicker = true } label: {
                            Label("Link an Existing List", systemImage: "link")
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
            .sheet(isPresented: $showLinkPicker) {
                if let existingTask {
                    LinkListPickerSheet(parentTask: existingTask) { dismiss() }
                }
            }
            .fileImporter(isPresented: $showAttachmentImporter, allowedContentTypes: [.data, .item, .content],
                          allowsMultipleSelection: true) { result in
                Task { await handleAttachmentImport(result) }
            }
            .sheet(isPresented: $showFilesPicker) {
                if let existingTask {
                    AttachFromFilesSheet(taskId: existingTask.id) { await loadAttachments() }
                }
            }
            .sheet(isPresented: $showAttachmentShare) {
                if let attachmentShareURL { ShareSheet(items: [attachmentShareURL]) }
            }
        }
        .onAppear(perform: populate)
        .task { await loadAttachments() }
    }

    // MARK: §1.5 Attachments

    @ViewBuilder
    private func attachmentsSection(_ task: AppTask) -> some View {
        Section("Attachments") {
            ForEach(attachments) { attachment in
                Button { Task { await openAttachment(attachment) } } label: {
                    HStack(spacing: 10) {
                        FileBadgeView(mime: attachment.mimeType, size: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(attachment.fileName).font(.system(size: 14)).foregroundStyle(SCColor.text).lineLimit(1)
                            Text(attachment.isLinked ? "Linked from Files" : byteLabel(attachment.size))
                                .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                        }
                        Spacer()
                        Image(systemName: "arrow.down.circle").font(.system(size: 14)).foregroundStyle(SCColor.text4)
                    }
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button("Remove", role: .destructive) {
                        Task { await store.deleteTaskAttachment(attachmentId: attachment.id); await loadAttachments() }
                    }
                }
            }
            if let attachmentError {
                Text(attachmentError).font(.system(size: 12)).foregroundStyle(SCColor.danger)
            }
            Menu {
                Button { showAttachmentImporter = true } label: { Label("Upload a File", systemImage: "arrow.up.doc") }
                Button { showFilesPicker = true } label: { Label("Attach from Files", systemImage: "folder") }
            } label: {
                HStack {
                    if uploadingAttachment { ProgressView() } else { Image(systemName: "paperclip") }
                    Text(uploadingAttachment ? "Uploading…" : "Add Attachment")
                }
                .font(.system(size: 13.5, weight: .semibold))
            }
            .disabled(uploadingAttachment)
        }
    }

    private func byteLabel(_ bytes: Int) -> String {
        let d = Double(bytes)
        if d >= 1e6 { return String(format: "%.1f MB", d / 1e6) }
        if d >= 1e3 { return String(format: "%.0f KB", d / 1e3) }
        return "\(bytes) B"
    }

    private func loadAttachments() async {
        guard let existingTask, store.isServer else { return }
        attachments = await store.taskAttachments(taskId: existingTask.id)
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) async {
        guard let existingTask, case .success(let urls) = result else { return }
        uploadingAttachment = true
        defer { uploadingAttachment = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else { continue }
            do {
                _ = try await store.uploadTaskAttachment(taskId: existingTask.id, fileName: url.lastPathComponent,
                                                         mimeType: Self.mimeType(for: url), data: data)
            } catch {
                attachmentError = (error as? APIError)?.errorDescription ?? "Upload failed."
            }
        }
        await loadAttachments()
    }

    private func openAttachment(_ attachment: AppTaskAttachment) async {
        do {
            attachmentShareURL = try await store.downloadTaskAttachment(attachment)
            showAttachmentShare = true
        } catch {
            attachmentError = (error as? APIError)?.errorDescription ?? "Couldn't open attachment."
        }
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "zip": return "application/zip"
        case "txt": return "text/plain"
        case "doc", "docx": return "application/msword"
        default: return "application/octet-stream"
        }
    }

    /// §1.4 — compact "Created → Done" strip with a duration badge, shown once
    /// a task is checked (mirrors web's `TaskMiniTimeline`).
    private func completionStrip(created: Date, completed: Date) -> some View {
        let df = DateFormatter(); df.dateFormat = "MMM d, h:mm a"
        let interval = max(0, completed.timeIntervalSince(created))
        let days = Int(interval / 86_400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86_400)) / 3_600)
        let durationText: String = days > 0 ? "\(days)d \(hours)h" : (hours > 0 ? "\(hours)h" : "<1h")
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Created").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(SCColor.text4)
                Text(df.string(from: created)).font(.system(size: 12)).foregroundStyle(SCColor.text3)
            }
            Image(systemName: "arrow.right").font(.system(size: 11)).foregroundStyle(SCColor.text4)
            VStack(alignment: .leading, spacing: 2) {
                Text("Done").font(.system(size: 10, weight: .bold)).tracking(0.6).foregroundStyle(SCColor.success)
                Text(df.string(from: completed)).font(.system(size: 12)).foregroundStyle(SCColor.text3)
            }
            Spacer()
            Text(durationText)
                .font(.system(size: 11, weight: .bold)).monospacedDigit()
                .foregroundStyle(SCColor.success)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(SCColor.success.opacity(0.12)))
        }
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

/// §1.3 — pick an existing standalone list to link into a task (a `'link'`
/// reference, not an owned sublist).
struct LinkListPickerSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var parentTask: AppTask
    var onLinked: () -> Void

    @State private var lists: [AppList] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(candidates) { list in
                    Button {
                        Task {
                            _ = await store.linkExistingList(parentTask: parentTask, targetListId: list.id)
                            dismiss()
                            onLinked()
                        }
                    } label: {
                        HStack {
                            Text(list.emoji ?? "📋")
                            Text(list.name).foregroundStyle(SCColor.text)
                            Spacer()
                            Text("\(list.totalTasks) tasks").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                        }
                    }
                }
                if candidates.isEmpty {
                    EmptyRowView(text: "No other lists to link.")
                }
            }
            .navigationTitle("Link a List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { lists = await store.lists().filter { !$0.isArchived } }
        }
    }

    /// Exclude the task's own list and any list already linked to it.
    private var candidates: [AppList] {
        lists.filter { $0.id != parentTask.listId && $0.id != parentTask.linkedListId }
    }
}

/// §1.5 — pick an existing uploaded file (from Files) to link onto a task.
struct AttachFromFilesSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var taskId: String
    var onAttached: () async -> Void

    @State private var files: [AppFileItem] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if files.isEmpty {
                    ContentUnavailableView("No files", systemImage: "folder",
                                           description: Text("Upload files from the Files tab first, then link them here."))
                } else {
                    List(files) { file in
                        Button {
                            Task {
                                _ = await store.linkTaskAttachment(taskId: taskId, sharedFileId: file.id)
                                dismiss()
                                await onAttached()
                            }
                        } label: {
                            HStack(spacing: 10) {
                                FileBadgeView(mime: file.mimeType, size: 30)
                                Text(file.name).foregroundStyle(SCColor.text).lineLimit(1)
                                Spacer()
                                Image(systemName: "link").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Attach from Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { files = await store.files(); loading = false }
        }
    }
}
