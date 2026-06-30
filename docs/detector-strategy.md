# Detector Strategy

AgentDeck should treat conversation detection as a progressive capability, not a
single all-or-nothing detector. The product object is still a conversation:
app + window + active conversation identity.

## Current detector stack

`Sources/AgentDeck/Detectors.swift` runs detectors from most app-specific to
most generic:

1. Codex title detector.
2. Cursor title detector.
3. WorkBuddy title detector.
4. Terminal agent title detector.
5. Browser title detector.
6. Generic title fallback.
7. Window-only fallback.

The current implementation is intentionally L1: it reads only visible app/window
metadata and parses titles. App-specific parsing helpers keep each app's title
cleanup rules explicit while sharing the same stable key shape:

```text
detector-prefix:ownerPID:windowNumber:normalized-title-slug
```

This is good enough to distinguish many windows and to notice active-title
changes inside one window, but it is not a durable conversation id.

## Browser next step

Browser windows need a real URL/tab source before they can be considered
conversation-stable.

Preferred order:

1. Use browser scripting or Accessibility to read the active tab URL and tab
   title for Chrome, Edge, and Safari.
2. Parse known conversation hosts into stable keys, for example:
   - ChatGPT conversation URL path;
   - Claude chat/project URL path;
   - WorkBuddy web thread/session URL;
   - local preview URL plus visible app title.
3. Fall back to active tab title when URL is unavailable.
4. Fall back to window identity only when title is empty or generic.

Target key shape:

```text
browser:<browser-bundle-or-app>:<host>:<stable-url-or-thread-id>
```

If a browser only exposes the active tab title, keep the detector confidence
below URL-backed detectors and keep the subtitle explicit about that limitation.

## Codex, Cursor, and WorkBuddy next step

For native agent apps, the next detector layer should inspect app-specific
conversation hints before falling back to title parsing.

Codex:

- title: current L1 source;
- next L2 source: Accessibility-selected sidebar/thread row if exposed;
- possible L3 source: persisted local thread metadata if the app exposes a
  thread id or route;
- activation target: window focus first, exact thread activation only after the
  selected-thread mechanism is proven.

Cursor:

- title: current L1 source, usually workspace/file/composer context;
- next L2 source: Accessibility text around the active composer/session;
- possible L3 source: workspace path plus selected composer/session id if
  exposed;
- activation target: focus the window; exact composer activation is a later
  app-specific command.

WorkBuddy:

- title: current L1 source;
- next L2 source: selected conversation/thread label from Accessibility or DOM
  if it is browser-backed;
- possible L3 source: thread/session id from local app state or URL;
- activation target: window focus until exact thread addressing is available.

## Confidence guidance

- L0 window-only: cannot identify a conversation, only a visible window.
- L1 title: usable for the panel and manual queueing, but not durable across
  retitles.
- L2 active UI selection: can distinguish active conversation inside a window.
- L3 stable id: durable enough for queue persistence and exact merge behavior.
- L4 activation: AgentDeck can focus or switch to the exact conversation.

Do not raise detector confidence just because parsing is cleaner. Raise it only
when the detector source becomes more stable.

## Safety rules

- Never read passwords, cookies, private messages, payment content, or hidden
  browser data to identify a conversation.
- Keep detector failures visible and low confidence instead of guessing.
- Preserve the fallback chain so unsupported apps still appear in the panel.
- Add new app detectors before generic title fallback, and document their source
  and confidence level here.
