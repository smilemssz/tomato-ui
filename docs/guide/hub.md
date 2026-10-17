# Cross-window communication

Works between all 2.2+ windows, even when they were created by different scripts.

```lua
-- Window A
A:On("speed", function(from, value) print(from, value) end)
A:Expose("getScore", function(from) return 42 end)

-- Window B
B:Send("A", "speed", 50)                      -- to one window
B:Broadcast("hello", "everyone")              -- to all others
local ok, score = B:Invoke("A", "getScore")   -- ok = true, score = 42

-- Shared values
A:SetShared("theme", "dark")
B:OnShared("theme", function(value, from) print(value) end)
print(B:GetShared("theme"))
```

## Built-in topics

| Topic | Arguments |
|---|---|
| `WindowAdded` | `name` |
| `WindowRemoved` | `name` |
| `ModeChanged` | `name`, `mode` |

Handlers run in separate threads. `Invoke` returns `false, message` when the window or function does not exist. Window names are unique inside the hub (see [Nudge](/guide/concepts#nudge)).
