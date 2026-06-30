# Development Workflow

This document defines how AgentDeck work should be split across agents or
contributors.

## 1. Development Rules

1. Keep product object language consistent: conversation, app, window.
2. Do not build generic window-manager features unless they serve conversation
   scheduling.
3. Keep detector logic separate from scheduler logic.
4. Keep window movement reversible.
5. Prefer local-only data and no cloud dependency.
6. Do not require SIP disable for the normal path.
7. Manual controls are acceptable before automatic detectors are reliable.

## 2. Workstreams

### Product / UX

Owns:

- product design;
- prototype;
- panel layout;
- interaction flows;
- app copy.

Main files:

- `docs/product-design.md`
- `docs/competitive-lessons.md`
- `prototype/`

### Platform / macOS

Owns:

- Accessibility permission;
- window enumeration;
- display/frame detection;
- focus/window watchers;
- window movement and restore.

Future files:

- `src/platform/`
- `src/platform/macos/`

### Conversation Detection

Owns:

- detector interface;
- per-app detectors;
- conversation key strategy;
- detector confidence.

Future files:

- `src/detectors/`
- `src/detectors/codex.*`
- `src/detectors/browser.*`
- `src/detectors/cursor.*`

### Scheduler

Owns:

- queue model;
- slot availability;
- promote/restore rules;
- active side protection;
- event log.

Future files:

- `src/scheduler/`
- `src/state/`

### App Shell / Panel

Owns:

- local app scaffold;
- state rendering;
- command palette;
- keyboard shortcuts;
- settings and health panel.

Future files:

- `src/app/`
- `src/ui/`

### QA / Packaging

Owns:

- manual test matrix;
- multi-display tests;
- permission tests;
- packaging;
- release checklist.

Future files:

- `docs/test-plan.md`
- `docs/release-checklist.md`

## 3. Branch Strategy

Use short feature branches:

```text
codex/docs-workflow
codex/app-shell
codex/window-facts
codex/detector-interface
codex/scheduler-mvp
```

Merge order:

1. docs and prototype;
2. app shell;
3. state model;
4. mock UI wiring;
5. macOS facts;
6. detectors;
7. scheduler actions;
8. packaging.

## 4. PR Standard

Each PR should include:

- scope;
- files changed;
- manual verification;
- remaining risk.

Avoid mixing:

- docs + app shell + detector code in one PR;
- UI redesign + scheduler behavior changes;
- platform permission changes + unrelated prototype updates.

## 5. Definition Of Done

A task is done when:

- behavior is visible in the panel or documented in the relevant design file;
- any new state shape is documented;
- manual test steps are written;
- no unrelated files are changed;
- known limitations are listed.

## 6. First Development Split

Run these in order:

1. Product agent finalizes docs and prototype.
2. App shell agent creates installable local panel skeleton with mock data.
3. State agent extracts the prototype data model into typed state.
4. Platform agent builds a macOS window facts spike.
5. Detector agent implements detector interface with title-based fallback.
6. Scheduler agent wires queue/promote/restore using mock actions first.

