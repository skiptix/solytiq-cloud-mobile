# Implementation Progress — Mobile Feature Parity

Tracking work against [implementation.md](implementation.md). This repo is an iOS
SwiftUI app. All in-scope sections of the plan are now implemented.

Legend: `[x]` done · `[~]` partial (with reason) · `[ ]` not started ·
`[—]` out of mobile scope

## Foundation — model/DTO/mapping field plumbing
- [x] `AppTask.completedAt`, `.linkedListType` (+ DTO + mapping)
- [x] `AppList.viewMode`, `.isArchived` + `ListViewMode`
- [x] `AppFolder.isPublic`, `.collapsed`, `.workspaceId`
- [x] New models: `AppMobileConnection`, `AppConnectedToken`, `AppSearchResult`,
      `AppTaskAttachment`, `AppMeetingAttendee`, `MeetingRecurrence`,
      `AppMarkdownList`, `AppAutomation`/`AppAutomationNode`/`AppAutomationRun`,
      `JSONValue`

## §1 — Lists / To-Do gaps
- [x] §1.1 List/Kanban/Timeline view-mode field + persist on switch
- [x] §1.1 Segmented mode switcher + `KanbanListView`
- [x] §1.1 `TaskGanttView` — Gantt with Day/Week/Month zoom, deadline flags, Today line
- [x] §1.2 Drag-to-reorder tasks within a section (`.draggable`/`.dropDestination`)
      + section up/down reorder; reorder API + optimistic cache wiring
- [x] §1.3 Linked lists: `linkedListType` + `ListsAPI.linkList` + `LinkListPickerSheet`
- [x] §1.4 Task `completedAt` + "Created → Done" strip
- [x] §1.5 Task attachments: `TaskAttachmentsAPI` (upload/link/download/delete) +
      `EditTaskSheet` section + `AttachFromFilesSheet`
- [x] §1.6 Archiving: `isArchived` + `archived()`/`unarchive()` + `ArchivedSheet` + entry
- [x] §1.7 Move task: `TasksAPI.move` + `MoveTaskSheet`

## §2 — Calendar / Meetings
- [x] §2.1 Recurring meetings: `repeat {freq,interval,count}` on create + Repeat control
- [x] §2.2 Attendees: invite picker on create, read-only invited view + Leave

## §3 — Folders
- [x] Fields + `FoldersAPI` patch + `moveToWorkspace`
- [x] `EditFolderSheet` (name/emoji/color + `VisibilityToggle`) + `MoveFolderSheet`
- [x] Collapse persistence wired to the server `collapsed` field

## §4 — Workspaces
- [x] §4.1 `WorkspacesAPI.update` + `WorkspaceSettingsSheet`
- [x] §4.2 `removeMember` + member management in the sheet

## §5 — Files
- [x] §5.1 `FilesAPI.storage()` authoritative quota
- [x] §5.2 `FilesAPI.bundle()` + multi-select mode + share sheet
- [x] §5.3 Preview endpoint — download already uses `/preview`

## §6 — Trash
- [x] §6.1 Milestone trash (end-to-end via `TrashSheet`)
- [x] §6.2 Markdown-list trash (`.markdownList` TrashKind + API + wiring)

## §7 — AI Assistant tool-calling
- [x] `AIAPI.tools()/execute()/uploadFile()` + request/execute/respond loop in
      `sendAIMessage` (degrades to plain chat when no tool registry)
- [x] File-attach button in `AIAssistantSheet`

## §9 — Markdown Lists
- [x] `MarkdownListsAPI` (CRUD + share + image upload) + `AppMarkdownList`
- [x] `MarkdownListView` editor + dependency-free `MarkdownRenderedView`
- [x] Wired into `AddChoiceSheet` + `ListsView` listing

## §10 — Automation Hub
- [x] `AutomationsAPI` (node-types/CRUD/runs/test) + models + `JSONValue`
- [x] `AutomationsListView` (enable toggle, create) + `AutomationEditorView`
      (vertical step-cards, schema-driven forms, per-node Test, run history)
- [x] Entry point in `ListsView` (server mode)

## §12 / §14 / §15 / §17 — Settings + Search
- [x] CalDAV, Connected Apps (tokens), Global Search, Device sessions

## §16 — Public share viewing
- [x] `SafariView` in-app browser + `OpenSharedLinkSheet` (Settings entry).
      Universal-Links deep-linking needs a backend `apple-app-site-association`
      config — flagged as backend-adjacent, not implemented here.

## §18 — Sync engine
- [x] New entities (attachments/markdown/automations) ride the engine's generic
      SIGNAL path (`entityRevisions` bump → screen refetch); screens observe it.
      No offline SwiftData models — these are server-mode-only per the plan.

## Removed from mobile scope
- [—] §8 GPS / Route Planner — web-only
- [—] §11 App Directory — web/admin only
- [—] §13 Admin capabilities — stay on web

## Notes / caveats
- No Swift toolchain in this environment — code is written by close
  pattern-matching, not compiled. New optional patch-body/model fields carry
  explicit defaults so existing call sites stay source-compatible.
- A few backend shapes (attachments, markdown lists, automations, recurrence,
  AI tools) were inferred from the plan + the Solytiq MCP tool schemas; all
  decoders fail soft (`try?` → empty/default) so a shape mismatch degrades
  gracefully rather than crashing.
- The `AppsAPI` client (from the first PR, now out of scope) remains as dead
  code to remove in a later cleanup.
