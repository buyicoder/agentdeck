# AgentDeck Architecture

AgentDeck is a local macOS app that tracks AI conversations across apps,
windows, and tabs, then schedules conversations onto the main display.

The core product object is:

```text
ConversationSurface = AppIdentity + WindowIdentity + ConversationIdentity
```

## 1. System Layers

```text
macOS Accessibility / App APIs
        |
        v
Window Fact Layer
        |
        v
Conversation Detector Layer
        |
        v
State Store
        |
        +------> Scheduler Engine
        |              |
        |              v
        |       Window Action Layer
        |
        v
Panel UI / Command Palette / Hotkeys
```

## 2. Modules

### 2.1 Window Fact Layer

Responsibility:

- enumerate running apps;
- enumerate windows;
- track focused window;
- track window frame and display;
- watch window title/frame/focus changes;
- expose a read-only snapshot.

Output shape:

```ts
type WindowFact = {
  appName: string;
  bundleId: string;
  pid: number;
  windowId: string;
  title: string;
  frame: Rect;
  displayId: string;
  isFocused: boolean;
  role?: string;
  subrole?: string;
};
```

### 2.2 Conversation Detector Layer

Responsibility:

- infer active conversation identity from each window;
- detect whether the active conversation changed inside the same window;
- assign detector confidence;
- support per-app detectors.

Detector levels:

| Level | Meaning |
| --- | --- |
| L0 | App/window detected only. |
| L1 | Window title identifies conversation. |
| L2 | Active conversation can be detected from Accessibility/DOM. |
| L3 | Running/completed status can be detected. |
| L4 | AgentDeck can activate a specific conversation inside the window. |

Output shape:

```ts
type ConversationSurface = {
  conversationKey: string;
  appName: string;
  bundleId: string;
  windowId: string;
  windowLabel: string;
  title: string;
  subtitle?: string;
  status: ConversationStatus;
  detectorLevel: 0 | 1 | 2 | 3 | 4;
  confidence: number;
  location: LocationState;
  updatedAt: string;
};
```

### 2.3 State Store

Responsibility:

- keep current conversation list;
- keep queue order;
- keep previous window frames for undo;
- persist user rules and ignored conversations;
- expose state changes to UI.

Initial storage:

- JSON file in app support directory for prototype;
- SQLite later if history/search grows.

### 2.4 Scheduler Engine

Responsibility:

- decide which queued conversation should surface next;
- protect the active editing side;
- select target display slot;
- emit reversible window actions.

First hardcoded rule:

```text
if conversation.status == queued
and opposite(activeSide).isFree
then promote(conversation, opposite(activeSide))
```

Later rule system:

- priority;
- per-app rules;
- project grouping;
- time since completion;
- manual pinning.

### 2.5 Window Action Layer

Responsibility:

- move windows to slots;
- focus windows;
- restore previous frame;
- attempt app-specific conversation activation where possible;
- fail safely when an action is unsupported.

Important rule:

> Never mutate window layout without storing an undo frame.

### 2.6 Panel UI

Responsibility:

- show conversation overview;
- show main display slots;
- show review queue;
- show detector health;
- expose manual actions.

The panel is the product center. It should remain useful even before automatic
detectors are perfect.

### 2.7 Command Layer

Responsibility:

- queue focused conversation;
- mark focused conversation running;
- mark focused conversation done;
- promote next;
- search conversations;
- restore previous layout.

This can start as hotkeys and become a command palette later.

## 3. Recommended Implementation Path

### Phase 0: Static Prototype

Current state:

- product docs;
- static conversation-level panel prototype;
- Hammerspoon sketch.

### Phase 1: Local Panel Skeleton

Build a local app shell that can load mock conversation data:

- preferred: Tauri or Electron for fastest UI iteration;
- alternative: SwiftUI if native integration becomes primary.

Deliverable:

- installable local dev app;
- panel UI matching the prototype;
- state store with mock data.

### Phase 2: macOS Window Facts

Deliverable:

- list real apps/windows;
- show real window title, app, frame, display;
- refresh manually;
- no conversation detection yet.

Current implementation:

- `Sources/AgentDeck/WindowFacts.swift` reads visible windows with
  `CGWindowListCopyWindowInfo`;
- it approximates focused window by taking the frontmost app from
  `NSWorkspace.shared.frontmostApplication`, then selecting that app's first
  visible CGWindow;
- it maps the focused window's horizontal midpoint to primary-display
  left/right active side;
- `ConversationStore.refreshSnapshot()` maps each real window into an L0
  `ConversationSurface`;
- the panel exposes Accessibility trust state and a manual Refresh button.

Known limitation:

- focused window is an approximation, not a direct AX focused-window query yet;
- conversation identity is mostly title-based and still needs deeper AX/DOM
  sources for high-confidence in-app conversation identity.

### Phase 3: Conversation Detection MVP

Deliverable:

- detector interface;
- browser/tab-title detector;
- window-title detector for Codex/Cursor/WorkBuddy;
- active conversation changes update the panel.

Current implementation:

- `Sources/AgentDeck/Detectors.swift` defines `ConversationDetector`,
  `DetectionContext`, `DetectionResult`, and `DetectorPipeline`;
- app-specific title detectors run before generic fallback:
  - `codex-title`;
  - `cursor-title`;
  - `workbuddy-title`;
  - `terminal-agent-title`;
  - `browser-title`;
- `TitleFallbackDetector` converts non-empty window titles into L1
  conversation identities;
- `WindowOnlyDetector` remains the L0 fallback;
- panel rows show detector id, level, and confidence.
- `ConversationStore` merges new scans by `conversationKey` and detects
  conversation switches inside the same `windowIdentity`;
- previous conversations from the same still-visible window are preserved as
  `inactive`.

Known limitation:

- app-specific detectors are still title-based, not AX/DOM-based;
- active conversation inside one native app window is not directly inspected
  yet; switch detection depends on detector key changes between scans;
- browser URL detection is not implemented yet.

### Phase 4: Scheduling MVP

Deliverable:

- queue focused conversation;
- mark running/done;
- promote next to opposite side;
- restore previous frame.

Current implementation:

- `Sources/AgentDeck/Scheduler.swift` contains the pure scheduling decision;
- `ConversationScheduler.nextPromotion` returns a `PromotionPlan` with
  conversation id and target side;
- `Sources/AgentDeck/WindowActions.swift` defines the platform action boundary,
  promotion action, and undo frame shape;
- `ConversationStore` applies the plan to panel state and records undo frames;
- real AX movement is behind an explicit `Move windows` toggle in the panel;
- `Restore` uses the latest undo frame when real actions are enabled.
- `Sources/AgentDeck/TestWindow.swift` provides a harmless local test window for
  validating scan/promote/restore before moving real agent windows.
- Validation mode runs the safe journey end to end: open test window, scan,
  detect, queue, promote, and restore. With `Move windows` off it validates only
  panel state; with `Move windows` on it validates real AX movement against the
  test window.

See `docs/platform-window-actions.md` for the real AX move/focus/restore plan.

### Phase 5: Packaging

Deliverable:

- local install package;
- permission onboarding;
- app health panel.
