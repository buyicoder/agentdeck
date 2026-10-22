-- AgentDeck Hammerspoon MVP
-- Copy this file to ~/.hammerspoon/init.lua and reload Hammerspoon.

local agentDeck = {
  queue = {},
  states = {},
}

local agentApps = {
  ["Codex"] = true,
  ["WorkBuddy"] = true,
  ["Cursor"] = true,
  ["Claude"] = true,
  ["Claude Code"] = true,
  ["Terminal"] = true,
  ["iTerm2"] = true,
  ["WezTerm"] = true,
  ["Google Chrome"] = true,
  ["Microsoft Edge"] = true,
}

local function windowId(win)
  return tostring(win:id())
end

local function isAgentWindow(win)
  if not win then return false end
  local app = win:application()
  if not app then return false end
  return agentApps[app:name()] == true
end

local function mainScreenFrame()
  return hs.screen.primaryScreen():frame()
end

local function slotFrame(slot)
  local frame = mainScreenFrame()
  local halfWidth = math.floor(frame.w / 2)

  if slot == "left" then
    return {
      x = frame.x,
      y = frame.y,
      w = halfWidth,
      h = frame.h,
    }
  end

  return {
    x = frame.x + halfWidth,
    y = frame.y,
    w = frame.w - halfWidth,
    h = frame.h,
  }
end

local function activeSide()
  local win = hs.window.focusedWindow()
  if not win then return "left" end

  local frame = win:frame()
  local screen = mainScreenFrame()
  local midpoint = screen.x + (screen.w / 2)
  local windowCenter = frame.x + (frame.w / 2)

  if windowCenter < midpoint then
    return "left"
  end

  return "right"
end

local function oppositeSide(side)
  if side == "left" then return "right" end
  return "left"
end

local function moveWindowToSlot(win, slot)
  if not win then return end
  win:move(slotFrame(slot), hs.screen.primaryScreen(), true, 0)
  win:focus()
end

local function queueContains(id)
  for _, queuedId in ipairs(agentDeck.queue) do
    if queuedId == id then return true end
  end
  return false
end

local function queueFocusedWindow()
  local win = hs.window.focusedWindow()
  if not isAgentWindow(win) then
    hs.alert.show("AgentDeck: focused window is not tracked")
    return
  end

  local id = windowId(win)
  agentDeck.states[id] = {
    state = "queued",
    title = win:title(),
    app = win:application():name(),
    window = win,
  }

  if not queueContains(id) then
    table.insert(agentDeck.queue, id)
  end

  hs.alert.show("AgentDeck: queued " .. agentDeck.states[id].app)
end

local function promoteNext()
  while #agentDeck.queue > 0 do
    local id = table.remove(agentDeck.queue, 1)
    local entry = agentDeck.states[id]

    if entry and entry.window and entry.window:isStandard() then
      local targetSlot = oppositeSide(activeSide())
      entry.state = "displayed"
      entry.slot = targetSlot
      moveWindowToSlot(entry.window, targetSlot)
      hs.alert.show("AgentDeck: displayed " .. entry.app)
      return
    end
  end

  hs.alert.show("AgentDeck: queue empty")
end

local function markFocusedRunning()
  local win = hs.window.focusedWindow()
  if not win then return end

  local id = windowId(win)
  agentDeck.states[id] = agentDeck.states[id] or {
    title = win:title(),
    app = win:application():name(),
    window = win,
  }
  agentDeck.states[id].state = "running"
  agentDeck.states[id].slot = nil

  hs.alert.show("AgentDeck: running")
  promoteNext()
end

local function markFocusedDone()
  local win = hs.window.focusedWindow()
  if not win then return end

  local id = windowId(win)
  if agentDeck.states[id] then
    agentDeck.states[id].state = "done"
    agentDeck.states[id].slot = nil
  end

  hs.alert.show("AgentDeck: done")
  promoteNext()
end

local function showStatus()
  local lines = {
    "AgentDeck",
    "Active side: " .. activeSide(),
    "Queued: " .. tostring(#agentDeck.queue),
  }

  for index, id in ipairs(agentDeck.queue) do
    local entry = agentDeck.states[id]
    if entry then
      table.insert(lines, index .. ". " .. entry.app .. " - " .. entry.title)
    end
  end

  hs.alert.show(table.concat(lines, "\n"), 4)
end

local hyper = { "ctrl", "alt", "cmd" }

hs.hotkey.bind(hyper, "q", queueFocusedWindow)
hs.hotkey.bind(hyper, "r", markFocusedRunning)
hs.hotkey.bind(hyper, "d", markFocusedDone)
hs.hotkey.bind(hyper, "n", promoteNext)
hs.hotkey.bind(hyper, "s", showStatus)

hs.alert.show("AgentDeck loaded")

