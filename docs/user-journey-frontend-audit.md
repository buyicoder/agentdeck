# AgentDeck User Journey Frontend Audit Plan

## Purpose

This audit verifies that AgentDeck feels usable as a local macOS control panel
from first install through daily queue review. It focuses on what the user sees,
understands, and can safely do in the frontend. It does not require code changes
to pass through this document; failures should become follow-up tasks.

The audit owner should test with real local app/window facts where possible and
with mock data where a platform capability is not implemented yet. Every gap
must be recorded with the exact screen, state, action, expected result, actual
result, and evidence.

Evidence records live in `docs/audit-evidence.md`. The one-click validation
mode is a required safety check, but alpha sign-off also needs manual evidence
for first launch, permission recovery, multi-display behavior, real agent
conversation switching, responsive layout, and accessibility.

## Product Baseline

AgentDeck should answer these questions at a glance:

- Is the app allowed to scan local windows right now?
- Was the latest state populated from sample data, a successful scan, an empty
  scan, or a limited/blocked scan?
- Which apps, windows, and conversations are being tracked?
- Which conversation is active inside each window?
- Which conversations are running, queued, displayed, editing, hidden,
  inactive, unknown, or done?
- Which detector produced each row, and which rows are low-confidence or
  unknown?
- Which side of the primary display is active, and where will the next review
  item appear?
- Which item is next in the review queue?
- What did AgentDeck just decide, and why?

## Audit Scope

In scope:

- First install and first launch.
- Permission onboarding for macOS trust/accessibility needs.
- First scan and refresh behavior.
- Health/status area for permission, scan result/freshness, detector confidence,
  queue, and focused-window context.
- App, window, and conversation row identification.
- Active conversation switching inside an already tracked window.
- Queue, promote, run, and done flows.
- Multi-display behavior and primary-display scheduling.
- Empty, partial, error, stale, and permission-denied states.
- Responsive/panel layout across narrow, default, and expanded sizes.
- Accessibility, keyboard navigation, labels, contrast, and reduced motion.
- Visual QA for density, alignment, truncation, and state clarity.

Out of scope:

- Implementing missing platform actions.
- Changing detector logic.
- Changing scheduling rules.
- Publishing, packaging, signing, or release automation beyond checking the
  user-facing install path.

## Test Environments

Run the audit on at least these configurations:

| Environment | Required Checks |
| --- | --- |
| Fresh local install or clean build | First launch, empty state, permissions |
| Existing local state | Refresh, persisted rows if applicable, stale data |
| Single built-in display | Left/right scheduling, focused side detection |
| External display attached | Primary display labeling, secondary windows |
| External display unplugged/replugged | Recovery, stale display labels |
| Narrow panel width | Table compression, controls, queue visibility |
| Default panel width | Primary intended workflow |
| Tall/short panel heights | Event log and queue overflow |

If only one machine is available, document missing environment coverage as audit
risk rather than pretending it was covered.

## Evidence Standard

Each audited flow should produce one of:

- Screenshot or short screen recording.
- Written reproduction note with app names, window titles, and display setup.
- Event log excerpt when the frontend exposes the relevant transition.
- Accessibility Inspector or VoiceOver note for accessibility checks.

Use this result vocabulary:

- `Pass`: Works as expected with no meaningful UX risk.
- `Pass with note`: Works, but has minor polish or documentation risk.
- `Fail`: Blocks or misleads the user.
- `Not testable`: Capability is not implemented or environment is unavailable.

## Full Journey Checklist

### 1. First Install And First Launch

- [ ] User can find the expected way to run/open AgentDeck from the repository or
  local build output.
- [ ] First launch presents a real app panel, not only terminal output.
- [ ] The app name, window title, and initial screen make it clear this is
  AgentDeck.
- [ ] Empty state explains that a scan or permissions may be needed without
  sounding like an error.
- [ ] No mock-only content is presented as real scanned state.
- [ ] If mock data is shown, it is clearly marked as sample/mock state.
- [ ] The panel does not open off-screen or behind other windows.
- [ ] Relaunching the app does not duplicate confusing panels or lose the main
  panel without a recovery path.

Acceptance criteria:

- A first-time user can open AgentDeck and identify the next action within 10
  seconds.
- The initial state never implies that real conversations were found unless they
  were actually scanned.
- The user can close and reopen the panel without getting stuck.

### 2. Permission Onboarding

- [ ] Permission status is visible before the user tries to scan real windows.
- [ ] Missing Accessibility or screen/window trust is shown as an actionable
  state, not a silent empty result.
- [ ] The request button or instruction is specific about which macOS setting is
  needed.
- [ ] The user can retry after granting permission without restarting if the
  platform allows it.
- [ ] Denied permission leaves the app usable in limited/mock mode where
  applicable.
- [ ] Permission state is reflected in a health/status area or equivalent.
- [ ] The health/status area names the permission state in plain language such
  as trusted, needs access, limited, or blocked.
- [ ] The UI distinguishes "permission missing" from "no windows found".
- [ ] The event log records permission-related failures or retries.

Acceptance criteria:

- A user who has never granted permissions can understand why scanning is
  blocked and how to proceed.
- After granting permission, the frontend clearly confirms the app can scan.
- If permission remains unavailable, AgentDeck explains the limitation and does
  not show misleading rows.

### 3. First Scan

- [ ] The scan/refresh action is discoverable and has clear feedback while
  running.
- [ ] Scan completion updates the conversation overview, display map, queue, and
  event log consistently.
- [ ] The panel shows last scan time or enough recency signal to avoid stale
  confusion.
- [ ] The health/status area distinguishes sample/mock data, successful scan,
  empty scan, and failed or blocked scan.
- [ ] Empty scan result shows a useful zero state.
- [ ] Partial scan result marks unknown or low-confidence rows explicitly.
- [ ] Repeated refreshes do not duplicate rows.
- [ ] Scan failure shows error copy and a retry path.
- [ ] The UI remains responsive while scan work is happening.

Acceptance criteria:

- After first scan, the user can tell whether AgentDeck found real windows.
- Rows are stable across repeated refreshes unless the underlying windows
  changed.
- A failed scan leaves the user with a next action.

### 4. App, Window, And Conversation Row Identification

- [ ] Each row shows app identity.
- [ ] Each row shows window identity or enough title/frame information to
  distinguish multiple windows from the same app.
- [ ] Each row shows conversation identity when detected.
- [ ] Unknown conversation identity is visually distinct from a detector failure.
- [ ] Detector confidence and level are visible where the product expects them.
- [ ] The health/status area summarizes detector coverage, including
  low-confidence or unknown rows.
- [ ] App, window, and conversation text truncate gracefully without hiding state
  or actions.
- [ ] Multiple conversations in one app do not collapse into one ambiguous row.
- [ ] Multiple conversations in one window preserve active versus inactive
  meaning.
- [ ] Rows show state, location/display, age or recency, and next action.
- [ ] Selecting a row makes the corresponding detail/action context clear.

Acceptance criteria:

- The user can identify the correct row for a target conversation without
  guessing from app name alone.
- Multiple rows from Codex, Cursor, browser, or terminal windows remain
  distinguishable.
- Low-confidence or unknown data is honest and actionable.

### 5. Active Conversation Switching

- [ ] When the user switches conversation inside a tracked window, refresh or
  detection updates the active row.
- [ ] The prior conversation becomes `inactive`, `hidden`, or another documented
  state rather than disappearing without explanation.
- [ ] Queue order is not corrupted when the active conversation identity changes.
- [ ] The panel indicates which conversation is currently active inside the
  physical window.
- [ ] If direct conversation activation is unsupported, the UI says that
  promotion targets the window, not guaranteed in-app conversation focus.
- [ ] Event log records the switch with old and new identity where available.

Acceptance criteria:

- The user can switch from one thread/session to another and trust the panel's
  active conversation row.
- Stale conversation rows are not confused with the current visible thread.
- Unsupported exact activation is disclosed before it surprises the user.

### 6. Queue, Promote, Run, And Done Flows

- [ ] User can open the safe AgentDeck test window before moving any real
  agent window.
- [ ] Validation mode works with Move windows off: open test window, scan,
  identify test row, queue, and perform panel-only promotion without touching
  real windows.
- [ ] Validation mode works with Move windows on: open test window, scan,
  identify test row, queue, promote with Accessibility movement, capture undo,
  and restore.
- [ ] User can queue the focused or selected conversation.
- [ ] Queued items appear in the review queue in FIFO order.
- [ ] Promote next selects the first eligible queued conversation.
- [ ] Promotion respects active editing side and targets the opposite primary
  display slot.
- [ ] If both slots are busy, the queued item remains queued and the UI explains
  why.
- [ ] Mark running removes the conversation from the displayed/review slot and
  frees scheduling capacity.
- [ ] Mark done removes or de-emphasizes the conversation without deleting useful
  context abruptly.
- [ ] After run or done, the next queued item is promoted when a slot is
  available.
- [ ] Manual actions are disabled, hidden, or explained when invalid for the
  current state.
- [ ] Event log entries explain queue, promote, run, and done transitions.
- [ ] Repeated clicks do not create duplicate queue entries or double-promote.

Acceptance criteria:

- The user can complete this loop without reading code: queue item, promote it,
  review it, send it back to running, and see the next item appear.
- Scheduling decisions preserve FIFO order unless the user explicitly changes
  priority.
- Invalid actions cannot silently damage state.

### 7. Multi-Display Behavior

- [ ] The primary display is clearly identified.
- [ ] Left/right slots refer to the primary display only in version 0.1.
- [ ] Windows on secondary displays are shown with correct display labels.
- [ ] Focusing a secondary-display window does not cause surprising replacement
  of the primary active editing side.
- [ ] Promotion target is clear when the selected conversation's window is
  currently on a secondary display.
- [ ] Unplugging a display updates stale location labels or marks them stale.
- [ ] Replugging a display does not duplicate rows or queue entries.
- [ ] If multi-display behavior is only partially supported, the limitation is
  visible in the UI or release note.

Acceptance criteria:

- On a multi-display setup, the user can predict where AgentDeck will place or
  surface the next review conversation.
- Primary-display scheduling remains stable when secondary displays change.
- Display-related uncertainty is shown as status, not hidden.

### 8. Failure And Recovery States

- [ ] Permission denied.
- [ ] Permission revoked while app is open.
- [ ] No tracked apps running.
- [ ] Tracked app running with no visible windows.
- [ ] Window vanishes while queued.
- [ ] Window vanishes while displayed.
- [ ] Detector returns low confidence.
- [ ] Detector cannot infer conversation identity.
- [ ] Scan times out or returns platform error.
- [ ] Promote requested for unavailable window.
- [ ] Move/restore action unavailable or fails.
- [ ] Event log grows long or contains repeated failures.

Acceptance criteria:

- Every failure has user-visible state, not only console output.
- The user can retry, dismiss, or understand the limitation.
- The frontend does not leave rows in impossible states such as displayed but
  window missing without explanation.

### 9. Responsive And Panel Layout

- [ ] Conversation overview remains the dominant, most useful area.
- [ ] The health/status area is compact and does not crowd out the conversation
  overview at default size.
- [ ] Main display map, queue, and event log are visible or reachable at default
  size.
- [ ] Narrow width does not make key controls unreadable.
- [ ] Tables preserve state/action visibility before less important metadata.
- [ ] Long app names, titles, and conversation names truncate predictably.
- [ ] Queue and event log have independent overflow behavior.
- [ ] No nested panel/card styling makes the app feel visually heavy.
- [ ] Resize does not cause overlapping text or controls.
- [ ] Empty, loading, and error states use the same layout regions as normal
  content.

Acceptance criteria:

- The app remains usable at narrow, default, and wide panel sizes.
- No text or controls overlap in core flows.
- The layout supports repeated scanning and reviewing, not only a demo
  screenshot.

### 10. Accessibility

- [ ] All interactive controls have accessible names.
- [ ] Keyboard users can reach scan, row selection, queue actions, promote, run,
  done, settings/permission actions, and event log if interactive.
- [ ] Focus order follows visual order.
- [ ] Focus ring is visible.
- [ ] State is conveyed by text/icon labels, not color alone.
- [ ] Health/status items use text plus symbols, not color alone.
- [ ] Contrast meets WCAG AA for normal text and important UI controls.
- [ ] Dynamic updates are announced or discoverable without stealing focus.
- [ ] Reduced motion setting is respected if animations are present.
- [ ] Touch targets/click targets are comfortably sized for frequent use.
- [ ] VoiceOver can distinguish app, window, conversation, state, and action for
  a row.

Acceptance criteria:

- A keyboard-only user can complete the queue/promote/run/done loop.
- A VoiceOver user can understand the selected row and available actions.
- Color is never the only way to understand queue or state priority.

### 11. Visual QA

- [ ] App, window, conversation, state, display, and action columns align cleanly.
- [ ] State badges or labels are consistent across table, queue, and display map.
- [ ] Primary display slots clearly show left/right, active/editing, and review
  side.
- [ ] Queue ordering is visually obvious.
- [ ] Disabled actions look disabled and include explanation where needed.
- [ ] Loading and error styles are calm and consistent with the panel.
- [ ] Event log entries are scannable and timestamped or ordered clearly.
- [ ] The panel avoids decorative visuals that reduce density or repeat use.
- [ ] Screenshots at default and narrow sizes look production-intentional.
- [ ] There are no clipped buttons, cut-off labels, or accidental horizontal
  scrollbars in normal use.

Acceptance criteria:

- A screenshot of the default panel communicates the product promise without
  narration.
- Visual hierarchy puts conversation identification and next action first.
- The UI looks like a durable local control panel, not a temporary debug view.

## Scenario Matrix

| Scenario | Setup | Action | Expected Result |
| --- | --- | --- | --- |
| Fresh launch without permission | New app state, no trust granted | Open AgentDeck | Permission status and next action are visible |
| Sample state before scan | Preview/mock data loaded | Open AgentDeck | Health/status area says sample/mock or limited state |
| First successful scan | Permission granted, several windows open | Click Refresh/Scan | Rows show app, window, conversation, state, display |
| No tracked windows | Permission granted, tracked apps closed | Scan | Zero state explains no windows found |
| Multiple Codex windows | Two Codex windows with different titles | Scan | Rows are distinguishable by window/conversation |
| Conversation switch | One tracked window, user changes thread | Refresh/detect | Active row updates; old row becomes inactive/hidden |
| Queue focused conversation | Track one active conversation | Queue | Item appears once in queue |
| Promote with left active | Editor focused on left primary slot | Promote next | Review item targets right slot |
| Promote with right active | Editor focused on right primary slot | Promote next | Review item targets left slot |
| Both slots busy | Two occupied primary slots | Queue finished item | Item stays queued with reason |
| Run displayed item | Displayed item selected | Mark running | Slot frees; next queued item promotes if available |
| Done displayed item | Displayed item selected | Mark done | Item leaves active loop; next queued item promotes |
| Window closed while queued | Queued window is closed externally | Refresh/promote | Row is removed, marked done, or marked unavailable |
| External display attached | Secondary display has tracked window | Scan | Display labels and primary slot rules are clear |
| External display unplugged | Tracked row was on secondary display | Unplug and scan | Stale/missing display state is clear |
| Scan failure | Simulate platform error if possible | Scan | Error state plus retry path |
| Narrow panel | Resize to minimum practical width | Use main actions | Core workflow remains reachable |
| Keyboard flow | Mouse not used | Queue/promote/run/done | Workflow is complete by keyboard |
| VoiceOver row readout | VoiceOver enabled | Navigate rows | Row identity and state are understandable |

## Acceptance Gate For Alpha

AgentDeck is ready to pass the full user-journey frontend audit when:

- First install, permission onboarding, first scan, and queue review can be
  completed by a new user without developer explanation.
- A compact health/status area clearly exposes permission, scan, detector, queue,
  and focused-window state.
- The panel reliably distinguishes app, window, and conversation identity.
- Conversation switching inside a tracked window produces understandable row
  state changes.
- Queue, promote, run, and done actions are visible, valid-state aware, and
  logged.
- Primary-display left/right scheduling is predictable on single-display and
  multi-display setups.
- Every major failure state has visible recovery or limitation copy.
- Narrow/default/wide panel layouts have no overlapping text or broken controls.
- Keyboard and VoiceOver users can complete the core review loop.
- Visual QA screenshots show a coherent, production-intentional local control
  panel.
- Any `Not testable` item is tied to a specific milestone or follow-up task.

## Audit Output Template

Use this structure for the final audit report:

```text
# AgentDeck User Journey Frontend Audit Report

Date:
Build/commit:
Tester:
Environment:

## Summary

- Overall result:
- Top 3 blockers:
- Top 3 polish risks:
- Not testable items:

## Journey Results

| Area | Result | Evidence | Notes |
| --- | --- | --- | --- |
| First install/launch |  |  |  |
| Permission onboarding |  |  |  |
| First scan |  |  |  |
| Row identification |  |  |  |
| Conversation switching |  |  |  |
| Queue/promote/run/done |  |  |  |
| Multi-display |  |  |  |
| Failure states |  |  |  |
| Responsive layout |  |  |  |
| Accessibility |  |  |  |
| Visual QA |  |  |  |

## Findings

| Severity | Area | Finding | Reproduction | Expected | Actual |
| --- | --- | --- | --- | --- | --- |

## Acceptance Decision

- Pass for alpha:
- Required fixes before alpha:
- Follow-up tasks:
```
