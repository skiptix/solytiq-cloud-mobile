import SwiftUI

/// §1.1 — Kanban view of a list: sections become horizontally-scrollable
/// columns, each task a card. Tapping a card opens it; the checkbox toggles
/// completion; a per-column "+" adds into that section. (Card-drag between
/// columns is tracked as a follow-up alongside the reorder API work in §1.2.)
struct KanbanListView: View {
    var list: AppList
    var onToggle: (AppTask) -> Void
    var onTapTask: (AppTask) -> Void
    var onAddTask: (String) -> Void

    private let columnWidth: CGFloat = 270

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 14) {
                ForEach(list.sections) { section in
                    column(section)
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
        }
    }

    private func column(_ section: AppSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                if let emoji = section.emoji { Text(emoji).font(.system(size: 13)) }
                Text(section.label.uppercased())
                    .font(.system(size: 10, weight: .bold)).tracking(0.9).foregroundStyle(SCColor.text3)
                Spacer()
                Text("\(section.tasks.count)")
                    .font(.system(size: 11, weight: .bold)).foregroundStyle(SCColor.text4)
                    .padding(.horizontal, 7).padding(.vertical, 1)
                    .background(Capsule().fill(SCColor.hover))
            }

            if section.tasks.isEmpty {
                Text("No tasks").italic().font(.system(size: 12)).foregroundStyle(SCColor.text4)
                    .frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ForEach(section.tasks.sorted { $0.position < $1.position }) { task in
                    card(task)
                }
            }

            Button { onAddTask(section.id) } label: {
                Label("Add", systemImage: "plus").font(.system(size: 12, weight: .semibold))
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(width: columnWidth, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SCColor.page))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
    }

    private func card(_ task: AppTask) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Button { onToggle(task) } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(task.checked ? SCColor.primary : SCColor.border, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(task.checked ? SCColor.primary : .clear))
                        .frame(width: 20, height: 20)
                    if task.checked {
                        Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.system(size: 13.5))
                    .foregroundStyle(task.checked ? SCColor.text4 : SCColor.text)
                    .strikethrough(task.checked)
                    .lineLimit(3)
                HStack(spacing: 6) {
                    if let fd = SCDate.friendly(task.deadline), !task.checked {
                        Label(fd.label, systemImage: "calendar")
                            .font(.system(size: 10, weight: fd.overdue ? .semibold : .regular))
                            .foregroundStyle(fd.overdue ? SCColor.danger : SCColor.text4)
                    }
                    if let badge = task.badge { BadgeView(label: badge) }
                    if let priority = task.priority, !task.checked {
                        Circle().fill(SCPriorityColor.color(for: priority.rawValue)).frame(width: 6, height: 6)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        .contentShape(Rectangle())
        .onTapGesture { onTapTask(task) }
    }
}
