# Text and layout

## Section

```lua
Page:Section(text)
```

Colored heading. It follows the main color automatically.

## Label

```lua
local l = Page:Label(text)
l:Set("new text")
```

Multi-line gray text.

## Divider

```lua
Page:Divider()
```

A 1 px separator line.

## Image

```lua
Page:Image(image, height, opts)
```

- `image`: asset id, digit string, url or `lucide:name`.
- `height`: pixels (default 80).
- `opts.Crop`: `true` fills the frame.
- `opts.Round`: corner radius 0 to 15.
- `opts.Color`: tint color.
- `opts.Background`: `true` adds a row background.

Object: `Set(image)`.

```lua
Main:Image(15175519385, 70, { Round = 8, Background = true })
```
