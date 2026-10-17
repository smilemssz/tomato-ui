# Whitelist

```lua
local allowed, reason = Library:Whitelist({
    Users = { 123456, { Id = 789, Games = { 1818 } } },
    Games = { 1818, 2788229376 },
    OnWrongGame = "https://example.com/other_game_script.lua",
    OnDenied = function(reason) print("denied", reason) end,
})
if not allowed then return end
```

| Key | Description |
|---|---|
| `Users` | Optional. Array of user ids. A table entry `{ Id, Games }` limits that user to the listed games. Omit it to allow every user. |
| `Games` | Optional. Place ids or game (universe) ids. Omit it to allow every game. |
| `OnWrongGame` | A url (loaded and run) or `function(reason)`. Runs when the game is not in `Games`. |
| `OnDenied` | A url or `function(reason)`. Runs when the user is not allowed. |

The game is checked first (against `game.PlaceId` and `game.GameId`), then the user (`LocalPlayer.UserId`).

Returns `true, "ok"`, or `false, "game"`, or `false, "user"`.

You can also pass the same table as `Whitelist` in [`CreateWindow`](/guide/config).

::: warning
This is a client-side check. It keeps honest users out but is not tamper-proof.
:::
