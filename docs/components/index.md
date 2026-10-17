# Components

All components are methods of a page UI, for example `Main:Button(...)`. Unless noted, a component returns an object with `Get()` and `Set(value)`, plus `Frame`, `Wrap`, `Lock`, `Unlock` and `IsLocked` (see [Lock, Round and Save](/guide/common-options)).

| Group | Tags |
|---|---|
| [Text and layout](/components/text-layout) | Section, Label, Divider, Image |
| [Buttons](/components/buttons) | Button, Buttons, ImageButton, ButtonHold, Copy |
| [Switches and values](/components/values) | Toggle, Slider, Stepper, Progress, Segmented, Keybind |
| [Text input](/components/inputs) | Textbox, TextboxFull, Input, CodeEditor |
| [Pickers](/components/pickers) | Dropdown, ColorPicker |
| [Containers](/components/containers) | Box, ScrollBox, Popup |

## Support matrix

`Lock`, `Round` and `Save` refer to the `opts` options.

| Tag | Lock | Round | Save | Returns |
|---|:-:|:-:|:-:|---|
| Section | - | - | - | frame |
| Label | - | - | - | `Set` |
| Divider | - | - | - | frame |
| Image | - | yes | - | `Set` |
| Button | yes | yes | - | `SetText` |
| Buttons | yes (each) | yes (each) | - | array of objects |
| ImageButton | yes | yes | - | `SetImage` |
| ButtonHold | yes | yes | - | `SetText` |
| Copy | yes | yes | - | `Get`, `Set` |
| Toggle | yes | yes | yes | `Get`, `Set` |
| Slider | yes | yes | yes | `Get`, `Set` |
| Stepper | yes | yes | yes | `Get`, `Set` |
| Progress | - | yes | - | `Get`, `Set` |
| Segmented | yes | yes | yes | `Get`, `Set` |
| Keybind | yes | yes | yes | `Get`, `Set` |
| Textbox | yes | yes | yes | `Get`, `Set` |
| TextboxFull | yes | yes | yes | `Get`, `Set` |
| Input | yes | yes | yes | `Get`, `Set` |
| CodeEditor | yes | yes | yes | `Get`, `Set`, `Run` |
| Dropdown | yes | yes | yes | `Get`, `Set` |
| ColorPicker | yes | yes | yes | `Get`, `Set` |
| Box | - | yes | - | sub UI |
| ScrollBox | - | yes | - | sub UI |
| Popup | - | yes | - | sub UI with open and close |
| PopupWindow | - | yes | - | sub UI with open and close |

Mode support: stacking works only in Dock mode. Window supports resize and the window corner radius. Edge is entered only from Window.
