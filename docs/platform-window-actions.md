# Platform Window Actions Plan

This plan covers real macOS window movement, focus, and restore for AgentDeck.
It is intentionally scoped to conversation scheduling, not general window
management.

## 1. Goals

AgentDeck needs a reversible platform layer that can:

- move a tracked conversation window into the primary display left or right slot;
- focus the promoted window when the user explicitly asks for it;
- restore a moved window to its previous frame;
- report unsupported or unsafe actions without corrupting scheduler state;
- keep AppKit, CoreGraphics, and Accessibility details out of Scheduler.

Non-goals:

- tiling every app window on the desktop;
- moving minimized or full-screen windows in the first implementation;
- controlling private app internals;
- requiring SIP disablement or private macOS APIs.

## 2. macOS API Surface

### 2.1 Existing Read Path

The current fact path already uses:

- `CGWindowListCopyWindowInfo` for visible layer-0 window enumeration;
- `NSWorkspace.shared.frontmostApplication` as a focused-window approximation;
- `NSScreen.screens` for display geometry and primary display detection;
- `AXIsProcessTrusted` / `AXIsProcessTrustedWithOptions` for Accessibility trust.

Keep this path for cheap read-only snapshots, but do not rely on CoreGraphics
window dictionaries for movement. CoreGraphics can tell AgentDeck where windows
are, but public APIs do not let AgentDeck move another app's window by CG window
number alone.

### 2.2 Required Write Path

Use Accessibility for cross-app window actions:

- `AXUIElementCreateApplication(pid)` to address the owning app;
- `AXUIElementCopyAttributeValue(app, kAXWindowsAttribute, ...)` to enumerate
  AX windows for that app;
- `AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute, ...)` to read
  the real focused window when available;
- `AXUIElementSetAttributeValue(window, kAXPositionAttribute, AXValue)` to move;
- `AXUIElementSetAttributeValue(window, kAXSizeAttribute, AXValue)` to resize;
- `AXUIElementPerformAction(window, kAXRaiseAction)` to bring a window forward;
- `NSRunningApplication(processIdentifier:)?.activate(options:)` to activate
  the app before or after raising its window.

Use `AXValueCreate(.cgPoint, &point)` and `AXValueCreate(.cgSize, &size)` for
position and size values. Read current position and size with
`AXUIElementCopyAttributeValue` before every mutation.

### 2.3 Window Matching

`ConversationSurface.windowIdentity` currently stores
`"\(ownerPID)-\(windowNumber)"`. The action layer should treat this as a stable
best-effort identity, then resolve it to an Accessibility window at execution
time.

Resolution strategy:

1. Parse `ownerPID` and `windowNumber` from `windowIdentity`.
2. Re-read current `WindowFact` snapshot and find the same identity.
3. Build the app AX element from `ownerPID`.
4. Enumerate `kAXWindowsAttribute`.
5. Match AX window to CG fact using a scored match:
   - same title when both titles are non-empty;
   - current frame close to the CG frame;
   - same role/subrole if available;
   - frontmost AX focused window when the target is the focused fact.
6. If multiple candidates remain, fail with `ambiguousWindow` instead of moving
   the wrong window.

Later, store richer platform identity when facts are collected:

```swift
struct PlatformWindowIdentity: Hashable, Codable {
    var ownerPID: pid_t
    var cgWindowNumber: Int
    var bundleID: String?
    var titleAtScan: String
    var frameAtScan: Rect
}
```

The first implementation can derive this from the existing string identity and
add the structured type when state persistence is introduced.

## 3. Platform Interface

Scheduler should remain a pure decision engine. It should return intent, not
call AppKit or Accessibility.

Recommended boundary:

```swift
protocol PlatformWindowActing {
    func currentSnapshot() async -> WindowSnapshot
    func moveWindow(
        _ identity: PlatformWindowIdentity,
        to target: WindowSlot,
        reason: WindowActionReason
    ) async -> Result<UndoFrame, WindowActionError>
    func focusWindow(
        _ identity: PlatformWindowIdentity,
        reason: WindowActionReason
    ) async -> Result<Void, WindowActionError>
    func restoreWindow(
        using undoFrame: UndoFrame,
        reason: WindowActionReason
    ) async -> Result<Void, WindowActionError>
}
```

Suggested orchestration:

1. `ConversationScheduler.nextPromotion(input)` returns `PromotionPlan`.
2. Store or a thin `PromotionCoordinator` maps the plan's conversation ID to a
   platform identity and target slot.
3. Coordinator calls `PlatformWindowActing.moveWindow`.
4. Only after success does Store mark the conversation as `.displayed` and save
   the returned undo frame.
5. On failure, Store leaves the conversation `.queued` and records an event.

This keeps Scheduler independent from AppKit and makes it easy to unit-test
scheduling rules with pure model fixtures.

## 4. Slot Geometry

Represent target slots with display-aware geometry:

```swift
struct Rect: Hashable, Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct WindowSlot: Hashable, Codable {
    enum Kind: String, Codable {
        case primaryLeft
        case primaryRight
    }

    var kind: Kind
    var displayID: String
    var frame: Rect
}
```

Compute `primaryLeft` and `primaryRight` from the visible frame of
`NSScreen.screens.first`, not the full frame, so menu bar and Dock are avoided.
Use a small inset, for example 8 px, only if product design wants breathing room.

Display IDs should be stable enough for undo diagnostics but not trusted forever.
Start with `NSScreen.deviceDescription["NSScreenNumber"]`; later wrap
`CGDirectDisplayID`.

Be explicit about coordinate spaces. `CGWindowListCopyWindowInfo` reports bounds
in global display coordinates, while AppKit screen frames and Accessibility
position/size values need careful conversion when displays sit above or to the
left of the primary display. Add a small geometry helper and test it with:

- single built-in display;
- primary display plus external display to the right;
- external display above the primary display;
- external display positioned left of the primary display;
- Dock on bottom, left, and right.

## 5. Undo Frames

Every mutating action must produce an undo frame before the first write.

```swift
struct UndoFrame: Identifiable, Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var actionID: UUID
    var conversationID: UUID
    var windowIdentity: PlatformWindowIdentity
    var appName: String
    var bundleID: String?
    var titleBefore: String
    var frameBefore: Rect
    var frameAfter: Rect
    var displayBefore: String
    var displayAfter: String
    var statusBefore: ConversationStatus
    var targetSide: DisplaySide
    var reason: WindowActionReason
}
```

Use an append-only undo stack in the state store:

- newest frame first;
- restore consumes or marks a frame as restored;
- keep at least the last 20 frames in memory;
- persist frames with the rest of local app state once persistence exists.

Restore algorithm:

1. Validate Accessibility trust.
2. Resolve the current target window from `undoFrame.windowIdentity`.
3. Re-read current frame and title.
4. If the title or PID no longer matches and confidence is low, fail with
   `staleUndoFrame`.
5. Move and resize back to `frameBefore`.
6. Optionally raise the window only for explicit restore commands, not automatic
   background cleanup.
7. Mark the undo frame restored and update Store state.

## 6. Safety Rules

Hard rules:

- Never move or resize without first capturing an `UndoFrame`.
- Never move the active editing side unless the user explicitly commands it.
- Never move a window when the target slot is occupied by an editing or displayed
  conversation.
- Never move a window if Accessibility is not trusted.
- Never guess when window resolution is ambiguous.
- Never mutate Scheduler state as if a move succeeded before Platform confirms.

First-version exclusions:

- full-screen windows;
- minimized windows;
- hidden apps;
- system apps, login items, and menu-bar-only agents;
- windows with non-standard roles that do not support position and size writes;
- windows smaller than the existing fact filter unless explicitly tracked.

Recommended preflight checks:

```swift
struct WindowActionPreflight {
    var accessibilityTrusted: Bool
    var targetWindowResolved: Bool
    var targetSlotFree: Bool
    var activeSideProtected: Bool
    var supportsPosition: Bool
    var supportsSize: Bool
    var isFullscreen: Bool
    var isMinimized: Bool
}
```

Treat preflight failures as user-visible events, not crashes.

## 7. Permission Constraints

Required:

- Accessibility permission for reading and setting AX window attributes.

Not required for the normal path:

- Screen Recording;
- Automation / Apple Events;
- SIP disablement;
- private APIs.

Notes:

- `CGWindowListCopyWindowInfo` may return less detail for some apps without
  Screen Recording, but the MVP should not require Screen Recording unless a
  later detector needs it.
- Some sandboxing configurations restrict Accessibility control. The first
  local alpha should run as a normal developer-signed app outside the Mac App
  Store sandbox.
- Permission health should stay visible in the panel because failed window
  actions will otherwise look like scheduler bugs.

## 8. Error Model

Use typed errors so UI and logs can distinguish user-fixable issues from app
limitations.

```swift
enum WindowActionError: Error, Hashable {
    case accessibilityNotTrusted
    case appNotRunning(pid_t)
    case windowNotFound(PlatformWindowIdentity)
    case ambiguousWindow(PlatformWindowIdentity)
    case unsupportedWindowRole(String?)
    case minimizedWindow
    case fullscreenWindow
    case targetSlotOccupied(DisplaySide)
    case activeSideProtected(DisplaySide)
    case axReadFailed(attribute: String, code: AXError)
    case axWriteFailed(attribute: String, code: AXError)
    case staleUndoFrame(UUID)
}
```

The event log should use plain-language summaries, for example:

- "Move skipped: Accessibility permission is not trusted."
- "Move skipped: target window could not be matched safely."
- "Restore skipped: original window appears to have changed."

## 9. Scheduler Integration

`PromotionPlan` should remain small and serializable:

```swift
struct PromotionPlan {
    let conversationID: UUID
    let targetSide: DisplaySide
    let event: String
}
```

Add a separate command object at the coordination boundary:

```swift
struct WindowActionRequest {
    var actionID: UUID
    var conversationID: UUID
    var windowIdentity: PlatformWindowIdentity
    var targetSlot: WindowSlot
    var reason: WindowActionReason
}

enum WindowActionReason: String, Codable {
    case promoteQueuedConversation
    case manualFocus
    case manualRestore
}
```

Flow:

```text
UI command / state change
  -> ConversationStore asks ConversationScheduler for a PromotionPlan
  -> PromotionCoordinator builds WindowActionRequest
  -> PlatformWindowActing executes AX action
  -> Platform returns UndoFrame or WindowActionError
  -> Store updates conversation status, location, side, undo stack, and event log
```

Do not import `AppKit` or `ApplicationServices` in `Scheduler.swift`. The
Platform implementation can live in a macOS-specific file such as
`MacOSWindowActionProvider.swift`; the protocol and model types can live in a
platform-neutral boundary file if they do not expose AppKit types.

## 10. Tests

### 10.1 Unit Tests

Scheduler:

- promotes queued conversation to the opposite free side;
- falls back to active side only when active side is free;
- returns no plan when both sides are occupied;
- preserves FIFO order;
- does not know about AppKit types.

Coordinator:

- does not update Store on platform failure;
- updates Store only after `moveWindow` success;
- saves exactly one undo frame per successful move;
- maps `WindowActionError` to event-log messages.

Undo:

- restore uses `frameBefore`;
- stale undo frames fail safely;
- restore does not consume an undo frame if Platform fails.

### 10.2 Platform Tests With Fakes

Create a fake `PlatformWindowActing` for deterministic tests:

- success returns a known `UndoFrame`;
- failure returns each typed error;
- delayed success validates async state handling.

No unit test should require Accessibility permission.

### 10.3 Local Manual Tests

Run on a real Mac with Accessibility permission granted:

1. Open two normal app windows on the primary display.
2. Queue a non-active conversation.
3. Promote it to the free opposite side.
4. Confirm original frame is stored before movement.
5. Restore and confirm the old frame returns.
6. Revoke Accessibility permission and confirm moves are skipped with a clear
   event.
7. Try a full-screen window and confirm it is skipped.
8. Try an external display, unplug it, then restore; confirm stale display
   handling fails safely.
9. Try Codex, Cursor, WorkBuddy, Terminal, Chrome, and Finder windows.

### 10.4 Regression Checks

- `swift test` once a test target exists;
- `swift run` for manual panel verification;
- visual panel check that permissions, events, side assignment, and queue state
  stay coherent after failed moves.

## 11. Implementation Sequence

1. Add platform-neutral data models for `PlatformWindowIdentity`,
   `WindowSlot`, `UndoFrame`, `WindowActionRequest`, and typed errors.
2. Add `PlatformWindowActing` protocol and fake implementation for tests.
3. Add `PromotionCoordinator` that bridges Scheduler plans to Platform actions.
4. Add macOS AX resolver for PID/window matching.
5. Add real move and resize.
6. Add focus / raise as a separate explicit action.
7. Add restore from undo frame.
8. Wire Store so conversation state changes only after Platform success.
9. Add permission and failure events to the panel.
10. Expand manual tests across apps and displays.

The first shippable slice is move-only with undo-frame capture and safe failure.
Focus and restore can follow immediately after the action boundary is in place.
