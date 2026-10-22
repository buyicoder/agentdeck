# Task Board

## Milestone 0: Product And Architecture Alignment

Status: in progress

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M0-01 | Rewrite product model around conversations | Product | Done | `docs/product-design.md` |
| M0-02 | Study mature window tools and extract lessons | Product | Done | `docs/competitive-lessons.md` |
| M0-03 | Build conversation-level static prototype | Product | Done | `prototype/` |
| M0-04 | Define architecture and workstreams | Product/Tech Lead | Done | `docs/architecture.md`, `docs/development-workflow.md` |
| M0-05 | Update README with new product direction | Product | Done | Conversation-level README |

## Milestone 1: Local App Shell With Mock Data

Goal: create a local installable panel that renders the conversation model with
mock state.

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M1-01 | Choose app shell: Tauri, Electron, or SwiftUI | Tech Lead | Done | ADR 001: Swift for native spike, Tauri later candidate |
| M1-02 | Scaffold app shell | App Shell | Done | Swift Package + AppKit window |
| M1-03 | Define typed conversation state model | State | Done | `ConversationSurface`, queue, status |
| M1-04 | Render conversation table from mock state | UI | Done | Native SwiftUI table |
| M1-05 | Render main display slots and queue | UI | Done | Native SwiftUI side panels |
| M1-06 | Add manual actions: queue/run/done/promote | Scheduler/UI | Done | Mock actions in `ConversationStore` |
| M1-07 | Add basic event log | Scheduler/UI | Done | State transitions visible |

## Milestone 2: macOS Window Facts Spike

Goal: read real local app/window facts without moving anything.

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M2-01 | Permission onboarding spike | Platform | In progress | Trust check + request button added |
| M2-02 | Enumerate running apps and windows | Platform | Done | `CGWindowListCopyWindowInfo`, visible layer-0 windows |
| M2-03 | Read window title, frame, display | Platform | Done | title/frame/display label mapped to L0 conversations |
| M2-04 | Detect focused window and active side | Platform | Done | Frontmost app + topmost window approximation |
| M2-05 | Show real window facts in panel | Platform/UI | Done | Refresh maps real windows into panel rows |

## Milestone 3: Conversation Detection MVP

Goal: detect conversation identity at least from titles and browser tabs.

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M3-01 | Detector interface | Detection | Done | `ConversationDetector`, `DetectorPipeline` |
| M3-02 | Title fallback detector | Detection | Done | L1 title-based conversation key |
| M3-03 | Browser/tab detector spike | Detection | In progress | Focused browser active-tab URL/title via AppleScript; background tabs not yet |
| M3-04 | Codex/Cursor/WorkBuddy title detectors | Detection | Done | App-specific L1 title detectors |
| M3-05 | Conversation switch detection | Detection | Done | Same windowIdentity + new conversationKey preserves old as inactive |
| M3-06 | Detector confidence in panel | UI | Done | Shows detector id, L-level, confidence |

## Milestone 4: Scheduling MVP

Goal: queue and promote conversations while protecting the active side.

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M4-01 | Queue model | Scheduler | Done | FIFO queued conversations |
| M4-02 | Slot availability model | Scheduler | Done | Pure active-side/opposite-side decision |
| M4-03 | Promote next with mock action | Scheduler | Done | `PromotionPlan` applied in store |
| M4-04 | Move real window to target slot | Platform/Scheduler | In progress | AX performer wired behind explicit Move windows toggle; needs manual verification |
| M4-05 | Restore previous frame | Platform/Scheduler | In progress | Undo frame stack + Restore button; needs manual verification |
| M4-06 | Hotkeys for focused conversation | Command | In progress | Panel-scoped shortcuts added; global hotkeys later |
| M4-07 | Safe test window for move/restore validation | Platform/UI | Done | `AgentDeck Test Conversation` window added |
| M4-08 | One-click validation mode | QA/UI | Done | Opens test window, scans, detects, queues, promotes, and restores safely |
| M4-09 | Copyable validation report | QA/UI | Done | Panel can copy run evidence for audit records |

## Milestone 5: Installable Alpha

Goal: make AgentDeck usable locally for daily dogfooding.

| ID | Task | Owner | Status | Notes |
| --- | --- | --- | --- | --- |
| M5-01 | App health panel | QA/UI | Done | permissions, detector level, last scan, queue, undo frames |
| M5-02 | Settings: tracked apps and ignored conversations | App Shell | Done | local-only UserDefaults settings panel |
| M5-03 | Multi-display manual test matrix | QA | Todo | plug/unplug external display |
| M5-04 | Package local build | Packaging | Done | `scripts/install_local_app.sh` installs `/Applications/AgentDeck.app` |
| M5-05 | Dogfood with Codex, Cursor, WorkBuddy | QA/Product | Todo | capture failures |
| M5-06 | Full user-journey frontend audit | QA/Product | In progress | Daily Chinese/layout pass captured; permission, keyboard, and real-move journeys still needed |
| M5-07 | Audit evidence record | QA/Product | In progress | `docs/audit-evidence.md`; Chinese/layout screenshot captured |
| M5-08 | Daily review dashboard IA refactor | UI/Product | Done | Daily, Setup, Diagnostics, Settings modes; debug controls removed from default first screen |
| M5-09 | Primary display visibility | UI/Platform | Done | Daily panel shows macOS primary display name and size |
| M5-10 | User-selectable primary display | UI/Platform | Todo | needed for 4-display setups where macOS main display differs from user's workbench |
| M5-11 | Chinese UI and mode layout stability | UI/Product | Done | Chinese panel copy, top-aligned mode shell, page-level Daily scroll, fixed top-bar control heights |
| M5-12 | Multi-display occupancy overview | UI/Product | Done | Daily shows a screen overview for four-display setups; true user-selectable workbench display remains M5-10 |
| M5-13 | Promote blocked-state feedback | Scheduler/UI | Done | Promote action now explains empty queue or full primary slots instead of silently no-oping |
| M5-14 | Flow occupancy model correction | Scheduler/Product | Done | Promotion now uses current editing side only; AgentDeck self app excluded from scans; defaults are agent-app only |
| M5-15 | Realtime workbench state | Platform/Scheduler/UI | Done | Added `WorkbenchState`, half-screen occupancy detection, self-app focus preservation, and 1s refresh loop |

## Immediate Next Tasks

1. Add a user-selectable workbench display so four-display users can choose the real operating screen.
2. Dogfood `/Applications/AgentDeck.app` with Accessibility permission from a normal app launch.
3. Dogfood browser active-tab detector and Automation permission flow.
4. Run Validation mode once with Move windows off, then once with Move windows on after granting Accessibility.
5. Complete keyboard-only and VoiceOver audit notes.
