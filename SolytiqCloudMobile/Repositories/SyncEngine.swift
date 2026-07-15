import Foundation

// MARK: - SyncCache
//
// The in-memory server-mode cache the delta engine maintains. A plain value
// type so delta application is deterministic and unit-testable. Mirrors the
// web frontend's `useAppStore` shape: `tasks` is the flattened set the
// backend's GET /tasks (and /sync/bootstrap) returns — standalone dashboard
// tasks PLUS every task inside every accessible list.
struct SyncCache {
    var tasks: [AppTask] = []
    var lists: [AppList] = []
    var folders: [AppFolder] = []
    var timelines: [AppTimeline] = []

    mutating func hydrate(from snap: SyncBootstrapResponse) {
        lists = snap.lists.map { $0.toApp() }
        folders = snap.folders.map { $0.toApp() }
        timelines = snap.timelines.map { $0.toApp() }
        let listNames = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0.name) })
        tasks = snap.tasks.map { dto in dto.toApp(listName: dto.listId.flatMap { listNames[$0.stringValue] }) }
    }

    /// Apply one authoritative change from `/api/sync/delta`. Mirrors the web
    /// store's `applyDeltas`: a list upsert replaces the list AND re-derives
    /// its flattened tasks; a list delete drops both.
    mutating func apply(_ change: SyncDeltaChange) {
        switch change.entity {
        case "task":
            if change.op == "delete" {
                tasks.removeAll { $0.id == change.entityId }
            } else if let dto = change.task {
                upsertTask(dto.toApp())
            }
        case "list":
            if change.op == "delete" {
                lists.removeAll { $0.id == change.entityId }
                tasks.removeAll { $0.listId == change.entityId }
            } else if let dto = change.list {
                upsertList(dto.toApp())
            }
        case "folder":
            if change.op == "delete" {
                folders.removeAll { $0.id == change.entityId }
            } else if let dto = change.folder {
                Self.upsert(&folders, dto.toApp())
            }
        case "timeline":
            if change.op == "delete" {
                timelines.removeAll { $0.id == change.entityId }
            } else if let dto = change.timeline {
                Self.upsert(&timelines, dto.toApp())
            }
        default:
            break // signal entities are handled by the engine, not the cache
        }
    }

    // MARK: shared upsert helpers (also used for optimistic local writes)

    mutating func upsertTask(_ task: AppTask) {
        var t = task
        if t.listName == nil, let lid = t.listId { t.listName = lists.first { $0.id == lid }?.name }
        Self.upsert(&tasks, t)
        // Keep the copy nested inside its list's section in step too.
        guard let lid = t.listId, let li = lists.firstIndex(where: { $0.id == lid }) else { return }
        for si in lists[li].sections.indices {
            lists[li].sections[si].tasks.removeAll { $0.id == t.id }
        }
        if let sid = t.sectionId, let si = lists[li].sections.firstIndex(where: { $0.id == sid }) {
            lists[li].sections[si].tasks.append(t)
        }
    }

    mutating func removeTask(id: String) {
        tasks.removeAll { $0.id == id }
        for li in lists.indices {
            for si in lists[li].sections.indices {
                lists[li].sections[si].tasks.removeAll { $0.id == id }
            }
        }
    }

    mutating func upsertList(_ list: AppList) {
        Self.upsert(&lists, list)
        tasks.removeAll { $0.listId == list.id }
        tasks.append(contentsOf: list.sections.flatMap { sec in
            sec.tasks.map { var t = $0; t.listName = list.name; return t }
        })
    }

    mutating func removeList(id: String) {
        lists.removeAll { $0.id == id }
        tasks.removeAll { $0.listId == id }
    }

    private static func upsert<T: Identifiable>(_ array: inout [T], _ element: T) {
        if let i = array.firstIndex(where: { $0.id == element.id }) { array[i] = element }
        else { array.append(element) }
    }

    mutating func upsertFolder(_ f: AppFolder) { Self.upsert(&folders, f) }
    mutating func removeFolder(id: String) { folders.removeAll { $0.id == id } }
    mutating func upsertTimeline(_ t: AppTimeline) { Self.upsert(&timelines, t) }
    mutating func removeTimeline(id: String) { timelines.removeAll { $0.id == id } }
}

// MARK: - SyncEngine
//
// The mobile port of the web frontend's `useSyncStore`: owns the cursor,
// bootstraps full state, pulls authoritative deltas, and treats SSE frames
// from `/api/events` purely as nudges. Server mode only — local mode never
// starts the engine and keeps reading SwiftData directly.
//
// Convergence paths (any one of them is sufficient):
//   • SSE frame → pullDelta            (realtime)
//   • ~300ms after any write → pullDelta (post-write reconcile)
//   • app returns to foreground → reconnect + pullDelta
//   • delta `reset` → full re-bootstrap  (cursor fell behind retention)
@MainActor
final class SyncEngine: ObservableObject {
    enum Status { case idle, bootstrapping, live }

    @Published private(set) var status: Status = .idle
    /// Bumped whenever the core cache (tasks/lists/folders/timelines) changes.
    /// Screens holding local copies reload (cheaply, from the cache) on change.
    @Published private(set) var revision = 0
    /// Monotonic per-kind counters for data that lives OUTSIDE the cache
    /// (meeting → Calendar, file → Files, trash → Trash sheet, template →
    /// Templates). The owning screen refetches when its counter bumps.
    @Published private(set) var entityRevisions: [String: Int] = [:]

    private(set) var cache = SyncCache()
    var isLive: Bool { status == .live }

    private let api = SyncAPI()
    private let sse = SSEClient()
    private var cursor: Int64 = 0
    private var baseURL: URL?
    private var token: String?
    private var currentWorkspaceId: String?

    // Single-flight + supersede guards, mirroring the web store.
    private var bootstrapGeneration = 0
    private var pulling = false
    private var pullAgainRequested = false
    private var reconcileTask: Task<Void, Never>?
    private var lastWorkspaceReload = Date.distantPast

    /// Reloads the workspace list (set by AppState). Throttled here so a
    /// misbehaving `workspace` signal can never drive an unbounded loop.
    var onWorkspacesChanged: (() async -> Void)?

    // MARK: lifecycle

    func start(baseURL: URL, token: String, workspaceId: String?) {
        self.baseURL = baseURL
        self.token = token
        self.currentWorkspaceId = workspaceId
        sse.onEvent = { [weak self] event, data in
            self?.handleServerEvent(event, data: data)
        }
        sse.onAuthRejected = {
            NotificationCenter.default.post(name: .scSessionInvalidated, object: nil)
        }
        sse.connect(baseURL: baseURL, token: token)
        Task { await bootstrap(workspaceId: workspaceId) }
    }

    func stop() {
        sse.disconnect()
        reconcileTask?.cancel()
        reconcileTask = nil
        bootstrapGeneration += 1 // supersede any in-flight bootstrap
        cache = SyncCache()
        cursor = 0
        baseURL = nil
        token = nil
        currentWorkspaceId = nil
        status = .idle
        entityRevisions = [:]
        revision += 1
    }

    /// The user switched workspaces — the whole scoped view changes, so
    /// re-bootstrap (matches the web app's workspace-switch behavior).
    func workspaceChanged(_ workspaceId: String?) {
        guard baseURL != nil else { return }
        currentWorkspaceId = workspaceId
        Task { await bootstrap(workspaceId: workspaceId) }
    }

    /// Foreground return: the SSE stream may have died in the background and
    /// nudges may have been missed — reconnect and reconcile once.
    func appBecameActive() {
        guard let baseURL, let token else { return }
        if !sse.isConnected { sse.connect(baseURL: baseURL, token: token) }
        if status == .live {
            Task { await pullDelta() }
        } else if status == .idle {
            Task { await bootstrap(workspaceId: currentWorkspaceId) }
        }
    }

    /// Call after every successful server write: schedules one debounced
    /// delta pull (~300ms) so optimistic local state reconciles with what the
    /// server actually committed, without waiting for a realtime frame.
    func noteMutationSettled() {
        guard status == .live else { return }
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.pullDelta()
        }
    }

    // MARK: bootstrap / delta

    func bootstrap(workspaceId: String?) async {
        bootstrapGeneration += 1
        let generation = bootstrapGeneration
        status = .bootstrapping
        do {
            let snap = try await api.bootstrap(workspaceId: workspaceId)
            guard generation == bootstrapGeneration else { return } // superseded
            cache.hydrate(from: snap)
            cursor = snap.cursor
            status = .live
            revision += 1
        } catch {
            guard generation == bootstrapGeneration else { return }
            // Bootstrap failed — DataStore falls back to the classic per-call
            // REST loaders until the next foreground/workspace-switch retry.
            status = .idle
            if is403(error) { await reloadWorkspacesThrottled() }
        }
    }

    func pullDelta() async {
        guard status == .live else { return }
        if pulling { pullAgainRequested = true; return }
        pulling = true
        defer { pulling = false }
        repeat {
            pullAgainRequested = false
            do {
                let res = try await api.delta(since: cursor, workspaceId: currentWorkspaceId)
                if res.reset == true {
                    await bootstrap(workspaceId: currentWorkspaceId)
                    return
                }
                var coreChanged = false
                var signals = Set<String>()
                for change in res.changes {
                    switch change.entity {
                    case "task", "list", "folder", "timeline":
                        cache.apply(change)
                        coreChanged = true
                    default:
                        signals.insert(change.entity)
                    }
                }
                if res.cursor > cursor { cursor = res.cursor }
                if coreChanged { revision += 1 }
                if !signals.isEmpty {
                    for s in signals { entityRevisions[s, default: 0] += 1 }
                    // Membership/visibility changed → the workspace list (and
                    // what's visible in it) may differ.
                    if signals.contains("workspace") { await reloadWorkspacesThrottled() }
                }
            } catch {
                // 403 → we lost access to the current workspace; refresh the
                // workspace list so the UI can switch away. Everything else is
                // transient — the next nudge / reconcile / foreground retries.
                if is403(error) { await reloadWorkspacesThrottled() }
                return
            }
        } while pullAgainRequested
    }

    // MARK: SSE frames

    private func handleServerEvent(_ event: String, data: String) {
        switch event {
        case "sync":
            guard let frame = try? JSONDecoder().decode(SyncFrame.self, from: Data(data.utf8)) else { return }
            applyFrame(frame)
        case "nuke":
            // Admin wiped the instance — this session is gone; bail out like a
            // revoked device.
            NotificationCenter.default.post(name: .scSessionInvalidated, object: nil)
        default:
            break
        }
    }

    func applyFrame(_ frame: SyncFrame) {
        // A change confined to a DIFFERENT workspace doesn't affect the current
        // view (switching workspaces re-bootstraps) — unless it's a workspace/
        // membership change, which can grant or revoke access.
        let touchesWorkspace = frame.entities?.contains { $0.entity == "workspace" } ?? false
        if let frameWs = frame.workspaceId, let ws = currentWorkspaceId,
           frameWs != ws, !touchesWorkspace { return }
        // Skip only when the frame's cursor is present AND already applied;
        // otherwise (advanced cursor, or a legacy `{type}` nudge) pull deltas.
        if let c = frame.cursor, c <= cursor { return }
        Task { await pullDelta() }
    }

    // MARK: optimistic local writes
    //
    // DataStore applies each successful mutation response here so the UI
    // updates instantly; the debounced reconcile pull (and realtime frames)
    // then make the cache authoritative again.

    func applyLocal(_ mutate: (inout SyncCache) -> Void) {
        guard status == .live else { return }
        mutate(&cache)
        revision += 1
    }

    // MARK: helpers

    private func is403(_ error: Error) -> Bool {
        if case APIError.server(let status, _) = error { return status == 403 }
        return false
    }

    private func reloadWorkspacesThrottled() async {
        guard Date().timeIntervalSince(lastWorkspaceReload) > 5 else { return }
        lastWorkspaceReload = Date()
        await onWorkspacesChanged?()
    }
}
