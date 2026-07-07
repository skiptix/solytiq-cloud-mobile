import SwiftUI

struct FolderDashboardView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss

    var folderId: String
    @State private var folder: AppFolder?
    @State private var lists: [AppList] = []
    @State private var confirmDelete = false

    private var dueToday: [AppTask] {
        lists.flatMap { $0.sections.flatMap(\.tasks) }
            .filter { !$0.checked && SCDate.friendly($0.deadline)?.label == "Today" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let folder {
                    VStack(spacing: 8) {
                        Text(folder.emoji ?? "📁").font(.system(size: 40))
                        Text(folder.name).font(.system(size: 22, weight: .bold))
                        Text("\(lists.count) list\(lists.count == 1 ? "" : "s")").font(.system(size: 12.5)).foregroundStyle(SCColor.text3)
                    }
                    .padding(.top, 12)
                }

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

                SectionHeaderView(title: "Lists")
                VStack(spacing: 10) {
                    ForEach(lists) { list in
                        Button { router.listsPath.append(.list(id: list.id)) } label: {
                            HStack {
                                Text(list.emoji ?? "📋")
                                Text(list.name).font(.system(size: 14.5, weight: .semibold)).foregroundStyle(SCColor.text)
                                Spacer()
                                Text("\(list.doneTasks)/\(list.totalTasks)").font(.system(size: 12)).foregroundStyle(SCColor.text4)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(SCColor.card))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(SCColor.border, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
            }
            .padding(.bottom, 100)
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
    }

    private func reload() async {
        async let allLists = store.lists()
        async let allFolders = store.folders()
        let (l, f) = await (allLists, allFolders)
        lists = l.filter { $0.folderId == folderId }
        folder = f.first { $0.id == folderId }
    }
}
