# Troubleshooting

| Problem | Fix |
|---|---|
| `attempt to index nil with 'CreateWindow'` | You forgot `local Library =` before `loadstring(...)()`. |
| Nothing happens, or a popup shows errors | Read the [Error Log](/systems/error-log). Select the text and Copy. Errors in callbacks never stop the rest of your script. |
| Icons are blank | The icon module could not be downloaded, or the name is wrong. Check the Error Log or call `Library:SetIconSource(...)`. |
| Copy says `No clipboard` | The executor has no `setclipboard`. Select the text manually where a box is shown. |
| Settings do not persist | The executor has no file functions. Check `Window:Cookies().Persistent`. |
| A window cannot be created | [Instance Guard](/systems/instance-guard) refused it. Check the returned `reason`. |
| Stacking does not work | Only collapsed Dock windows stack, up to 6 layers. Drag a collapsed window up close to another collapsed window. |
| Odd layout with several windows | Windows from older versions do not take part in 2.3 features. Use one version for all windows. |

::: warning
The Whitelist is not secure against someone who edits the script.
:::

Input positions assume the default `IgnoreGuiInset` of the ScreenGui. The library does not change it.
