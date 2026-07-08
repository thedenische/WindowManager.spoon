--- === WindowManager ===
---
--- Simple window management for Hammerspoon: move the focused window between
--- monitors (with full-screen handling), maximize / restore it, or push it to
--- native full screen.
---
--- `moveWindowToScreen` moves the focused window to the monitor that is
--- physically in a given direction (`"east"` / `"west"` / `"north"` / `"south"`),
--- so the move matches the display layout rather than an arbitrary ordering.
--- If the window is in native full screen it is briefly taken out of full
--- screen, moved, then put back -- so full-screen windows follow you across
--- displays instead of refusing to move.
---
--- `maximizeWindow` remembers the window's current frame before maximizing, and
--- `restoreWindow` puts it back (or drops out of full screen first if needed).
---
--- The methods can be bound to hotkeys via `:bindHotkeys` (see `defaultHotkeys`),
--- or called directly -- e.g. wired into another Spoon such as Hammerflow:
---
---   hs.loadSpoon("WindowManager")
---   local wm = spoon.WindowManager
---   spoon.Hammerflow.registerFunctions({
---     moveWindowToEastScreen = function() wm:moveWindowToScreen("east") end,
---     maximizeWindow         = function() wm:maximizeWindow() end,
---   })
---
--- Download: https://github.com/thedenische/WindowManager.spoon

-- `hs` (and `spoon`) are injected by the Hammerspoon runtime; see .luarc.json
-- for the lua-language-server global declarations.

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowManager"
obj.version = "1.0.0"
obj.author = "Denis Che <the.denis.che@gmail.com>"
obj.homepage = "https://github.com/thedenische/WindowManager.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Default hotkeys. Override any subset via `:bindHotkeys`; missing actions fall
-- back to these. Each action maps to a `{ mods, key }` pair. Movement uses vim
-- directions (h/j/k/l) so the whole set can be bound with `:bindHotkeys()`.
-- `maximize` / `restore` are also available as separate actions if you prefer
-- dedicated keys; by default a single key (`toggleMaximize`) covers both.
obj.defaultHotkeys = {
    moveWest       = { { "ctrl", "cmd" }, "h" },
    moveSouth      = { { "ctrl", "cmd" }, "j" },
    moveNorth      = { { "ctrl", "cmd" }, "k" },
    moveEast       = { { "ctrl", "cmd" }, "l" },
    toggleMaximize = { { "ctrl", "cmd" }, "m" },
    minimize       = { { "ctrl", "cmd" }, "n" },
    fullscreen     = { { "ctrl", "cmd" }, "f" },
}

-- Compass directions -> the hs.screen method that finds the physically adjacent
-- screen in that direction (returns nil when there is none, i.e. no wrap).
local SCREEN_IN_DIRECTION = {
    east  = "toEast",
    west  = "toWest",
    north = "toNorth",
    south = "toSouth",
}

-- Delays (seconds) used when moving a native full-screen window between screens:
-- wait for the exit-fullscreen animation before moving, then a short beat before
-- re-entering full screen on the target display.
local EXIT_FULLSCREEN_DELAY = 0.6
local ENTER_FULLSCREEN_DELAY = 0.4

-- Per-window saved frames, keyed by window id, so `restoreWindow` can put a
-- maximized window back exactly where it was.
obj._savedFrames = {}

-- Drop saved frames for windows that no longer exist, so the table can't grow
-- unbounded as windows are maximized and then closed without being restored.
local function pruneSavedFrames(self)
    for id in pairs(self._savedFrames) do
        if not hs.window.get(id) then
            self._savedFrames[id] = nil
        end
    end
end

--- WindowManager:moveWindowToScreen(direction) -> self
--- Method
--- Move the focused window to the monitor physically adjacent in `direction`.
---
--- Parameters:
---  * direction - one of `"east"`, `"west"`, `"north"`, `"south"`. The target is
---    the display in that direction relative to the window's current screen, so
---    it follows the physical monitor layout (no wrap-around). If there is no
---    monitor in that direction an alert is shown and nothing moves. If the
---    window is in native full screen it is taken out of full screen, moved, and
---    put back on the target display.
---
--- Returns:
---  * The WindowManager object
function obj:moveWindowToScreen(direction)
    local win = hs.window.focusedWindow()
    if not win then return self end

    local method = SCREEN_IN_DIRECTION[direction]
    if not method then
        hs.alert.show('WindowManager: unknown direction "' .. tostring(direction) .. '"')
        return self
    end

    local screen = win:screen()
    local targetScreen = screen[method](screen)
    if not targetScreen then
        hs.alert.show("No monitor to the " .. direction)
        return self
    end

    if win:isFullScreen() then
        win:setFullScreen(false)
        hs.timer.doAfter(EXIT_FULLSCREEN_DELAY, function()
            win:moveToScreen(targetScreen)
            hs.timer.doAfter(ENTER_FULLSCREEN_DELAY, function()
                win:setFullScreen(true)
            end)
        end)
    else
        win:moveToScreen(targetScreen)
    end
    return self
end

--- WindowManager:maximizeWindow() -> self
--- Method
--- Maximize the focused window, remembering its current frame first so
--- `restoreWindow` can put it back.
---
--- Returns:
---  * The WindowManager object
function obj:maximizeWindow()
    local win = hs.window.focusedWindow()
    if not win then return self end

    pruneSavedFrames(self)
    local id = win:id()
    -- `win:id()` can be nil for some windows; only track when we have a real id
    -- (assigning to `savedFrames[nil]` would raise a Lua error).
    if id and not self._savedFrames[id] then
        self._savedFrames[id] = win:frame()
    end
    win:maximize()
    return self
end

--- WindowManager:restoreWindow() -> self
--- Method
--- Restore the focused window: drop out of native full screen if it is in it,
--- otherwise put it back to the frame saved by `maximizeWindow`.
---
--- Returns:
---  * The WindowManager object
function obj:restoreWindow()
    local win = hs.window.focusedWindow()
    if not win then return self end

    if win:isFullScreen() then
        win:setFullScreen(false)
        return self
    end

    local id = win:id()
    local frame = id and self._savedFrames[id]
    if frame then
        win:setFrame(frame)
        self._savedFrames[id] = nil
    end
    return self
end

--- WindowManager:toggleMaximize() -> self
--- Method
--- Toggle the focused window between maximized and its previous size: maximize
--- it if it is not currently maximized (or full screen), otherwise restore it.
--- Uses the frame saved by `maximizeWindow`, and exits native full screen if the
--- window is in it.
---
--- Returns:
---  * The WindowManager object
function obj:toggleMaximize()
    local win = hs.window.focusedWindow()
    if not win then return self end

    local id = win:id()
    if win:isFullScreen() or (id and self._savedFrames[id]) then
        self:restoreWindow()
    else
        self:maximizeWindow()
    end
    return self
end

--- WindowManager:fullscreenWindow() -> self
--- Method
--- Put the focused window into native macOS full screen.
---
--- Returns:
---  * The WindowManager object
function obj:fullscreenWindow()
    local win = hs.window.focusedWindow()
    if not win then return self end
    win:setFullScreen(true)
    return self
end

--- WindowManager:minimizeWindow() -> self
--- Method
--- Minimize the focused window to the Dock. This is one-way: macOS gives a
--- minimized window no focus, so there is no reliable target to un-minimize from
--- a hotkey (click it in the Dock, or use the app's window menu, to bring back).
---
--- Returns:
---  * The WindowManager object
function obj:minimizeWindow()
    local win = hs.window.focusedWindow()
    if not win then return self end
    win:minimize()
    return self
end

-- Resolve a hotkey spec ({ mods, key }) for `action` from the bound mapping,
-- falling back to the default.
local function hotkeySpec(self, action)
    local map = self._hotkeys or {}
    return map[action] or self.defaultHotkeys[action]
end

--- WindowManager:bindHotkeys(mapping) -> self
--- Method
--- Binds hotkeys for WindowManager.
---
--- Parameters:
---  * mapping - A table with any of the keys `moveWest`, `moveEast`, `moveNorth`,
---    `moveSouth`, `toggleMaximize`, `maximize`, `restore`, `minimize`,
---    `fullscreen`, each a `{ mods, key }` pair (e.g. `{ {"ctrl","cmd"}, "l" }`).
---    Missing keys fall back to `WindowManager.defaultHotkeys` (which binds
---    `toggleMaximize`, not the separate `maximize` / `restore`).
---
--- Returns:
---  * The WindowManager object
function obj:bindHotkeys(mapping)
    self._hotkeys = mapping or {}

    -- Rebind cleanly if called more than once.
    if self._boundHotkeys then
        for _, k in ipairs(self._boundHotkeys) do k:delete() end
    end

    local actions = {
        moveWest       = function() self:moveWindowToScreen("west") end,
        moveEast       = function() self:moveWindowToScreen("east") end,
        moveNorth      = function() self:moveWindowToScreen("north") end,
        moveSouth      = function() self:moveWindowToScreen("south") end,
        toggleMaximize = function() self:toggleMaximize() end,
        maximize       = function() self:maximizeWindow() end,
        restore        = function() self:restoreWindow() end,
        minimize       = function() self:minimizeWindow() end,
        fullscreen     = function() self:fullscreenWindow() end,
    }

    self._boundHotkeys = {}
    for action, fn in pairs(actions) do
        local spec = hotkeySpec(self, action)
        if spec then
            self._boundHotkeys[#self._boundHotkeys + 1] = hs.hotkey.bind(spec[1], spec[2], fn)
        end
    end
    return self
end

return obj
