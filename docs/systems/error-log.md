# Error Log

A popup that appears automatically when `CreateWindow`, a callback, the key system, icons or cookies fail. It shows timestamped messages in a selectable box with **Copy**, **Clear** and **Close**.

| Function | Description |
|---|---|
| `Library:Protect(fn, ...)` | Run your own code under protection. Errors open the log. |
| `Library:ShowLog()` | Open the log manually. |
| `Library:LogError(tag, err)` | Add an entry. |
| `Window:Log(message)` | Add a message and open the log. |
| `Library.Logs` | The raw list of entries. |

```lua
Library:Protect(function()
    error("something went wrong")
end)
```

Set `CatchAllErrors = true` in [`CreateWindow`](/guide/config) to also record every game script error.
