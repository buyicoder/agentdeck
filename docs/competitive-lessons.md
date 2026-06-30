# Competitive Lessons

AgentDeck should not become another generic macOS window manager. Mature tools
already solve snapping, tiling, shortcuts, and workspace movement well.

The product should absorb their proven techniques, then apply them to the
conversation-level AI workflow.

## 1. Tools Studied

| Tool | What It Is | Lesson For AgentDeck |
| --- | --- | --- |
| AeroSpace | i3-like tiling window manager for macOS. | Separate workspaces and layouts from app identity. Use explicit commands and predictable rules. |
| yabai | Powerful scriptable tiling window manager. | Provide a scriptable command layer, but avoid requiring unsafe setup for normal users. |
| Hammerspoon | macOS automation framework with Accessibility APIs. | Use watchers and filters for window discovery, but wrap them in a product UI. |
| Rectangle | Simple snapping and resizing app. | Keep common actions obvious and reversible. |
| Moom | Window manager with custom actions and saved layouts. | Support saved layouts, chained actions, and display-change restoration. |
| Raycast Window Management | Command/hotkey-based window management inside a launcher. | Make every panel action available as a command/hotkey. |
| AltTab / Contexts | Window switchers for many windows across apps/spaces. | Search, grouping, and same-app window disambiguation are essential. |

## 2. Required Techniques To Absorb

### 2.1 Window Fact Layer

AgentDeck needs a neutral window inventory before it applies scheduling logic.

Track:

- app name and bundle id;
- physical window id;
- window title;
- window frame and display;
- tab count when available;
- focused window;
- accessibility role/subrole;
- active conversation identity if detectable.

This layer should be read-only by default. Movement and activation should be
separate commands.

### 2.2 Conversation Identity Layer

Generic window managers stop at app/window identity. AgentDeck must add:

```text
conversationKey = appBundleId + windowId + conversationId
```

Fallback:

```text
conversationKey = appBundleId + windowId + normalized visible title
```

If a user switches conversations inside one window, AgentDeck should detect the
conversation key change and update the active row. The old conversation should
become `inactive`, not disappear immediately.

### 2.3 Rule Layer

Borrow the rule style from tiling managers:

```text
when conversation.status == queued
and mainDisplay.opposite(activeSide).isFree
then promote(conversation)
```

Rules should be visible and editable later. The first version can hardcode them,
but the architecture should not bury scheduling decisions inside UI code.

### 2.4 Event Watchers

Use watchers instead of polling whenever possible:

- app launched / terminated;
- window created / destroyed;
- focused window changed;
- window title changed;
- window moved / resized;
- active tab changed when available;
- accessibility focused element changed.

Polling can remain as a fallback for apps that do not expose enough events.

### 2.5 Reversible Layout Actions

Window movement must be reversible.

Before AgentDeck moves a window, store:

- previous display;
- previous frame;
- previous focused conversation;
- previous status.

This allows:

- restore previous position;
- undo last promote;
- send conversation back to background.

### 2.6 Multi-Display Model

Do not treat all monitors as one flat canvas.

Track:

- primary display;
- left/right slots on primary display;
- external display inventory;
- whether a display is a backlog wall, editing screen, or passive screen;
- saved layout per display configuration.

Moom-style display-change restoration matters because the user may unplug
external monitors.

### 2.7 Search And Grouping

Window switchers show a major lesson: when many windows exist, flat lists break.

AgentDeck needs:

- grouping by app;
- grouping by physical window;
- grouping by project/workspace;
- search by conversation title;
- quick filter: queued / running / displayed / inactive;
- same-app disambiguation.

### 2.8 Command Palette And Hotkeys

Every panel action should be callable without touching the mouse:

- queue focused conversation;
- mark focused conversation running;
- mark focused conversation done;
- promote next;
- focus queued conversation;
- restore previous layout;
- ignore this conversation;
- search conversations.

Raycast-style commands can exist before a full native UI.

### 2.9 Permission And Reliability UX

macOS window tools fail mostly because of permissions, Spaces, Stage Manager,
fullscreen windows, or app-specific Accessibility gaps.

AgentDeck needs a visible health panel:

- Accessibility permission;
- Screen Recording permission if needed;
- per-app detector status;
- last successful scan time;
- windows detected vs conversations detected;
- warnings when an app only exposes window-level identity.

### 2.10 Progressive Detector Quality

AgentDeck should not pretend every app can be perfectly parsed.

Use detector levels:

| Level | Meaning |
| --- | --- |
| L0 | App/window detected only. |
| L1 | Window title identifies conversation. |
| L2 | Active conversation can be detected from accessibility/DOM. |
| L3 | Agent running/completed state can be detected. |
| L4 | AgentDeck can activate a specific conversation inside the window. |

The panel should show detector confidence per row.

## 3. Product Decisions

1. AgentDeck's main table is conversation-level, not app-level.
2. App and window are metadata columns, not the primary object.
3. The scheduling queue stores conversation ids.
4. Window movement must be reversible.
5. The first implementation can use manual status controls, but the data model
   must support automatic detectors.
6. Avoid requiring SIP disable. Use standard Accessibility APIs first.
7. Keep a scriptable command layer so power users can automate the workflow.

## 4. Source Links

- AeroSpace: https://github.com/nikitabobko/AeroSpace
- AeroSpace guide: https://nikitabobko.github.io/AeroSpace/guide
- yabai: https://github.com/asmvik/yabai/wiki
- Hammerspoon docs: https://www.hammerspoon.org/docs/0.9.91/index.html
- Hammerspoon window filter: https://www.hammerspoon.org/docs/hs.window.filter.html
- Hammerspoon window API: https://www.hammerspoon.org/docs/hs.window.html
- Rectangle: https://rectangleapp.com/
- Rectangle GitHub: https://github.com/rxhanson/rectangle
- Moom: https://manytricks.com/moom/
- Raycast Window Management: https://manual.raycast.com/window-management
- AltTab: https://github.com/lwouis/alt-tab-macos
- Contexts: https://contexts.co/

