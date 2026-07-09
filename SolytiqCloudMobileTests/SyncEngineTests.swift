import Testing
import Foundation
@testable import SolytiqCloudMobile

// MARK: - Wire-format tests for the delta-sync engine

struct SyncWireFormatTests {
    @Test func bootstrapResponseDecodesAndHydratesCache() throws {
        let json = """
        {
          "cursor": 42,
          "workspaceId": "ws-1",
          "tasks": [
            {"id": 1, "title": "Standalone", "checked": false, "position": 0},
            {"id": 2, "title": "In list", "checked": true, "position": 0, "listId": "list_9", "sectionId": "sec_1"}
          ],
          "lists": [
            {"id": "list_9", "name": "Groceries", "isPublic": false, "position": 0,
             "sections": [{"id": "sec_1", "label": "Tasks", "position": 0,
               "tasks": [{"id": 2, "title": "In list", "checked": true, "position": 0, "listId": "list_9", "sectionId": "sec_1"}]}]}
          ],
          "folders": [],
          "timelines": []
        }
        """
        let snap = try JSONDecoder().decode(SyncBootstrapResponse.self, from: Data(json.utf8))
        #expect(snap.cursor == 42)

        var cache = SyncCache()
        cache.hydrate(from: snap)
        #expect(cache.tasks.count == 2)
        #expect(cache.lists.count == 1)
        // The flattened copy of a list task gets its list's name resolved.
        #expect(cache.tasks.first { $0.id == "2" }?.listName == "Groceries")
        #expect(cache.tasks.first { $0.id == "1" }?.listName == nil)
    }

    @Test func deltaChangeDecodesCorePayloadAndDelete() throws {
        let json = """
        {"cursor": 50, "reset": false, "changes": [
          {"entity": "task", "entityId": "7", "op": "upsert",
           "payload": {"id": 7, "title": "New", "checked": false, "position": 3}},
          {"entity": "list", "entityId": "list_1", "op": "delete"},
          {"entity": "meeting", "entityId": "", "op": "upsert"}
        ]}
        """
        let res = try JSONDecoder().decode(SyncDeltaResponse.self, from: Data(json.utf8))
        #expect(res.cursor == 50)
        #expect(res.changes.count == 3)
        #expect(res.changes[0].task?.toApp().title == "New")
        #expect(res.changes[1].op == "delete")
        #expect(res.changes[1].list == nil)
        #expect(res.changes[2].entity == "meeting")
    }

    @Test func deltaResetFlagDecodes() throws {
        let json = #"{"cursor": 3, "changes": [], "reset": true}"#
        let res = try JSONDecoder().decode(SyncDeltaResponse.self, from: Data(json.utf8))
        #expect(res.reset == true)
    }

    @Test func syncFrameDecodesModernAndLegacyShapes() throws {
        let modern = #"{"cursor": 12, "workspaceId": "ws-1", "entities": [{"entity": "list", "entityId": "l1", "op": "upsert"}]}"#
        let legacy = #"{"type": "lists"}"#
        let a = try JSONDecoder().decode(SyncFrame.self, from: Data(modern.utf8))
        let b = try JSONDecoder().decode(SyncFrame.self, from: Data(legacy.utf8))
        #expect(a.cursor == 12)
        #expect(a.entities?.first?.entity == "list")
        #expect(b.cursor == nil)
        #expect(b.type == "lists")
    }
}

// MARK: - Cache delta-application tests (mirrors the web store's applyDeltas)

struct SyncCacheTests {
    private func makeList(id: String, name: String, taskIds: [String]) -> AppList {
        let tasks = taskIds.enumerated().map { i, tid in
            AppTask(id: tid, title: "t\(tid)", listId: id, sectionId: "sec-\(id)", position: i)
        }
        return AppList(id: id, name: name, emoji: nil, colorHex: "#5e4dbb", subtitle: nil,
                        folderId: nil, workspaceId: nil, isPublic: false, shareEnabled: false,
                        shareToken: nil, position: 0,
                        sections: [AppSection(id: "sec-\(id)", listId: id, label: "Tasks", emoji: nil, position: 0, tasks: tasks)])
    }

    @Test func listUpsertReplacesItsFlattenedTasks() {
        var cache = SyncCache()
        cache.upsertList(makeList(id: "L1", name: "One", taskIds: ["a", "b"]))
        #expect(cache.tasks.count == 2)

        // Re-upsert with one task removed and one added — the flattened set follows.
        cache.upsertList(makeList(id: "L1", name: "One", taskIds: ["b", "c"]))
        #expect(Set(cache.tasks.map(\.id)) == ["b", "c"])
        #expect(cache.lists.count == 1)
    }

    @Test func listDeleteDropsListAndItsTasks() {
        var cache = SyncCache()
        cache.upsertList(makeList(id: "L1", name: "One", taskIds: ["a"]))
        cache.upsertTask(AppTask(id: "dash-1", title: "Standalone"))
        cache.apply(SyncDeltaChange(entity: "list", entityId: "L1", op: "delete"))
        #expect(cache.lists.isEmpty)
        #expect(cache.tasks.map(\.id) == ["dash-1"])
    }

    @Test func taskUpsertUpdatesFlattenedAndNestedCopies() {
        var cache = SyncCache()
        cache.upsertList(makeList(id: "L1", name: "One", taskIds: ["a"]))
        var edited = cache.tasks.first { $0.id == "a" }!
        edited.checked = true
        cache.upsertTask(edited)
        #expect(cache.tasks.first { $0.id == "a" }?.checked == true)
        #expect(cache.lists[0].sections[0].tasks.first { $0.id == "a" }?.checked == true)
    }

    @Test func taskRemoveClearsBothCopies() {
        var cache = SyncCache()
        cache.upsertList(makeList(id: "L1", name: "One", taskIds: ["a", "b"]))
        cache.removeTask(id: "a")
        #expect(cache.tasks.map(\.id) == ["b"])
        #expect(cache.lists[0].sections[0].tasks.map(\.id) == ["b"])
    }

    @Test func flattenedTaskGetsListNameOnUpsert() {
        var cache = SyncCache()
        cache.upsertList(makeList(id: "L1", name: "Groceries", taskIds: []))
        cache.upsertTask(AppTask(id: "x", title: "Milk", listId: "L1", sectionId: "sec-L1"))
        #expect(cache.tasks.first { $0.id == "x" }?.listName == "Groceries")
    }
}

// MARK: - SSE line parsing

struct SSEParsingTests {
    @Test func fieldValueStripsPrefixAndOneSpace() {
        #expect(SSEClient.fieldValue(of: "data", in: "data: {\"a\":1}") == "{\"a\":1}")
        #expect(SSEClient.fieldValue(of: "data", in: "data:{\"a\":1}") == "{\"a\":1}")
        #expect(SSEClient.fieldValue(of: "event", in: "event: sync") == "sync")
        #expect(SSEClient.fieldValue(of: "data", in: "event: sync") == nil)
        #expect(SSEClient.fieldValue(of: "data", in: ": ping") == nil)
    }
}
