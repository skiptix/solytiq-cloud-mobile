import SwiftUI

struct AddChoiceSheet: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                choiceRow(icon: "checklist", color: SCColor.primary, title: "New List", subtitle: "A checklist with sections and tasks") {
                    open { router.sheet = .addList(folderId: nil) }
                }
                choiceRow(icon: "folder.fill", color: SCColor.success, title: "New Folder", subtitle: "Group related lists together") {
                    open { router.sheet = .addFolder }
                }
                choiceRow(icon: "chart.xyaxis.line", color: Color(hex: "#0ea5e9"), title: "New Timeline", subtitle: "Track milestones chronologically") {
                    open { router.sheet = .addTimeline }
                }
                if appState.mode == .server {
                    choiceRow(icon: "square.on.square", color: Color(hex: "#9d8dff"), title: "From Template", subtitle: "Start from a saved list or timeline") {
                        open { router.sheet = .templates }
                    }
                }
                Spacer()
            }
            .padding(20)
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.height(appState.mode == .server ? 390 : 320)])
    }

    private func open(_ action: @escaping () -> Void) {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: action)
    }

    private func choiceRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.12))
                    Image(systemName: icon).foregroundStyle(color)
                }
                .frame(width: 42, height: 42)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .bold)).foregroundStyle(SCColor.text)
                    Text(subtitle).font(.system(size: 12.5)).foregroundStyle(SCColor.text3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(SCColor.text4)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(SCColor.border, lineWidth: 1.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
