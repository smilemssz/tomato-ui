# Text input

## Textbox

```lua
Page:Textbox(text, placeholder, callback, opts)
```

Label on the left, input on the right. `callback(text, enterPressed)` runs when focus is lost.

## TextboxFull

An input only. No label, it fills the whole row, single line.

```lua
Page:TextboxFull(placeholder, callback, opts)
```

| Option | Description |
|---|---|
| `Text` | Initial text. |
| `Live` | `true` runs the callback on every change. |
| `Round`, `Lock`, `LockKey`, `Save` | Common options. |

## Input

A full-width input with a label above.

```lua
Page:Input(text, placeholder, callback, opts)
```

| Option | Description |
|---|---|
| `MultiLine` | Allow several lines. |
| `Height` | Box height in pixels. |
| `Live` | Callback on every change. |
| `Round`, `Lock`, `LockKey`, `Save` | Common options. |

## CodeEditor

A monospace editor with line numbers and a toolbar (Copy, Clear and an optional Run).

```lua
Page:CodeEditor(text, default, callback, opts)
```

| Option | Description |
|---|---|
| `Height` | Editor height (default 120). |
| `ReadOnly` | Disable editing. |
| `Run` | Show a Run button that executes the text with `loadstring`. Errors go to the [Error Log](/systems/error-log). |
| `Live` | Callback on every change. |
| `Placeholder` | Placeholder text. |
| `Round`, `Lock`, `LockKey`, `Save` | Common options. |

Object: `Get()`, `Set(text)`, `Run()`. There is no syntax highlighting.

```lua
local ed = Main:CodeEditor("Script", "print('hello')", nil, { Height = 100, Run = true })
```

::: tip
Text inputs restore a saved value without calling the callback. See [Save](/guide/common-options#save).
:::
