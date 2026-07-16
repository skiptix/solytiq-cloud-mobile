import SwiftUI

/// §1.1 — the Timeline (Gantt) view of a list. Tasks are horizontal bars from
/// `createdAt` to `completedAt` (or "today" while open), grouped by section,
/// with a deadline flag (red when overdue) and a "today" guide line. Day/Week/
/// Month zoom controls set the pixels-per-day scale; a "Today" button recenters.
struct TaskGanttView: View {
    var list: AppList
    var onTapTask: (AppTask) -> Void

    enum Zoom: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month"
        var id: String { rawValue }
        var pxPerDay: CGFloat { switch self { case .day: return 44; case .week: return 14; case .month: return 5 } }
        var tickEveryDays: Int { switch self { case .day: return 1; case .week: return 7; case .month: return 30 } }
    }

    @State private var zoom: Zoom = .week
    private let rowHeight: CGFloat = 34
    private let labelWidth: CGFloat = 128
    private let cal = Calendar.current

    var body: some View {
        VStack(spacing: 10) {
            Picker("Zoom", selection: $zoom) {
                ForEach(Zoom.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        axisHeader
                        ForEach(list.sections) { section in
                            sectionLabel(section)
                            ForEach(section.tasks.sorted { $0.position < $1.position }) { task in
                                ganttRow(task)
                            }
                        }
                    }
                    .overlay(alignment: .topLeading) { todayLine }
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        withAnimation { proxy.scrollTo("today-anchor", anchor: .center) }
                    } label: {
                        Label("Today", systemImage: "scope").font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(SCColor.primaryBg))
                            .foregroundStyle(SCColor.primary)
                    }
                    .padding(10)
                }
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: axis

    private var axisHeader: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: labelWidth, height: 26)
            ForEach(tickDates, id: \.self) { date in
                Text(tickLabel(date))
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(SCColor.text4)
                    .frame(width: zoom.pxPerDay * CGFloat(zoom.tickEveryDays), alignment: .leading)
            }
        }
        .id("today-anchor")
    }

    private func sectionLabel(_ section: AppSection) -> some View {
        HStack(spacing: 6) {
            if let emoji = section.emoji { Text(emoji).font(.system(size: 11)) }
            Text(section.label.uppercased())
                .font(.system(size: 10, weight: .bold)).tracking(0.8).foregroundStyle(SCColor.text3)
            Spacer()
        }
        .frame(width: max(totalWidth, labelWidth), alignment: .leading)
        .padding(.vertical, 6)
        .background(SCColor.hover.opacity(0.5))
    }

    private func ganttRow(_ task: AppTask) -> some View {
        HStack(spacing: 0) {
            Text(task.title)
                .font(.system(size: 12)).foregroundStyle(task.checked ? SCColor.text4 : SCColor.text)
                .strikethrough(task.checked).lineLimit(1)
                .frame(width: labelWidth, alignment: .leading).padding(.trailing, 6)

            ZStack(alignment: .leading) {
                Color.clear.frame(width: timelineWidth, height: rowHeight)
                bar(task)
                if let deadlineX = deadlineOffset(task) {
                    let overdue = isOverdue(task)
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(overdue ? SCColor.danger : SCColor.warning)
                        .offset(x: deadlineX - 5)
                }
            }
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .onTapGesture { onTapTask(task) }
    }

    private func bar(_ task: AppTask) -> some View {
        let start = barStartOffset(task)
        let width = max(zoom.pxPerDay * 0.6, barWidth(task))
        let color = task.checked ? SCColor.success : Color(hex: list.colorHex)
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(color.opacity(task.checked ? 0.65 : 0.85))
            .frame(width: width, height: 18)
            .offset(x: start)
    }

    private var todayLine: some View {
        Rectangle()
            .fill(SCColor.danger.opacity(0.5))
            .frame(width: 1.5)
            .offset(x: labelWidth + offset(for: startOfToday))
            .allowsHitTesting(false)
    }

    // MARK: geometry

    private var startOfToday: Date { cal.startOfDay(for: Date()) }

    private var rangeStart: Date {
        let created = list.sections.flatMap(\.tasks).map { cal.startOfDay(for: $0.createdAt) }.min()
        let earliest = min(created ?? startOfToday, startOfToday)
        return cal.date(byAdding: .day, value: -2, to: earliest) ?? earliest
    }

    private var rangeEnd: Date {
        var candidates: [Date] = [startOfToday]
        for task in list.sections.flatMap(\.tasks) {
            if let done = task.completedAt { candidates.append(cal.startOfDay(for: done)) }
            if let dl = task.deadline, let d = SCDate.date(fromISO: dl) { candidates.append(cal.startOfDay(for: d)) }
        }
        let latest = candidates.max() ?? startOfToday
        return cal.date(byAdding: .day, value: 3, to: latest) ?? latest
    }

    private var totalDays: Int { max(1, cal.dateComponents([.day], from: rangeStart, to: rangeEnd).day ?? 1) }
    private var timelineWidth: CGFloat { CGFloat(totalDays) * zoom.pxPerDay }
    private var totalWidth: CGFloat { labelWidth + timelineWidth }

    private func offset(for date: Date) -> CGFloat {
        let days = cal.dateComponents([.day], from: rangeStart, to: cal.startOfDay(for: date)).day ?? 0
        return CGFloat(days) * zoom.pxPerDay
    }

    private func barStartOffset(_ task: AppTask) -> CGFloat { offset(for: task.createdAt) }

    private func barWidth(_ task: AppTask) -> CGFloat {
        let end = task.completedAt ?? Date()
        let days = max(1, cal.dateComponents([.day], from: cal.startOfDay(for: task.createdAt), to: cal.startOfDay(for: end)).day ?? 1)
        return CGFloat(days) * zoom.pxPerDay
    }

    private func deadlineOffset(_ task: AppTask) -> CGFloat? {
        guard let dl = task.deadline, let d = SCDate.date(fromISO: dl) else { return nil }
        return offset(for: d)
    }

    private func isOverdue(_ task: AppTask) -> Bool {
        guard !task.checked, let dl = task.deadline, let d = SCDate.date(fromISO: dl) else { return false }
        return cal.startOfDay(for: d) < startOfToday
    }

    private var tickDates: [Date] {
        var dates: [Date] = []
        var d = rangeStart
        while d <= rangeEnd {
            dates.append(d)
            d = cal.date(byAdding: .day, value: zoom.tickEveryDays, to: d) ?? rangeEnd.addingTimeInterval(1)
        }
        return dates
    }

    private func tickLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = zoom == .month ? "MMM" : "MMM d"
        return f.string(from: date)
    }
}
