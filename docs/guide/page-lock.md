# Page lock

Methods of a page UI:

```lua
page:LockPage({ Mode = "password", Password = "1234", Text = "Enter password" })
page:UnlockPage()
```

| Mode | Behavior |
|---|---|
| `block` | The tab cannot be opened and a notification explains why. If the page was open, another page is shown. |
| `overlay` | The tab opens, but a faint black layer with a lock icon covers the whole page. |
| `password` | Like `overlay`. Tap the lock: the icon moves up and a password prompt appears. A wrong password shakes the prompt. A correct password fades the overlay away. |

`Password` accepts a string, a table of strings, or `function(input)` returning a boolean.

```lua
local Vip = Window:AddPage("VIP", "lucide:crown")
Vip:Label("Secret content")
Vip:LockPage({ Mode = "password", Password = { "abc", "def" } })
```

The lock icon uses [Lucide](/guide/icons). If icons cannot load, the text `LOCKED` is shown instead.
