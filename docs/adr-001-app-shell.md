# ADR 001: App Shell Choice

## Status

Accepted for Milestone 1.

## Decision

Use a native Swift app shell with AppKit + SwiftUI for the first macOS risk
spike and Milestone 1 scaffold.

Keep Tauri 2 + React/TypeScript + Rust as the leading candidate for a later
product shell if the team installs Rust/Node tooling and wants faster web UI
iteration.

## Context

AgentDeck must become a locally installed macOS app. It needs:

- Accessibility permission onboarding;
- app/window enumeration;
- window movement and focus control;
- multi-display frame handling;
- a fast panel UI for conversation state.

Current local toolchain check:

- Swift is available through Command Line Tools.
- `xcodebuild` is present but full Xcode is not selected/available.
- Rust/cargo are not available.
- Node/npm are not available in the regular shell, though Codex has bundled
  Node for tooling.

## Options

### SwiftUI / AppKit

Pros:

- best fit for macOS Accessibility and window APIs;
- no Rust/npm requirement;
- native permission story;
- easiest path to a menu bar app and installable `.app`;
- can use SwiftUI for panel iteration and AppKit for window operations.

Cons:

- UI iteration is slower than browser-only prototyping;
- packaging may require Xcode later;
- conversation detectors for web apps may still need app-specific bridges.

### Tauri

Pros:

- good local app model;
- web UI iteration;
- smaller than Electron.
- strong long-term fit for a plugin-friendly control panel if Rust/Node are
  available.

Cons:

- requires Rust/cargo;
- still needs native macOS bridge code;
- adds two-language complexity early.

### Electron

Pros:

- fastest reuse of HTML/CSS prototype;
- large ecosystem.

Cons:

- regular npm is not available locally right now;
- heavier runtime;
- native Accessibility integration still needs native modules or sidecar code.

## Consequences

Milestone 1 will use a Swift Package executable that opens a native panel window
and renders mock conversation state. This validates the native macOS API path
without waiting on Rust/npm setup.

After the Accessibility/window-control spike, revisit whether to:

- keep Swift as the product shell; or
- move the panel UI to Tauri and keep native macOS operations behind a bridge.

The static HTML prototype remains a design artifact, not the production shell.
