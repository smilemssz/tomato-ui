# Icons (Lucide)

Anywhere an image is accepted you can write `lucide:icon-name`, for example `lucide:home` or `lucide:settings`.

Supported in: the `AddPage` icon, `Image`, `ImageButton`, `Button` (`Icon` option), `PopupWindow` (`Icon` option) and the page lock icon.

The icon module is loaded on first use from the [latte-soft/lucide-roblox](https://github.com/latte-soft/lucide-roblox) release. If loading fails, an entry is added to the [Error Log](/systems/error-log) and the UI keeps working.

| Function | Description |
|---|---|
| `Library:SetIconSource(urlOrModule)` | Use another url, or a loaded module that has `GetAsset`. |
| `Library:GetIcon(name, size)` | Returns the asset table (`Url`, `ImageRectOffset`, `ImageRectSize`) or nil. |
| `Library:IconNames()` | Array of available icon names. |

::: warning
The upstream icon repository is archived, so icons added to Lucide after its last release will not appear.
:::
