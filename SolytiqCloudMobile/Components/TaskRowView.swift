import SwiftUI

/// Mirrors `TaskRow` from `components.jsx`: checkbox, title (strike-through
/// when done), deadline/list/badge/subitem chips, priority dot.
struct TaskRowView: View {
    var task: AppTask
    var showDivider: Bool = true
    var onToggle: () -> Void
    var onTap: (() -> Void)? = nil

    @State private var checking = false

    var body: some View {
        HStack(spacing: 11) {
            Button {
                checking = true
                withAnimation(SCMotion.checkPop) { checking = false }
                onToggle()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(task.checked ? SCColor.primary : SCColor.border, lineWidth: 1.5)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(task.checked ? SCColor.primary : .clear))
                        .frame(width: 24, height: 24)
                    if task.checked {
                        Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .scaleEffect(checking ? 0.82 : 1)
                .rotationEffect(.degrees(checking ? 4 : 0))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14.5))
                    .foregroundStyle(task.checked ? SCColor.text4 : SCColor.text)
                    .strikethrough(task.checked)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let fd = SCDate.friendly(task.deadline), !task.checked {
                        Label(fd.label, systemImage: "calendar")
                            .font(.system(size: 11, weight: fd.overdue ? .semibold : .regular))
                            .foregroundStyle(fd.overdue ? SCColor.danger : SCColor.text4)
                    }
                    if let listName = task.listName, !listName.isEmpty {
                        Text("· \(listName)").font(.system(size: 10)).foregroundStyle(SCColor.text4)
                    }
                    if let badge = task.badge { BadgeView(label: badge) }
                    if !task.subItems.isEmpty {
                        Label("\(task.subItems.filter(\.checked).count)/\(task.subItems.count)", systemImage: "checklist")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(SCColor.primary)
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(Capsule().fill(SCColor.primaryBg))
                    }
                    if task.linkedListId != nil {
                        Label("Sublist", systemImage: "arrow.triangle.branch")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "#0d9488"))
                            .padding(.horizontal, 7).padding(.vertical, 1)
                            .background(Capsule().fill(Color(hex: "#0d9488").opacity(0.1)))
                    }
                }
            }

            Spacer(minLength: 4)

            if let priority = task.priority, !task.checked {
                Circle().fill(SCPriorityColor.color(for: priority.rawValue)).frame(width: 7, height: 7)
            }
            if task.checked {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(SCColor.success)
            } else if onTap != nil {
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(SCColor.text4)
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .overlay(alignment: .bottom) {
            if showDivider { Divider().opacity(0.5) }
        }
    }
}

struct QuickAddBar: View {
    var placeholder: String = "Add task…"
    var onAdd: (String) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous).fill(focused ? SCColor.primary : SCColor.primaryBg)
                Image(systemName: "plus").font(.system(size: 13, weight: .bold)).foregroundStyle(focused ? .white : SCColor.primary)
            }
            .frame(width: 24, height: 24)

            TextField(placeholder, text: $text)
                .focused($focused)
                .font(.system(size: 14.5))
                .onSubmit(submit)

            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Add", action: submit)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Capsule().fill(SCColor.primary))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(SCColor.card))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(focused ? SCColor.primary : SCColor.border, lineWidth: focused ? 1.5 : 0.5))
        .padding(.horizontal, 18)
    }

    private func submit() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        onAdd(t)
        text = ""
    }
}

struct StatCardView: View {
    var label: String
    var value: Int
    var sub: String
    var icon: String
    var accent: Color = SCColor.primary
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button { onTap?() } label: {
            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous).fill(accent.opacity(0.1))
                        Image(systemName: icon).font(.system(size: 16)).foregroundStyle(accent)
                    }
                    .frame(width: 34, height: 34)
                    Spacer()
                    Text(sub.uppercased())
                        .font(.system(size: 9.5, weight: .bold))
                        .tracking(0.5)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Capsule().fill(accent.opacity(0.08)))
                }
                Text("\(value)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(SCColor.text)
                    .monospacedDigit()
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(SCColor.text3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SCColor.card))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
        }
        .scPressStyle()
    }
}
