import SwiftUI

struct AddTimelineSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var subtitle = ""
    @State private var emoji = "🚀"
    @State private var colorHex = "#5e4dbb"

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
                        ForEach(["#5e4dbb", "#10B981", "#0ea5e9", "#ea580c", "#db2777"], id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("New Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            await store.createTimeline(name: name.trimmingCharacters(in: .whitespaces), emoji: emoji,
                                                        colorHex: colorHex, subtitle: subtitle.isEmpty ? nil : subtitle, folderId: nil)
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

struct MilestoneEditorSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    var timelineId: String
    var existing: AppMilestone?

    @State private var title = ""
    @State private var summary = ""
    @State private var hasDate = false
    @State private var date = Date.now
    @State private var status: MilestoneStatus = .upcoming
    @State private var emoji = ""
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Emoji", text: $emoji)
                    TextField("Title", text: $title)
                    TextField("Description", text: $summary, axis: .vertical).lineLimit(2...4)
                }
                Section {
                    Toggle("Date", isOn: $hasDate.animation())
                    if hasDate { DatePicker("Date", selection: $date, displayedComponents: .date) }
                }
                Section("Status") {
                    Picker("Status", selection: $status) {
                        Text("Upcoming").tag(MilestoneStatus.upcoming)
                        Text("In Progress").tag(MilestoneStatus.inProgress)
                        Text("Done").tag(MilestoneStatus.done)
                    }
                    .pickerStyle(.segmented)
                }
                if existing != nil {
                    Section { Button("Delete Milestone", role: .destructive) { confirmDelete = true } }
                }
            }
            .navigationTitle(existing == nil ? "New Milestone" : "Edit Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmDelete(isPresented: $confirmDelete, title: "Delete Milestone?", message: "This can't be undone.") {
                Task {
                    if let existing { await store.deleteMilestone(timelineId: timelineId, milestoneId: existing.id) }
                    dismiss()
                }
            }
            .onAppear(perform: populate)
        }
    }

    private func populate() {
        guard let existing else { return }
        title = existing.title
        summary = existing.summary ?? ""
        if let d = existing.date, let parsed = SCDate.date(fromISO: d) { hasDate = true; date = parsed }
        status = existing.status
        emoji = existing.emoji ?? ""
    }

    private func save() async {
        let m = AppMilestone(id: existing?.id ?? UUID().uuidString, title: title, summary: summary.isEmpty ? nil : summary,
                              date: hasDate ? SCDate.iso(date) : nil, time: nil, status: status,
                              emoji: emoji.isEmpty ? nil : emoji, colorHex: existing?.colorHex)
        if existing != nil { await store.updateMilestone(timelineId: timelineId, m) }
        else { await store.addMilestone(timelineId: timelineId, m) }
        dismiss()
    }
}
