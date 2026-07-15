import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine

    @State private var allTasks: [AppTask] = []
    @State private var filterPush: DashboardFilterPayload?

    // ── Derived task buckets (mirror DashboardScreen in screens.jsx) ──
    private var open: [AppTask] { allTasks.filter { !$0.checked } }
    private var completed: [AppTask] { allTasks.filter(\.checked) }
    private var dueToday: [AppTask] {
        open.filter { SCDate.friendly($0.deadline)?.label == "Today" }
    }
    private var overdue: [AppTask] {
        open.filter { SCDate.friendly($0.deadline)?.overdue == true }
    }
    /// "This Week" stat/section: open tasks due strictly after today but within
    /// the coming 7 days (today's tasks surface in "Due Today"), matching the
    /// prototype's dashboard stat filter.
    private var thisWeek: [AppTask] {
        let today = SCDate.todayISO()
        let weekEnd = SCDate.iso(SCDate.addDays(7))
        return open.filter { t in
            guard let d = t.deadline else { return false }
            let day = String(d.prefix(10))
            return day > today && day <= weekEnd
        }
    }
    private var completionPct: Int {
        allTasks.isEmpty ? 0 : Int((Double(completed.count) / Double(allTasks.count) * 100).rounded())
    }

    private var dateEyebrow: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "EEEE, MMMM d"
        return f.string(from: Date()).uppercased()
    }

    private var headerSubtitle: String {
        if dueToday.isEmpty {
            return "No deadlines today — you're all clear."
        }
        let plural = dueToday.count > 1 ? "s" : ""
        var s = "\(dueToday.count) task\(plural) due today"
        if !overdue.isEmpty { s += " · \(overdue.count) overdue" }
        return s + "."
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date eyebrow + due summary (prototype's NavHeader eyebrow +
                    // subtitle, surfaced here since we use native large titles).
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dateEyebrow)
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.0)
                            .foregroundStyle(SCColor.primarySoft)
                        Text(headerSubtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(SCColor.text3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)

                    if !overdue.isEmpty { overdueBanner }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        StatCardView(label: "Open Tasks", value: open.count, sub: "\(allTasks.count) total",
                                     icon: "tray.full.fill", accent: SCColor.primary) {
                            filterPush = DashboardFilterPayload(title: "Open Tasks", tasks: open)
                        }
                        StatCardView(label: "Completed", value: completed.count,
                                     sub: completionPct > 0 ? "\(completionPct)%" : "Start!",
                                     icon: "checkmark.circle.fill", accent: SCColor.success) {
                            filterPush = DashboardFilterPayload(title: "Completed", tasks: completed)
                        }
                        StatCardView(label: "Due Today", value: dueToday.count,
                                     sub: dueToday.isEmpty ? "Clear" : "Focus",
                                     icon: "sun.max.fill", accent: SCColor.warning) {
                            filterPush = DashboardFilterPayload(title: "Due Today", tasks: dueToday)
                        }
                        StatCardView(label: "This Week", value: thisWeek.count, sub: "Upcoming",
                                     icon: "calendar", accent: SCColor.info) {
                            filterPush = DashboardFilterPayload(title: "This Week", tasks: thisWeek)
                        }
                    }
                    .padding(.horizontal, 22)

                    weeklyProgressCard

                    SectionHeaderView(title: "Due Today", rightText: "\(dueToday.count)")
                    taskCard(dueToday, empty: "Nothing due today. 🌿")

                    QuickAddBar(placeholder: "Add task…") { title in
                        Task {
                            await store.createDashboardTask(AppTask(title: title, deadline: SCDate.todayISO()))
                            await reload()
                        }
                    }

                    SectionHeaderView(title: "All Todos", rightText: "\(open.count) open")
                    allTodosCard
                }
                .padding(.bottom, 110)
            }
            .background(SCColor.page)
            .navigationTitle("Dashboard")
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

    // ── Overdue banner (prototype: red tappable strip above the stat grid) ──
    private var overdueBanner: some View {
        Button {
            filterPush = DashboardFilterPayload(title: "Overdue", tasks: overdue)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(SCColor.danger)
                Text("\(overdue.count) task\(overdue.count > 1 ? "s" : "") overdue — tap to view")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(hex: "#8b1414"))
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(SCColor.danger)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: "#ffefeb")))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(hex: "#ffdad6"), lineWidth: 0.5))
            .padding(.horizontal, 22)
        }
        .buttonStyle(.plain)
    }

    // ── Weekly progress card ──
    private var weeklyProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Progress this week")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(SCColor.text2)
                Spacer()
                Text("\(completed.count) done · \(open.count) open")
                    .font(.system(size: 11)).monospacedDigit()
                    .foregroundStyle(SCColor.text3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(SCColor.hover)
                    Capsule()
                        .fill(completionPct == 100
                              ? LinearGradient(colors: [SCColor.success, SCColor.success], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [SCColor.primarySoft, SCColor.primary], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * Double(completionPct) / 100))
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .padding(.horizontal, 22)
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

    /// "All Todos" preview — up to 7 open tasks with a "+N more" affordance
    /// that pushes the full filtered list, matching the prototype.
    @ViewBuilder
    private var allTodosCard: some View {
        if open.isEmpty {
            Card { EmptyRowView(text: "No open tasks. Enjoy your day!") }
        } else {
            let preview = Array(open.prefix(7))
            Card {
                ForEach(Array(preview.enumerated()), id: \.element.id) { idx, task in
                    TaskRowView(task: task, showDivider: idx < preview.count - 1 || open.count > 7) {
                        Task { await toggle(task) }
                    } onTap: {
                        router.sheet = .editTask(task)
                    }
                }
                if open.count > 7 {
                    Button {
                        filterPush = DashboardFilterPayload(title: "Open Tasks", tasks: open)
                    } label: {
                        HStack(spacing: 6) {
                            Text("+\(open.count - 7) more tasks")
                                .font(.system(size: 13, weight: .semibold))
                            Image(systemName: "chevron.right").font(.system(size: 12))
                        }
                        .foregroundStyle(SCColor.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
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

struct DashboardFilterPayload: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var tasks: [AppTask]

    static func == (lhs: DashboardFilterPayload, rhs: DashboardFilterPayload) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
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
