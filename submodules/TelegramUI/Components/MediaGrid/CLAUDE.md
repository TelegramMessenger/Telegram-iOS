# MediaGrid

Standalone layer-based photo grid on CoreList's `PhysicsScrollEngine`. Zoom levels are 1, 3, 5, 15 and 31 photos per row.

The `.xcodeproj` is generated and untracked; edit `project.yml`. The `CoreList` framework target compiles `../CoreList/CoreListDemo` with the same excludes as `CoreList/BUILD`.

```sh
cd submodules/TelegramUI/Components/MediaGrid
xcodegen generate --quiet
SIM=4FAA8C5A-1B8A-4350-9627-917227146FA2
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" -parallel-testing-enabled NO test
xcodebuild -project MediaGrid.xcodeproj -scheme MediaGridDemo -destination "id=$SIM" build
```

Run only on the dedicated simulator `MediaGridDemo iPhone 18 Pro 27.0` (UDID above); never on the booted logged-in simulators.

Sources import only UIKit, QuartzCore, Foundation, Photos and CoreList. No Display, AsyncDisplayKit, SwiftSignalKit, Postbox, TelegramCore or LegacyComponents. APIs newer than iOS 13 need `#available` guards, since the sources also compile in the app.
