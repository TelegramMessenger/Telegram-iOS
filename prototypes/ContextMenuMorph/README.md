# Custom context menu morph prototype

Standalone UIKit app using custom buttons and menu rows. No `UIMenu` or `UIContextMenuInteraction`. It compiles the same `LiquidMorphTransition.swift`, Objective-C runtime bridge, and source-decoration lease used by Telegram.

Generate/open:

```sh
xcodegen generate --spec prototypes/ContextMenuMorph/project.yml
open prototypes/ContextMenuMorph/ContextMenuMorph.xcodeproj
```

Choose `ContextMenuMorph`, an iOS 26+ simulator, and Run. Tap a shape to open its custom menu; any menu row dismisses. **Run shape + interruption checks** exercises 18 round trips across circle, capsule, square, wide, tall, and asymmetric shapes. Every cycle checks source parent/visibility and menu parent after UIKit cleanup. Twelve cycles request dismissal before presentation completes; the close takes over the running morph at once, as in Telegram.

Run the `ContextMenuMorph` scheme's tests to check real native round-trip completion, hierarchy/frame restoration, concurrent-request rejection, removal from the window before starting, and cropped/transformed source geometry. The tests also support the Release configuration. Reduced Motion is read from the simulator's actual accessibility setting.

The generated Xcode project is ignored by the repository; `project.yml` is the source of truth. No third-party package dependencies or signing are required for Simulator.

Implementation evidence and validation are in `docs/context-menu-liquid-morph.md`.

The production Telegram gallery also accepts `--context-menu-morph-overlap` (together with `--context-menu-morph-gallery`) to reopen one profile-style composite source 150 ms into dismissal. It verifies that an older menu cannot reveal the new menu's backdrop and that the final dismissal restores it.

Profile sources now lease live foreground views and a matching live backdrop instead of capturing UIImage previews. The current-content pixel regression verifies that updates while open remain visible at full brightness; extraction is shared across overlapping menus. Production gallery cases additionally exercise ASDisplayNode reparenting and verify foreground restoration.
