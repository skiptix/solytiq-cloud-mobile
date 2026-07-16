import SwiftUI

struct TrashSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var sync: SyncEngine
    @Environment(\.dismiss) private var dismiss

    @State private var entries: [AppTrashEntry] = []
    @State private var confirmEmpty = false

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "trash").font(.system(size: 32)).foregroundStyle(SCColor.text4)
                        Text("Trash is empty").font(.system(size: 14)).foregroundStyle(SCColor.text3)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(entries) { entry in
                            HStack {
                                Image(systemName: icon(for: entry.kind)).foregroundStyle(SCColor.text4)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).font(.system(size: 14, weight: .medium))
                                    Text(entry.deletedAt, style: .date).font(.system(size: 11)).foregroundStyle(SCColor.text4)
                                }
                                Spacer()
                                Button("Restore") { Task { await store.restore(entry); await reload() } }
                                    .font(.system(size: 12, weight: .semibold))
                                    .buttonStyle(.bordered).tint(SCColor.primary)
                            }
                        }
                        .onDelete { idx in
                            Task {
                                for i in idx { await store.deleteForever(entries[i]) }
                                await reload()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trash")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                if !entries.isEmpty {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Empty", role: .destructive) { confirmEmpty = true }
                    }
                }
            }
            .confirmDelete(isPresented: $confirmEmpty, title: "Empty Trash?", message: "Everything in Trash will be permanently deleted.", confirmLabel: "Empty Trash") {
                Task { await store.emptyTrash(); await reload() }
            }
            .task { await reload() }
            .onChange(of: sync.entityRevisions) { _, _ in
                Task { await reload() }
            }
            .onChange(of: store.localRevision) { _, _ in
                Task { await reload() }
            }
        }
    }

    private func icon(for kind: TrashKind) -> String {
        switch kind {
        case .task: return "checkmark.circle"
        case .list: return "checklist"
        case .folder: return "folder"
        case .timeline: return "chart.xyaxis.line"
        case .milestone: return "flag"
        case .markdownList: return "doc.richtext"
        }
    }

    private func reload() async { entries = await store.trashEntries() }
}
