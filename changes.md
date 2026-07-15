# Solytiq Cloud (web) vs. Solytiq Cloud Mobile — Feature & Architecture Diff

Compared repositories:

- **Web/backend**: [skiptix/solytiq-cloud](https://github.com/skiptix/solytiq-cloud) — React 19 + Vite frontend, Express 4 + PostgreSQL 16 backend, self-hosted via Docker Compose. Commit analyzed: current `main` as of 2026-07-15.
- **Mobile**: this repository, `solytiq-cloud-mobile` — native SwiftUI iOS app (`SolytiqCloudMobile`) that talks to a `solytiq-cloud` server's REST/SSE API, plus an offline-only "local mode".

This document lists every concrete difference found by reading both codebases (routes, screens, stores, models). It does **not** speculate about roadmap intent — only what currently exists in each repo.

---

## 1. Architecture-level differences

| Aspect | Web (`solytiq-cloud`) | Mobile (`solytiq-cloud-mobile`) |
|---|---|---|
| Client stack | React 19 + Vite + Zustand + React Router 7 | SwiftUI, `ObservableObject`/`@Published` state (`AppState`, `DataStore`, `Router`), no third-party deps |
| Realtime | SSE (`GET /api/events`) feeds Zustand stores directly | SSE (`SSEClient.swift`) used **only as a "nudge"** to trigger a delta pull (`SyncEngine.swift`); never applied directly to local state |
| Offline / local data | None — web is always server-backed | **Mobile-only**: a full offline "local mode" (`AppMode.local`) backed by on-device SwiftData, usable with no server/account at all. Web has no equivalent concept |
| Multi-server | N/A (one deployment = one origin) | Mobile can connect to any self-hosted instance by URL (`ConnectServerView`), stored in Keychain — web is always same-origin |
| Auth storage | `localStorage` (Zustand persist) | iOS Keychain (`KeychainStore.swift`) |
| Device/session model | `mobile_connections` table tracks each signed-in mobile device (`device_name/model/os_version/app_version`), manageable from **Settings → Mobile** on web (list + revoke) | The mobile app *sends* the device descriptor on login (so it shows up in the web's device list) but has **no UI of its own** to view or revoke its own or other devices' sessions |
| Biometric auth | N/A | None found (no Face ID/Touch ID/`LAContext` usage) — despite Keychain-backed credentials |
| Routing | React Router 7, ~25 authenticated + public routes | 4 tabs (`home`, `calendar`, `files`, `lists`) + a single-slot sheet router (`Router.swift`) — much flatter navigation |
| Search | Full backend `search.ts` (`GET /api/search`) + frontend `CommandPalette.tsx` (⌘K-style global search across tasks/lists/timelines/milestones/meetings/workspaces) | **No search feature anywhere in the mobile app** — no API call, no UI |

---

## 2. Feature parity matrix

Legend: ✅ full · 🟡 partial · ❌ absent

| Feature | Web | Mobile | Notes |
|---|:--:|:--:|---|
| Dashboard (due today, priority, stats) | ✅ | ✅ | |
| Folders (nested groups of lists/timelines) | ✅ | 🟡 | Mobile folders have no `isPublic`/visibility toggle, no collapse state, no move-between-workspace |
| Lists ("To-Do") — CRUD, sections, tasks | ✅ | 🟡 | See §3.1 |
| List views: List / Kanban / Timeline (Gantt) | ✅ (3 view modes, per-list `view_mode`) | ❌ | Mobile only ever renders the flat "List" layout |
| Sublists (`linkedListType='sublist'`) | ✅ | ✅ | `createSublist` exists |
| Linked lists (`linkedListType='link'`, reference to unrelated list) | ✅ | ❌ | Mobile has no `apiLinkListAsTask` equivalent — `linkedListId` exists but the type distinction (sublist vs. link) isn't modeled |
| Task reordering (drag within/between sections) | ✅ (`PUT /:listId/reorder`, `/sections/reorder`, `/tasks/reorder`) | ❌ | No reorder calls anywhere in mobile networking layer |
| List/section/folder/timeline reordering | ✅ | ❌ | Same — no reorder endpoints called |
| Task sub-items (checklist inside a task) | ✅ | ✅ | `AppSubItem` present |
| Task completion timestamp (`completedAt`) & duration badge | ✅ | ❌ | Not in `AppTask`/`APITaskDTO` |
| Task attachments (upload or link a file to a task) | ✅ (`taskAttachments.ts`) | ❌ | No attachment API/UI in mobile at all |
| Archiving lists (`is_archived`, Archived modal) | ✅ | ❌ | |
| Move task between lists (`PUT /:id/move`) | ✅ | ❌ | |
| Calendar — month grid, meetings | ✅ | ✅ | |
| Calendar — drag unscheduled task onto a date | ✅ | ✅ | Mobile has this (`CalendarView.swift`, `.draggable`) |
| Recurring meetings (`recurrence_id`, repeating series) | ✅ | ❌ | `AppMeeting` has no recurrence fields |
| Meeting attendees (invite other instance users) | ✅ (`meeting_attendees`, `/:id/leave`) | ❌ | |
| CalDAV sync (Apple Calendar/Thunderbird subscription) | ✅ (`/caldav`, app-password mgmt) | ❌ | Entirely absent from mobile |
| Timelines & milestones | ✅ | ✅ | Layout variants (`vertical/compact/detailed`) exist on web; mobile doesn't expose a layout switch |
| Files — list/upload/download/delete/share (password+expiry) | ✅ | ✅ | |
| Files — storage quota display | ✅ (`GET /files/storage`) | 🟡 | Mobile shows a "storage card" in `FilesView` but has no dedicated `/storage` API call — likely computed client-side from the file list, not the server's authoritative per-user quota |
| Files — bulk download/bundle (`POST /files/bundle`) | ✅ | ❌ | |
| Files — server-rendered preview (`GET /files/:id/preview`) | ✅ | 🟡 | Mobile has `FilePreviewSheet` but downloads the raw file directly rather than calling the dedicated preview endpoint |
| Trash & restore (tasks/lists/folders/timelines/milestones) | ✅ | 🟡 | Web also has **markdown-list trash** (`/trash/markdown-lists/*`); mobile trash covers only task/list/folder/timeline (no milestone-specific restore path, no markdown lists at all) |
| Templates (capture list/timeline, reuse, share) | ✅ | ✅ | Close parity — create/list/update/delete/use all present |
| GPS tracks & route planner (GPX/FIT upload, smoothing, Valhalla routing, Overpass POIs, map rendering) | ✅ (full `/api/gps` domain + Leaflet map UI) | ❌ | **Completely absent** — no networking, no models, no screen |
| Markdown Lists (standalone markdown documents, image uploads, share links) | ✅ (`markdownLists.ts`, `MarkdownListScreen.tsx`) | ❌ | Not modeled or implemented at all |
| Automation Hub (flow-chart automations, triggers/actions, run history, HTTP/code actions) | ✅ | ❌ | Entire domain absent — no API, no data model, no UI |
| App Directory ("Discover Apps" — install/uninstall `gps`/`files`/`mcp`/`automations`) | ✅ (`apps.ts`, `AppsStoreModal.tsx`) | ❌ | |
| AI Assistant chat | ✅ | 🟡 | See §3.2 — mobile has a simpler, non-tool-using chat |
| AI tool-calling (Sol can read/write tasks, lists, files, etc. via `aiTools.ts`) | ✅ | ❌ | Mobile's `AIAPI.chat` is a plain prompt/response call — no tool execution surface |
| AI file uploads into a chat (PDF/XLSX context extraction) | ✅ | ❌ | |
| MCP server (external AI agents connect via OAuth 2.1 + PAT) | ✅ | ❌ | |
| OAuth 2.1 connector flow (DCR, consent screen, token exchange) | ✅ | ❌ | |
| Connected-app token management (`GET/DELETE /api/tokens`) | ✅ | ❌ | |
| n8n community node (wraps Admin API) | ✅ (published npm package `n8n-nodes-solytiq-cloud`) | N/A | Not a mobile-relevant feature, but a whole automation surface with no mobile equivalent |
| Admin instance-wide REST API (`/api/admin-read`, scoped API keys) | ✅ | ❌ | |
| Admin API key management UI (Settings → API) | ✅ | ❌ | |
| Admin: create/edit/delete any user, toggle `isAdmin` | ✅ | ❌ | Mobile's Settings only **lists** members (`AuthAPI.members()`), read-only — no create/edit/delete/promote |
| Admin: instance settings (AI model, 2FA toggle, storage quota, mobile-app kill switch) | ✅ (`Settings → System`) | ❌ | Mobile shows a static message pointing users to the web UI instead |
| Admin: "Nuke" (full instance reset) | ✅ (route-guarded screen) | ❌ | |
| Admin password reset flow (request/confirm) | ✅ (`/admin-password-reset/*`, `AdminPasswordResetScreen.tsx`) | ❌ | |
| First-run Setup Wizard (create first admin via setup token) | ✅ | N/A | Mobile connects to an already-set-up server; doesn't perform first-run instance setup |
| Public share pages (view a shared file/list/timeline via link, no login) | ✅ (`SharePage`, `SharedListPage`, `SharedTimelinePage`, `SharedMarkdownListPage`) | ❌ | Mobile can **create/toggle** share links for lists/timelines/files it owns, but cannot itself render someone else's public share link — that's inherently a web-page feature |
| Global search (⌘K command palette) | ✅ | ❌ | |
| Keyboard shortcuts (customizable, `registry.ts`) | ✅ | N/A | Not meaningful on touch, but confirms zero parity |
| Workspaces — list/create/switch | ✅ | ✅ | |
| Workspaces — update (rename/description/emoji/visibility) | ✅ (`PUT /workspaces/:id`) | ❌ | Mobile's `WorkspacesAPI` has no `update` — only `list`, `create`, `addMember`, `delete` |
| Workspaces — remove a member | ✅ (`DELETE /:id/members/:userId`) | ❌ | Mobile can add a member but not remove one |
| Workspace member roles (owner/member) | ✅ | 🟡 | `AppWorkspaceMember.role` is modeled/read but there's no UI to change a role |
| 2FA (TOTP) setup/enable/disable/verify | ✅ | ✅ | Close parity, including the pending-token verify flow |
| Change password | ✅ | ✅ | |
| Profile (name, email, avatar) | ✅ | ✅ | |
| Feature flags (`mobileEnabled`, etc.) | ✅ (drives conditional UI) | ✅ (mobile calls `featureFlags()`) | |
| Dark mode / appearance | ✅ (CSS-driven) | ✅ (`appearanceSection` in Settings) | |

---

## 3. Deeper dives on the largest gaps

### 3.1 Lists / "To-Do" — what's missing beyond the table

The web `ListScreen` is the single most feature-dense screen in the product; mobile's `ListDetailView` implements a meaningful subset:

- **View switcher (List/Kanban/Timeline)** — entirely absent on mobile. `lists.view_mode` isn't read or written by the mobile client, so a list set to Kanban/Timeline view on web still just renders as a flat list on mobile (harmless, since it's the same underlying data, but the Gantt/Kanban presentations themselves don't exist).
- **Reordering** — no drag-to-reorder for tasks, sections, lists, or folders on mobile (the only drag interaction implemented is "drop a task onto a calendar day").
- **`linkedListType`** — web distinguishes an owned "sublist" from a "link" to an unrelated standalone list; mobile only implements sublist creation (`createSublist`), never the plain "link" relationship.
- **Task attachments** — web tasks can have uploaded or linked file attachments (`task_attachments` table, full CRUD + download route); mobile's `AppTask` has no attachments field or API surface at all.
- **`completedAt` / duration** — web tracks exactly when a task was completed (independent of `updatedAt`) and shows a "time to finish" badge; mobile has no such field, so this data isn't even round-tripped even though the server returns it.
- **Buffered editing semantics** — web's `TaskDialog` is explicitly buffer-then-save (Cancel discards); mobile's `EditTaskSheet` behavior wasn't verified field-by-field but the underlying data model gap above (attachments/completedAt) is the more material difference.

### 3.2 AI Assistant

- Web: `Sol` is a tool-using agent — it can call the same `aiTools.ts` registry the MCP server exposes (read/write tasks, lists, files, etc.), supports uploading files into a conversation for context (PDF/XLSX text extraction), tracks per-call token usage, and its enabled state/model are admin-configurable.
- Mobile (`AIAPI.swift`, `AIAssistantSheet.swift`): creates a session, fetches history, and posts messages to `chat(sessionId:messages:)` — a plain prompt/response proxy with **no tool-calling, no file upload, no usage tracking**. It's a chat UI over the same OpenRouter-backed endpoint, but without the agentic capabilities the web client exposes.

### 3.3 GPS / Route Planner — entirely absent

The web app has a full second "workspace app" (gated behind the App Directory) for GPS: upload GPX/FIT files, smooth/decimate tracks, combine multiple tracks, plan routes with Valhalla road-snapping and Overpass POI search, edit a versioned `route_state` (control points, off-grid spans, course points), and render everything on a Leaflet map (`GPSScreen.tsx`, `GPSEditScreen.tsx`). Nothing in this domain — API client, data model, or screen — exists in the mobile codebase.

### 3.4 Markdown Lists — entirely absent

A standalone content type (separate from task-based "Lists") for freeform markdown documents with inline image uploads and their own share-link/trash lifecycle (`markdownLists.ts`, `MarkdownListScreen.tsx`, `SharedMarkdownListPage.tsx`). No mobile equivalent.

### 3.5 Automation Hub — entirely absent

Per-workspace, flow-chart-style automations (trigger → chained actions, including sandboxed JS execution via `isolated-vm` and SSRF-guarded HTTP requests), with run history and a per-node test button. This is one of the most complex subsystems in the web app (`automationEngine.ts`, `automationGraph.ts`, `automationExpressions.ts`, `codeNode.ts`, `httpNode.ts`) and has zero presence in mobile — no API calls, no models, no screen.

### 3.6 CalDAV Server — entirely absent (as a mobile *feature*)

The web backend runs a read/write CalDAV server so external calendar apps (Apple Calendar, Thunderbird) can subscribe to workspaces' milestones/tasks (read-only) and manage meetings (read/write), authenticated via a generated app password. The mobile app neither exposes this app-password management UI nor otherwise interacts with `/caldav` — its own Calendar tab talks to the regular JSON meetings API instead.

### 3.7 MCP Server + OAuth 2.1 connector — entirely absent

Lets external AI agents (e.g., Claude's MCP connector) authenticate via a full OAuth 2.1 + PKCE + Dynamic Client Registration flow and call the same tool registry the in-app AI uses. No mobile equivalent (no OAuth consent screen, no PAT/token management screen).

### 3.8 Admin capabilities — almost entirely absent on mobile

Web's Settings (admin-only sections) cover: user management (create/edit/delete/promote), instance-wide Admin REST API + scoped API key issuance, app settings (AI model/enable, 2FA gate, storage quota, mobile-app kill switch), storage/system stats, and the destructive "Nuke" reset. Mobile's Settings screen explicitly punts on all of this with a static string: *"More settings are available in the web interface of your self-hosted instance — storage quotas, server config, SMTP and danger zone."* The only admin-adjacent thing mobile does is **read** the member list.

### 3.9 Global Search — entirely absent

Web's `search.ts` + `CommandPalette.tsx` provide instant cross-entity search (tasks, lists, timelines, milestones, meetings, workspaces). No search bar, endpoint call, or shortcut exists anywhere in the mobile app.

---

## 4. Mobile-only capabilities (not present on web)

- **Offline "local mode"** — the mobile app can be used with no server/account at all, storing everything in an on-device SwiftData store (`AppMode.local`). The web app has no offline/local-only concept; it always requires a live backend connection.
- **Multi-instance connect flow** — a guided "Connect to Server" wizard (URL → username → password → optional 2FA) lets one mobile install point at any self-hosted Solytiq Cloud instance, with the URL and token stored in Keychain. The web app is inherently single-origin (it *is* the instance).
- **Native iOS presentation chrome** — glass tab bar, sheet-based single-modal router, drag-and-drop task scheduling via native `.draggable`/`.dropDestination`, all iOS-idiomatic and not shared code with the web frontend (expected, given the platforms, but noted since it's mobile-exclusive UI work rather than a port).

---

## 5. Summary

The mobile app implements a solid, functional core of Solytiq Cloud — dashboard, lists/tasks (flat view only), folders, calendar with drag-to-schedule, files, timelines, templates, trash, workspaces, 2FA, and a basic AI chat — backed by a real offline-capable sync engine (bootstrap + delta + SSE nudges).

Entirely missing web domains: **GPS/Route Planner, Markdown Lists, Automation Hub, CalDAV server integration, MCP server/OAuth connector flow, Admin REST API + admin panel (users, API keys, instance settings, Nuke), Global Search/Command Palette, and public share-page rendering.**

Partially missing within otherwise-shared domains: **List Kanban/Timeline views, task/list/section reordering, task attachments, task completion timestamps, meeting recurrence and attendees, linked (non-sublist) lists, list/folder archiving, workspace update/member-removal, and AI tool-calling/file-context.**
