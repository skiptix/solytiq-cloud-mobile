import SwiftUI

/// The floating pill tab bar from the prototype's `FloatingTabBar` —
/// Home / Calendar / (Files, server-only) / Lists, with a center AI bubble
/// that only appears once connected to a server.
struct GlassTabBar: View {
    @Binding var selected: MainTab
    var connected: Bool
    var onAI: () -> Void

    private var tabs: [(MainTab, String, String)] {
        var left: [(MainTab, String, String)] = [(.home, "house.fill", "Home"), (.calendar, "calendar", "Calendar")]
        var right: [(MainTab, String, String)] = []
        if connected { right.append((.files, "icloud.fill", "Files")) }
        right.append((.lists, "checklist", "Lists"))
        return left + right
    }

    var body: some View {
        HStack(spacing: 2) {
            let all = tabs
            ForEach(0..<all.count, id: \.self) { idx in
                if connected && idx == 2 {
                    aiBubble
                }
                tabButton(all[idx])
            }
            if connected && all.count == 2 { aiBubble }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: 1))
        )
        .shadow(color: SCColor.primary.opacity(0.18), radius: 20, y: 8)
        .padding(.bottom, 16)
    }

    private func tabButton(_ tab: (MainTab, String, String)) -> some View {
        let isActive = selected == tab.0
        return Button {
            withAnimation(SCMotion.interactive) { selected = tab.0 }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: tab.1)
                    .font(.system(size: isActive ? 19 : 18))
                    .symbolVariant(isActive ? .fill : .none)
                    .foregroundStyle(isActive ? SCColor.primary : SCColor.text3.opacity(0.85))
                if isActive {
                    Text(tab.2).font(.system(size: 9.5, weight: .bold)).foregroundStyle(SCColor.primary)
                }
            }
            .padding(.vertical, 7)
            .frame(width: 64)
            .background(
                Capsule().fill(isActive ? Color.white.opacity(0.7) : .clear)
            )
        }
        .scPressStyle()
    }

    private var aiBubble: some View {
        Button(action: onAI) {
            ZStack {
                Circle().fill(
                    LinearGradient(colors: [Color(hex: "#b59cff"), SCColor.primary, Color(hex: "#3d2d99")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                Image(systemName: "sparkles").font(.system(size: 18)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 2))
            .shadow(color: SCColor.primary.opacity(0.5), radius: 12, y: 3)
        }
        .scPressStyle()
        .padding(.horizontal, 4)
    }
}
