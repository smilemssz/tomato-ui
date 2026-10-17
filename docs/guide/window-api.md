# Window API

| Method | Description |
|---|---|
| `AddPage(name, icon)` | New tab. `icon` is optional (`lucide:home`, an asset id or a url). Returns the page UI. |
| `Notify(...)` | Toast. See [Popups and notifications](/guide/popups#notify). |
| `Dialog(opts)`, `Confirm(...)`, `Prompt(...)` | Modal dialogs. See [Popups](/guide/popups#dialog-confirm-prompt). |
| `Popup(opts)` | Popup inside the window body. |
| `PopupWindow(opts)` | Draggable Windows-style dialog. |
| `Log(message)` | Add a message to the Error Log and open it. |
| `GetMode()` | `dock`, `window` or `edge`. |
| `OnModeChanged(fn)` | `fn(mode)` on every mode change. Returns an object with `Disconnect`. |
| `On(topic, fn)` | Receive messages. `fn(from, ...)`. |
| `Send(target, topic, ...)` | Message one window by name. |
| `Broadcast(topic, ...)` | Message every other window. |
| `Expose(name, fn)` | Publish a function. `fn(from, ...)`. |
| `Invoke(target, name, ...)` | Call a published function. Returns `ok, result...`. |
| `List()` | Names of the other windows. |
| `SetShared(key, value)`, `GetShared(key)`, `OnShared(key, fn)` | Values shared by all windows. |
| `Cookies()` | The [cookie store](/systems/cookies) of this window. |

::: warning
The main Settings page belongs to the library. User scripts have no API to change its hotkey, color or Kill UI.
:::

## Library API

| Method | Description |
|---|---|
| `Library:CreateWindow(config)` | Create a window. |
| `Library:KeySystem(cfg)` | [Key screen](/systems/key-system). |
| `Library:Whitelist(cfg)` | [User and game whitelist](/systems/whitelist). |
| `Library:Cookies(name, persistent)` | [Saved data store](/systems/cookies). |
| `Library:Protect(fn, ...)` | Run your code under error protection. |
| `Library:LogError(tag, err)`, `Library:ShowLog()` | Record an error, open the [Error Log](/systems/error-log). |
| `Library:SetIconSource(src)`, `Library:GetIcon(name, size)`, `Library:IconNames()` | [Icons](/guide/icons). |
| `Library:GetWindows()` | Names of all open windows in the family. |
