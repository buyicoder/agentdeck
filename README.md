# AgentDeck

AgentDeck is a local-first macOS window dispatcher for people who run many AI
agents at once: Codex, WorkBuddy, Cursor, Claude Code, browser agents, and other
assistant windows.

Its job is simple:

- keep your active editing side stable;
- send completed or newly surfaced agent windows to the opposite half of the
  main display;
- queue completed agents without asking for confirmation;
- promote the next queued window whenever a main-display slot becomes free.

## Core Idea

The main display is treated as a two-slot workbench.

```text
Left slot                          Right slot
active editing side                review / next-agent side
```

When the left slot is active, AgentDeck presents the next agent window on the
right. When the right slot is active, it presents the next agent window on the
left.

Completed agents do not interrupt your flow. They enter a FIFO review queue and
wait until a slot opens.

## State Machine

```text
Running
  -> Queued       agent finishes and needs review
  -> Displayed    a screen slot is available
  -> Running      you send it back to work
  -> Done         you close, archive, or dismiss it
```

## First MVP

The first version is a Hammerspoon-based prototype:

- detect agent windows by application name and title;
- track which half of the main screen currently has focus;
- move a queued agent window to the opposite half;
- use hotkeys to mark windows as running, queued, displayed, or done;
- keep the scheduling logic in one local Lua file.

This avoids building a full native macOS app before the interaction model is
proven.

## Setup

1. Install Hammerspoon from <https://www.hammerspoon.org/>.
2. Give Hammerspoon Accessibility permission in macOS Settings.
3. Copy `hammerspoon/init.lua` into `~/.hammerspoon/init.lua`.
4. Reload Hammerspoon.

## MVP Hotkeys

| Hotkey | Action |
| --- | --- |
| `ctrl + alt + cmd + q` | Queue focused agent window |
| `ctrl + alt + cmd + r` | Mark focused window as running and free its slot |
| `ctrl + alt + cmd + d` | Mark focused window as done |
| `ctrl + alt + cmd + n` | Promote next queued window |
| `ctrl + alt + cmd + s` | Show AgentDeck status |

## Project Docs

- `docs/flow.md` describes the full workflow.
- `docs/mvp.md` describes the first build target.

