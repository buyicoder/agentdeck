# MVP Plan

## Version 0.1

Build the smallest usable AgentDeck loop using Hammerspoon.

## Why Hammerspoon First

Hammerspoon has direct access to macOS window management through Accessibility
APIs. It can move windows, read the focused app, bind hotkeys, and show local
alerts without building a signed native app.

## In Scope

- Track a FIFO queue of agent windows.
- Identify likely agent windows by app name:
  - Codex
  - WorkBuddy
  - Cursor
  - Claude
  - Terminal
  - iTerm
  - WezTerm
  - Chrome
  - Edge
- Move windows to left or right half of the primary screen.
- Detect the active side from the focused window's frame.
- Promote queued windows to the opposite side.
- Provide hotkeys for manual state changes.

## Out of Scope

- Native menu bar UI.
- Cross-device sync.
- Automatic parsing of every agent's internal status.
- Browser DOM automation.
- External notifications.
- Cloud storage.

## Future Versions

### Version 0.2

- App-specific completion detectors.
- Persistent queue file.
- Ignore-list for windows that should never be managed.
- Better support for secondary displays.

### Version 0.3

- Menu bar status UI.
- Visual queue inspector.
- Rules editor.
- Per-agent priority.

