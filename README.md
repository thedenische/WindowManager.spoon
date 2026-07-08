# WindowManager.spoon

A small Hammerspoon [Spoon](https://www.hammerspoon.org/Spoons/) for window
management: move the focused window between monitors (handling native full
screen), maximize / restore it, or push it to full screen.

`moveWindowToScreen` moves the focused window to the monitor physically adjacent
in a given direction (`"east"` / `"west"` / `"north"` / `"south"`), so the move
follows the display layout instead of an arbitrary ordering. If the window is in
native full screen it is briefly taken out of full screen, moved, then put
back — so full-screen windows follow you across displays instead of refusing to
move. `maximizeWindow` remembers the window's frame first so `restoreWindow` can
put it back exactly where it was.

## Requirements

- [Hammerspoon](https://www.hammerspoon.org/)

## Installation

Clone into `~/.config/hammerspoon/Spoons/`:

```sh
git clone https://github.com/thedenische/WindowManager.spoon.git \
  ~/.config/hammerspoon/Spoons/WindowManager.spoon
```

## Usage

In your `~/.config/hammerspoon/init.lua`, the minimal setup binds every action
with the default vim-style hotkeys (`ctrl+cmd+H/J/K/L` move the window to the
monitor west / south / north / east, `ctrl+cmd+M` toggles maximize/restore,
`ctrl+cmd+N` minimize, `ctrl+cmd+F` full screen):

```lua
hs.loadSpoon("WindowManager")
spoon.WindowManager:bindHotkeys() -- uses WindowManager.defaultHotkeys
```

To customise, pass your own hotkeys (any subset — missing actions fall back to
`WindowManager.defaultHotkeys`). `maximize` and `restore` are available as
separate actions if you prefer dedicated keys over the single `toggleMaximize`:

```lua
hs.loadSpoon("WindowManager")
spoon.WindowManager:bindHotkeys({
  moveWest       = { { "ctrl", "cmd" }, "h" },
  moveSouth      = { { "ctrl", "cmd" }, "j" },
  moveNorth      = { { "ctrl", "cmd" }, "k" },
  moveEast       = { { "ctrl", "cmd" }, "l" },
  toggleMaximize = { { "ctrl", "cmd" }, "m" },
  minimize       = { { "ctrl", "cmd" }, "n" },
  -- maximize    = { { "ctrl", "cmd" }, "," }, -- optional dedicated keys
  -- restore     = { { "ctrl", "cmd" }, "." },
  fullscreen     = { { "ctrl", "cmd" }, "f" },
})
```

### Called directly (e.g. from Hammerflow)

The methods can be wired into another Spoon instead of hotkeys:

```lua
hs.loadSpoon("WindowManager")
local wm = spoon.WindowManager

spoon.Hammerflow.registerFunctions({
  moveWindowToWestScreen  = function() wm:moveWindowToScreen("west") end,
  moveWindowToEastScreen  = function() wm:moveWindowToScreen("east") end,
  moveWindowToNorthScreen = function() wm:moveWindowToScreen("north") end,
  moveWindowToSouthScreen = function() wm:moveWindowToScreen("south") end,
  maximizeWindow          = function() wm:maximizeWindow() end,
  restoreWindow           = function() wm:restoreWindow() end,
  fullscreenWindow        = function() wm:fullscreenWindow() end,
})
```

## Controls (default hotkeys)

| Action           | Default        | Effect                                       |
| ---------------- | -------------- | -------------------------------------------- |
| `moveWest`       | `ctrl+cmd+H`   | Move window to the monitor on the left       |
| `moveSouth`      | `ctrl+cmd+J`   | Move window to the monitor below             |
| `moveNorth`      | `ctrl+cmd+K`   | Move window to the monitor above             |
| `moveEast`       | `ctrl+cmd+L`   | Move window to the monitor on the right      |
| `toggleMaximize` | `ctrl+cmd+M`   | Toggle maximize / restore (exits full screen)|
| `minimize`       | `ctrl+cmd+N`   | Minimize the window to the Dock              |
| `fullscreen`     | `ctrl+cmd+F`   | Enter native macOS full screen               |

`maximize` and `restore` are also bindable as separate actions (no default key)
if you prefer them split rather than toggled.

## API

- `spoon.WindowManager:moveWindowToScreen(direction)` — `"east"` / `"west"` /
  `"north"` / `"south"` (physical monitor layout, no wrap-around).
- `spoon.WindowManager:toggleMaximize()` — maximize, or restore if already
  maximized / full screen.
- `spoon.WindowManager:maximizeWindow()` / `:restoreWindow()`.
- `spoon.WindowManager:minimizeWindow()` — minimize to the Dock (one-way).
- `spoon.WindowManager:fullscreenWindow()`.
- `spoon.WindowManager:bindHotkeys(mapping)` — bind any subset of
  `moveWest` / `moveEast` / `moveNorth` / `moveSouth` / `toggleMaximize` /
  `maximize` / `restore` / `minimize` / `fullscreen`.

## Known limitations

- **Moving a full-screen window relies on fixed timing.** macOS animates the
  exit from native full screen, so `moveWindowToScreen` waits a fixed delay
  before moving the window and re-entering full screen on the target display.
  With "Reduce motion" enabled, on slow machines, or if the animation timing
  changes, the move can occasionally misfire. The call also returns immediately
  while this finishes asynchronously.
- **Restore uses the frame captured at maximize time.** If you maximize a window
  and then move it to another display before restoring, it is restored to the
  original display's coordinates. Saved frames are keyed by window id and pruned
  when their window no longer exists, so closing a maximized window without
  restoring it does not leak.

## License

[MIT](./LICENSE)
