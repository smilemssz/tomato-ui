# CreateWindow config

```lua
local Window, reason = Library:CreateWindow(config)
```

Returns the window. If the window is refused (see [Instance Guard](/systems/instance-guard)) or creation fails, it returns a safe empty object that accepts any call without errors, plus a `reason` string.

| Key | Type | Default | Description |
|---|---|---|---|
| `Name` | string | `UI` | Title and window id. Also the default cookie file name. |
| `Accent` | Color3 | tomato red | Main color. Changeable in Settings > Theme. |
| `Hotkey` | KeyCode | `RightShift` | Hide and show key. |
| `OnKill` | function | nil | Called on Kill UI. Clean up your loops here. |
| `NotifyDuration` | number | `3` | Default toast time in seconds. |
| `CatchAllErrors` | boolean | `false` | Send every `ScriptContext.Error` to the Error Log. |
| `Stack` | boolean | `true` | Allow proximity stacking in Dock mode. |
| `WindowRound` | number | `0` | Corner radius (0 to 15) in Window mode. |
| `Whitelist` | table | nil | Same table as [`Library:Whitelist`](/systems/whitelist). The window is not created when denied. |
| `Instance` | string | `multi` | `multi`, `unique` or `exclusive`. See [Instance Guard](/systems/instance-guard). |
| `OnRefused` | function | nil | `function(reason, name)` called when Instance Guard refuses. |
| `Cookies` | boolean or string | `true` | `false` keeps data in memory only. A string sets a custom cookie file name. |

## Return reasons

| Reason | Meaning |
|---|---|
| `whitelist` | The whitelist denied the user or game. |
| `duplicate` | `Instance = "unique"` and the name is already open. |
| `exclusive` | An exclusive window is open. |
| `error` | Creation failed. The Error Log has details. |
