# iPhone Duo layout

How the app lays out on iPhone Duo (iPhone19,4), the rules every screen follows there, and how to check a
screen. The screen-by-screen audit that applied these rules is recorded in
[`superpowers/duo-screen-audit-2026-10.md`](superpowers/duo-screen-audit-2026-10.md).

## The device

Most of what the system reserves on the Duo is not an edge but a **block in one corner** (the status corner:
clock, connectivity, camera). UIKit widens that block into a full-edge `safeAreaInsets` inset. The app keeps
honouring `safeInsets` and additionally reads the blocks from `ContainerViewLayout.reservedCorners`.

Both come from the system (`reservedRegions(kind: .occlusion)`, `safeAreaInsets`) whenever its report fits the
window's posture: a block that fills the posture's corner and is exactly as thick as the system's inset on the
posture's edge, with no inset on the other edges (`iPhoneDuoReservedArea` in `Display/Source/ReservedArea.swift`).
For up to 0.65s after every rotation and fold the report is transitional (the previous posture's block or insets, a
stray block, none), and some of it fits the new posture (folded landscape's block in folded portrait's corner), so the
report is not taken for 0.7s after a size change and is read again then. A per-posture table
(`iPhoneDuoReservedCorners`, `iPhoneDuoSafeInsets`) names the posture and stands in meanwhile with the sizes the
simulator settled on. The sizes below are the simulator's (iOS 27.1); code reads them from the layout, never as
constants.

| id | posture | window | safe insets (t,l,b,r) | corner block | derived |
|----|---------|--------|-----------------------|--------------|---------|
| FP | folded cover, portrait | 466x678 | 0,0,0,84 | top-right 84x170 | right strip x 382..466, y 170..678 |
| FL | folded, landscape-left | 678x466 | 0,0,0,84 | bottom-right 84x82 | right strip x 594..678, y 0..384 |
| FR | folded, landscape-right | 678x466 | 0,84,0,0 | top-left 84x82 (table: 84x84) | left strip x 0..84, y 82..466 |
| UP | unfolded, portrait | 669x951 | 82,0,0,0 | top-right 134x82 "status island" | no strip |
| UL | unfolded, landscape | 951x669 | 0,0,0,84 | top-right 84x120 | right strip; width class **regular** although it is a phone |

- FP has a **side** inset in **portrait**: code that assumes "portrait has no side insets" is the main hazard.
- `UIScreen.main` is the cover screen even while unfolded; use `mainWindowScreenBounds` / `mainWindowScreen`
  (`Display/Source/MainWindowScreen.swift`) for the screen the app is on. Legacy code reads `TGScreenSize()`,
  which follows the app window on the Duo.
- The cover screen's corners differ: 8pt on the hinge side, 59pt outside (`layout.screenCornerRadii`); the inner
  screen is a uniform 55pt.
- The fold cannot be driven from the command line (`simctl` has no posture command); unfolded checks need the
  Simulator window.

## Layout API (Display, ViewControllerComponent)

- `layout.reservedCorners`, `layout.sideStrip(edge:)`: the blocks, and a side whose inset exists only because of them.
- `layout.sideInsets(forBandFrom:to:)` / `bandSideInsets(...)` / `Environment.sideInsets(forBandFrom:to:containerHeight:)`:
  a horizontal row's side insets. A strip side keeps its inset only where its corner block reaches the row.
- `layout.bottomEdgeSideInsets()` / `bottomEdgeSideInsets(safeInsets:reservedCorners:)` /
  `Environment.bottomEdgeSideInsets()`: the same for a row at the bottom edge. Equal to `safeInsets` on every
  other device.
- `horizontalContainerFillingPlacementForLayout(layout:margin:includesSafeInsets:anchoredAtBottom:)`: a centred
  container; beside a strip it sits in the band, and with `anchoredAtBottom` it spans the strip (compact width) or
  centres on the bottom-edge band (regular width).
- `layout.sideColumnNavigationButtonFrame`, `ViewController.placesNavigationButtonInSideColumn`: where a screen's
  own back/close button goes in the strip.
- Unfolded portrait island: `layout.topBarStatusIsland`, `layout.navigationBarStatusBarHeight` (compact 16 for a
  top bar), `layout.navigationBarTrailingButtonsInset` (the island's width, 134 on the simulator),
  `statusIslandTrailingShift(rowMinY:rowHeight:islandHeight:inset:)` for a control in a row that rises and falls
  with a sheet. Component environments carry `statusBarHeight` (compact), `fullStatusBarHeight`,
  `navigationBarTrailingButtonsInset` and `reservedCorners`; a screen that builds an
  `Environment` by hand must pass them all (the defaults are 0 / `.none`).
- Sheets: `sheetHeaderCornerInsets(...)`, `resizableSheetHorizontalPlacement`, `sheetBandPlacement`,
  `centeredAlertSideInsets` for centred alerts (`Display/Source/SheetPlacement.swift`); per-corner bottoms with `layout.screenCornerRadii.sheetBottomCornerRadii(inset:)` and
  `CALayer.applyCornerRadiiIfNeeded` (`Display/Source/CALayerCornerRadii.swift`, private `cornerRadii` via KVC,
  guarded by `cornerRadiiSupported`).
- A sheet taller than the screen: `sheetRestingScrollOffset`. On every device `SheetComponent` rests it on its top, as
  it opens and snaps back, and it scrolls up to its bottom; it used to jump to its bottom, header above the screen,
  after a rotation, a content change or the keyboard toggling (#79: the report reasons, ~715pt, on the Duo's 678pt
  folded and 669pt unfolded-landscape screens; phones in landscape too). While the keyboard is up, or where the sheet
  cannot scroll, it rests on its bottom, and when the keyboard goes down it stays where it was.
- Side column / tab bar / lists: `layout.sideColumnFrames(...)`, `tabBarSidePlacement(layout:itemCount:)`,
  `chatInputPanelSideInsets(layout:bandMinY:bandMaxY:column:)`, `layout.listSideMargins(base:)`;
  `layout.centeredListPlacement(base:)` for a list narrowed on both sides whose rows fill its width (their side
  insets then take no strip, which the margin already clears).
- Legacy hosts: `reservedCornersForHostedLayout(size:orientation:)`; `LegacyComponentsContext.statusIslandTrailingInset`.
- Status bar style: `layout.coversStatusCorner(frame:)` tells whether a surface still overlaps the status corner block;
  `NavigationModalContainer.presentedCardFrame` is a card's frame including an interactive dismiss.
- `deviceMetrics.isIPhoneDuoInnerScreen(size:)`: a full-screen layout on the unfolded screen (either orientation).
- `deviceMetrics.screenPortraitDeviceOrientation(size:)`: the body position (`UIDevice.orientation`) in which the
  screen's portrait reads upright. Landscape-left on the inner screen, portrait elsewhere. `UIDevice.orientation` is
  measured against the body on both screens and a window's interface orientation against its own screen, so code that
  compares the two (call video rotation: `callInterfaceOrientationInDeviceFrame`) converts first. Measured on the
  device with `AVCaptureDevice.RotationCoordinator` (iOS 27.1): inner portrait = body landscape-left, inner
  landscape-right = body upside down. A capture connection's orientation is a body position too: the camera previews
  (`CameraPreviewView`, Legacy and Neo) convert the window scene's orientation with `CameraVideoOrientation(
  interfaceOrientation:screenPortrait:)` and `screenPortraitDeviceOrientationForWindow(size:)`, and photos and videos
  are captured in the preview's orientation; round videos too on iPad and iPhone Duo
  (`cameraRecordsRoundVideoInPreviewOrientation`), while other iPhones record them in portrait.
- The fold: `layout.division`, the active `.division` region (half open). Flat and sheet modals pass it on in their
  content's coordinates (`NavigationModalContainer`; it was dropped there in portrait until 2026-10-29, so nothing
  presented as a modal saw a fold running across the screen). The 1:1 call screen splits at a fold across the inner
  screen: the main video centered above it, the self-view centered below it with the buttons.
- Bar buttons: `UIBarButtonItem.staysInRow` / `NavigationBarComponent.Button.staysInRow` /
  `ItemListNavigationButton(staysInRow:)` keep a button in the row instead of the side column.

## The rules

These are the user's decisions; a screen that follows them is correct, one that does not is a bug.

1. **Back/close goes in the side strip** when there is one (Duo guideline). Standard bars do it; a screen that draws
   its own button uses `sideColumnNavigationButtonFrame`.
2. **Content keeps to the band** between the side insets: lists, headers, top rows, centred texts. Scrolling content
   stays in the band too (it would otherwise pass under the corner block).
   The login flow on the unfolded screen is the exception: its content is centred on the full width, in line with its
   bottom button and the keyboard, inset by the larger side inset on both sides, when that leaves room for its 430pt
   column (`authorizationContentBand` in AuthorizationUtils). Folded, it keeps to the band. This covers every
   AuthorizationUI screen, also where Settings reuses them (Change Number, login email setup), and
   `TwoFactorDataInputScreen` and `TwoFactorAuthSplashScreen` with an unauthorized engine (password recovery during
   login).
3. **A button or panel anchored at the bottom spans the strip** and keeps clear only of a corner block that reaches
   its row, which at the bottom is only FL's bottom-right block (`bottomEdgeSideInsets()`). This covers primary
   bottom buttons, bottom toolbars, selection panels, short bottom sheets and their buttons.
   Keeps the band instead:
   - a **small centred control** on the axis of band-centred content (a fixed-width button, a round record button,
     a Done drawn on a camera preview, a text Cancel under a ring): moving it puts it 42pt off that axis;
   - a **tall sheet that scrolls up to the top** (share, import stickers): its corner buttons would reach the block;
   - a **full-width sheet in landscape** beside a strip (`SheetComponent`): the whole sheet, background included,
     keeps to the band and its content is centred on it; spanning the screen it ran under the strip's corner block
     (unfolded landscape's status corner) with its content off the sheet's centre;
   - a **panel that grows upward** (a text input above the keyboard): it takes the band of its actual rows, as the
     chat's input panel does;
   - anything beside the **side tab bar**, which sits in the strip at the bottom of the root screens;
   - a **caption that can be dragged up** (gallery footers: `GalleryFooterContentNode.screenSideInsets`);
   - everything at the bottom of the **story camera and story editor** (and their tool panels): laid out as on a phone
     whose screen is the 9:16 viewfinder's band (`storyControlsBandLayout`), the editor's bar on the camera's bottom row.
   - the **chat camera** on the folded screen follows the system Camera instead: centred on the screen, the photo preview
     filling it and the video one 9:16 in the middle, side buttons mirrored on both edges (`CameraScreenChatScreenLayout`).
   - the **login flow's bottom button** on the folded screen (with the divider and Sign in with Apple beside it, and the
     actions in the password-recovery button rows): it keeps to the content band so the title, the fields and the
     button share one axis; only the system keyboard spans the strip there. Unfolded it spans the strip on the axis
     of the centred content (rule 2's exception). `authorizationBottomBand` in AuthorizationUtils; the same screens as
     rule 2's exception.
   - the **text actions that take a hidden button's place** in Settings' 2FA data input ("Can't access your email?"
     or "Change Email", and "Re-send Code"): they line up with the fields above them, while the button itself spans the strip
     (`twoFactorDataInputHorizontalLayout` in PasswordSetupUI). In the login flow they keep to the button's frame, as
     above.

   **Centred alerts** (`AlertScreen`, `AlertControllerNode`) keep the axis of the screen's sheets
   (`centeredAlertSideInsets`), whatever is behind them: the screen's centre in folded portrait, where sheets span the
   strip (the band only when the keyboard lifts the alert into the corner block), and the band's in landscape, where
   sheets keep to it. Over band-centred content in folded portrait (a list) an alert is therefore 42pt off its axis.
4. **Unfolded portrait island**: top bars use the compact status height (16), trailing buttons move left by the
   island's width (134), the title stays centred. Editors, camera, stories and full-screen live stream keep their top
   row on the island's clock line (centre ≈ 47) and mirror it at the bottom; pop-up cards stay below the island;
   sheets that rise with scrolling slide their top-right control clear by the row's current position.
5. **Full-screen viewers** (browser documents, full-screen mini apps) fill the screen beside the island.
6. **Per-corner radii** follow the screen: sheets' bottom corners, inner clips inside them, and in-progress
   navigation transitions (and the story camera sliding the chat list aside) use `screenCornerRadii`, not one uniform
   radius.
7. **Unfolded landscape is a regular-width phone**: check `deviceMetrics.type == .tablet`, not
   `widthClass == .regular`, for anything meant for iPads; it also refuses programmatic rotation requests. Modals see
   compact metrics there (`forOptionalFloatingPresentation`). The story viewer is the exception the other way: on the
   unfolded screen, both orientations, it uses the iPad card layout (9:16 card centred in the band, blurred backdrop),
   kept clear of the status island in portrait and 16pt from the top and bottom in landscape, with an input row and a
   footer row (a channel's or one's own story: views, share, reposts, likes) at least a phone's width (375pt).
8. **The status bar follows what covers its corner block**: with a modal up, the folded postures and unfolded
   landscape take the style of the topmost card that still overlaps the block, else the screens behind; an
   interactive dismiss switches it once the card has left the block entirely (not the regular phone's forced white).
9. **Edit/Done stays in one place**: a Done that takes turns with a text Edit is marked `staysInRow`, so it stays in
   the top row (as an accent pill) instead of jumping into the side column's trailing circle. A Done-only form keeps
   its accent circle in the column.
10. **Column shapes pair by position in transitions**: between two bars the side column's shapes (back circle,
   buttons capsule, trailing circle, whichever a bar has) pair by index from the column's top, as the row's right
   platters pair from the edge; Chats' story capsule and compose circle become the chat's back circle and avatar.

## Bug shapes (all invisible when the side insets are equal)

- Symmetric left inset: `X + safeInsets.left` used for both sides, or `right: safeInsets.left`.
- Band-sized but screen-centred: width `W - L - R` placed at `(W - w) / 2`, 42pt toward the strip.
- A presenting context's side insets counted on top of `safeInsets`: a chat hands its presentation context (toasts,
  tooltips) its history list's insets, whose left and right hold the safe insets swapped, so `intrinsicInsets.left` is
  FP's 84pt strip. Counting it on both sides again left the undo toast no width for its text (one letter per line);
  `undoOverlayHorizontalLayout` takes the strip (the side safe insets' difference) out of it.
- Trailing control at `W - safeInsets.left - N`.
- Side insets ignored in a full-screen surface: controls under a corner block.
- Two status heights mixed in unfolded portrait (compact for one part, full for the other).
- `UIScreen.main` used for layout while unfolded.
- `widthClass == .regular` treated as iPad.
- "Landscape" meaning "too short for this": unfolded landscape's detail pane is portrait-shaped (about 631x669) but
  hardly taller than wide. A profile's expanded photo (`min(w, h − 61) + 98`) reached past its bottom, leaving no list to
  drag, so the profile opened from a chat's avatar could not scroll; `peerInfoAvatarExpansionFits` asks for the room.
- A 9:16 preview taller than the screen (UP, FP) leaving negative space below it for the bottom controls.
- Something anchored to that preview's bottom edge, which on UP is below the screen: the dual camera's front preview
  keeps to the shutter there (`cameraDualPreviewCenter`), though the capture keeps it at the frame's corner. On FP the
  edge is the screen's, under the lifted controls, and the preview keeps the corner the capture uses, as on home-button
  phones.
- A bottom row lifted by a constant tuned for home-button phones, until the Duo the only phones whose 9:16 preview is
  taller than the screen: measured from the screen edge, it lands on the home indicator. The indicator is
  `layout.intrinsicInsets.bottom` (20pt); the Duo's `safeInsets.bottom` is 0. The story camera keeps its controls above
  it; the editor's bar, the drawing screen's and the sticker frame sit 62pt above it on the folded screen. Beside the
  unfolded island the bar mirrors the top row, which already clears it.
- Something parked just past the content's edge, off-screen on a phone, shows in the strip beside a band: the story
  viewer's resting cube neighbours sat 40pt into FP's strip. Clip to the band (the stories turn the clip off while
  opening and closing, which can start or end at an avatar in the strip).
- A layout that computes the right value and never applies it (dead code), or that fixes a legacy node while the
  visible control is a different one: verify each fix on screen, not only by build and review.

Any fix must reduce to the old expression when `reservedCorners` is `.none` and the side insets are equal, so every
other device stays byte-identical; the band helpers above are built that way.

## Checking a screen

- Dedicated simulator, iPhone Duo (iOS 27.1). Install by copying the whole `.app` from the unzipped `.ipa`
  (CLAUDE.md, "Updating the running simulator").
- Reach screens with deep links, not taps: `xcrun simctl openurl <udid> "tg://settings/<id>"` (any searchable-item id
  in `SettingsUI/Sources/Search/SettingsSearchableItems.swift`), `tg://addstickers?set=<name>`, `tg://bg?color=<hex>`,
  `tg://setlanguage?lang=<code>`, `tg://msg_url?url=<url>`, `tg://socks?server=…&port=…`. AXe taps on a loaded Mac
  arrive late or read as long presses.
- Rotate with lldb (`requestGeometryUpdate` on the window scene), then capture with
  `xcrun simctl io <udid> screenshot --display=<uuid>`; the cover and inner screens are separate displays whose UUIDs
  change when the simulator reboots (`simctl io <udid> enumerate`).
- Screens no link reaches: a temporary Darwin-notification hook that pushes the screen (marked for removal and
  stripped before committing).
- Pure placement helpers have tests: `//submodules/TelegramUI/Components/TabBarLayout:TabBarLayoutTests`
  (side tab bar and its edit toolbar per posture), `//submodules/UndoUI:UndoUITests` (the undo toast's panel and text
  widths in and outside a chat), `//submodules/ReactionSelectionNode:ReactionContextGeometryTests` (the reaction panel's
  glass keeps to the panel when its hidden tail points past it, as at a story's input row on the landscape card),
  `//submodules/PasswordSetupUI:PasswordSetupUITests` (the 2FA data input's
  bands and its button-row actions per posture), `//submodules/AuthorizationUtils:AuthorizationUtilsTests` (the login
  flow's content and bottom-button bands per posture, and the password screen's column above the keyboard: on the
  Duo's short screens it drops the animation so Forgot password keeps its gap below the field),
  `//submodules/TelegramUI/Components/ChatMediaEditorScreen:ChatMediaEditorScreenTests` (the chat media editor's
  trimmer, counter and camera button, Edit Cover title beside a strip),
  `//submodules/TelegramUI/Components/LegacyMessageInputPanel:LegacyMessageInputPanelTests` (the media editors'
  caption panel: a caption above the media keeps clear of folded portrait's status corner),
  `//submodules/TelegramUI/Components/VideoMessageCameraScreen:VideoMessageCameraScreenTests` (the round video
  message preview kept above the input panel, its trailing buttons clear of the status corner, touches reaching the
  panel above a bot keyboard),
  `//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboardTests`
  (the emoji / stickers / GIFs keyboard's grid, headers and switcher on the band),
  `//submodules/TelegramUI/Components/CameraScreen:CameraScreenTests`
  (the story camera's dual-camera front preview: on UP a bottom corner keeps to the shutter, as where the 9:16
  viewfinder fits),
  `//submodules/Display:DisplayTests` (`CenteredAlertSideInsetsTests`:
  a centred alert's band per posture).
