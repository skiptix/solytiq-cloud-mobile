import SwiftUI

struct TimelinesView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine
    @State private var timelines: [AppTimeline] = []

    var body: some View {
        ScrollView {
            if timelines.isEmpty {
                EmptyRowView(text: "No timelines yet.").padding(.top, 40)
            } else {
                VStack(spacing: 10) {
                    ForEach(timelines) { tl in
                        Button { router.listsPath.append(.timeline(id: tl.id)) } label: { card(tl) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 110)
            }
        }
        .background(SCColor.page)
        .navigationTitle("Timelines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.sheet = .addTimeline } label: { Image(systemName: "plus") }
            }
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

    private func card(_ tl: AppTimeline) -> some View {
        let done = tl.milestones.filter { $0.status == .done }.count
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: tl.colorHex).opacity(0.14))
                Text(tl.emoji ?? "🚀").font(.system(size: 20))
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text(tl.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                if let subtitle = tl.subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(SCColor.text3) }
            }
            Spacer()
            Text("\(done)/\(tl.milestones.count)").font(.system(size: 12, weight: .semibold)).foregroundStyle(SCColor.text4)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
    }

    private func reload() async { timelines = await store.timelines() }
}

struct TimelineDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss
    var timelineId: String
    @State private var timeline: AppTimeline?
    @State private var confirmDelete = false
    @State private var showEdit = false
    @State private var showSaveTemplate = false
    @State private var templateName = ""
    @State private var templateSavedBanner = false

    var body: some View {
        ScrollView {
            if let timeline {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(spacing: 6) {
                        Text(timeline.emoji ?? "🚀").font(.system(size: 36))
                        Text(timeline.name).font(.system(size: 20, weight: .bold))
                        if let subtitle = timeline.subtitle { Text(subtitle).font(.system(size: 13)).foregroundStyle(SCColor.text3) }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)

                    ForEach(sortedMilestones(timeline.milestones)) { m in
                        milestoneRow(m)
                    }

                    Button {
                        router.sheet = .milestoneEditor(timelineId: timelineId, existing: nil)
                    } label: {
                        Label("Add Milestone", systemImage: "plus").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 24).padding(.top, 8)
                }
                .padding(.bottom, 110)
            } else {
                ProgressView().padding(.top, 60)
            }
        }
        .background(SCColor.page)
        .navigationTitle(timeline?.name ?? "Timeline")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Timeline", systemImage: "pencil") { showEdit = true }
                    if appState.mode == .server {
                        Button("Save as Template", systemImage: "square.on.square") {
                            templateName = timeline?.name ?? ""
                            showSaveTemplate = true
                        }
                    }
                    Button("Delete Timeline", systemImage: "trash", role: .destructive) { confirmDelete = true }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let timeline { EditTimelineSheet(timeline: timeline) { await reload() } }
        }
        .alert("Save as Template", isPresented: $showSaveTemplate) {
            TextField("Template name", text: $templateName)
            Button("Save") {
                Task {
                    let name = templateName.trimmingCharacters(in: .whitespaces)
                    if (try? await store.saveAsTemplate(type: "timeline", sourceId: timelineId,
                                                         name: name.isEmpty ? nil : name,
                                                         description: nil, isShared: false)) != nil {
                        templateSavedBanner = true
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Snapshots this timeline's milestones (dates become relative) so you can reuse it from Add → From Template.")
        }
        .alert("Template saved", isPresented: $templateSavedBanner) {
            Button("OK") {}
        }
        .confirmDelete(isPresented: $confirmDelete, title: "Delete Timeline?", message: "\"\(timeline?.name ?? "")\" will move to Trash.") {
            Task { await store.deleteTimeline(id: timelineId); dismiss() }
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

    private func sortedMilestones(_ ms: [AppMilestone]) -> [AppMilestone] {
        ms.sorted { ($0.date ?? "") < ($1.date ?? "") }
    }

    private func milestoneRow(_ m: AppMilestone) -> some View {
        let color = m.colorHex.map { Color(hex: $0) } ?? Color(hex: timeline?.colorHex ?? "#5e4dbb")
        return HStack(alignment: .top, spacing: 12) {
            VStack {
                Circle().fill(m.status == .done ? SCColor.success : color).frame(width: 12, height: 12)
                Rectangle().fill(SCColor.border).frame(width: 2).frame(maxHeight: .infinity)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if let emoji = m.emoji { Text(emoji) }
                    Text(m.title).font(.system(size: 14.5, weight: .bold)).foregroundStyle(SCColor.text)
                    Spacer()
                    statusPill(m.status)
                }
                if let date = m.date, let d = SCDate.date(fromISO: date) {
                    Text(d, style: .date).font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
                }
                if let summary = m.summary { Text(summary).font(.system(size: 12.5)).foregroundStyle(SCColor.text3) }
            }
            .padding(.bottom, 16)
            .contentShape(Rectangle())
            .onTapGesture { router.sheet = .milestoneEditor(timelineId: timelineId, existing: m) }
        }
        .padding(.horizontal, 24)
    }

    private func statusPill(_ status: MilestoneStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .done: ("Done", SCColor.success)
        case .inProgress: ("In Progress", SCColor.warning)
        case .upcoming: ("Upcoming", SCColor.text4)
        }
        return Text(label.uppercased())
            .font(.system(size: 8.5, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func reload() async {
        timeline = await store.timelines().first { $0.id == timelineId }
    }
}

struct EditTimelineSheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    var timeline: AppTimeline
    var onSave: () async -> Void

    @State private var name: String
    @State private var subtitle: String
    @State private var emoji: String
    @State private var colorHex: String

    init(timeline: AppTimeline, onSave: @escaping () async -> Void) {
        self.timeline = timeline
        self.onSave = onSave
        _name = State(initialValue: timeline.name)
        _subtitle = State(initialValue: timeline.subtitle ?? "")
        _emoji = State(initialValue: timeline.emoji ?? "🚀")
        _colorHex = State(initialValue: timeline.colorHex)
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
                        ForEach(["#5e4dbb", "#10B981", "#0ea5e9", "#ea580c", "#db2777"], id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 28, height: 28)
                                .overlay(Circle().strokeBorder(.primary, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("Edit Timeline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            var updated = timeline
                            updated.name = name; updated.subtitle = subtitle.isEmpty ? nil : subtitle
                            updated.emoji = emoji; updated.colorHex = colorHex
                            await store.updateTimeline(updated)
                            await onSave()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
