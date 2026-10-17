# Getting started

Tomato UI is loaded with one `loadstring` call. The file ends with `return Library`, so keep the `local Library =` part.

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/smilemssz/tomato-ui/refs/heads/main/main.lua"))()
```

## CreateWindow

```lua
local Window = Library:CreateWindow({
    Name = "Tomato",
    Accent = Color3.fromRGB(255, 99, 71),
    Hotkey = Enum.KeyCode.RightShift,
})
```

`Window:AddPage` returns a **page UI**. Every component is a method of a page UI.

::: tip
Callbacks are protected. If your callback errors, the [Error Log](/systems/error-log) opens instead of your script stopping.
:::

## Where to go next

- [Core concepts](/guide/concepts): modes, stacking, Nudge, the Hub.
- [Components](/components/): every tag with parameters and options.
- [Systems](/systems/instance-guard): Instance Guard, Whitelist, Key system, Cookies.
