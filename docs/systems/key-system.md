# Key system

```lua
local passed = Library:KeySystem({
    Name = "Tomato",
    Description = "Enter your key",
    Url = "https://example.com/getkey",
    GetKeyText = "getkey",
    CheckText = "Check Key",
    Keys = { "KEY-1" },              -- or Key = "..." or Validate = function(key) return true end
    SaveFile = "tomato_key.txt",     -- remember a valid key (needs executor file functions)
    OnSuccess = function(key) end,
    OnClose = function() end,
})
if not passed then return end
```

| Option | Description |
|---|---|
| `Url` | Link to get a key. The getkey button copies it, and it is also shown in a selectable box. |
| `GetKeyText` | Text of the get-key button (default `getkey`). |
| `CheckText` | Text of the check button (default `Check Key`). |
| `Key`, `Keys`, `Validate` | A key, an array of keys, or a function that returns a boolean. |
| `SaveFile` | File used to remember a valid key. |
| `Accent`, `WrongText`, `GetKeyCallback` | Color, wrong-key message, and a function run when getkey is pressed. |

The function waits until finished. It returns `true` for a valid key and `false` if the window was closed. Pressing Enter in the key box checks the key, and a wrong key shakes the window.
