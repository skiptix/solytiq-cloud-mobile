# Implementation Plan — Mobile Full Feature Parity with `solytiq-cloud` Web

Source: [changes.md](changes.md). This file breaks every gap identified there into concrete engineering work against this repo's existing conventions (`Networking/*API.swift` clients, `Models/DomainModels.swift` + `DTO/APIModels.swift`, `Repositories/DataStore*.swift` + `SyncEngine.swift`, `Screens/*`, `Sheets/*`, `Router.swift`/`MainTabView.swift`).

Each section lists: the backend surface it talks to (already exists on the server — nothing here requires backend work), the mobile files to add/change, and the concrete steps. Sections are ordered roughly by dependency and effort (cheap/foundational first, large standalone domains last).

> **Out of scope for mobile.** The following are intentionally **not** part of the mobile app and have been removed from this plan — the section numbers are left with gaps rather than renumbered so existing cross-references stay valid:
> - **§8 GPS / Route Planner** — web-only.
> - **§11 App Directory ("Discover Apps")** — instance-wide app install/uninstall stays a web/admin concern; mobile does no install-state gating.
> - **§13 Admin capabilities** — user/API-key/instance-settings management, admin password reset, and Nuke all stay on web.

---

## 0. Conventions to follow throughout

- New API clients go in `Networking/<Domain>API.swift`, mirroring existing files (`static let shared`/`APIClient`-based, `async throws` methods returning DTOs).
- New wire types go in `DTO/APIModels.swift` as `APIXxxDTO: Codable`; new UI-facing types go in `Models/DomainModels.swift` as `AppXxx: Identifiable, Codable, Hashable`; mapping between them belongs in `Models/PersistedModels+Mapping.swift`.
- Anything that must work offline needs a SwiftData persisted model in `Models/PersistedModels.swift` plus sync support in `Repositories/DataStore+*.swift` and `SyncEngine.swift` (bootstrap fetch + delta channel + SSE nudge handling). Anything explicitly server-only (MCP/OAuth, Automations editor) can skip local persistence and just hit the network live, same pattern as `AIAPI`.
- New screens go in `Screens/<Domain>/`, new modals in `Sheets/`, new top-level destinations get added to `Router.swift` (`SheetRoute` / `ListsRoute` enums) and, if they need their own tab, `MainTab` in `Router.swift` + `MainTabView.swift` + `GlassTabBar.swift`.
- Every new entity type needs `checked`/list of fields to exactly match the server DTO shape documented in `CLAUDE.md`'s Core Data Model table (see `changes.md` §1–§3 for the field-level deltas already identified).

---

## 1. Lists / "To-Do" — close the gaps (§3.1 of changes.md)

### 1.1 List view modes: List / Kanban / Timeline (Gantt)
- Backend: `lists.view_mode` field, already returned by `GET /api/lists` and settable via `PUT /api/lists/:listId` (`viewMode` in body).
- Add `viewMode: String` (`"list" | "kanban" | "timeline"`) to `APIListDTO` and `AppList`; map through `PersistedModels+Mapping.swift`.
- `ContentAPI.ListsAPI.update` already does generic `UpdateBody` patches — add `viewMode` to whatever patch type is used so a view switch can persist.
- Build a segmented control (List/Kanban/Timeline) at the top of `ListDetailView.swift`, matching the web's tab switcher position (above the progress hero).
- **List** view: already implemented — reuse as-is.
- **Kanban** view: new `KanbanListView.swift` under `Screens/Lists/` — sections as horizontal scrollable columns, each `TaskRowView` as a card; drag a card between columns to change `sectionId` (see §1.2 for the underlying reorder API), drag a column header to reorder sections.
- **Timeline (Gantt)** view: new `TaskGanttView.swift` — horizontally scrollable rows grouped by section, each task a bar from `createdAt` to `completedAt` (or "today" if open — requires §1.4's `completedAt` field), deadline as a flag marker (red if overdue). Needs Day/Week/Month zoom controls and a "Today" recenter button, mirroring `TaskTimelineView.tsx`. This is the highest-effort sub-item in this section — treat as its own task.
- Persist the active mode by writing `viewMode` on switch (same list, no new entity).

### 1.2 Drag-to-reorder (tasks within/between sections, sections, lists, folders)
- Backend endpoints already exist and are unused by mobile:
  - `PUT /api/tasks/reorder` (dashboard tasks)
  - `PUT /api/lists/:listId/reorder` (list-level reorder among siblings)
  - `PUT /api/lists/:listId/sections/reorder`
  - `PUT /api/lists/:listId/sections/:sectionId/tasks/reorder`
  - `PUT /api/folders/*` reorder equivalents (check `folders.ts` if a distinct reorder route exists; otherwise `position` is set via the folder `PUT`).
- Add `reorder(listId:sectionId:orderedIds:)`-style methods to `ContentAPI.swift` (`TasksAPI`, `ListsAPI`) posting the new ordering (array of ids) as the server route expects.
- Wire SwiftUI's `.onMove`/`.draggable`+`.dropDestination` (already used for calendar drag-to-schedule in `CalendarView.swift` — same pattern) into `ListDetailView.swift`'s task rows, section headers, and `ListsView.swift`'s list/folder rows.
- Update local `position` fields optimistically in `DataStore`, then fire the reorder call; reconcile via the next delta pull like other mutations.

### 1.3 Linked lists (`linkedListType = 'link'`, distinct from sublist)
- Backend: `POST /api/lists/:listId/sections/:sectionId/tasks/link` (creates a `'link'`-type reference to an existing standalone list — as opposed to the already-implemented `.../tasks/sublist`).
- Add `linkedListType: String?` (`"sublist" | "link"`) to `APITaskDTO`/`AppTask` alongside the existing `linkedListId`.
- Add `ContentAPI.TasksAPI.linkList(listId:sectionId:targetListId:)` calling the `/link` endpoint.
- UI: extend the "add task" / task detail action sheet with a "Link an existing list" option (a list picker) next to the existing "Create sublist" action; render linked (non-owned) list references distinctly from sublists in `TaskRowView.swift` (e.g. no progress ring rollup, since the child isn't owned).

### 1.4 Task completion timestamp + duration
- Backend already returns `completedAt` on tasks (`tasks.completed_at`, set server-side when `checked` flips true/false — no client action needed beyond reading/patching `checked`).
- Add `completedAt: Date?` to `APITaskDTO`/`AppTask`.
- In `EditTaskSheet.swift`, add a compact "Created → Done" strip (mirrors `TaskMiniTimeline`) plus a duration badge once checked, using `createdAt`/`completedAt`.
- Required by §1.1's Timeline/Gantt view (bar end point).

### 1.5 Task attachments
- Backend: `taskAttachments.ts` — `GET/POST /api/tasks/:taskId/attachments`, `POST .../attachments/link` (attach an existing `shared_files` row), `DELETE /:attachmentId`, `GET /:attachmentId/download`.
- New `Networking/TaskAttachmentsAPI.swift`: `list(taskId:)`, `upload(taskId:fileName:mimeType:data:)` (reuse the multipart pattern from `FilesAPI.upload`), `link(taskId:sharedFileId:)`, `delete(attachmentId:)`, `download(attachmentId:)`.
- New `AppTaskAttachment: Identifiable, Codable, Hashable` (`id`, `taskId`, `attachmentType: "upload"|"linked"`, `fileName`, `mimeType`, `size`, `sharedFileId: String?`) in `DomainModels.swift`.
- UI: add an "Attachments" section to `EditTaskSheet.swift` — thumbnail/file-icon row, a "+" to upload new or pick from existing Files (reuse `FilesView`'s file list as a picker), tap to preview via the existing `FilePreviewSheet.swift`, swipe/long-press to delete.

### 1.6 List/folder archiving
- Backend: `PUT /api/lists/:listId/unarchive`; archived lists are excluded from `GET /api/lists` unless `?archived=true`; `archive_list` is otherwise only reachable via an Automation action on web, but nothing stops a plain "archive" mutation from being exposed directly — check whether `lists.ts` has a direct archive route besides the automation action; if not, add archiving to the mobile roadmap as **read/restore only** (list `GET /api/lists?archived=true` + `PUT /:listId/unarchive`) since there's no confirmed direct "archive" write route outside the Automation Hub (§10) — verify against `backend/src/routes/lists.ts` before implementing the write side.
- Add `isArchived: Bool` to `APIListDTO`/`AppList`.
- New `Sheets/ArchivedSheet.swift` mirroring `TrashSheet.swift`'s structure: list of archived lists, "Unarchive" action per row. Add `.archived` case to `Router.SheetRoute`, surface an entry point next to Trash in Settings or a list's action menu.

### 1.7 Move task between lists
- Backend: `PUT /api/tasks/:id/move` (body likely `{listId, sectionId}` — confirm exact shape in `backend/src/routes/tasks.ts` before wiring).
- Add `ContentAPI.TasksAPI.move(id:toListId:toSectionId:)`.
- UI: new `Sheets/MoveTaskSheet.swift` (folder → list → section picker), invoked from the task's action menu in `EditTaskSheet.swift`/`TaskRowView.swift`, mirroring web's `MoveTaskModal.tsx`.

---

## 2. Calendar / Meetings

### 2.1 Recurring meetings
- Backend: `meetings.recurrence_id` groups occurrences of a repeating series (exact recurrence-rule shape/creation route needs confirming in `backend/src/routes/meetings.ts` — the endpoint list only showed plain CRUD + `/leave`, so recurrence generation may happen server-side from a rule payload on `POST /`; read that route's body-parsing before implementing).
- Add `recurrenceId: String?` and whatever recurrence-rule fields the create payload expects to `APIMeetingDTO`/`AppMeeting`.
- `MeetingSheet.swift`: add a "Repeat" control (None/Daily/Weekly/Monthly, matching whatever options the backend accepts) when creating a new meeting; when editing an occurrence of a series, offer "This event" vs. "All events" like standard calendar apps.

### 2.2 Meeting attendees
- Backend: `meeting_attendees` table; `POST /api/meetings/:id/leave` exists (an attendee removing themselves) — attendee *invitation* likely happens via the meeting create/update body (an array of user ids) since there's no separate `/attendees` sub-route in the endpoint list; confirm in `meetings.ts`.
- Add `attendeeIds: [String]` (or richer `[AppMeetingAttendee]`) to `AppMeeting`.
- `MeetingSheet.swift`: add an attendee picker (reuse the members list already fetched via `AuthAPI.members()`), show attendee avatars on the meeting row/detail. Meetings you're invited to (not organizing) should render read-only, with a "Leave" action calling the new `leave(id:)` method.
- New `ContentAPI.MeetingsAPI.leave(id:)`.

---

## 3. Folders

- Add `isPublic: Bool`, `collapsed: Bool`, `workspaceId: String?` to `APIFolderDTO`/`AppFolder` (currently missing per `changes.md` §2).
- `FoldersAPI.update` patch type: include `isPublic`/`collapsed`.
- Add a workspace-move action: backend has `PUT /api/folders/:id/workspace`; add `FoldersAPI.moveToWorkspace(id:workspaceId:)`; surface via a "Move to workspace…" action in `FolderDashboardView.swift`'s menu (mirrors §4.2's list/timeline equivalent if those are added too).
- Add the same public/private visibility toggle UI pattern already likely used elsewhere (two-button lock/globe selector, per web's design system) to folder settings.
- Add collapse/expand persistence in `ListsView.swift`'s folder rows (currently, if folders can collapse at all, confirm whether it's local-only UI state today — if so, wire it to the `collapsed` server field so it syncs across devices).

---

## 4. Workspaces

### 4.1 Update workspace (`PUT /api/workspaces/:id`)
- Add `WorkspacesAPI.update(id:name:description:emoji:visibility:)` to `ContentAPI.swift`.
- New `Sheets/WorkspaceSettingsSheet.swift` (mirrors web's `WorkspaceSettingsModal.tsx`) — edit name/description/emoji/visibility, reachable from `WorkspaceSwitcherSheet.swift`'s per-workspace menu.

### 4.2 Remove a workspace member
- Backend: `DELETE /api/workspaces/:id/members/:userId`.
- Add `WorkspacesAPI.removeMember(workspaceId:userId:)`.
- In the new `WorkspaceSettingsSheet`, list members (`GET /:id/members`) with a swipe-to-remove or per-row "Remove" action (owner/admin only — gate on `AppWorkspaceMember.role`).

### 4.3 Member role display/management
- If the backend supports changing a member's role beyond owner/member (check `workspaces.ts` — the endpoint list only shows add/remove, no explicit role-change route), skip role editing; otherwise wire it into the same sheet. At minimum, show each member's role as a label (data already modeled in `AppWorkspaceMember.role`).

---

## 5. Files

### 5.1 Authoritative storage quota
- Backend: `GET /api/files/storage` returns the server's per-user quota + used bytes (`app_settings.storage_quota_per_user`).
- Add `FilesAPI.storage()` returning `(used: Int, quota: Int)`.
- Replace `FilesView.swift`'s `storageCard`'s client-computed total (sum of listed files) with this authoritative value.

### 5.2 Bundle download
- Backend: `POST /api/files/bundle` (zips multiple files server-side).
- Add `FilesAPI.bundle(ids: [String])` returning a downloadable URL/data, same pattern as `download(id:)`.
- UI: add multi-select mode to `FilesView.swift` (long-press to enter selection, checkbox per row, a "Download selected" toolbar action using the iOS share sheet).

### 5.3 Server-rendered preview endpoint
- Backend: `GET /api/files/:id/preview` — likely returns a lighter/transcoded representation for preview vs. the raw file.
- Update `FilePreviewSheet.swift` to call this endpoint instead of the full `download(id:)` call when just previewing (keep `download` for the explicit "Save"/"Share" action).

---

## 6. Trash

### 6.1 Milestone-specific restore
- Backend: `GET /api/trash/milestones`, `POST /:trashId/restore`, `DELETE /:trashId` — distinct from the timeline trash bucket.
- Add `TrashAPI.milestones()`, `restoreMilestone(entryId:)`, `deleteMilestoneForever(entryId:)` to `TimelinesTrashAPI.swift`.
- `TrashSheet.swift`: add a "Milestones" section/tab alongside the existing Tasks/Lists/Folders/Timelines ones.

### 6.2 Markdown list trash
- Depends on §9 (Markdown Lists) existing at all. Once added: `GET /api/trash/markdown-lists`, restore/delete-forever endpoints, same pattern as above.

---

## 7. AI Assistant — reach tool-calling parity

- Backend: `GET /api/ai/tools` (tool defs), `POST /api/ai/execute` (run a data tool), `POST /api/ai/files` (upload a file into a chat for context), `GET/POST/DELETE /api/ai/sessions`.
- Extend `AIAPI.swift`:
  - `tools()` — fetch the tool registry once per session/app-launch.
  - `execute(toolName:args:)` — run a server-side data tool (task/list read/write etc.) when the model requests one.
  - `uploadFile(sessionId:fileName:mimeType:data:)` — multipart upload into `ai_chat_files`.
- Update `AIAssistantSheet.swift`'s chat loop: when a `chat()` response includes tool calls (check the response shape — currently `chat()` returns a flat `String`, so this likely needs to change to a richer response type mirroring `tool_calls`/`metadata` the server already returns per `ai_chats` schema), execute each via `execute()` and feed results back into the conversation before showing the final assistant message — same request/execute/respond loop as `components/AIAssistant/index.tsx` on web (`SUPERSEDED_CLIENT_TOOLS` there is the reference for which tools are server vs. client-side; mobile can start by supporting only server-side data tools and skip client-coupled ones like GPS browser-downloads that don't apply to mobile).
  - **Client-side tools note**: web reserves some tools for local execution (navigation, reorder/move, sublists, workspace switch). Decide per-tool whether mobile executes locally (dispatch into `Router`/`DataStore`) or always routes through `POST /api/ai/execute`; starting with "always server-side" is simplest and matches what most of the registry already is.
- Add a file-attach button to the AI chat input, using the same file picker as §1.5's attachment upload.
- Add usage/limits display if desired (`ai_usage` — optional, lower priority; web surfaces this mainly in admin, not the chat itself).

---

## 9. Markdown Lists (new domain)

- Backend: `markdownLists.ts` — `GET /`, `GET /:id`, `POST /`, `PUT /:id`, `DELETE /:id`, `PUT /:id/share`, `POST /:id/images`, `GET /:id/images/:imageId`.
- New `Networking/MarkdownListsAPI.swift` covering all of the above (image upload as multipart, same pattern as `FilesAPI.upload`).
- New `AppMarkdownList: Identifiable, Codable, Hashable` (`id`, `title`, `content: String` (markdown source), `folderId`, `workspaceId`, share fields mirroring `AppList`'s).
- New `Screens/MarkdownLists/MarkdownListView.swift` — a markdown editor. Options:
  - Minimal: a `TextEditor` for raw markdown + a live-rendered preview pane below/toggleable (iOS 15+ `AttributedString(markdown:)` covers basic rendering; for full CommonMark parity consider a small markdown-render dependency, but check whether the project's "no third-party deps" convention (per `changes.md` §1) should be preserved — if so, build a lightweight custom renderer covering the subset web's `MarkdownView.tsx` actually uses).
  - Image insertion: tap to insert, upload via `POST /:id/images`, insert a markdown image reference at the cursor.
- Wire into `ListsView.swift`/`AddChoiceSheet.swift` as a third creatable content type alongside List and Timeline (mirrors web's `AddWizard` step order: choose List/Timeline/Markdown List → template-select → classic wizard).
- Add markdown-list trash support (§6.2) and template support if `templates.ts`'s `type` enum covers markdown lists (confirm — the documented `type: 'list'|'timeline'` in `CLAUDE.md` suggests markdown lists are **not** templatable; if so, skip template integration for this type).

---

## 10. Automation Hub (new domain — second-largest item)

Given the complexity documented in `CLAUDE.md` (flow-chart graph model, sandboxed JS execution, SSRF-guarded HTTP action, run history, per-node testing), mobile should **not** attempt a visual node-canvas editor initially — web itself falls back to "a vertical step-card list" on mobile viewports (`AutomationEditorScreen.tsx`'s `useMobile()` branch), which is the right reference UX to port natively.

### 10.1 Networking
- New `Networking/AutomationsAPI.swift` covering `automations.ts`: `nodeTypes()`, `list()`, `get(id:)`, `runs(id:)`, `test(id:nodeId:)`, `create()`, `update(id:graph:)`, `setEnabled(id:enabled:)`, `delete(id:)`.
- New DTOs/models: `AppAutomation` (id, name, enabled, `graph` — array of ordered nodes, each `{id, type, params}`), `AppAutomationRun` (status, steps, error, isTest).

### 10.2 UI
- `Screens/Automations/AutomationsListView.swift` — gallery of automations for the active workspace (mirrors `AutomationsScreen.tsx`), enable/disable toggle per row, create button.
- `Screens/Automations/AutomationEditorView.swift` — **vertical step-card list**: one card for the trigger (dropdown: `task_completed`/`list_all_completed`/`task_created`/`schedule`), then N action cards in order (add/remove/reorder via up/down or drag), each rendering its `paramsSchema` as a form (reuse a generic schema-driven form renderer — text fields, dropdowns for `isListId`/`isFolderId`/`isWorkspaceId` params populated from already-loaded lists/folders/workspaces, key-value repeatable rows for the HTTP action's headers/query params, a code editor `TextEditor` for the `code` action).
- Per-card "Test" button calling `test(id:nodeId:)`, showing the result inline (skip the desktop-only drag-and-drop field-picker/`JsonTree` — a mobile-appropriate simplification is to show the Input/Output JSON as a collapsible read-only tree using a basic recursive `DisclosureGroup`).
- Run History: a simple list of `AppAutomationRun` (status badge, timestamp, tap to expand steps).
- Surface the tab/entry point whenever connected to a server (no App Directory install gating on mobile — that catalog is web-only).

---

## 12. CalDAV integration

- Backend: `caldavManage.ts` — `GET /api/caldav` (status), `POST /api/caldav/password` (generate/regenerate app password), `DELETE /api/caldav` (revoke).
- Add `Networking/CalDAVAPI.swift`: `status()`, `generatePassword()`, `revoke()`.
- New section in `SettingsView.swift` ("Calendar Sync", mirrors web's `UserSettingsModal` tab): show connection status, a "Generate App Password" button that displays the CalDAV URL + generated password once (with a copy button, since it's shown only once), and a "Revoke" action.
- The actual CalDAV *subscription* itself is consumed by iOS's native Calendar app (Settings → Calendar → Accounts → Add CalDAV Account), not by this app — mobile's job here is only exposing the credential management screen so a user can set up that native subscription. Add a short in-app instructional note with the server's `/caldav` URL, similar to how the web surfaces it.

---

## 14. MCP Server / OAuth connector — token management only

- The actual OAuth 2.1 DCR/authorize/consent/token-exchange dance (§ MCP Server in `CLAUDE.md`) is inherently a **web** flow driven by the external agent (e.g., Claude) redirecting a browser through `/oauth/consent`; there's no scenario where the mobile app itself performs that handshake.
- What mobile *can* usefully do: **view and revoke** already-connected external agents/tokens.
  - Backend: `tokens.ts` — `GET/DELETE /api/tokens`.
  - Add `Networking/TokensAPI.swift`: `list()`, `revoke(id:)`.
  - New section in `SettingsView.swift` ("Connected Apps") listing active PATs (client name, created date) with a revoke action per row — mirrors the token-list half of web's `UserSettingsModal` "Claude MCP" section, minus the "connect" button (which stays web-only).

---

## 15. Global Search / Command Palette

- Backend: `GET /api/search?q=` (`search.ts`) — cross-entity search over tasks/lists/timelines/milestones/meetings/workspaces.
- Add `Networking/SearchAPI.swift`: `search(query:)` returning a discriminated-union result list (add `APISearchResultDTO`/`AppSearchResult` with a `kind` enum matching the entities above).
- UI: add a search bar (`.searchable()` modifier) to a natural home — either its own tab or a persistent entry point from `DashboardView.swift`'s toolbar (a magnifying-glass button opening a full-screen `Sheets/SearchSheet.swift` with results grouped by kind, tap-through to the right screen/sheet via `Router`).
- No native equivalent needed for the ⌘K keyboard-shortcut trigger itself (touch has no keyboard shortcut), but the underlying search capability and results UI should match.

---

## 16. Public share-page viewing

- Web's `SharePage`/`SharedListPage`/`SharedTimelinePage`/`SharedMarkdownListPage` render a public share link (`/share/:token`, etc.) for anyone, logged in or not.
- Mobile doesn't need to *reimplement* these pages natively — the pragmatic parity move is: when a share link (or its raw token) is opened via a Universal Link / pasted into the app, open it in an in-app `SFSafariViewController`/`WKWebView` pointed at the connected server's public share URL, rather than leaving the user without any way to view a link they were sent. Add:
  - A "Copy share link" action already likely exists for owned lists/timelines/files (confirm) — additionally register the app for the server's `/share/*` URL pattern as a Universal Link (requires an `apple-app-site-association` entry on the backend/nginx side — flag this as a **backend-adjacent** config change, not pure mobile work) so tapping a shared link opens natively.
  - Fallback: an in-app "Open in browser" affordance for any share token entered manually.

---

## 17. Device / session management (mobile's own connections)

- Backend already tracks this app's logins in `mobile_connections` and exposes `GET/DELETE /api/auth/mobile-connections/:id` — currently only consumed by the *web* Settings → Mobile screen.
- Add `AuthAPI.mobileConnections()` and `AuthAPI.revokeMobileConnection(id:)`.
- New "This Device" / "Other Sessions" section in `SettingsView.swift`'s Security section: list connected devices (name/model/OS/app version/last seen), allow revoking others, and clearly mark the current device. This closes the one asymmetry noted in `changes.md` §1 where mobile *reports* its session but can't manage any sessions itself.

---

## 18. Sync engine updates required to support the above

`SyncEngine.swift`'s bootstrap/delta model needs to know about every new syncable entity added above so changes propagate across devices/the web app in real time, not just on next full bootstrap:

- Extend `SyncAPI.bootstrap`/`delta` response handling (and the corresponding backend `sync.ts` payload — confirm it already includes markdown lists/automations/attachments as SIGNAL or PATCH entities per `CLAUDE.md`'s "automation is a SIGNAL sync entity" note) for: task/milestone attachments, markdown lists, automations.
- For entities documented as **SIGNAL** sync type (refetch-on-bump rather than patch-in-place — automations and templates are called out explicitly in `CLAUDE.md`), mirror that in `DataStore`: on the relevant `entityRevisions.*` bump via SSE, trigger a full refetch of that domain's list rather than trying to patch it in place, exactly like automations/templates behave on web.
- Add SwiftData persisted models (`Models/PersistedModels.swift`) + mapping only for entities that should work offline in "local mode" — likely tasks/lists/folders/timelines/meetings/files stay as-is, while Automations/MCP tokens data are reasonably **server-mode only** (no offline story needed, matching that they're inherently server-dependent features even on web).

---

## Suggested build order

1. §1 (List gaps) + §18 (sync groundwork) — highest daily-usage impact, and the sync work de-risks everything after it.
2. §2 (Calendar recurrence/attendees), §3 (Folders), §4 (Workspaces), §5 (Files), §6 (Trash) — round out existing domains to full parity.
3. §17 (device sessions), §12 (CalDAV credential screen), §14 (token management) — small, self-contained Settings additions.
4. §7 (AI tool-calling) — moderate effort, high visible value.
5. §15 (Search) — self-contained, moderate effort.
6. §9 (Markdown Lists) — new domain, moderate effort.
7. §10 (Automation Hub) — largest remaining item, plan as a dedicated workstream.
8. §16 (Public share viewing) — depends on a backend/nginx Universal Links config decision; coordinate before starting.
