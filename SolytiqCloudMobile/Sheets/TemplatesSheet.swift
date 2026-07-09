import SwiftUI

/// Browse the instance's templates (own + shared) and materialize one into a
/// brand-new list or timeline in the current workspace — the mobile
/// counterpart of the web app's `/templates` screen + `UseTemplateModal`.
/// Server mode only: templates are server-side snapshots.
struct TemplatesSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    @State private var templates: [AppTemplate] = []
    @State private var loaded = false
    @State private var filter: Filter = .all
    @State private var pendingUse: AppTemplate?
    @State private var useName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var pendingDelete: AppTemplate?

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", lists = "Lists", timelines = "Timelines"
        var id: String { rawValue }
    }

    private var filtered: [AppTemplate] {
        switch filter {
        case .all: return templates
        case .lists: return templates.filter { $0.type == .list }
        case .timelines: return templates.filter { $0.type == .timeline }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filtered.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "square.on.square.dashed").font(.system(size: 32)).foregroundStyle(SCColor.text4)
                        Text("No templates yet").font(.system(size: 14)).foregroundStyle(SCColor.text3)
                        Text("Save any list or timeline as a template from its ••• menu.")
                            .font(.system(size: 12)).foregroundStyle(SCColor.text4)
                            .multilineTextAlignment(.center).padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let errorMessage {
                            Text(errorMessage).font(.system(size: 12.5)).foregroundStyle(SCColor.danger)
                        }
                        ForEach(filtered) { tpl in
                            row(tpl)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { f in Text(f.rawValue).tag(f) }
                    }
                    .pickerStyle(.menu)
                }
            }
            .alert("Use Template", isPresented: Binding(get: { pendingUse != nil }, set: { if !$0 { pendingUse = nil } })) {
                TextField("Name", text: $useName)
                Button("Create") { Task { await use() } }
                Button("Cancel", role: .cancel) { pendingUse = nil }
            } message: {
                Text("Creates a new \(pendingUse?.type == .timeline ? "timeline" : "list") from \"\(pendingUse?.name ?? "")\" in the current workspace.")
            }
            .confirmDelete(isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                           title: "Delete Template?", message: "\"\(pendingDelete?.name ?? "")\" will be deleted permanently. Lists and timelines already created from it are not affected.") {
                guard let tpl = pendingDelete else { return }
                Task { await store.deleteTemplate(id: tpl.id); await reload() }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: sync.entityRevisions) { _, _ in
                Task { await reload() }
            }
        }
    }

    private func row(_ tpl: AppTemplate) -> some View {
        Button { pendingUse = tpl; useName = tpl.name } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: tpl.colorHex).opacity(0.14))
                    Text(tpl.emoji ?? (tpl.type == .timeline ? "🚀" : "📋")).font(.system(size: 20))
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(tpl.name).font(.system(size: 14.5, weight: .bold)).foregroundStyle(SCColor.text).lineLimit(1)
                        if tpl.isShared {
                            Image(systemName: "globe").font(.system(size: 10)).foregroundStyle(SCColor.success)
                        }
                    }
                    Text(summaryLine(tpl)).font(.system(size: 11.5)).foregroundStyle(SCColor.text3)
                    if !tpl.isOwner, let owner = tpl.ownerName {
                        Text("Shared by \(owner)").font(.system(size: 10.5)).foregroundStyle(SCColor.text4)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(SCColor.primary)
            }
        }
        .disabled(isWorking)
        .swipeActions(edge: .trailing) {
            if tpl.isOwner {
                Button("Delete", role: .destructive) { pendingDelete = tpl }
            }
        }
        .contextMenu {
            if tpl.isOwner {
                Button(tpl.isShared ? "Stop Sharing" : "Share with Everyone",
                       systemImage: tpl.isShared ? "globe.badge.chevron.backward" : "globe") {
                    Task {
                        _ = await store.setTemplateShared(tpl, isShared: !tpl.isShared)
                        await reload()
                    }
                }
                Button("Delete Template", systemImage: "trash", role: .destructive) { pendingDelete = tpl }
            }
        }
    }

    private func summaryLine(_ tpl: AppTemplate) -> String {
        if tpl.type == .timeline {
            return "Timeline · \(tpl.milestoneCount) milestone\(tpl.milestoneCount == 1 ? "" : "s")"
        }
        return "List · \(tpl.sectionCount) section\(tpl.sectionCount == 1 ? "" : "s") · \(tpl.taskCount) task\(tpl.taskCount == 1 ? "" : "s")"
    }

    private func use() async {
        guard let tpl = pendingUse else { return }
        pendingUse = nil
        isWorking = true
        defer { isWorking = false }
        do {
            let name = useName.trimmingCharacters(in: .whitespaces)
            let created = try await store.useTemplate(tpl, name: name.isEmpty ? nil : name)
            dismiss()
            // Land directly on what was just created.
            router.tab = .lists
            switch created {
            case .list(let list): router.listsPath = [.list(id: list.id)]
            case .timeline(let timeline): router.listsPath = [.timelines, .timeline(id: timeline.id)]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reload() async {
        templates = await store.templates()
        loaded = true
    }
}
