# Solytiq Cloud — iOS Design Handoff

**Read this file in full before writing or changing any code.** It tells you what's in this bundle, what fidelity to treat it at, and the order of operations for building the feature.

## 1. Read the handoff doc first

Open **`Design-Handoff.html`** in this folder before doing anything else. It is the source of truth for:
- Color, typography, spacing, radius, and shadow tokens
- Iconography (Material Symbols Rounded, exact glyph names in use)
- Device frame spec (status bar, dynamic island, home indicator dimensions)
- The full screen inventory and sheet/modal inventory
- Component API tables (props for every reusable primitive)
- Animation/motion timing and easing curves
- Architecture notes for how the prototype is wired together

Do not skip straight to the `.jsx` source files — the handoff doc explains *why* things are structured the way they are and calls out which values are exact vs. which are placeholder.

## 2. What the bundled source actually is

`ui_kits/solytiq-cloud-ios/` contains the **working design prototype** — React 18 (UMD) + in-browser Babel, no build step, no bundler. It is a **design reference, not production code**:

- State is in-memory seed data (`SEED_*` constants in `index.html`) — there is no real backend, auth, or persistence beyond a `localStorage` profile cache.
- Components use inline styles and `window.*` global exports instead of ES modules — this is how a script-tag-only prototype shares code, not a pattern to carry into a real app.
- Treat every pixel value, color, radius, spacing, and animation timing in the source as **exact and intentional** — carry those values over precisely when you port this into the target codebase's real environment (SwiftUI, React Native, or whatever this repo already uses).

If this repo already has a design system / component library / navigation pattern, **prefer its idioms** over literally re-implementing `PhoneFrame`, the `window` global pattern, or the bottom-sheet-router approach — reproduce the *visual and interaction result*, not the prototype's plumbing.

## 3. Build order

1. Skim `Design-Handoff.html` end to end once, so you know what exists before you start.
2. Confirm design tokens (colors/type/spacing/radius) against this repo's existing token system — add or reconcile as needed, don't duplicate a second token set.
3. Build screens in this order, since later ones depend on chrome/components built in earlier ones:
   - Core primitives (checkbox row, card, section header, nav header) → see "Component Library" in the handoff doc
   - Welcome → Login → Dashboard (establishes the shell + tab chrome)
   - List detail, Scheduled/Calendar, Files, Lists index, Folder dashboard
   - Sheets/modals (task editor, add flows, settings, etc.)
   - Timelines + workspace features (features.jsx) — these are the most speculative/least core, confirm scope with whoever requested the feature before building them.
4. Match motion specs from the "Animation & Interaction" section — don't invent new easing curves.
5. Cross-check icon names against the "Iconography" table — if the target platform doesn't have Material Symbols Rounded, map to the closest equivalent in the platform's icon system (e.g. SF Symbols) rather than shipping the web font.

## 4. File map

```
Design-Handoff.html          ← START HERE — full design spec
colors_and_type.css          ← canonical design-system tokens (desktop/web scope; iOS kit's --sc-* vars mirror these)
fonts/                       ← Hanken Grotesk + Inter variable fonts (brand fallback; iOS prototype prefers system font)
assets/solytiq-cloud-logo.png
ui_kits/solytiq-cloud-ios/
  index.html                 ← app shell, CSS tokens/keyframes, seed data, script load order
  components.jsx             ← primitives (SFSymbol, PhoneFrame, NavHeader, TaskRow, Card, …)
  sheets.jsx                 ← bottom-sheet modals
  screens.jsx                ← full-page screens + AppShell router
  features.jsx                ← timelines, workspaces, 2FA
  calendar.jsx                ← unified calendar screen
  ios-frame.jsx               ← standalone "iOS 26 Liquid Glass" device-frame kit for static mockups
  tweaks-panel.jsx            ← live theme/shape/density tweak controls
```

## 5. Open questions to confirm with the requester before building

- Is this feature going into an existing iOS/React Native codebase, or is a codebase being chosen from scratch?
- Does the target app already have auth/sync — if so, map this UI onto the real API contract instead of the seed data.
- Are Timelines and multi-Workspace support in scope for this build, or dashboard/lists/scheduled/files only?
