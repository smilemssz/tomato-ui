# Instance Guard

Controls what happens when a window is created while another window is already open. Set `Instance` in [`CreateWindow`](/guide/config).

| Value | Behavior |
|---|---|
| `multi` (default) | Duplicates are allowed. A duplicate name becomes `Name (2)`. |
| `unique` | A window with the same `Name` may not be opened twice. The second call is refused and the existing window shows an "Already open" toast. |
| `exclusive` | While this window is open, no other 2.2+ window can be created, whatever its name. Closing it lifts the block. |

```lua
local Window, reason = Library:CreateWindow({
    Name = "Tomato",
    Instance = "unique",
    OnRefused = function(reason, name) print("refused", reason, name) end,
})
if reason then return end   -- "duplicate" or "exclusive"
```

When a window is refused, `CreateWindow` returns a safe empty object and the reason, so the rest of your script does not error.
