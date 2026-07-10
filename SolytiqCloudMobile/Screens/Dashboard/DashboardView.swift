import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine

    @State private var allTasks: [AppTask] = []
    @State private var filterPush: DashboardFilterPayload?

    private var open: [AppTask] { allTasks.filter { !$0.checked } }
    private var completed: [AppTask] { allTasks.filter(\.checked) }
    private var dueToday: [AppTask] {
        allTasks.filter { !$0.checked && SCDate.friendly($0.deadline)?.label == "Today" }
    }
    private var dueThisWeek: [AppTask] {
        guard let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: .now) else { return [] }
        return allTasks.filter { t in
            guard !t.checked, let d = SCDate.date(fromISO: t.deadline) else { return false }
            return d <= weekFromNow
        }
    }
    /// "This Week" panel: open tasks due within the coming week but not today
    /// (today's tasks already surface in Today's Focus), mirroring the web
    /// Dashboard's split between the "Due Today" and "This Week" observer panels.
    private var upcomingThisWeek: [AppTask] {
        dueThisWeek.filter { SCDate.friendly($0.deadline)?.label != "Today" }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCardView(label: "Open", value: open.count, sub: "Active", icon: "circle.dashed", accent: SCColor.primary) {
                            filterPush = DashboardFilterPayload(title: "Open", tasks: open)
                        }
                        StatCardView(label: "Completed", value: completed.count, sub: "Done", icon: "checkmark.circle.fill", accent: SCColor.success) {
                            filterPush = DashboardFilterPayload(title: "Completed", tasks: completed)
                        }
                        StatCardView(label: "Due Today", value: dueToday.count, sub: "Focus", icon: "sun.max.fill", accent: SCColor.warning) {
                            filterPush = DashboardFilterPayload(title: "Due Today", tasks: dueToday)
                        }
                        StatCardView(label: "This Week", value: dueThisWeek.count, sub: "Ahead", icon: "calendar", accent: SCColor.info) {
                            filterPush = DashboardFilterPayload(title: "This Week", tasks: dueThisWeek)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    QuickAddBar(placeholder: "Add a new task for Today…") { title in
                        Task {
                            await store.createDashboardTask(AppTask(title: title, deadline: SCDate.todayISO()))
                            await reload()
                        }
                    }

                    SectionHeaderView(title: "Today's Focus")
                    taskCard(dueToday, empty: "Nothing due today — enjoy it.")

                    if !upcomingThisWeek.isEmpty {
                        SectionHeaderView(title: "This Week")
                        taskCard(upcomingThisWeek, empty: "No deadlines this week.")
                    }
                }
                .padding(.bottom, 110)
            }
            .background(SCColor.page)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { router.sheet = .addTask(listId: nil, sectionId: nil, presetDeadline: nil) } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                if appState.mode == .server {
                    ToolbarItem(placement: .principal) { workspaceChip }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileToolbarButton() }
            }
            .navigationDestination(item: $filterPush) { (payload: DashboardFilterPayload) in
                FilteredTasksView(title: payload.title, tasks: payload.tasks)
            }
            .refreshable { await reload() }
            .task { await reload() }
            .onChange(of: sync.revision) { _, _ in
                Task { await reload() }
            }
            .onChange(of: store.localRevision) { _, _ in
                Task { await reload() }
            }
        }
    }

    /// Renders a card of tappable/toggleable task rows, or an italic empty
    /// state when there's nothing to show.
    @ViewBuilder
    private func taskCard(_ tasks: [AppTask], empty: String) -> some View {
        if tasks.isEmpty {
            Card { EmptyRowView(text: empty) }
        } else {
            Card {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { idx, task in
                    TaskRowView(task: task, showDivider: idx < tasks.count - 1) {
                        Task { await toggle(task) }
                    } onTap: {
                        router.sheet = .editTask(task)
                    }
                }
            }
        }
    }

    /// Home-screen workspace switcher — the phone has no sidebar, so the active
    /// workspace and the switch affordance live in the nav bar here.
    private var workspaceChip: some View {
        let current = appState.workspaces.first(where: { $0.id == appState.currentWorkspaceId })
        return Button { router.sheet = .workspaceSwitcher } label: {
            HStack(spacing: 5) {
                Text(current?.emoji ?? "🏠").font(.system(size: 13))
                Text(current?.name ?? "Workspace")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SCColor.text)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(SCColor.text3)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(SCColor.primaryBg))
            .overlay(Capsule().strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ task: AppTask) async {
        var updated = task
        updated.checked.toggle()
        await store.updateTask(updated)
        await reload()
    }

    private func reload() async {
        allTasks = await store.allTasks()
    }
}

struct DashboardFilterPayload: Identifiable {
    var id: String { title }
    var title: String
    var tasks: [AppTask]
}

/// Read-only filtered list pushed from a Dashboard stat tile.
struct FilteredTasksView: View {
    var title: String
    var tasks: [AppTask]
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @State private var local: [AppTask]

    init(title: String, tasks: [AppTask]) {
        self.title = title
        self.tasks = tasks
        _local = State(initialValue: tasks)
    }

    var body: some View {
        ScrollView {
            if local.isEmpty {
                EmptyRowView(text: "Nothing here.")
            } else {
                Card {
                    ForEach(Array(local.enumerated()), id: \.element.id) { idx, task in
                        TaskRowView(task: task, showDivider: idx < local.count - 1) {
                            Task {
                                var updated = task
                                updated.checked.toggle()
                                await store.updateTask(updated)
                                local[idx] = updated
                            }
                        } onTap: { router.sheet = .editTask(task) }
                    }
                }
                .padding(.top, 12)
            }
        }
        .background(SCColor.page)
        .navigationTitle(title)
    }
}
