const state = {
  activeSide: "left",
  queue: [],
  nextId: 8,
  conversations: [
    {
      id: 1,
      appName: "Cursor",
      windowLabel: "Cursor window 1",
      conversationTitle: "AgentDeck prototype",
      conversationKey: "cursor:w1:agentdeck-prototype",
      subtitle: "Editing product UI",
      status: "editing",
      location: "Main display / Left",
      side: "left",
      age: "now",
    },
    {
      id: 2,
      appName: "WorkBuddy",
      windowLabel: "WorkBuddy window 1",
      conversationTitle: "Jarvis delivery thread",
      conversationKey: "workbuddy:w1:thread-4537",
      subtitle: "Waiting for review",
      status: "displayed",
      location: "Main display / Right",
      side: "right",
      age: "3m",
    },
    {
      id: 3,
      appName: "Codex",
      windowLabel: "Codex window 1",
      conversationTitle: "AIZZ markdown audit",
      conversationKey: "codex:w1:aizz-markdown",
      subtitle: "Running background task",
      status: "running",
      location: "External display 1",
      side: null,
      age: "11m",
    },
    {
      id: 4,
      appName: "Codex",
      windowLabel: "Codex window 1",
      conversationTitle: "AgentDeck product design",
      conversationKey: "codex:w1:agentdeck-design",
      subtitle: "Same Codex window, different conversation",
      status: "inactive",
      location: "Codex window 1 / background thread",
      side: null,
      age: "13m",
    },
    {
      id: 5,
      appName: "Claude Code",
      windowLabel: "Terminal tab 2",
      conversationTitle: "Hammerspoon detector",
      conversationKey: "terminal:tab2:hammerspoon-detector",
      subtitle: "Needs human instruction",
      status: "queued",
      location: "Hidden",
      side: null,
      age: "18m",
    },
    {
      id: 6,
      appName: "Chrome",
      windowLabel: "Chrome window 3 / tab 8",
      conversationTitle: "Agent browser preview",
      conversationKey: "chrome:w3:t8:agent-browser-preview",
      subtitle: "Browser tab conversation",
      status: "hidden",
      location: "External display 2",
      side: null,
      age: "24m",
    },
    {
      id: 7,
      appName: "Codex",
      windowLabel: "Codex window 2",
      conversationTitle: "Jarvis memory scan",
      conversationKey: "codex:w2:jarvis-memory-scan",
      subtitle: "Different Codex window",
      status: "running",
      location: "External display 1",
      side: null,
      age: "31m",
    },
  ],
};

const agentCopy = {
  Codex: {
    conversationTitle: "Implementation finished",
    subtitle: "Ready for code review",
    windowLabel: "Codex window 3",
  },
  WorkBuddy: {
    conversationTitle: "Background run complete",
    subtitle: "Thread has a completed response",
    windowLabel: "WorkBuddy window 1",
  },
  Cursor: {
    conversationTitle: "Patch prepared",
    subtitle: "Needs a human pass",
    windowLabel: "Cursor window 2",
  },
  "Claude Code": {
    conversationTitle: "Agent checkpoint",
    subtitle: "Waiting for next instruction",
    windowLabel: "Terminal tab 4",
  },
};

const windowRows = document.querySelector("#window-rows");
const queueList = document.querySelector("#queue-list");
const queueCount = document.querySelector("#queue-count");
const eventLog = document.querySelector("#event-log");
const activeSideLabel = document.querySelector("#active-side-label");
const trackedCount = document.querySelector("#tracked-count");

function opposite(side) {
  return side === "left" ? "right" : "left";
}

function initials(appName) {
  return appName
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2);
}

function addLog(message) {
  const item = document.createElement("li");
  item.textContent = message;
  eventLog.prepend(item);
}

function visibleSlot(side) {
  return state.conversations.find((item) => item.side === side && ["editing", "displayed"].includes(item.status));
}

function availableSlot() {
  const preferred = opposite(state.activeSide);
  if (!visibleSlot(preferred)) return preferred;
  if (!visibleSlot(state.activeSide)) return state.activeSide;
  return null;
}

function normalizeQueue() {
  state.queue = state.conversations.filter((item) => item.status === "queued").map((item) => item.id);
}

function setActiveSide(side) {
  state.activeSide = side;

  for (const item of state.conversations) {
    if (item.status === "editing") {
      item.status = "displayed";
    }
  }

  const current = visibleSlot(side);
  if (current) {
    current.status = "editing";
    current.location = `Main display / ${capitalize(side)}`;
    current.side = side;
  }

  addLog(`Active editing side set to ${side}.`);
  promoteIfPossible();
  render();
}

function finishAgent(appName) {
  const copy = agentCopy[appName];
  const item = {
    id: state.nextId++,
    appName,
    windowLabel: copy.windowLabel,
    conversationTitle: copy.conversationTitle,
    conversationKey: `${appName.toLowerCase().replaceAll(" ", "-")}:new:${Date.now()}`,
    subtitle: copy.subtitle,
    status: "queued",
    location: "Hidden",
    side: null,
    age: "now",
  };

  state.conversations.unshift(item);
  state.queue.push(item.id);
  addLog(`${appName} conversation finished and entered the review queue.`);
  promoteIfPossible();
  render();
}

function promoteIfPossible() {
  normalizeQueue();
  const slot = availableSlot();
  if (!slot || state.queue.length === 0) return;

  const nextId = state.queue.shift();
  const item = state.conversations.find((conversation) => conversation.id === nextId);
  if (!item) return;

  item.status = "displayed";
  item.side = slot;
  item.location = `Main display / ${capitalize(slot)}`;
  addLog(`${item.appName} conversation "${item.conversationTitle}" promoted to ${slot}.`);
}

function markRunning(id) {
  const item = state.conversations.find((conversation) => conversation.id === id);
  if (!item) return;

  const oldSide = item.side;
  item.status = "running";
  item.side = null;
  item.location = oldSide ? `Freed ${oldSide} slot` : "Background";
  addLog(`${item.appName} conversation "${item.conversationTitle}" marked running; ${oldSide || "no"} slot is available.`);
  promoteIfPossible();
  render();
}

function markDone(id) {
  const item = state.conversations.find((conversation) => conversation.id === id);
  if (!item) return;

  const oldSide = item.side;
  item.status = "done";
  item.side = null;
  item.location = "Done";
  addLog(`${item.appName} conversation "${item.conversationTitle}" marked done; ${oldSide || "no"} slot is available.`);
  promoteIfPossible();
  render();
}

function queueWindow(id) {
  const item = state.conversations.find((conversation) => conversation.id === id);
  if (!item || item.status === "queued") return;

  item.status = "queued";
  item.side = null;
  item.location = "Hidden";
  state.queue.push(item.id);
  addLog(`${item.appName} conversation "${item.conversationTitle}" queued for review.`);
  promoteIfPossible();
  render();
}

function switchActiveConversation() {
  const active = state.conversations.find((item) => item.status === "editing");
  if (active) {
    active.status = "inactive";
    active.side = null;
    active.location = `${active.windowLabel} / background conversation`;
  }

  const target = state.conversations.find((item) => item.conversationKey === "codex:w1:agentdeck-design");
  if (!target) return;

  target.status = "editing";
  target.side = state.activeSide;
  target.location = `Main display / ${capitalize(state.activeSide)}`;
  addLog(`Active conversation switched inside ${target.windowLabel}: "${target.conversationTitle}".`);
  render();
}

function capitalize(value) {
  return value[0].toUpperCase() + value.slice(1);
}

function statusClass(status) {
  return `status-pill status-${status}`;
}

function renderWindowRows() {
  windowRows.innerHTML = "";

  for (const item of state.conversations) {
    const row = document.createElement("tr");
    row.innerHTML = `
      <td>
        <div class="app-cell">
          <span class="app-icon">${initials(item.appName)}</span>
          <span>${item.appName}</span>
        </div>
      </td>
      <td>
        <div class="window-ref">
          <strong>${item.windowLabel}</strong>
          <span>${item.conversationKey.split(":").slice(0, 2).join(":")}</span>
        </div>
      </td>
      <td>
        <div class="window-title">
          <strong>${item.conversationTitle}</strong>
          <span>${item.subtitle}</span>
        </div>
      </td>
      <td><span class="${statusClass(item.status)}">${item.status}</span></td>
      <td class="location-cell">${item.location}</td>
      <td class="age-cell">${item.age}</td>
      <td>
        <div class="row-actions">
          <button data-action="queue" data-id="${item.id}" type="button">Queue</button>
          <button data-action="run" data-id="${item.id}" type="button">Run</button>
          <button data-action="done" data-id="${item.id}" type="button">Done</button>
        </div>
      </td>
    `;
    windowRows.appendChild(row);
  }
}

function renderSlot(side) {
  const slot = document.querySelector(`#${side}-slot`);
  const stateLabel = document.querySelector(`#${side}-slot-state`);
  const body = document.querySelector(`#${side}-slot-body`);
  const win = visibleSlot(side);
  const isActive = side === state.activeSide;

  slot.classList.toggle("active-side", isActive);
  stateLabel.textContent = isActive ? "Editing" : win ? "Displayed" : "Open";
  body.innerHTML = "";

  if (!win) {
    body.innerHTML = `<div class="empty-slot">No tracked window in this slot</div>`;
    return;
  }

  const card = document.createElement("div");
  card.className = "slot-card";
  card.innerHTML = `
    <span>${win.appName} / ${win.windowLabel}</span>
    <strong>${win.conversationTitle}</strong>
    <span>${win.subtitle}</span>
  `;
  body.appendChild(card);
}

function renderQueue() {
  normalizeQueue();
  queueList.innerHTML = "";
  for (const id of state.queue) {
    const win = state.conversations.find((item) => item.id === id);
    if (!win) continue;
    const item = document.createElement("li");
    item.textContent = `${win.appName} / ${win.windowLabel}: ${win.conversationTitle}`;
    queueList.appendChild(item);
  }

  if (state.queue.length === 0) {
    const item = document.createElement("li");
    item.textContent = "Queue is empty.";
    queueList.appendChild(item);
  }

  queueCount.textContent = `${state.queue.length} queued`;
}

function renderControls() {
  document.querySelector("#set-left").classList.toggle("active", state.activeSide === "left");
  document.querySelector("#set-right").classList.toggle("active", state.activeSide === "right");
  activeSideLabel.textContent = `Active side: ${state.activeSide}`;
  trackedCount.textContent = `${state.conversations.filter((item) => item.status !== "done").length} tracked conversations`;
}

function resetDemo() {
  window.location.reload();
}

function refreshWindows() {
  addLog("Local conversation list refreshed from Accessibility and visible title snapshot.");
  render();
}

function render() {
  renderWindowRows();
  renderSlot("left");
  renderSlot("right");
  renderQueue();
  renderControls();
}

document.querySelector("#set-left").addEventListener("click", () => setActiveSide("left"));
document.querySelector("#set-right").addEventListener("click", () => setActiveSide("right"));
document.querySelector("#promote-next").addEventListener("click", () => {
  promoteIfPossible();
  render();
});
document.querySelector("#reset-demo").addEventListener("click", resetDemo);
document.querySelector("#refresh-windows").addEventListener("click", refreshWindows);
document.querySelector("#switch-conversation").addEventListener("click", switchActiveConversation);

for (const button of document.querySelectorAll("[data-agent]")) {
  button.addEventListener("click", () => finishAgent(button.dataset.agent));
}

windowRows.addEventListener("click", (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;

  const id = Number(button.dataset.id);
  if (button.dataset.action === "queue") queueWindow(id);
  if (button.dataset.action === "run") markRunning(id);
  if (button.dataset.action === "done") markDone(id);
});

normalizeQueue();
addLog("Local panel loaded. AgentDeck is watching conversations inside Mac windows.");
render();
