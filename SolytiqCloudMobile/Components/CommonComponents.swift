import SwiftUI

/// `Card` — flat white/tinted container with the 0.5pt hairline border and
/// token corner radius used everywhere in the prototype (task groups,
/// settings rows, stat tiles).
struct Card<Content: View>: View {
    @EnvironmentObject var appState: AppState
    var content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(SCColor.card)
            .clipShape(RoundedRectangle(cornerRadius: appState.metrics.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: appState.metrics.radius, style: .continuous)
                    .strokeBorder(SCColor.border, lineWidth: 0.5)
            )
            .padding(.horizontal, 18)
    }
}

struct SectionHeaderView: View {
    var title: String
    var rightText: String? = nil
    var rightAction: (() -> Void)? = nil
    var rightIcon: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(SCColor.text4)
            Spacer()
            if let rightAction {
                Button(action: rightAction) {
                    HStack(spacing: 3) {
                        if let rightIcon { Image(systemName: rightIcon).font(.system(size: 12, weight: .semibold)) }
                        if let rightText { Text(rightText).font(.system(size: 12, weight: .semibold)) }
                    }
                }
                .tint(SCColor.primary)
            } else if let rightText {
                Text(rightText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(SCColor.text4)
                    .padding(.horizontal, 9).padding(.vertical, 2)
                    .background(Capsule().fill(SCColor.hover))
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 18)
        .padding(.bottom, 6)
    }
}

struct EmptyRowView: View {
    var text: String
    var body: some View {
        Text(text)
            .italic()
            .font(.system(size: 13))
            .foregroundStyle(SCColor.text4)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
    }
}

struct BadgeView: View {
    var label: String
    var body: some View {
        let c = SCBadgeColor.colors(for: label)
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(c.fg)
            .padding(.horizontal, 9).padding(.vertical, 2)
            .background(Capsule().fill(c.bg))
    }
}

struct FileBadgeView: View {
    var mime: String
    var size: CGFloat = 44
    private var label: String {
        if mime.contains("pdf") { return "PDF" }
        if mime.contains("image") { return "IMG" }
        if mime.contains("video") { return "VID" }
        if mime.contains("zip") { return "ZIP" }
        if mime.contains("word") || mime.contains("doc") { return "DOC" }
        return "FILE"
    }
    private var accent: Color {
        if mime.contains("pdf") { return Color(hex: "#dc2626") }
        if mime.contains("image") { return Color(hex: "#2563eb") }
        if mime.contains("video") { return Color(hex: "#7c3aed") }
        if mime.contains("zip") { return Color(hex: "#d97706") }
        return SCColor.primary
    }
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SCColor.primaryBg.opacity(0.5))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
            Image(systemName: "doc.fill").font(.system(size: size * 0.4)).foregroundStyle(Color(hex: "#d1d5db"))
            Text(label)
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(accent))
                .padding(.bottom, 3)
        }
        .frame(width: size, height: size)
    }
}

struct StorageBarView: View {
    var usedBytes: Int
    var totalBytes: Int
    var isAdmin: Bool = false

    private func fmt(_ b: Int) -> String {
        let d = Double(b)
        if d >= 1e9 { return String(format: "%.1f GB", d / 1e9) }
        if d >= 1e6 { return String(format: "%.0f MB", d / 1e6) }
        return String(format: "%d KB", b / 1000)
    }
    private var pct: Double { totalBytes == 0 ? 0 : min(1, Double(usedBytes) / Double(totalBytes)) }
    private var barColor: Color {
        pct >= 0.9 ? SCColor.danger : (pct >= 0.7 ? SCColor.warning : SCColor.primary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(fmt(usedBytes)) used").font(.system(size: 13, weight: .medium)).foregroundStyle(SCColor.text2)
                Spacer()
                if isAdmin {
                    Text("∞").font(.system(size: 18, weight: .bold)).foregroundStyle(SCColor.primary)
                } else {
                    Text("of \(fmt(totalBytes))").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                }
            }
            if !isAdmin {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(SCColor.hover)
                        Capsule().fill(barColor).frame(width: geo.size.width * pct)
                    }
                }
                .frame(height: 7)
            }
        }
    }
}

/// Two-step "are you sure" confirmation used by delete actions throughout
/// the app (task, list, meeting, workspace, account…).
struct ConfirmDeleteDialog: ViewModifier {
    @Binding var isPresented: Bool
    var title: String
    var message: String
    var confirmLabel: String = "Delete"
    var onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(title, isPresented: $isPresented, titleVisibility: .visible) {
            Button(confirmLabel, role: .destructive, action: onConfirm)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}

extension View {
    func confirmDelete(isPresented: Binding<Bool>, title: String, message: String, confirmLabel: String = "Delete", onConfirm: @escaping () -> Void) -> some View {
        modifier(ConfirmDeleteDialog(isPresented: isPresented, title: title, message: message, confirmLabel: confirmLabel, onConfirm: onConfirm))
    }
}
