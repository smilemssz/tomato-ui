# Buttons

## Button

```lua
Page:Button(text, callback, opts)
```

`opts` can be a `Color3` (button color) or a table:

| Option | Description |
|---|---|
| `Color` | Button color. |
| `Icon` | `lucide:name` icon shown at the left. |
| `Round` | Corner radius 0 to 15. |
| `Lock`, `LockKey` | See [Lock](/guide/common-options#lock). |

Object: `SetText(text)`.

## Buttons

Two to three buttons in one row.

```lua
local objs = Page:Buttons({
    { Text = "A", Callback = function() print("A") end },
    { Text = "B", Callback = function() print("B") end, Color = Color3.fromRGB(80, 200, 120) },
    { Text = "C", Callback = function() print("C") end, LockKey = "1234", Round = 8 },
})
```

Each item accepts `Text`, `Callback`, `Color`, `Round`, `Lock` and `LockKey`. It returns an array of button objects with `SetText` and the lock methods.

## ImageButton

```lua
Page:ImageButton(image, text, callback, opts)
```

- `text` may be `nil` for an image-only centered button.
- `opts.Height` (default 28), `Round`, `Lock`, `LockKey`.

Object: `SetImage(image)`.

## ButtonHold

Press and hold to confirm.

```lua
Page:ButtonHold(text, callback, opts)
```

| Option | Description |
|---|---|
| `Duration` | Seconds to hold. Default: the last stage time, or 1.5. |
| `Color` | Fill color before the first stage. |
| `Stages` | Array of `{ Time, Color }`. The fill takes the color of the latest stage whose `Time` was reached. |
| `Round`, `Lock`, `LockKey` | Common options. |

```lua
Main:ButtonHold("Hold to delete", function() print("deleted") end, {
    Stages = {
        { Time = 1, Color = Color3.fromRGB(255, 200, 0) },
        { Time = 2, Color = Color3.fromRGB(255, 120, 0) },
        { Time = 3, Color = Color3.fromRGB(255, 40, 40) },
    },
})
```

Releasing early cancels. The callback runs only after the full duration. Object: `SetText(text)`.

## Copy

A label with a Copy button.

```lua
Page:Copy(text, source, opts)
```

- `source`: a string, or a function returning a string (evaluated when pressed).
- `opts.ButtonText` (default `Copy`), `opts.OnCopy` (`function(text)`), `Round`, `Lock`, `LockKey`.
- Shows `Copied` or `No clipboard` when the executor has no `setclipboard`.

Object: `Set(source)`, `Get()` (current text).
