import SwiftUI

struct ListsView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var sync: SyncEngine

    @State private var lists: [AppList] = []
    @State private var folders: [AppFolder] = []
    @State private var collapsedFolders: Set<String> = []

    private var rootLists: [AppList] { lists.filter { $0.folderId == nil } }
    private func lists(in folder: AppFolder) -> [AppList] { lists.filter { $0.folderId == folder.id } }

    private var totalTasks: Int { lists.reduce(0) { $0 + $1.totalTasks } }
    private var doneTasks: Int { lists.reduce(0) { $0 + $1.doneTasks } }

    var body: some View {
        NavigationStack(path: $router.listsPath) {
            ScrollView {
                VStack(spacing: 16) {
                    summaryStrip

                    if appState.mode == .server && appState.workspaces.count > 1 {
                        workspacePicker
                    }

                    timelinesEntry

                    ForEach(folders) { folder in
                        folderSection(folder)
                    }

                    if !rootLists.isEmpty || folders.isEmpty {
                        SectionHeaderView(title: folders.isEmpty ? "Your Lists" : "Other Lists")
                        VStack(spacing: 10) { ForEach(rootLists) { listCard($0) } }
                            .padding(.horizontal, 18)
                    }

                    if lists.isEmpty && folders.isEmpty {
                        Card { EmptyRowView(text: "No lists yet. Tap + to create one.") }
                    }
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
                        Button { router.sheet = .trash } label: { Image(systemName: "trash") }
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
            .onChange(of: store.localRevision) { _, _ in
                Task { await reload() }
            }
            .onChange(of: appState.currentWorkspaceId) { _, _ in
                Task { await reload() }
            }
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            statPill("Lists", "\(lists.count)")
            Divider().frame(height: 28)
            statPill("Open", "\(totalTasks - doneTasks)")
            Divider().frame(height: 28)
            statPill("Done", "\(doneTasks)")
        }
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 18)
    }

    private func statPill(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 18, weight: .bold)).monospacedDigit()
            Text(label).font(.system(size: 10.5)).foregroundStyle(SCColor.text3)
        }.frame(maxWidth: .infinity)
    }

    private var workspacePicker: some View {
        Button { router.sheet = .workspaceSwitcher } label: {
            HStack {
                Text(appState.workspaces.first(where: { $0.id == appState.currentWorkspaceId })?.emoji ?? "🏠")
                Text(appState.workspaces.first(where: { $0.id == appState.currentWorkspaceId })?.name ?? "Personal")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
            }
            .foregroundStyle(SCColor.primary)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Capsule().fill(SCColor.primaryBg))
        }
        .padding(.horizontal, 18)
    }

    private var timelinesEntry: some View {
        Button { router.listsPath.append(.timelines) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: "#0ea5e9").opacity(0.14))
                    Image(systemName: "chart.xyaxis.line").foregroundStyle(Color(hex: "#0ea5e9"))
                }
                .frame(width: 40, height: 40)
                Text("Timelines").font(.system(size: 14.5, weight: .semibold)).foregroundStyle(SCColor.text)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(SCColor.text4)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 18)
    }

    private func folderSection(_ folder: AppFolder) -> some View {
        let items = lists(in: folder)
        let collapsed = collapsedFolders.contains(folder.id)
        return VStack(spacing: 8) {
            Button {
                withAnimation { if collapsed { collapsedFolders.remove(folder.id) } else { collapsedFolders.insert(folder.id) } }
            } label: {
                HStack {
                    Text(folder.emoji ?? "📁")
                    Text(folder.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                    Spacer()
                    Text("\(items.count)").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                    Image(systemName: collapsed ? "chevron.right" : "chevron.down").font(.system(size: 11)).foregroundStyle(SCColor.text4)
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .onTapGesture { router.listsPath.append(.folder(id: folder.id)) }

            if !collapsed {
                VStack(spacing: 10) { ForEach(items) { listCard($0) } }
                    .padding(.horizontal, 18)
            }
        }
    }

    private func listCard(_ list: AppList) -> some View {
        Button { router.listsPath.append(.list(id: list.id)) } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(hex: list.colorHex).opacity(0.14))
                    Text(list.emoji ?? "📋").font(.system(size: 20))
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 4) {
                    Text(list.name).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                    if let subtitle = list.subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.system(size: 12)).foregroundStyle(SCColor.text3).lineLimit(1)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(SCColor.hover)
                            Capsule().fill(Color(hex: list.colorHex)).frame(width: geo.size.width * list.progress)
                        }
                    }
                    .frame(height: 5)
                }
                Spacer()
                Text("\(list.doneTasks)/\(list.totalTasks)").font(.system(size: 12, weight: .semibold)).foregroundStyle(SCColor.text4)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func reload() async {
        async let l = store.lists()
        async let f = store.folders()
        lists = await l
        folders = await f
    }
}
