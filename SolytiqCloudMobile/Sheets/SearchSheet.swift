import SwiftUI

/// §15 — global cross-entity search. A `.searchable` sheet whose results are
/// grouped by kind; tapping a hit routes to the relevant list/timeline.
struct SearchSheet: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [AppSearchResult] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    private var grouped: [(kind: AppSearchResult.Kind, items: [AppSearchResult])] {
        let order: [AppSearchResult.Kind] = [.task, .list, .timeline, .milestone, .meeting, .folder, .file, .workspace]
        return order.compactMap { kind in
            let items = results.filter { $0.kind == kind }
            return items.isEmpty ? nil : (kind, items)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    ContentUnavailableView("Search everything", systemImage: "magnifyingglass",
                                           description: Text("Find tasks, lists, timelines, milestones, meetings and more."))
                } else if results.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                } else {
                    List {
                        ForEach(grouped, id: \.kind) { group in
                            Section(group.kind.rawValue.capitalized + "s") {
                                ForEach(group.items) { result in
                                    Button { open(result) } label: { row(result) }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .onChange(of: query) { _, _ in scheduleSearch() }
        }
    }

    private func row(_ result: AppSearchResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.kind.symbol)
                .font(.system(size: 15)).foregroundStyle(SCColor.primary).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title).font(.system(size: 14.5)).foregroundStyle(SCColor.text)
                if let subtitle = result.subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(SCColor.text4).lineLimit(1)
                }
            }
        }
    }

    /// Debounce keystrokes so we don't fire a request per character.
    private func scheduleSearch() {
        searchTask?.cancel()
        let q = query
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            isSearching = true
            let hits = await store.search(query: q)
            guard !Task.isCancelled else { return }
            results = hits
            isSearching = false
        }
    }

    private func open(_ result: AppSearchResult) {
        let destination: ListsRoute?
        switch result.kind {
        case .list:      destination = .list(id: result.id.replacingOccurrences(of: "list-", with: ""))
        case .task:      destination = result.parentId.map { .list(id: $0) }
        case .timeline:  destination = .timeline(id: result.id.replacingOccurrences(of: "timeline-", with: ""))
        case .milestone: destination = result.parentId.map { .timeline(id: $0) }
        case .folder:    destination = .folder(id: result.id.replacingOccurrences(of: "folder-", with: ""))
        default:         destination = nil
        }
        dismiss()
        guard let destination else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            router.tab = .lists
            router.listsPath.append(destination)
        }
    }
}
