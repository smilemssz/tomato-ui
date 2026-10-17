# Lock, Round and Save

Pass these in the `opts` table of a component. See the [support matrix](/components/#support-matrix) for which tags accept which option.

## Lock

| Option or method | Behavior |
|---|---|
| `Lock = true` | Locked from the start (dark overlay with `LOCKED`). |
| `LockKey = "key"` | Locked until the user enters the key. Accepts a string, a table of strings, or `function(input)` returning a boolean. |
| `obj:Lock()` or `obj:Lock("key")` | Lock from code, plain or key-protected. |
| `obj:Unlock()` | Unlock from code. |
| `obj:IsLocked()` | Current state. |

```lua
Main:Button("Premium", function() end, { LockKey = "abc123" })
local s = Main:Slider("Speed", 16, 100, 16, print)
s:Lock()      -- plain lock
s:Unlock()
```

## Round

`Round = 0` to `15` rounds the corners of a component. It is off when omitted and values above 15 are clamped to 15.

- It works on components only, never on the page body.
- The window itself can be rounded in Window mode with `WindowRound` or the Settings slider.

```lua
Main:Button("Rounded", print, { Round = 10 })
```

## Save

`Save = "key"` stores the value in the window's [cookies](/systems/cookies) and restores it the next time the same component is created.

```lua
Main:Toggle("Auto Farm", false, function(on) _G.farm = on end, { Save = "autofarm" })
```

- Restoring calls the component's `Set`, so value callbacks (Toggle, Slider, Stepper, Dropdown, ColorPicker, Segmented) run with the restored value.
- Text inputs (Textbox, TextboxFull, Input, CodeEditor) and Keybind restore their value without calling the callback.
- Use a unique key per component.
