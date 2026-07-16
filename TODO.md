# Implementation Progress — Mobile Feature Parity

Tracking work against [implementation.md](implementation.md). This repo is an iOS
SwiftUI app; the plan is a large (self-described "multi-week") effort. Items are
worked in the doc's suggested build order — foundational/self-contained first.

Legend: `[x]` done this pass · `[~]` partial/scaffolded · `[ ]` not started

## Foundation — model/DTO/mapping field plumbing (prereq for §1, §3)
- [x] `AppTask.completedAt`, `AppTask.linkedListType` (+ DTO + mapping) — §1.3, §1.4
- [x] `AppList.viewMode`, `AppList.isArchived` (+ DTO + mapping) — §1.1, §1.6
- [x] `AppFolder.isPublic`, `.collapsed`, `.workspaceId` (+ DTO + mapping) — §3
- [x] New domain models: `AppMobileConnection`, `AppConnectedToken`,
      `AppSearchResult`, `AppInstalledApp`

## §1 — Lists / To-Do gaps
- [x] §1.1 List/Kanban/Timeline view-mode field + persist on switch
- [x] §1.1 Segmented mode switcher in `ListDetailView`
- [x] §1.1 `KanbanListView` (columns = sections, cards = tasks)
- [~] §1.1 Timeline/Gantt view — deferred (largest sub-item; needs `completedAt`)
- [~] §1.2 Drag-to-reorder — reorder API methods added; full drag UI deferred
- [x] §1.3 Linked lists: `linkedListType` field + `ListsAPI.linkList` + DataStore
- [x] §1.4 Task `completedAt` field + "Created → Done" strip in `EditTaskSheet`
- [~] §1.5 Task attachments — deferred (own domain; needs new API + models + UI)
- [~] §1.6 List archiving — `isArchived` field + `unarchive`/archived-list API
- [x] §1.7 Move task between lists: `TasksAPI.move` + `MoveTaskSheet` + wiring

## §2 — Calendar / Meetings
- [x] §2.2 `MeetingsAPI.leave` + `DataStore.leaveMeeting`
- [~] §2.1 Recurring meetings — deferred (needs backend recurrence-shape confirm)

## §3 — Folders
- [x] Folder `isPublic`/`collapsed`/`workspaceId` fields + `FoldersAPI` patch
- [x] `FoldersAPI.moveToWorkspace`

## §4 — Workspaces
- [x] §4.1 `WorkspacesAPI.update` + `WorkspaceSettingsSheet`
- [x] §4.2 `WorkspacesAPI.removeMember` + member list w/ remove in the sheet

## §5 — Files
- [x] §5.1 `FilesAPI.storage()` authoritative quota (+ wired into `FilesView`)
- [~] §5.2 Bundle download — API method added; multi-select UI deferred

## §6 — Trash
- [x] §6.1 Milestone trash: `TrashAPI.milestones()/restore/deleteForever`


## §12 — CalDAV credential screen
- [x] `CalDAVAPI.status/generatePassword/revoke` + Settings section

## §14 — MCP token management
- [x] `TokensAPI.list/revoke` + Settings "Connected Apps" section

## §15 — Global Search
- [x] `SearchAPI.search` + `SearchSheet` + Dashboard toolbar entry

## §17 — Device / session management
- [x] `AuthAPI.mobileConnections/revokeMobileConnection` + Settings "Devices"

## Large standalone domains — deferred (own workstreams per the plan)
- [~] §7 AI tool-calling parity
- [ ] §9 Markdown Lists
- [ ] §10 Automation Hub
- [ ] §16 Public share viewing (needs backend Universal-Links config)
- [~] §18 Sync-engine extensions for new syncable entities

## Removed from mobile scope (dropped from the plan)
- §8 GPS / Route Planner — web-only
- §11 App Directory ("Discover Apps") — web/admin only; no install-state gating on mobile
- §13 Admin capabilities — user/API-key/instance-settings/password-reset/Nuke stay on web

> Note: an `AppsAPI` client (§11) was added in the first PR before this scope
> change. It's harmless dead code now — remove it in a later cleanup pass.
