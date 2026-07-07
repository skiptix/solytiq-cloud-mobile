import SwiftUI

private struct CalendarChip: Identifiable {
    enum Kind { case task, meeting, milestone }
    var id: String
    var kind: Kind
    var label: String
    var time: String?
    var accent: Color
    var subtitle: String?
    var priorityColor: Color?
    var emoji: String?
    var onTap: () -> Void
}

struct CalendarView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router

    @State private var tasks: [AppTask] = []
    @State private var meetings: [AppMeeting] = []
    @State private var timelines: [AppTimeline] = []
    @State private var monthAnchor = Date()
    @State private var selectedDay = SCDate.todayISO()
    @State private var editingMeeting: AppMeeting?

    private let calendar = Calendar.current
    private let months = Calendar.current.monthSymbols

    private var chipsByDate: [String: [CalendarChip]] {
        var map: [String: [CalendarChip]] = [:]
        for t in tasks where t.deadline != nil && !t.checked {
            let c = CalendarChip(id: "t-\(t.id)", kind: .task, label: t.title, time: t.time,
                                  accent: SCColor.primary, subtitle: t.listName,
                                  priorityColor: t.priority.map { SCPriorityColor.color(for: $0.rawValue) }, emoji: nil) {
                router.sheet = .editTask(t)
            }
            map[t.deadline!, default: []].append(c)
        }
        for m in meetings {
            let accent = Color(hex: m.colorHex)
            let c = CalendarChip(id: "m-\(m.id)", kind: .meeting, label: m.title, time: m.allDay ? nil : m.startTime,
                                  accent: accent, subtitle: m.location, priorityColor: nil, emoji: nil) {
                editingMeeting = m
            }
            map[m.date, default: []].append(c)
        }
        for tl in timelines {
            for ms in tl.milestones where ms.status != .done {
                guard let date = ms.date else { continue }
                let accent = Color(hex: tl.colorHex)
                let c = CalendarChip(id: "ms-\(ms.id)", kind: .milestone, label: ms.title, time: ms.time,
                                      accent: accent, subtitle: tl.name, priorityColor: nil, emoji: ms.emoji ?? tl.emoji) {
                    router.tab = .lists
                    router.listsPath = [.timeline(id: tl.id)]
                }
                map[date, default: []].append(c)
            }
        }
        for key in map.keys { map[key]!.sort { ($0.time ?? "") < ($1.time ?? "") } }
        return map
    }

    private var unscheduled: [AppTask] { tasks.filter { $0.deadline == nil && !$0.checked } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    monthNav
                    monthGrid
                    agenda
                    if !unscheduled.isEmpty { unscheduledSection }
                }
                .padding(.bottom, 110)
            }
            .background(SCColor.page)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { monthAnchor = .now; selectedDay = SCDate.todayISO() } label: { Text("Today") }
                }
                ToolbarItem(placement: .topBarTrailing) { ProfileToolbarButton() }
            }
            .sheet(item: $editingMeeting) { m in MeetingSheet(existing: m, presetDate: nil) }
            .task { await reload() }
            .refreshable { await reload() }
        }
    }

    private var monthNav: some View {
        HStack {
            Button { monthAnchor = calendar.date(byAdding: .month, value: -1, to: monthAnchor) ?? monthAnchor } label: {
                Image(systemName: "chevron.left")
            }
            Spacer()
            Text(monthTitle).font(.system(size: 18, weight: .bold))
            Spacer()
            Button { monthAnchor = calendar.date(byAdding: .month, value: 1, to: monthAnchor) ?? monthAnchor } label: {
                Image(systemName: "chevron.right")
            }
        }
        .foregroundStyle(SCColor.text2)
        .padding(.horizontal, 24)
    }

    private var monthTitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: monthAnchor)
    }

    private var monthGrid: some View {
        let days = daysInMonthGrid()
        return VStack(spacing: 4) {
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { d in
                    Text(d).font(.system(size: 10, weight: .bold)).foregroundStyle(SCColor.text4).frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private func dayCell(_ date: Date) -> some View {
        let iso = SCDate.iso(date)
        let isToday = iso == SCDate.todayISO()
        let isSelected = iso == selectedDay
        let chips = chipsByDate[iso] ?? []
        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 13, weight: isToday || isSelected ? .bold : .medium))
                .monospacedDigit()
            HStack(spacing: 2) {
                ForEach(chips.prefix(4)) { c in Circle().fill(isSelected ? .white.opacity(0.8) : c.accent).frame(width: 4, height: 4) }
            }
            .frame(height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isSelected ? SCColor.primary : (isToday ? SCColor.primaryBg2 : .clear)))
        .foregroundStyle(isSelected ? .white : (isToday ? SCColor.primary : SCColor.text))
        .contentShape(Rectangle())
        .onTapGesture { selectedDay = iso }
        .dropDestination(for: String.self) { items, _ in
            guard let taskId = items.first else { return false }
            Task {
                if let t = tasks.first(where: { $0.id == taskId }) {
                    var updated = t
                    updated.deadline = iso
                    await store.updateTask(updated)
                    await reload()
                }
            }
            return true
        }
    }

    private var agenda: some View {
        let chips = chipsByDate[selectedDay] ?? []
        let selDate = SCDate.date(fromISO: selectedDay) ?? .now
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"
        return VStack(spacing: 0) {
            SectionHeaderView(title: f.string(from: selDate), rightText: "Add", rightAction: {
                router.sheet = .dayAdd(date: selectedDay)
            }, rightIcon: "plus")
            if chips.isEmpty {
                Card { EmptyRowView(text: "Nothing scheduled. Tap Add to plan this day.") }
            } else {
                VStack(spacing: 7) {
                    ForEach(chips) { chip in chipRow(chip) }
                }
                .padding(.horizontal, 18)
            }
        }
    }

    private func chipRow(_ chip: CalendarChip) -> some View {
        Button(action: chip.onTap) {
            HStack(spacing: 6) {
                if let priorityColor = chip.priorityColor {
                    Circle().fill(priorityColor).frame(width: 6, height: 6)
                } else if let emoji = chip.emoji {
                    Text(emoji).font(.system(size: 12))
                } else {
                    Circle().fill(chip.accent).frame(width: 6, height: 6)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(chip.label).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(chip.accent).lineLimit(1)
                    if let time = chip.time { Text(SCDate.to12h(time)).font(.system(size: 10.5)).foregroundStyle(SCColor.text3) }
                    else if let subtitle = chip.subtitle { Text(subtitle).font(.system(size: 10.5)).foregroundStyle(SCColor.text3) }
                }
                Spacer()
            }
            .padding(.horizontal, 9).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(chip.accent.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(chip.accent.opacity(0.25), lineWidth: 0).frame(width: 3), alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private var unscheduledSection: some View {
        VStack(spacing: 0) {
            SectionHeaderView(title: "Unscheduled", rightText: "\(unscheduled.count)")
            Text("Drag a task onto a date to schedule it")
                .font(.system(size: 11.5)).foregroundStyle(SCColor.text4)
                .padding(.horizontal, 18).padding(.bottom, 6)
            Card {
                ForEach(Array(unscheduled.enumerated()), id: \.element.id) { idx, task in
                    HStack {
                        Image(systemName: "line.3.horizontal").foregroundStyle(SCColor.text4)
                        Text(task.title).font(.system(size: 14)).lineLimit(1)
                        Spacer()
                        if let p = task.priority { Circle().fill(SCPriorityColor.color(for: p.rawValue)).frame(width: 7, height: 7) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .overlay(alignment: .bottom) { if idx < unscheduled.count - 1 { Divider() } }
                    .contentShape(Rectangle())
                    .draggable(task.id)
                    .onTapGesture { router.sheet = .editTask(task) }
                }
            }
        }
    }

    private func daysInMonthGrid() -> [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: monthAnchor),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for d in range { days.append(calendar.date(byAdding: .day, value: d - 1, to: firstOfMonth)) }
        return days
    }

    private func reload() async {
        tasks = await store.allTasks()
        meetings = await store.meetings()
        timelines = await store.timelines()
    }
}
