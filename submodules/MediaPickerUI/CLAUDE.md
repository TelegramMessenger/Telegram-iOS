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

**Routing.** The new host is used only for `.assets(_, .default)` without `forCollage` (the chat attachment menu, the
story-reply attachment menu, an album pushed from it) and only when `context.usesMediaPickerGridV2`
(`AccountContext/Sources/MediaPickerGridV2.swift`): the app-config key `ios_killswitch_disable_media_grid_v2` or Debug
Settings ▸ "Media picker: legacy grid" forces the old path. The flag is read in `init`, so each picker open uses the
then-current value. Every other mode (stories, avatar, files, passport, `.media`, drafts) stays on `GridNode`.

**Data.** The new host does not consume `MediaPickerGridEntry` transactions (`consumesEntries == false`): `updateState`
hands it the fetch result and a `MediaPickerGridAssetsConfiguration` (Recents reversed and driving the filler; a
menu-selected album reversed, as the old path does, without the filler; a pushed album unreversed and starting at its
end). One `MediaGridPhotoLibraryDataSource` exists at a time; an album switch replaces the grid and keeps the level.
Library changes reach the grid through the data source's own PHChange observer, not the picker's state.

**Selection** stays in `TGMediaSelectionContext`, read by identifier; order numbers come from
`selectedItemsIdentifiers`. Pan-to-select is MediaGrid's gesture; its begin cancels the attachment container's pan.

**Attachment container.** `MediaPickerMediaGridContainerView` adopts `AttachmentScrollableContent` (AttachmentUI), which
the container finds when the nearest content in the hit-test chain is not a scroll view; the scroll-view path is
unchanged. A pinch on the grid never moves the sheet.

**Known limits.** Edits and spoilers at levels 15 and 31 come only from what was cached at 1/3/5; the download-status
overlay is not drawn (downloads never start in default mode).
