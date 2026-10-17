# Cookies

Saves data on the user's device in `TomatoUI/name.json` (needs `writefile`, `readfile` and `isfile`). Without file functions the data stays in memory for the session and `store.Persistent` is `false`.

```lua
local store = Library:Cookies("MyScript")   -- or Window:Cookies()
store:Set("coins", 10)
print(store:Get("coins", 0))
store:Delete("coins")
store:Clear()
print(store:Keys(), store:All(), store.Persistent, store.Path)
store:Save()   -- optional: writes are also saved automatically after 0.5 s
```

| Method | Description |
|---|---|
| `Get(key, default)` | Read a value. |
| `Set(key, value)` | Write a value (`nil` deletes it). |
| `Delete(key)`, `Clear()` | Remove one key or everything. |
| `Keys()`, `All()` | List keys, or copy all data. |
| `Save()` | Write now. |

## Supported types

Numbers, strings, booleans, tables of those, `Color3`, `Vector2`, `Vector3` and `EnumItem` (for example a KeyCode). Other types are skipped.

## Saving components

Components can save themselves with the `Save` option. See [Lock, Round and Save](/guide/common-options#save).

`CreateWindow({ Cookies = false })` keeps everything in memory. `Cookies = "name"` uses a custom file name. Settings > System has a **Clear saved data** button.
