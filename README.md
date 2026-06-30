# AgentDeck

AgentDeck is a local macOS control panel for AI conversations.

It tracks conversations across apps, windows, and tabs, then helps the user
review completed agent work without hunting through windows.

The core object is:

```text
conversation = app + window + active conversation identity
```

This means AgentDeck must distinguish:

- different apps, such as Codex, Cursor, WorkBuddy, Chrome, Terminal;
- different windows inside the same app;
- different conversations inside the same window.

## Product Goal

AgentDeck should make a multi-agent Mac setup feel like a dispatch desk:

- all important AI conversations are visible in one local panel;
- running conversations stay out of the way;
- finished conversations enter a review queue;
- the next conversation appears when the main display has room;
- the active editing side is protected.

## Current Status

Status: native app skeleton with real window facts, detector pipeline,
conversation scheduler, guarded window actions, and validation mode.

Completed:

- conversation-level product design;
- mature window-manager lessons;
- static local panel prototype;
- architecture split;
- development workflow and task board.
- Swift native panel skeleton;
- real visible-window scan;
- focused-window approximation;
- detector pipeline with title-based detectors;
- scheduler decision module.
- guarded macOS Accessibility move/restore path behind `Move windows`;
- safe test window and one-click validation mode.

Next:

- browser URL/tab detector;
- manual multi-display validation;
- local packaging;
- user full-journey frontend audit.

## Local Prototype

Open:

```text
prototype/index.html
```

The prototype simulates:

- app/window/conversation separation;
- multiple conversations in the same window;
- switching the active conversation inside a window;
- queue, run, done, and promote flows;
- main display left/right slot behavior.

## Documentation

| File | Purpose |
| --- | --- |
| `docs/product-design.md` | Product definition and interaction model. |
| `docs/competitive-lessons.md` | Lessons from mature macOS window tools. |
| `docs/architecture.md` | System layers and module boundaries. |
| `docs/development-workflow.md` | Workstream split and collaboration rules. |
| `docs/task-board.md` | Milestones and implementation tasks. |
| `docs/platform-window-actions.md` | Real macOS move/focus/restore plan. |
| `docs/user-journey-frontend-audit.md` | Required full journey frontend audit before alpha. |
| `docs/audit-evidence.md` | Validation and audit evidence procedure. |
| `docs/flow.md` | Original queue flow sketch. |
| `docs/mvp.md` | Original MVP notes. |

## Development Workstreams

- Product / UX
- Platform / macOS
- Conversation Detection
- Scheduler
- App Shell / Panel
- QA / Packaging

See `docs/development-workflow.md` for ownership and merge order.
