# Switches and values

## Toggle

```lua
Page:Toggle(text, default, callback, opts)
```

`callback(state)`. Object: `Get()`, `Set(bool)`.

## Slider

```lua
Page:Slider(text, min, max, default, callback, step, opts)
```

`callback(value)`. `step` defaults to 1. Page scrolling pauses while you drag. Object: `Get()`, `Set(n)`.

## Stepper

```lua
Page:Stepper(text, min, max, default, callback, step, opts)
```

Minus, value, plus. Object: `Get()`, `Set(n)`.

## Progress

```lua
Page:Progress(text, min, max, default, opts)
```

Animated score bar that shows a percent. Object: `Get()`, `Set(n)`. Only `Round` is supported in `opts`.

## Segmented

```lua
Page:Segmented(options, default, callback, opts)
```

An exclusive option row. `callback(option)`. Object: `Get()`, `Set(option)`.

## Keybind

```lua
Page:Keybind(text, default, callback, allowClear, opts)
```

- `callback(keyCode)` runs when the bound key is pressed.
- `allowClear = false` stops Esc from clearing the key.
- Object: `Get()`, `Set(keyCode)`.
