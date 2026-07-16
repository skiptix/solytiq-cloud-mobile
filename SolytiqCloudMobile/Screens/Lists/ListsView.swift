import SwiftUI

struct ListsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sync: SyncEngine

    @State private var lists: [AppList] = []
    @State private var folders: [AppFolder] = []
    @State private var timelines: [AppTimeline] = []
    @State private var markdownDocs: [AppMarkdownList] = []
    @State private var collapsedFolders: Set<String> = []

    private var rootLists: [AppList] { lists.filter { $0.folderId == nil } }
    private func lists(in folder: AppFolder) -> [AppList] { lists.filter { $0.folderId == folder.id } }

    private var totalTasks: Int { lists.reduce(0) { $0 + $1.totalTasks } }
    private var doneTasks: Int { lists.reduce(0) { $0 + $1.doneTasks } }

    private var currentWorkspace: AppWorkspace? {
        appState.workspaces.first(where: { $0.id == appState.currentWorkspaceId })
    }

    var body: some View {
        NavigationStack(path: $router.listsPath) {
            ScrollView {
                VStack(spacing: 16) {
                    if appState.mode == .server, let ws = currentWorkspace {
                        workspaceSwitcher(ws)
                    }

                    summaryStrip

                    timelinesEntry

                    if appState.mode == .server {
                        automationsEntry
                    }

                    ForEach(folders) { folder in
                        folderSection(folder)
                    }

                    if !markdownDocs.isEmpty {
                        VStack(spacing: 0) {
                            SectionHeaderView(title: "Markdown Documents", rightText: "\(markdownDocs.count)")
                            Card {
                                ForEach(Array(markdownDocs.enumerated()), id: \.element.id) { idx, doc in
                                    markdownRow(doc, showDivider: idx < markdownDocs.count - 1)
                                }
                            }
                        }
                    }

                    if !rootLists.isEmpty {
                        VStack(spacing: 0) {
                            if !folders.isEmpty { SectionHeaderView(title: "Other Lists") }
                            Card {
                                ForEach(Array(rootLists.enumerated()), id: \.element.id) { idx, list in
                                    listRow(list, showDivider: idx < rootLists.count - 1)
                                }
                            }
                        }
                    }

                    if lists.isEmpty && folders.isEmpty { emptyState }
                }
                .padding(.bottom, 110)
                .padding(.top, 8)
            }
            .background(SCColor.page)
            .navigationTitle("Lists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.sheet = .addChoice } label: { Image(systemName: "plus.circle.fill") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 14) {
                        Menu {
                            Button("Trash", systemImage: "trash") { router.sheet = .trash }
                            if appState.mode == .server {
                                Button("Archived Lists", systemImage: "archivebox") { router.sheet = .archived }
                            }
                        } label: { Image(systemName: "ellipsis.circle") }
                        ProfileToolbarButton()
                    }
                }
            }
            .navigationDestination(for: ListsRoute.self) { route in
                switch route {
                case .list(let id): ListDetailView(listId: id)
                case .folder(let id): FolderDashboardView(folderId: id)
                case .timelines: TimelinesView()
                case .timeline(let id): TimelineDetailView(timelineId: id)
                }
            }
            .task { await reload() }
            .refreshable { await reload() }
            .onChange(of: sync.revision) { _, _ in
                Task { await reload() }
            }
            // §18 — markdown lists are a SIGNAL sync entity (refetch on bump).
            .onChange(of: sync.entityRevisions) { _, _ in
                Task { await reload() }
            }
            .onChange(of: store.localRevision) { _, _ in
                Task { await reload() }
            }
            .onChange(of: appState.currentWorkspaceId) { _, _ in
                Task { await reload() }
            }
        }
    }

    // ── Workspace switcher card (server only) ──
    private func workspaceSwitcher(_ ws: AppWorkspace) -> some View {
        Button { router.sheet = .workspaceSwitcher } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous).fill(SCColor.primaryBg)
                    Text(ws.emoji ?? "🏠").font(.system(size: 20))
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WORKSPACE")
                        .font(.system(size: 9.5, weight: .bold)).tracking(0.8)
                        .foregroundStyle(SCColor.text4)
                    Text(ws.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                }
                Spacer()
                HStack(spacing: 4) {
                    Text("Switch").font(.system(size: 12.5, weight: .semibold))
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 13))
                }
                .foregroundStyle(SCColor.primary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    // ── Summary strip: three stat cards ──
    private var summaryStrip: some View {
        HStack(spacing: 10) {
            summaryStat("Lists", lists.count, icon: "checklist", color: SCColor.primary)
            summaryStat("Open", totalTasks - doneTasks, icon: "circle", color: SCColor.warning)
            summaryStat("Done", doneTasks, icon: "checkmark.circle.fill", color: SCColor.success)
        }
        .padding(.horizontal, 18)
    }

    private func summaryStat(_ label: String, _ value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(color)
            Text("\(value)").font(.system(size: 20, weight: .bold)).monospacedDigit().foregroundStyle(SCColor.text)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(SCColor.text4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
    }

    // ── Timelines entry ──
    private var timelinesEntry: some View {
        Button { router.listsPath.append(.timelines) } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(SCColor.primaryBg)
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 20)).foregroundStyle(SCColor.primary)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Timelines").font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text)
                    Text("\(timelines.count) timeline\(timelines.count != 1 ? "s" : "") · milestones & plans")
                        .font(.system(size: 12.5)).foregroundStyle(SCColor.text3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(SCColor.text4)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    // ── Automations entry (server only) ──
    private var automationsEntry: some View {
        Button { router.sheet = .automations } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: "#f59e0b").opacity(0.14))
                    Image(systemName: "bolt.badge.automatic").font(.system(size: 20)).foregroundStyle(Color(hex: "#f59e0b"))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Automations").font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text)
                    Text("Trigger-and-action workflows").font(.system(size: 12.5)).foregroundStyle(SCColor.text3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(SCColor.text4)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private func markdownRow(_ doc: AppMarkdownList, showDivider: Bool) -> some View {
        Button { router.sheet = .markdownList(id: doc.id) } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#f59e0b").opacity(0.14))
                    Text(doc.emoji ?? "📝").font(.system(size: 22))
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text(doc.title).font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text).lineLimit(1)
                    Text("Markdown document").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(SCColor.text4)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showDivider { Divider().opacity(0.5).padding(.leading, 16) }
        }
    }

    // ── Folder section: colored header + row-in-card lists ──
    private func folderSection(_ folder: AppFolder) -> some View {
        let items = lists(in: folder)
        let collapsed = collapsedFolders.contains(folder.id)
        let fc = Color(hex: folder.colorHex)
        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    let nowCollapsed = !collapsed
                    withAnimation(SCMotion.interactive) {
                        if nowCollapsed { collapsedFolders.insert(folder.id) } else { collapsedFolders.remove(folder.id) }
                    }
                    // §3 — persist so the collapse state syncs across devices.
                    Task { await store.setFolderCollapsed(id: folder.id, collapsed: nowCollapsed) }
                } label: {
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(fc)
                }
                .buttonStyle(.plain)

                Button { router.listsPath.append(.folder(id: folder.id)) } label: {
                    HStack(spacing: 8) {
                        Text(folder.emoji ?? "📁").font(.system(size: 16))
                        Text(folder.name.uppercased())
                            .font(.system(size: 12, weight: .bold)).tracking(0.7)
                            .foregroundStyle(fc)
                    }
                }
                .buttonStyle(.plain)

                Text("\(items.count)")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(SCColor.text4)
                    .padding(.horizontal, 8).padding(.vertical, 1)
                    .background(Capsule().fill(SCColor.hover))
                Spacer()
            }
            .padding(.horizontal, 26).padding(.top, 14).padding(.bottom, 6)

            if !collapsed {
                Card {
                    if items.isEmpty {
                        EmptyRowView(text: "No lists in this folder")
                    } else {
                        ForEach(Array(items.enumerated()), id: \.element.id) { idx, list in
                            listRow(list, showDivider: idx < items.count - 1)
                        }
                    }
                }
            }
        }
    }

    // ── Single list row (inside a Card) ──
    private func listRow(_ list: AppList, showDivider: Bool) -> some View {
        Button { router.listsPath.append(.list(id: list.id)) } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: list.colorHex).opacity(0.16))
                    Text(list.emoji ?? "📋").font(.system(size: 22))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 5) {
                    Text(list.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text).lineLimit(1)
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: "#ebe6f0"))
                                Capsule().fill(Color(hex: list.colorHex)).frame(width: geo.size.width * list.progress)
                            }
                        }
                        .frame(height: 4)
                        Text("\(list.doneTasks)/\(list.totalTasks)")
                            .font(.system(size: 11, weight: .medium)).monospacedDigit()
                            .foregroundStyle(SCColor.text3)
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(SCColor.text4)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showDivider { Divider().opacity(0.5).padding(.leading, 16) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("📋").font(.system(size: 48))
            Text("No lists yet").font(.system(size: 17, weight: .semibold)).foregroundStyle(SCColor.text3)
            Text("Tap + to create your first list.").font(.system(size: 13)).foregroundStyle(SCColor.text4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func reload() async {
        async let l = store.lists()
        async let f = store.folders()
        async let t = store.timelines()
        lists = await l
        folders = await f
        timelines = await t
        markdownDocs = await store.markdownLists()
        // §3 — seed collapse state from the (server-synced) `collapsed` field.
        collapsedFolders = Set(folders.filter(\.collapsed).map(\.id))
    }
}
