import Foundation

/// §15 — cross-entity global search (`GET /api/search?q=`). The backend returns
/// a discriminated-union list over tasks/lists/timelines/milestones/meetings/
/// workspaces; this maps each row to an `AppSearchResult` the UI groups by kind.
struct SearchAPI {
    let client = APIClient.shared

    struct ResultDTO: Decodable {
        var id: IntOrString
        var type: String
        var title: String?
        var name: String?
        var subtitle: String?
        var listId: IntOrString?
        var timelineId: IntOrString?
        var parentId: IntOrString?

        func toApp() -> AppSearchResult? {
            guard let kind = AppSearchResult.Kind(rawValue: type) else { return nil }
            let displayTitle = title ?? name ?? "Untitled"
            let parent = (parentId ?? listId ?? timelineId)?.stringValue
            return AppSearchResult(id: "\(type)-\(id.stringValue)", kind: kind, title: displayTitle,
                                    subtitle: subtitle, parentId: parent)
        }
    }

    func search(query: String) async throws -> [AppSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        struct R: Decodable { var results: [ResultDTO] }
        return try await client.request("/search", query: ["q": trimmed], as: R.self).results.compactMap { $0.toApp() }
    }
}
