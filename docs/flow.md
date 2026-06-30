# AgentDeck Flow

## Goal

AgentDeck turns many AI agent windows into a review queue. The user should not
keep switching windows just to discover which agent has finished.

## Concepts

### Main Display

The primary display is split into two slots:

- `left`
- `right`

Only these two slots are part of the first scheduling loop.

### Active Side

The side that contains the focused window is considered active. AgentDeck avoids
covering it.

### Free Side

The opposite side is the preferred placement for the next agent that needs the
user's attention.

### Review Queue

Completed agents enter a FIFO queue. A queued window is not automatically
focused if both slots are occupied.

## Window States

| State | Meaning |
| --- | --- |
| `running` | The agent is working and does not need attention. |
| `queued` | The agent finished or needs review, but no slot is free. |
| `displayed` | The agent is visible in a main-display slot. |
| `done` | The user closed, archived, or dismissed it. |

## Scheduling Rules

1. If the left side is active, promote queued windows to the right side.
2. If the right side is active, promote queued windows to the left side.
3. If both sides are occupied, keep completed agents in the queue.
4. When a displayed agent is sent back to run, its slot is considered free.
5. When a slot is free, promote the first queued agent.
6. If multiple agents finish together, preserve completion order.

## Typical Loop

```text
Agent starts running
  -> user continues working elsewhere
  -> agent finishes
  -> AgentDeck queues it
  -> a main-display slot opens
  -> AgentDeck moves the queued window into that slot
  -> user reviews the result
  -> user sends the agent back to work
  -> AgentDeck frees the slot and promotes the next queued window
```

## First Manual Signals

Automatic completion detection is hard because every agent app exposes status
differently. The MVP starts with explicit hotkeys:

- queue this window;
- mark this window running;
- mark this window done;
- promote next.

Once the loop feels right, completion detection can be added per app.

