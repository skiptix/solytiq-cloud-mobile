import SwiftUI

/// §1.6 — archived lists (read + restore). Mirrors `TrashSheet`'s structure:
/// a list of archived lists with a per-row "Unarchive" action. Server mode only.
struct ArchivedSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    @State private var lists: [AppList] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if lists.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "archivebox").font(.system(size: 32)).foregroundStyle(SCColor.text4)
                        Text("No archived lists").font(.system(size: 14)).foregroundStyle(SCColor.text3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(lists) { list in
                            HStack(spacing: 12) {
                                Text(list.emoji ?? "📋")
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(list.name).font(.system(size: 14, weight: .medium))
                                    Text("\(list.totalTasks) task\(list.totalTasks == 1 ? "" : "s")")
                                        .font(.system(size: 11)).foregroundStyle(SCColor.text4)
                                }
                                Spacer()
                                Button("Unarchive") { Task { await unarchive(list) } }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.bordered).tint(SCColor.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Archived Lists")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { await reload() }
            .onChange(of: sync.revision) { _, _ in Task { await reload() } }
        }
    }

    private func unarchive(_ list: AppList) async {
        await store.unarchiveList(id: list.id)
        lists.removeAll { $0.id == list.id }
    }

    private func reload() async {
        lists = await store.archivedLists()
        loading = false
    }
}
