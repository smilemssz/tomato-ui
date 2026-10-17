# Containers

Containers return a **sub UI** that has all component methods.

## Box

A container like a div. It can be nested.

```lua
local box = Page:Box({ Title = "Group", Round = 8 })
box:Label("Inside the box")
box:Stepper("Count", 1, 10, 3, print)
```

| Option | Description |
|---|---|
| `Title` | Adds a Section at the top. |
| `Height` | Fixed height. When omitted the box grows with its content. |
| `Transparency` | Background transparency. |
| `Round` | Corner radius 0 to 15. |
| `NoStroke` | `true` removes the outline. |

Sub UI extras: `Frame` and `Wrap`. Use `sub.Wrap.Visible = false` to hide the whole box.

## ScrollBox

A fixed-height box with its own scrollbar.

```lua
local list = Page:ScrollBox(80, { Title = "Items" })
for i = 1, 8 do list:Button("Item " .. i, function() print(i) end) end
```

Options: `Title`, `Transparency`, `Round`.

## Popup

See [Popups and notifications](/guide/popups#popup-body-popup).
