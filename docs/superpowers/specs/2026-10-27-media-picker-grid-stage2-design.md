# MediaPickerScreen on MediaGrid (stage 2)

Status: proposed, 2026-10-27. Builds on `2026-10-27-media-picker-grid-design.md` (stage 1) and
`2026-10-27-media-grid-thumbnail-store-design.md`.

## Intent

Ship the new layer-based grid (`submodules/TelegramUI/Components/MediaGrid`) in the app's photo picker:
- the fast scroll from stage 1;
- Photos-style zoom 1/3/5/15/31;
- instant thumbnails at every level and in every motion;
- a sharp first screen on open.

The old `GridNode` path stays intact behind a killswitch.

## Decisions (Ilya, 2026-10-27)

- **Killswitch, not replacement.** The killswitch is a server app-config flag. By default the new grid is **on** for everyone. The server can turn it off, and then the picker uses the untouched `GridNode` path. Debug Settings gets a toggle too.
- **Scope of v1: the chat attachment menu only.** That covers Recents and albums, at full feature parity: selection with order numbers, pan-to-select, camera cell, tap-to-open with the gallery transition, spoiler/price, duration, live photo, edited thumbnails, the limited-access header, the date scrubber, and album switching.
  - Every other picker mode stays on `GridNode`: stories, the avatar editor, files, passport, `.media` subject lists, and drafts.
- **Zoom.** Zoom works only in the attachment menu, with the stage-1 rules: levels 1/3/5/15/31, default 3 in portrait and 5 in compact landscape, and the camera hidden by alpha at 1/15/31.

## Design (my calls)

- **Killswitch.**
  - Key: `ios_killswitch_disable_media_grid_v2`. Its presence means the old path.
  - Debug flag: `ExperimentalUISettings.mediaGridLegacy`, which forces the old path.
  - A pure function `mediaPickerGridV2Enabled(legacyOverride:killswitchPresent:)` with unit tests, plus an `AccountContext` convenience. This copies the `chatMediaEditorV2` precedent in `AccountContext/Sources/ChatMediaEditorV2.swift`.
  - The flag is read once, when the picker is created. It never switches while the picker is open.
- **The PhotoKit stack becomes a module.** The demo's PhotoKit loading moves into a new `submodules/TelegramUI/Components/MediaGridPhotoLibrary`, which imports Photos, MediaGrid and Foundation/UIKit. It contains:
  - the image scheduler and the photo-library data source;
  - the thumbnail filler with its network lane and backoff;
  - the store wiring;
  - the launch cache matching;
  - the catalog and PHChange handling.

  The demo then uses the module. Their tests move with them.
  - Storage is device-wide, not per account, under `<Caches>/MediaGridThumbnails/`.
- **Seam in MediaPickerUI.** A small internal protocol covers the surface the picker uses today: data updates, layout, visible cells, item at point, scroll state and offset, scroll to top, the camera host, the header host, and transition views. There are two implementations:
  - the `GridNode` one, a mechanical forward of today's code with no behaviour change;
  - the `MediaGrid` one.

  `MediaPickerScreen.Node` branches once, when it is created.
- **Data mapping.**
  - The picker's Recents list is reversed relative to the fetch result. An album is not reversed and opens scrolled to the end.
  - The new data source serves picker indices.
  - The selection source of truth stays `TGMediaSelectionContext`, read by identifier.
  - Edited thumbnails from `editingContext.thumbnailImageSignal` override the sharp image for their id.
- **The cell.** `MediaPickerGridCellLayer` subclasses `MediaGridCellLayer`. It has layer-only decorations:
  - the check with its order number;
  - duration or GIF;
  - the live-photo icon;
  - the price;
  - the download-status overlay.

  A spoiler cell gets its dust effect from a small overlay view that the grid positions above that cell. Spoilers are rare, so this is fine. Compact levels (15/31) show no decorations, as stage 1 already rules.
- **Transitions.** `transitionView(for:)` builds a snapshot view from the cell's contents in grid coordinates. `hideSource` and `hiddenMediaId` hide the cell layer. The send-preview and selected-list `getTransitionView` paths get the same treatment.
- **Attachment container arbitration.** This is the biggest risk. `AttachmentContainer` finds a `UIScrollView` to arbitrate pan-to-dismiss and expansion, and MediaGrid has none. The fix adds a protocol that a non-`UIScrollView` content can adopt. It exposes:
  - whether the content is at its top;
  - whether it is scrolling;
  - a way to stop or hand off its pan.

  The container uses that when no scroll view is found. Behaviour must match today: pulling down at the top collapses or dismisses, scrolling expands, and selection-pan cancels the container pan.
- **Header and camera.**
  - The limited-access `MediaPickerManageNode` goes into a header region that MediaGrid scrolls with its content, above the first row.
  - The camera view (`TGAttachmentCameraView` and its wrapper) is hosted in `MediaGridView.cameraView`. Its visibility is driven from the grid.
- **Launch cache.** Its loading starts when the attachment menu begins presenting. The thumbnail store and filler live for the app session, created on first use.

## Verification

- Unit tests for the flag, the data mapping, the cell decorations and the arbitration protocol.
- `Make.py build`.
- On a simulator with Telegram logged in, with Ilya's OK on which one:
  - open the attachment menu;
  - scroll, scrub, zoom and select;
  - open the gallery and come back;
  - send;
  - check pull-to-dismiss and expansion;
  - check the limited-access header;
  - switch albums;
  - flip the debug toggle and check the old path still works.
- Recorded and checked frame by frame, as in stage 1.

## Not in scope

Every non-attachment-menu mode, drafts, and removing `GridNode`.
