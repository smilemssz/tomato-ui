# Popups and notifications

## Popup (body popup)

`Window:Popup(opts)` or `Page:Popup(opts)`: a card centered over the page area. The tab bar stays usable.

| Option | Default | Description |
|---|---|---|
| `Title` | empty | Card title. |
| `Height` | `140` | Card height. |
| `Width` | page width | Card width in pixels. |
| `Closable` | `true` | `false` hides the X and disables tapping outside. |
| `Round` | off | Corner radius 0 to 15. |

It returns a sub UI with `Open()`, `Close()`, `Toggle()` and `IsOpen()`.

```lua
local pop = Window:Popup({ Title = "Options", Height = 120 })
pop:Toggle("Option A", true, print)
pop:Button("Close", function() pop:Close() end)
Main:Button("Open", function() pop:Open() end)
```

## PopupWindow (draggable)

`Window:PopupWindow(opts)`: a Windows-style dialog with a title bar, icon and X. It is draggable, stays inside the screen, comes to the front when clicked, and several can be open at once.

| Option | Default | Description |
|---|---|---|
| `Title`, `Icon`, `Text` | empty | Title, `lucide:name` or asset icon, body text. |
| `Width`, `Height` | `240`, `170` | Size in pixels. |
| `Position` | centered | `Vector2` start position. |
| `Closable` | `true` | Show the X button. |
| `Round` | off | Corner radius 0 to 15. |
| `Buttons` | none | Array of `{ Text, Callback, Primary, Color, Keep }`. Each press closes the window unless `Keep` is true. |

It returns a sub UI with `Open()`, `Close()`, `Toggle()`, `IsOpen()` and `SetTitle(text)`.

```lua
local pw = Window:PopupWindow({
    Title = "Settings", Icon = "lucide:sliders-horizontal",
    Text = "Drag the title bar to move me.",
    Buttons = { { Text = "Close" }, { Text = "Save", Primary = true, Callback = function() print("saved") end } },
})
pw:Toggle("Option A", true, print)
pw:Open()
```

## Dialog, Confirm, Prompt

- `Window:Dialog({ title, text, input, default, buttons, dismissable })`: modal with a dim background. `input` (a placeholder string) adds a text field. `buttons` is an array of `{ text, primary, color, callback }`, and callbacks receive the input text.
- `Window:Confirm(title, text, onYes, onNo)`.
- `Window:Prompt(title, text, placeholder, onSubmit)`: `onSubmit(text)`.

Only one Dialog is shown at a time.

## Notify

```lua
Window:Notify("Title", "Text", 3, "success")   -- info, success, warn or error

Window:Notify({
    Title = "Update", Text = "New version",
    Duration = 0,                              -- 0 stays until dismissed
    Color = Color3.fromRGB(80, 160, 255),
    Buttons = { { Text = "OK" }, { Text = "View", Callback = function() end } },
})
```

- Timed toasts show a countdown bar. Without buttons, tapping the toast dismisses it.
- At most 4 toasts are visible. The oldest is dismissed first.
- It returns an object with `Dismiss()`.
