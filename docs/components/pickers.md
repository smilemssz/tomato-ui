# Pickers

## Dropdown

```lua
Page:Dropdown(text, options, default, callback, opts)
```

`options` is an array. The list floats on the top layer: it never pushes rows and is never clipped. Its maximum height is 112 px and it scrolls when longer. `callback(option)`. Object: `Get()`, `Set(option)`.

```lua
Tools:Dropdown("Mode", { "Easy", "Normal", "Hard" }, "Normal", print)
```

## ColorPicker

```lua
Page:ColorPicker(text, default, callback, opts)
```

A saturation and value box plus a hue bar in a floating panel. `callback(color3)`. Object: `Get()`, `Set(color3)`.
