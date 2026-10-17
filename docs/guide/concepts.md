# Core concepts

## Window and pages

`Library:CreateWindow` returns a **Window**. `Window:AddPage(name, icon)` returns a **page UI** with all component methods. `Box`, `ScrollBox`, `Popup` and `PopupWindow` return their own sub UI with the same component methods.

## Modes

The mode button on the title bar switches modes. `Window:GetMode()` returns the current name.

| Mode | Name in code | Description |
|---|---|---|
| Dock | `dock` | Bottom-right of the screen. Drag horizontally. This is the start mode. |
| Window | `window` | Floating window. Drag anywhere and resize from any of the 4 corners. Each mode remembers its last position. |
| Edge | `edge` | Release a dragged Window at a screen edge. The window shrinks (25%), dims, and a strip sticks out. Tap it to return to Window mode. |

## Proximity stacking

Stacking works only for **collapsed windows in Dock mode**. Window and Edge never stack.

1. Collapse a Dock window with the arrow button.
2. Drag its title bar **up** until it is close to another collapsed window or an existing stack.
3. Release. It snaps on top of that stack as a new layer.

Rules:

- A stack holds at most **6 layers**. The bottom layer is the leader.
- If nothing is nearby when you release, the window is not pulled anywhere and drops back to the bottom.
- Dragging the leader moves the whole stack horizontally.
- Pull a layer away from the stack to detach it.
- Expanding a layer, switching mode, or turning off **Stack in Dock** removes it from the stack.
- Disable it per window with `Stack = false` in [CreateWindow](/guide/config).

## Nudge

Windows from the 2.2+ family never close each other. A new window takes the right-most Dock column and pushes older Dock windows to the left. A duplicate name becomes `Name (2)`, `Name (3)` and so on. See [Instance Guard](/systems/instance-guard) for other behaviors.

## Hub

All 2.2+ windows share a global hub, so they can message each other even when loaded from different scripts. See [Cross-window communication](/guide/hub).
