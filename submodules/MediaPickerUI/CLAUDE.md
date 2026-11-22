# MediaPickerUI

## Grid seam and MediaGrid v2

`MediaPickerScreenImpl.Node` talks to its grid only through `MediaPickerGridHost` (`Sources/MediaPickerGridHost.swift`).
Two hosts, chosen once when the controller is created:

- `MediaPickerGridNodeHost`: the old `GridNode` path, a verbatim forward of the code it replaced. Every protocol member
  added for the new host has a GridNode implementation equal to the expression it replaced (`scrollingTag`,
  `isCameraPreviewVisible`, `cameraFrame`, `updateItemsSelectionState`, …); keep it that way.
- `MediaPickerMediaGridHost` (`Sources/MediaPickerMediaGridHost.swift`): the layer grid
  (`submodules/TelegramUI/Components/MediaGrid`), with cells in `MediaPickerGridCellLayer` and the decisions (badges,
  order numbers, routing, album configuration) in the pure `MediaPickerGridCellDecorations.swift`, tested on the host by
  `//submodules/MediaPickerUI:MediaPickerGridCellDecorationsTests`.

**Routing.** Every mode uses the new host when `context.usesMediaPickerGridV2`
(`AccountContext/Sources/MediaPickerGridV2.swift`): the app-config key `ios_killswitch_disable_media_grid_v2` or Debug
Settings ▸ "Media picker: legacy grid" puts every mode back on `GridNode`. The flag is read in `init`, so each picker
open uses the then-current value. `mediaPickerGridModeKind` / `mediaPickerGridModeConfiguration` decide per mode:

- `.chatAttachment` (`.assets(_, .default)` without `forCollage`: the chat attachment menu, the story-reply attachment
  menu, an album pushed from it): zoom (pinch, menu, tap) on, so levels 1–31 and the compact-level bar; camera at 3 only.
- `.story` (`.assets(_, .story)`, `forCollage` too): zoom off, cells `cellAspect` 1.227 (the old
  `itemWidth * 1.227`), landscape photos aspect-fit over a gradient from their colours (`fitAspect` in the cell state,
  gradients cached by identifier in the host), story drafts prepended.
- `.other` (avatar, sticker, wallpaper, add image, cover, QR code, poll, rich text, files, passport, `.media`): zoom off.

With zoom off the grid stays at 3 (portrait) or 5 (landscape) and the camera cell shows at both (`cameraLevels`), as
the old cutout did. Download rings (`AssetDownloadManager`, iCloud assets fetched before `customSelection`) are drawn
in every mode but `.chatAttachment` as `RadialStatusNode`s in the grid's `overlayView`, one progress subscription per
visible asset; a tap on a downloading cell cancels it. Checks and pan-to-select follow `gridAllowsSelection`
(`.default`, `.files(false)`, `.passport(true)`, `.media`, or `explicitMultipleSelection`, which the story Select
button turns on at runtime). The avatar preview is MediaGrid's `accessoryView` (one reserved slot right of the camera,
or first without one); `setAccessoryView` / `updateAccessoryFrame` keep the GridNode path's frame code unchanged.

**Data.** The new host does not consume `MediaPickerGridEntry` transactions (`consumesEntries == false`): `updateState`
hands it the fetch result, a `MediaPickerGridAssetsConfiguration` (Recents reversed and driving the filler; a
menu-selected album reversed, as the old path does, without the filler; a pushed album unreversed and starting at its
end; a type-filtered fetch, e.g. images only for wallpaper or stickers, never drives the filler, since its catalog would
call every video an orphan) and the extras: story drafts, or for `.media` the pasted items with no fetch result at all.
`MediaPickerMediaGridDataSource` serves extras at indices `0 ..< extras.count` and the fetch result after them
(`mediaPickerGridSlot`); asset changes, thumbnail ranges and caching indices are shifted by the extras count, and a
change of the extras is applied as a replaced prefix. Extras' images are the draft thumbnail or the pasted image
(an edited thumbnail wins, as for assets); a draft shows "Draft", a video icon and duration, no check, and its tap calls
`openDraft`. One `MediaGridPhotoLibraryDataSource` exists at a time; an album switch replaces the grid and keeps the
level. Library changes reach the grid through the data source's own PHChange observer, not the picker's state.

**Selection** stays in `TGMediaSelectionContext`, read by identifier; order numbers come from
`selectedItemsIdentifiers`. Pan-to-select is MediaGrid's gesture; its begin cancels the attachment container's pan.

**Attachment container.** `MediaPickerMediaGridContainerView` adopts `AttachmentScrollableContent` (AttachmentUI), which
the container finds when the nearest content in the hit-test chain is not a scroll view; the scroll-view path is
unchanged. A pinch on the grid never moves the sheet by itself; the start of any zoom (pinch, menu, tap) asks the attachment menu to expand (`zoomingStarted` → `requestAttachmentMenuExpansion`, a no-op when it is already expanded or tracking).

**Transitions.** `transitionView(snapshot: false)` returns the cell's proxy view in the grid's `overlayView` (in the
hierarchy, so the media editor can convert its bounds and add a view to its grandparent); `snapshot: true` a detached
snapshot. `defaultTransitionItem()` is the cell at index 0 (the GridNode path keeps `item(at: .zero)`).

**Known limits.** Edits and spoilers at levels 15 and 31 come only from what was cached at 1/3/5. A story's landscape
photo's gradient comes from whichever image the cell shows first, the 48 px thumbnail's slot during a fast scroll, and
is cached by identifier, so a later sharp image does not recompute it. A
pasted video (`.media`) has no image; the GridNode path showed no image for any pasted item. A draft has no check even
in a collage multi-selection (the old cell showed an inert one).
