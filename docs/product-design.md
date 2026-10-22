# AgentDeck Product Design

## 1. Product Positioning

AgentDeck is a locally installed macOS control panel for multi-conversation AI
work.

It is not a general window manager. Its first job is to solve one painful loop:

> The user runs many AI conversations at the same time across Codex, WorkBuddy,
> Cursor, browsers, and terminals. Some apps contain multiple windows, and some
> windows contain multiple conversations. The user wastes attention finding
> which conversation needs review.

AgentDeck watches local application windows and the active conversation inside
those windows. It shows conversation state in one panel, turns finished
conversations into a review queue, and automatically presents the right window
and conversation when the main screen has space.

## 2. Target User

Primary user:

- runs Codex, WorkBuddy, Cursor, browser agents, terminals, and AI chat windows
  in parallel;
- often has more active agent tasks than visible screen slots;
- wants to preserve deep editing focus on one side of the main monitor;
- wants finished agents to wait politely, then surface automatically.

## 3. Product Promise

AgentDeck should make the user's screen feel like a dispatch desk:

- all important AI conversations are visible in one local panel;
- each conversation is tied back to its app and window;
- running agents stay out of the way;
- finished agents line up;
- the next result appears where attention is available;
- the user stops hunting for windows.

## 4. Core Model

### 4.0 Local App Panel

AgentDeck is a local macOS app, not only a script. The panel is the center of the
product.

The panel should answer, at a glance:

- which conversations exist;
- which app and physical window each conversation belongs to;
- which conversation is currently active inside each window;
- which conversations are running, queued, displayed, editing, hidden, or done;
- which screen and side each visible window occupies;
- which conversation will surface next;
- which conversations are stale, idle, or require attention.

The panel can live as a menu bar app with a detachable main window, or as a
normal desktop app. Version 0.1 can still use Hammerspoon or Accessibility APIs
under the hood, but the user-facing product should be a panel.

### 4.1 Main Display Slots

The main display is divided into two logical slots:

- `left`
- `right`

Each slot can hold one visible window, but the scheduled object is a
conversation inside that window.

### 4.2 Active Editing Side

The side containing the focused window is the active editing side. AgentDeck
should avoid replacing or covering this side.

### 4.3 Review Side

The opposite side is the preferred review side. When the user edits on the left,
AgentDeck surfaces review windows on the right. When the user edits on the
right, AgentDeck surfaces review windows on the left.

### 4.4 Conversation Surface

The core object is not an app and not only a window. It is a conversation
surface:

```text
conversation = app + window + active conversation identity
```

Examples:

- Codex app, window A, thread "AgentDeck product design"
- Codex app, window A, thread "AIZZ formula bug"
- Cursor app, window B, composer/session "Hammerspoon detector"
- Chrome app, tab "WorkBuddy thread 4537"

If the user changes the active conversation inside an already tracked window,
AgentDeck should update the row to the new conversation. If the previous
conversation still exists in the sidebar/history, AgentDeck may keep it as a
hidden or inactive conversation.

### 4.5 Conversation Queue

A conversation enters the queue when it needs user attention. In the MVP this
can be manual or simulated. Later it can be automatic, based on app-specific
conversation detection and completion detection.

## 5. Conversation States

| State | Meaning | User Expectation |
| --- | --- | --- |
| `running` | Agent is working. | Do not surface it. |
| `queued` | Agent needs review but no slot is ready. | Keep order and wait. |
| `displayed` | Agent is visible in a main-display slot. | Let the user review it. |
| `editing` | User is actively working in this window. | Do not disturb this side. |
| `hidden` | Conversation exists but is not currently visible. | Keep it tracked, do not surface it. |
| `inactive` | Conversation exists in a window but is not the active conversation. | Keep history without scheduling it. |
| `unknown` | AgentDeck sees the window but cannot infer conversation identity. | Let the user classify it quickly. |
| `done` | Window is dismissed or no longer relevant. | Remove it from the loop. |

## 5.1 Panel Layout

The panel has four primary areas:

| Area | Purpose |
| --- | --- |
| Conversation Overview | Table of all tracked conversations with app, window, conversation, state, location, age, and next action. |
| Main Display Map | Visual left/right slots for the primary screen. |
| Review Queue | Ordered list of conversations waiting to be reviewed. |
| Event Log | Recent state changes and scheduling decisions. |

The Conversation Overview is the most important area. The user should be able to
open AgentDeck and immediately know what each conversation is doing, even when
several conversations belong to the same app or same window.

## 6. Key Flows

### 6.1 Agent Finishes While User Edits Left

1. User is focused on a left-side editor.
2. Conversation A finishes.
3. AgentDeck adds Conversation A to the queue.
4. Right side is available.
5. AgentDeck moves the owning window to the right half and activates
   Conversation A if possible.

### 6.2 Agent Finishes While Both Sides Are Busy

1. User is editing on one side.
2. Another displayed result occupies the other side.
3. Conversation B finishes.
4. AgentDeck queues Conversation B.
5. Its owning window stays hidden or untouched until a slot opens.

### 6.3 User Sends Displayed Agent Back To Work

1. Conversation A is visible on the review side.
2. User reviews it and gives another instruction.
3. AgentDeck marks Conversation A as `running`.
4. Its previous slot becomes available.
5. AgentDeck promotes the first queued conversation into that slot.

### 6.4 User Switches Editing Side

1. User clicks a right-side window.
2. Right becomes the active editing side.
3. Future promoted windows prefer the left side.

### 6.5 User Switches Conversation Inside A Window

1. User is focused in Codex window A.
2. User switches from thread "AIZZ bug" to thread "AgentDeck design".
3. AgentDeck detects the active conversation identity changed.
4. The panel updates the active row for that window.
5. The old conversation becomes `inactive` or `hidden`, depending on whether it
   is still discoverable.

## 7. Scheduling Rules

1. Never replace the active editing side.
2. Prefer the opposite half of the main display for review.
3. Keep a FIFO queue by default at the conversation level.
4. When a displayed window is marked running, immediately promote the next
   queued window if one exists.
5. When a displayed window is marked done, immediately promote the next queued
   window if one exists.
6. If no tracked slot is available, keep queued conversations hidden or
   untouched.
7. The user can always manually promote the next queued conversation.
8. If an app supports direct conversation activation, promote the exact
   conversation. If it only supports window activation, promote the window and
   show the expected conversation in the panel.

## 8. Edge Cases

### 8.1 Both Slots Look Free

If no focused window is on the main display, AgentDeck should use the last known
active side. If there is no history, default to showing the next agent on the
right.

### 8.2 Window Vanished

If a queued window has been closed, remove it from the queue and continue.

If a queued conversation belonged to that window, mark it `unknown` or `done`
depending on whether the app still exposes it in history.

### 8.3 Untracked Window Focused

If the user focuses an untracked app, AgentDeck can still infer the active side
from its frame. It should not require every focused window to be an agent.

### 8.4 Multiple Displays

Version 0.1 only schedules the primary display. Future versions can add:

- a secondary display as a backlog wall;
- dedicated slots per monitor;
- different rules for laptop screen vs external monitor.

### 8.5 Conversation Detection

Detection quality differs by app:

| App type | Possible identity source |
| --- | --- |
| Browser-based tools | URL, tab title, DOM title, visible conversation header. |
| Codex desktop | Window title, thread id if exposed, sidebar selected item if accessible. |
| Cursor | Window title, workspace, composer/session text if accessible. |
| Terminal agents | Working directory, command, prompt markers, session title. |
| WorkBuddy | Window title, thread/session id if accessible. |

AgentDeck should store a stable `conversationKey` when possible:

```text
appBundleId + windowId + conversationId
```

When no stable conversation id exists, it should fall back to:

```text
appBundleId + windowId + normalized visible title
```

### 8.6 Agent Completion Detection

Completion detection is app-specific. The MVP should not pretend this is solved.
Start with manual hotkeys, then add detectors one by one.

## 9. MVP Interaction Surface

### 9.1 Required Controls

| Control | Purpose |
| --- | --- |
| Refresh conversations | Rescan local windows and active conversation identities. |
| Track / ignore conversation | Decide whether a conversation belongs to AgentDeck. |
| Queue focused conversation | Mark current conversation as ready for review. |
| Mark focused conversation running | Free its slot and promote the next queued item. |
| Mark focused conversation done | Remove it and promote the next queued item. |
| Promote next | Manually pull the next queued conversation onto screen. |
| Show status | Display queue length and active side. |

### 9.2 Prototype Controls

The static prototype exposes the same core logic with buttons:

- inspect a conversation-state table;
- set active side;
- simulate conversation completion;
- simulate switching conversations inside the same window;
- send displayed agent back to work;
- dismiss displayed agent;
- promote next queued item.

## 10. Visual Design Direction

AgentDeck should feel like an operations console, not a marketing site.

Design principles:

- dense enough for repeated work;
- calm contrast;
- clear state color;
- no decorative hero sections;
- no full-screen notification drama;
- queue and slots visible at a glance.

## 11. Technical Direction

See also: `docs/competitive-lessons.md` for mature window-manager techniques
AgentDeck should absorb without becoming a generic window manager.

### 11.1 Version 0.1

Build a local panel prototype backed by Hammerspoon or a small native shell:

- local-only;
- reads windows and active conversation hints through Accessibility APIs;
- shows tracked conversations in a table;
- moves windows through Hammerspoon or native macOS APIs;
- supports manual status changes before automatic detection is reliable.

### 11.2 Version 0.2

Add persistence and app rules:

- save conversation queue state to disk;
- add ignore-list;
- add per-app conversation and completion detectors;
- support multiple monitors.

### 11.3 Version 0.3

Consider native shell:

- menu bar app;
- settings UI;
- onboarding;
- rule editor;
- packaged installer.

## 12. Success Criteria

The first usable version succeeds if:

- the user stops manually searching for finished agent windows;
- the user can see all active AI conversations in one panel;
- the user can distinguish multiple windows in the same app;
- the user can distinguish multiple conversations inside the same window;
- the active editing side is not disturbed;
- queued results appear predictably;
- the user can run at least 5 agents without losing track of them.
