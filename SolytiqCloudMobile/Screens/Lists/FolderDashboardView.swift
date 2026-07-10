import SwiftUI

struct FolderDashboardView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    var folderId: String
    @State private var folder: AppFolder?
    @State private var lists: [AppList] = []
    @State private var confirmDelete = false

    private var dueToday: [AppTask] {
        lists.flatMap { $0.sections.flatMap(\.tasks) }
            .filter { !$0.checked && SCDate.friendly($0.deadline)?.label == "Today" }
    }

    private var allFolderTasks: [AppTask] { lists.flatMap { $0.sections.flatMap(\.tasks) } }
    private var totalCount: Int { allFolderTasks.count }
    private var doneCount: Int { allFolderTasks.filter(\.checked).count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let folder { hero(folder) }

                if !dueToday.isEmpty {
                    SectionHeaderView(title: "Due Today")
                    Card {
                        ForEach(Array(dueToday.enumerated()), id: \.element.id) { idx, task in
                            TaskRowView(task: task, showDivider: idx < dueToday.count - 1) {
                                Task { var t = task; t.checked.toggle(); await store.updateTask(t); await reload() }
                            } onTap: { router.sheet = .editTask(task) }
                        }
                    }
                }

                SectionHeaderView(title: "Lists in this folder", rightText: "\(lists.count)")
                Card {
                    if lists.isEmpty {
                        EmptyRowView(text: "No lists in this folder yet.")
                    } else {
                        ForEach(Array(lists.enumerated()), id: \.element.id) { idx, list in
                            listRow(list, showDivider: idx < lists.count - 1)
                        }
                    }
                }

                Button { router.sheet = .addList(folderId: folderId) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "plus").font(.system(size: 15, weight: .semibold))
                        Text("Add List to Folder").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(SCColor.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.primary, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .padding(.top, 4)
            }
            .padding(.bottom, 100)
            .padding(.top, 8)
        }
        .background(SCColor.page)
        .navigationTitle(folder?.name ?? "Folder")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Delete Folder", systemImage: "trash", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmDelete(isPresented: $confirmDelete, title: "Delete Folder?", message: "Lists inside will move to the top level, not be deleted.") {
            Task { await store.deleteFolder(id: folderId); dismiss() }
        }
        .task { await reload() }
        .refreshable { await reload() }
        .onChange(of: sync.revision) { _, _ in
            Task { await reload() }
        }
        .onChange(of: store.localRevision) { _, _ in
            Task { await reload() }
        }
    }

    /// Gradient hero with the folder emoji/name and a Total/Done/Open stat trio,
    /// matching the prototype's FolderDashboardScreen.
    private func hero(_ folder: AppFolder) -> some View {
        let color = Color(hex: folder.colorHex)
        return VStack(alignment: .leading, spacing: 0) {
            Text(folder.emoji ?? "📁").font(.system(size: 42)).padding(.bottom, 10)
            Text(folder.name).font(.system(size: 24, weight: .bold)).foregroundStyle(color)
            Text("\(lists.count) list\(lists.count == 1 ? "" : "s")")
                .font(.system(size: 13)).foregroundStyle(SCColor.text3).padding(.top, 4)
            HStack(spacing: 8) {
                folderStat("Total", totalCount, color: SCColor.primary)
                folderStat("Done", doneCount, color: SCColor.success)
                folderStat("Open", totalCount - doneCount, color: SCColor.warning)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18).padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.094), SCColor.card], startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(color.opacity(0.19), lineWidth: 0.5))
        .padding(.horizontal, 22)
    }

    private func folderStat(_ label: String, _ value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(color)
            Text(label.uppercased()).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(SCColor.text4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.7)))
    }

    private func listRow(_ list: AppList, showDivider: Bool) -> some View {
        Button { router.listsPath.append(.list(id: list.id)) } label: {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Color(hex: list.colorHex).opacity(0.16))
                    Text(list.emoji ?? "📋").font(.system(size: 22))
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 5) {
                    Text(list.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(SCColor.text).lineLimit(1)
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: "#ebe6f0"))
                                Capsule().fill(Color(hex: list.colorHex)).frame(width: geo.size.width * list.progress)
                            }
                        }
                        .frame(height: 4)
                        Text("\(Int((list.progress * 100).rounded()))%")
                            .font(.system(size: 11)).monospacedDigit().foregroundStyle(SCColor.text3)
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 15)).foregroundStyle(SCColor.text4)
            }
            .padding(.horizontal, 16).padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if showDivider { Divider().opacity(0.5).padding(.leading, 16) }
        }
    }

    private func reload() async {
        async let allLists = store.lists()
        async let allFolders = store.folders()
        let (l, f) = await (allLists, allFolders)
        lists = l.filter { $0.folderId == folderId }
        folder = f.first { $0.id == folderId }
    }
}
