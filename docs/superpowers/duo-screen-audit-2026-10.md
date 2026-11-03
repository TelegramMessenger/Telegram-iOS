# iPhone Duo screen audit (October 2026)

The record of the all-screens pass that applied the rules in [`../iphone-duo-layout.md`](../iphone-duo-layout.md)
to every screen of the app, 2026-10-08 to 2026-10-09. Posture ids (FP, FL, FR, UP, UL) are defined there. The
per-fix commits are on the local pre-squash branch `feature/reserved-corners`; master has them as one squashed
commit.

## Method

- 298 screens (every `ViewController` subclass but two test doubles) were audited by read-only agents against a
  brief: the posture table, the layout API, the user's decisions, and the bug classes below. Every screen got a row,
  either a finding or "n/a" with a reason.
- Fixers changed only their own files; every fix had to reduce to the old expression with equal side insets and no
  reserved corners. Three read-only reviewers then checked every diff for that and for posture mistakes; their
  confirmed points were fixed before commit (REVIEW rows).
- Runtime checks on the iPhone Duo simulator used deep links and lldb rotation (see the guide). "(code)" in the
  table means checked by build and review, not on screen.

## Bug classes

- B1 symmetric left inset (`X + safeInsets.left` on both sides, or `right: safeInsets.left`).
- B2 band-sized but screen-centred (width `W - L - R` at `(W - w) / 2`).
- B3 trailing control at `W - safeInsets.left - N`.
- B4 side insets ignored in a full-screen surface (controls under a corner block).
- B5 compact and full status heights mixed (unfolded portrait).
- B6 top-right control at a status-derived y in unfolded portrait without `navigationBarTrailingButtonsInset`.
- B7 `UIScreen.main` used for layout or presentation (it is the cover screen while unfolded).
- B8 own back/close drawn in the header row while a strip exists, instead of in the strip.
- B9 9:16 preview taller than the screen: negative space passed to bottom controls.
- B10 web views framed across the strip with `contentInsetAdjustmentBehavior = .never`.
- B11 forced orientation (the unfolded screen refuses rotation requests).
- B12 `widthClass == .regular` treated as iPad (unfolded landscape is a regular-width phone).
- B13 anything else concretely wrong for a posture.

"decision N" in the table refers to the user's decisions as they were numbered in the audit brief: 2 full-screen
viewers beside the island, 3 editors' top rows on the island clock line, 5 folded-portrait bottom sheets and panels
may span the strip (now the general bottom rule, below).

## Findings

| # | Screen | File:line | Posture | Class | Evidence | Status |
|---|--------|-----------|---------|-------|----------|--------|
| F1 | MediaToolsScreen / MediaCutoutScreen / MediaCoverScreen | MediaEditorScreen/Sources/{MediaToolsScreen:1053,MediaCutoutScreen:543,MediaCoverScreen:465} | unfolded P (951: bottomInset 951-1189-87=-325), folded P (~-155) | 9:16 overflow unclamped | buttons container y = H - safeInsets.bottom - 75 => off screen | open |
| F2 | ResizableSheetComponent (23 sheets) | Components/ResizableSheetComponent/Sources/ResizableSheetComponent.swift:852 | UP | static island inset | `sheetHeaderCornerInsets` from the sheet's MAX rise -> a tall sheet resting low had its right item 134pt in and title off-centre by 67 (a shape rejected earlier in the branch) | fixed: slides by current top (code) |
| F1 fix | Tools/Cutout/Cover | | UP, FP | | preview taller than screen -> top 0, bottom 0; env carries compact status + island fields; Tools/Cutout bottom bar mirrored beside island (-77 / -71.5), 16pt sides | fixed (code) |
| F3 | Gallery footer (download status) | GalleryUI/ChatItemGalleryFooterContentNode.swift:1497 | FP/FL/FR/UL | B2 | status centred at W/2 (FP 233) vs playback at band centre (191) | fixed (code) |
| F4 | Gallery video live-photo button | GalleryUI/Items/UniversalVideoGalleryItem.swift:338 | FR | B4 | x=16 inside left strip, overlaps the strip back circle | fixed: insets.left + 16 (code) |
| F5 | Gallery video ad card | UniversalVideoGalleryItem.swift:360 | FP/FL/UL | B1 | 434 wide across the strip while footer keeps to band | fixed: band-limited/centred (code) |
| F6 | Secret media countdown | GalleryUI/SecretMediaPreviewController.swift:142 | UP | B6 | x 632..660 y 23..51 under island | fixed: - navigationBarTrailingButtonsInset (code) |
| F7 | Secret media footer text | GalleryUI/SecretMediaPreviewFooterContentNode.swift:38 | FP/FL/UL | B1/B2 | width W-2(L+8), centred on W | fixed: band (code) |
| F8 | Secret chat key | PeerInfoUI/SecretChatKeyControllerNode.swift:87,134 | FP/FL/UL | B4 | image 446 wide under the 84x170 block; texts under strip | fixed: band (code) |
| F9 | NavigationBarImpl replacement content (in-chat search, admin-log search, location/country/contact/sticker search, profile chat panes) | NavigationBarImpl.swift:948 | UP | B6 | replacement content got rightInset only; close at x 609..653 y 24..68 under island | fixed: + trailingButtonsInset (code) |
| F10 | CameraScreen tablet layout | CameraScreen.swift:1603,1883,2073,2178 | UL | B4 | right panel centre W - panel/2 = 858 crosses strip; flash 887..927 x 37..77 inside 84x120 block | fixed: panel ends at W - safeInsets.right (code) |
| F11 | Brightness (camera front flash, video message flash, QR code, IV backlight, auto-night) | 5 files | UP/UL | B7 | UIScreen.main = cover screen while unfolded | fixed: mainWindowScreen (Display) (code) |
| F12 | PeerSelection empty state + forward panel | PeerSelectionControllerNode.swift:1128,1273,1292 | FP/FL/FR/UL | B1/B2 | empty texts W-2L wide centred on W; button band-wide but screen-centred; forward panel inset L both sides | fixed: band (code) |
| F13 | Checkout info / card entry forms | BotPaymentsUI/BotCheckoutInfoControllerNode.swift:445, BotCheckoutNativeCardEntryControllerNode.swift:458 | UP | B5 | max(navBar 76, full status 82) -> 6pt gap under the bar | fixed: bar's own status height (code) |
| F14 | Payment receipt button | BotPaymentsUI/BotReceiptControllerNode.swift:345 | FL/UL/FR | B4 | x 30..648 into the BR block / strip | fixed: strip insets as checkout (code) |
| F15 | Schedule message sheet mute button | ChatScheduleTimeScreen.swift:902 | FP | B4 | tall sheet top ~33: button x 400..444 y 55..99 in the 84x170 block | fixed: sheetHeaderCornerInsets from the sheet's top (code) |
| F16 | Community join requests | CommunityRequestsScreen.swift:660,743 | FP/FL/FR/UL | B13 | 16 + max(L,R) on both sides: 84pt dead margin on the free side | fixed: per-side (code) |
| F17 | Hashtag search tabs | HashtagSearchUI/HashtagSearchNavigationContentNode.swift:205 | FP | B1/B2 | tabs centred on W reach x 393 at y 80..124 (84x170 block) | fixed: horizontallyCenteredOrigin in band (code) |
| F18 | Sticker import progress | ImportStickerPackUI/ImportStickerPackControllerNode.swift:542 | FP/FL/UL | B2 | ring/texts centred on screen (233) vs card (191) | fixed: centred on card (code) |
| F19 | IV gallery caption | InstantPageUI/InstantPageGalleryFooterContentNode.swift:111 | FL/FP/UL | B1 | caption to x 670 under BR block | fixed: right inset (code) |
| F20 | Invite link sheet title | InviteLinksUI/InviteLinkViewController.swift:1199 | FP | B2 | title centred on W overlaps Done (moved in by R) | fixed: between buttons (code) |
| F21 | Premium limits list | PremiumUI/PremiumLimitsListScreen.swift:1554 | UL | B12 | iPad card on a phone | fixed: forOptionalFloatingPresentation (code) |
| F22 | Replace boost | PremiumUI/ReplaceBoostScreen.swift:983 | UL, FP | B12/B13 | iPad card in UL; strip close circle fixed on screen while the bar moves with the sheet | fixed: phone form + placesNavigationButtonInSideColumn false (code) |
| F23 | QR scanner | QrCodeUI/QrCodeScanScreen.swift:816,802 | UL, UP | B13 | viewfinder 735 > 669 tall; back at y 92 below island | fixed: clamp by height; clock line (code) |
| F24 | Theme crossfade | SettingsUI/Themes/ThemeSettingsController.swift:1526 | UP/UL | B7 | UIScreen.main.snapshotView = cover screen | fixed: mainWindowScreen (code) |
| F25 | 31 sheets' presentation contexts | (scripted) | UP | B5 | compact 16 + no corners for overlays | fixed: fullStatusBarHeight + reservedCorners (code) |
| F26 | Passcode options | SettingsUI/Privacy and Security/PasscodeOptionsScreen.swift:720 | FP/FL/FR/UL | B13 | max(L,R) both sides | fixed: per-side (code) |
| F27 | Chat list edit toolbar (non-root lists) | ChatListUI/ChatListControllerNode.swift:1915 | FL/FP/FR | B1/B4 | 20..658 under the BR block | fixed: strip-side max(20, inset) (code) |
| F28 | Chat search filter bar | ChatListUI/ChatListSearchContainerNode.swift:832,862 | FL/FR | B1 | 32..646 under BR block; FR gave up 84 | fixed: sideInsets(forBand) per side, one helper (code) |
| F29 | Chat list top action panel | ActionPanelComponent.swift:174 + ChatListContainerItemNode | FP/FL | B4 | dismiss X under the block / strip buttons | fixed: sideInsets (strip only) (code) |
| F30 | Chat list empty state | ChatListUI/ChatListEmptyNode.swift:241 | FP | B2 | centred on 233, text into the strip | fixed: band (strip only) (code) |
| F31 | Folder emoji keyboard | ChatListUI/ChatListFilterPresetController.swift:1297 | FL | B4 | grid under BR block | fixed: band insets (strip only) (code) |
| F32 | Contacts search empty results | ContactListUI/ContactsSearchContainerNode.swift:713 | FP | B1 | W - 2L | fixed: W - L - R (code) |
| F33 | Calls empty state | CallListUI/CallListControllerNode.swift:918 | FP | B2 | centred on W | fixed: band (strip only) (code) |
| F34 | Editor text Done | MediaEditorScreen.swift:2868 | FP/UL | B3/B4 | no safeInsets.right: under the 84x170 / 84x120 block | fixed (code) |
| F35 | Cover top row | MediaCoverScreen.swift:217 | UP | decision 3 | Cancel/title 9pt above the clock line | fixed: topRowY (code) |
| F36 | Link sheet Done | CreateLinkScreen.swift:157 | FP | B4 | keyboard raises sheet: Done in the 84x170 block | fixed: sheetHeaderCornerInsets from sheet top (code) |
| F37 | Blur tool overlay | MediaToolsScreen.swift:894 | UP/FP | B9 | overlay = visible area (874) vs preview (1189): handle 157pt off | fixed: preview height when preview > screen (code) |
| F38 | Cutout fade/outlines | MediaCutoutScreen.swift:430 | UP/FP | B9 | centred in visible area vs editor's preview | fixed: editor preview geometry (code) |
| F39 | Editor/Tools/Cutout/Cover bottom-right controls (tablet layout) | 4 files | UL | B13 | Done x 877..921 in the strip; Save Cover to 935 | fixed: + safeInsets.right in tablet branch (code) |
| F40 | Editor bottom bar side inset | MediaEditorScreen.swift:839 | FP | B13 | 9pt: corner clips Done ~2pt | fixed: 16 on Duo (code) |
| F41 | Editor card transition | MediaEditorScreen.swift:5841 | UP/FP | B13 | assumes preview top at status+5: card off the top | fixed: 0 when preview > screen (code) |
| OPEN-1 | Sticker editor (sticker frame + Cut Out/Erase/Outline) | MediaEditorScreen.swift:2534/6503 | UP/FP | B9 | 0.97W square frame centred in the 9:16 preview: UP buttons below the screen; FP overlap | fixed: `mediaEditorStickerPreviewFrame` narrows the preview (Duo only) so frame + undo/cut-out/erase/outline fit above the bottom bar in the band; export unchanged (canvas-centred square); buttons centred on the frame (FP erase+restore pair reached 16pt into the strip). FP sim-verified: frame x 5..376, y 100..470; Cut Out centred under it |
| F42 | Live stream bars (nav, toolbar, buttons row) | TelegramCallsUI/Components/MediaStreamComponent.swift:672,790,936 | FP (sheet), FL/UL (full screen), UP (PiP) | B1/B4/B6 | right items at W - 16 - L: PiP under the island (device only: sim has no PiP), under the 84x170 block in the FP sheet, minimize under FL BR block | fixed: rightInset = R (+ island inset in full screen) (code) |
| F43 | Live stream orientation | MediaStreamComponent.swift:281 | UL | B11 | regular-width unfolded landscape treated as rotatable: refused portrait request, cannot leave full screen | fixed: expand in place when width class is regular (code) |
| F44 | Community sheet bar placement | CommunityViewScreen.swift:2806 | FR/FL/UL | B1/B2 | bar sized W-2L centred while the sheet is band-placed: buttons over the dim (FL) | fixed: resizableSheetHorizontalPlacement (code) |
| F45 | Community sheet bar corner inset | CommunityViewScreen.swift:2990 | FP | B4 | risen bar's search/settings in the 84x170 block | fixed: island toggle generalised to any top-right block overlap (code) |
| F46 | Community full-screen search layout | CommunityViewScreen.swift:2795 | UP | B6 | reservedCorners .none: search bar end under the island | fixed: corners + full status in full screen (code) |
| F47 | Community content margins | CommunityViewScreen.swift:1660 | FP/FL/FR/UL | B13 | max(L,R) both sides | fixed: per-side (code) |
| F48 | Login flow (phone, code, email, password, recovery, sign-up, reset wait, payment, phone confirmation, splash) | AuthorizationUI (10 files) | FP/UL (+UP help button) | B4/B3/B2/B6/B12 | content on the full width into the strip; Help under the island | fixed, reviewed (code) |
| F49 | Payment alert pill, chat QR screen, rank info, send stars, quick share | Chat components (5 files) | FP/FL/FR/UL/UP | B1/B2/B4/B12/B13 | details in the branch commit messages | fixed, reviewed (code) |
| F50 | Notification banner | NotificationItemContainerNode.swift:107 | UP | B6 | banner at y 42 reaches x 546 (island from 535) | fixed: below the island (code) |
| F51 | PiP overlay | OverlayMediaControllerNode.swift:111 | FP/FL/UL/UP | B3 | right edge uses the left inset | fixed: right inset; top-right below the island (code) |
| F52 | Tooltip screen | TooltipUI/TooltipScreen.swift:489 | FP/FL/UL | B1 | left inset both sides | fixed: per-side (code) |
| F53 | Chat footer panels | ChatControllerNode.swift:2773 | FL | B2 | band-wide but screen-centred | fixed (code) |
| F54 | Chat under the attachment sheet | ChatController.swift:8466 | UL | B12 | caption keyboard height reached the chat behind the phone sheet | fixed: !presentsFloatingPanels (code) |
| F55 | Premium limits list collapsed offset | PremiumLimitsListScreen.swift:1255 | FP | B13 | defaultTopInset -71..-84: sheet top cut off | fixed: clamp 0 (+ div-by-zero guard) (code) |
| REVERTED | PremiumLimitsList / ReplaceBoost forOptionalFloatingPresentation | | UL | | sent UL into an untested compact-landscape branch that runs under the strip | reverted; UL keeps the centred card (clear of the strip) |
| F56 | Video chat (close into strip, FL column vs BR block, UL grid, UP pin control, island + column inset), voice-chat camera preview (UL card, FL/FR band), recording setup (FL/FR), permission screens (+ PermissionControllerNode strip insets), tooltips (TooltipControllerNode) | TelegramCallsUI, TelegramPermissionsUI, Display | all | B1/B2/B4/B6/B8/B12/B13 | details in the branch commit messages | fixed, reviewed (code) |
| F57 | Drawing (mode pill, UL top panel), colour picker (height-bounded field FP/UL, eyedropper below island), browser (IV page in band, section header clear, address rows, close into strip), calendar (rotation cache, toolbar height), send-options context (effects panel, video circle), ad info title | DrawingUI, BrowserUI, CalendarMessageScreen, ChatSendMessageActionUI, AdUI | all | B1-B13 | details in the branch commit messages | fixed, DrawingScreen reviewed: UP unchanged (code) |
| SKIP | Drawing legacy adapter corners | DrawingScreen.swift:2986 | UP | low | needs a Display API for the legacy host's corners | fixed: `reservedCornersForHostedLayout(size:orientation:)` (Display) passed by the legacy adapter (code) |
| F58 | Mini app list header/empty, formula sheet Done, rich-text close into strip, allowed reactions (+ shared EmojiSelectionComponent right inset), affiliate setup/join, copy-protection info, story search grid, add gifts, quick reply empty state + bottom panel | PeerInfo/Settings/RichText components (13 files) | all | B1/B2/B4/B8/B12 | details in the branch commit messages | fixed; RichText close reviewed (single item) (code) |
| F59 | Passcode keypad (FP off screen) + entry/setup fields, media picker selection pill (FR block), channel members list, external stream close into strip, location picker/view close into strip, passport auth + doc caption, 2FA setup (+ caller passes safe insets), 2FA data input/splash | PasscodeUI, MediaPickerUI, PeerInfoUI, LocationUI, PassportUI, PasswordSetupUI | all | B1/B4/B8/B13 | details in the branch commit messages | fixed (code) |
| SKIP | Legacy inset table | LegacyComponents/TGViewController.mm:1118 | FP/UP | med | no posture information in LegacyComponents; island inset unreachable; ~30 call sites | fixed: on the 466x678 cover screen `calculatedSafeAreaInset`/`_updateControllerInsetForOrientation` use the context's real safe area; FP sim-verified: gallery check button right edge 374 < 382 |
| SKIP | Location view title | LocationViewControllerNode.swift:1196 | FP | low | 133..333 fits clear of the strip | not a bug |
| F60 | Story viewer presentation context, video message circle, wallpaper gallery close into strip, wallet app info context, Stars balance beside island, wallet apps margins, live stream settings close into strip, sticker picker (phone form in UL + keyboard band), passkeys (band; list max(L,R)), countries/share-with-peers sheets (band, close out of the FR block / into strip) | Stories, VideoMessageCamera, Settings, Stars, Wallet, ShareWithPeers, StickerPicker | all | B1/B4/B6/B8/B12/B13 | details in the branch commit messages | fixed (code); StickerPicker UL needs a runtime check |
| F61 | Theme preview + limits list page dots, gift auction accessory panel, wallet collectible/transaction sheets (more button vs FP block), wallet peer selection empty state, wallet send close into strip, music player controls (band) + playlist margins (listSideMargins) | Settings, Premium, TelegramBaseController, Wallet, TelegramUI overlay audio player | all | B1/B2/B4/B8 | details in the branch commit messages | fixed (code) |
| SKIP | Recent session card, Text Size / Theme preview UL split, sticker pack UL popover | | UL | B12/B13 | unreachable: .modal/.flatModal get forOptionalFloatingPresentation (StickerPackScreen applies it itself) | not a bug on the Duo |
| F62 | Poll/checklist/new-contact close into strip, sticker attachment (close + keyboard band), context menu preview (UL phone branch) + ContextMenuNode block clamp, entity search, emoji status picker, forum topic header, gift options/store widths + close, five gift sheets' FR width (+ GiftAuctionBid), gift variants playback slide, video message capture circle (ObjC) | Compose, Context, EntityKeyboard, Gifts, LegacyComponents | all | B1/B2/B4/B8/B12/B13 | details in the branch commit messages | fixed (code) |
| F63 | Gift craft slots + avatar, face scan ring/preview/instruction/cancel, QR preview orientation in UL, video message camera tablet-landscape band | GiftCraftScreen/CraftTableComponent, FaceScanScreen, QrCodeScanScreen, VideoMessageCameraScreen | FP/FL/UL | B2/B11/B12 | band-sized but screen-centred; regular-width phone treated as fixed portrait | fixed: centred on the band (`bandCenterX`), `previewFollowsDeviceOrientation` for a regular-width Duo, band insets added (code) |
| F64 | Legacy photo editor (crop/adjust/quality/avatar/drawing host) | LegacyComponents TGPhotoCropController/TGPhotoEditorTabController container frames + TGViewController class table | FP/FL/UL | B4 | static inset table (no context) => crop area full width, top-right handle under the 84x170 block | fixed: table returns the last context safe area on the Duo; portrait branch honours side insets. FP sim-verified: crop area x 7..374, adjust photo in band |
| F65 | Legacy photo viewer top row in UP | TGMediaPickerGalleryInterfaceView + LegacyComponentsContext.statusIslandTrailingInset | UP | B6/decision 2 | after F64 the top row (recipient, check) moved below the island; decision 2 keeps viewers' top rows beside it | fixed: row stays at the top, check button left by the island inset (0 elsewhere; FP unchanged, sim-checked) — UP code-only |
| SKIP | Five gift B12 rows | | UL | B12 | unreachable on the Duo (flatModal gets forOptionalFloatingPresentation) | not a bug on the Duo |
| REVIEW R2 | 3 med + 2 low fixed: invite-link title, QR viewfinder clamp, limits-list clamp now Duo-only (non-Duo neutral); key screen strip-only band; passcode Cancel centred with the field. Accepted: AdInfo (iPad Stage Manager only, better), sticker import 1pt rounding, ReplaceBoost close stays in its moving sheet. | | | | | done (code) |
| REVIEW R3 | fixed: 5 wallet presentation contexts the script missed (multi-line blocks); forward panel neutral on notch phones; schedule title stays between Cancel and the moved bell; wallet controls laid out with the last corner inset (no double move). Not changed: 14 `.regular` toast branches (flatModal sheets get forOptionalFloatingPresentation, verified in NavigationModalContainer isFlat path; pre-existing), formula title (unlikely), gift sheets' contexts w/o side insets (nothing reads them), GiftOptions non-glass Cancel. | | | | | done (code) |
| REVIEW R1 | fixed: point tooltips clamp to the bubble's own band (arrow stays inside); stream centre items centred on the band + portrait sheet row keeps the strip (decision 5); live-photo button strip-only; editor preview-overflow gates need >30pt (320x568 phones unchanged); colour-picker height bound Duo-only; drawing mode pill on controlsCenterX (UL back on the column). Not changed: video message circle in UL tablet branch (below the block, cosmetic); Environment.sideColumnNavigationButtonFrame in FP sheet content is intentional (matches standard bars there). | | | | | done (code) |

## After the audit

Runtime-checked on the folded simulator: editor Tools bar, blur handle, editor bottom bar, discard alert, schedule
sheet, passcode options, 2FA password, passkeys, Get Stars, birthday, proxy, Business, Text Size (portrait-only),
My Gifts, Saved Messages (portrait and both landscapes: back/close in the strip, content in the band; the birthday
card's background passes under the FR corner block with its content clear, an accepted bottom-sheet case). On the
unfolded simulator: sticker editor (portrait, real cut-out), photo viewer and crop (portrait), drawing over the photo
editor (portrait), QR scanner and video message circle (landscape), and the call screen in landscape (not a bug: it
lays out at 951x669 with back in the strip and content in the band).

Fixed after the audit, found by runtime checks or by the user:

- Chat Themes crashed when scrolled: list item nodes were created off the main thread.
- Navigation transitions round in-progress controllers with the screen's per-corner radii, not one radius.
- Legacy photo viewer and editor (LegacyComponents) laid out for the cover screen while unfolded: `TGScreenSize()`
  now follows the app window; the photo viewer's top row stays beside the island
  (`LegacyComponentsContext.statusIslandTrailingInset`); the legacy inset table and the crop/adjust containers
  honour side insets in portrait.
- Drawing over the photo editor uses the island's height for its status row.
- Full-screen mini app: back in the strip. Chat import progress and the music player's album cover keep to the band
  (the user checked the music player; chat import was closed by the user as code-only).
- Sheets round each bottom corner by its own screen corner (SheetComponent, ResizableSheetComponent, and the one-off
  sheets: emoji status, location, music playlist, sticker pack, chat QR, the six ItemLayout sheets), and the clips
  inside them keep their bottom corners within the sheet's. Pop-up cards (NavigationModalContainer and its three
  copies) round their bottom corners only with a bottom safe inset; the Duo has none, so they stay square and the
  screen mask clips them (checked on the proxy card and the sticker picker).
- Band-centred texts measured on the whole width ran off the left edge (Buy a Gift description, Premium gift-code
  link); a scan of the 43 band-centred files found no other instance.
- The chat QR code card fits above its sheet on the folded screen; the QR code, schedule time and recording setup
  sheets span the screen's width on the Duo (the 440pt compact cap was narrower than its screens).

## Bottom buttons and panels span the strip

The user's rule after Change Profile Color: a button or panel anchored at the bottom is not inset by the side strip;
it keeps clear only of a corner block that reaches its row (FL's bottom-right block). About 60 sites in six groups:
legacy bottom sheets, sign-in and security, panels and toolbars, gallery / Premium / settings, component screens,
calls / drawing / media editor. Shared pieces: `bottomEdgeSideInsets()` (layout, environment, free function),
`horizontalContainerFillingPlacementForLayout(anchoredAtBottom:)`, `GalleryFooterContentNode.screenSideInsets`.

Real bugs found on the way:

- LiveStreamSettingsScreen's action button was `W - 60` wide but centred on the band: 12pt off screen beside a strip.
- Passport's authorization button ran under FL's bottom-right block (the panel was full width with no inset).

Review and runtime findings, fixed:

- The join-link card's close button slides clear of the FP block when the card rises to it.
- The peer picker's text input and forward panels grow upward (to half the screen), so they take the band of their
  actual rows, like the chat's input panel.
- The sticker pack's visible glass button was a different node from the legacy one the fixer changed; caught by an
  FP capture, not by the two reviewers.
- Share and import-sticker sheets stay in the band: tall scrolling grids whose corner buttons rise to the block.
- Small centred controls stay on the axis of their content: camera preview Done, face scan Cancel, the round record
  button, the landscape wallet Send, the quick-reply empty-state button.

Deliberately not changed:

- Chat list empty state: the side tab bar sits in the strip at the bottom of the root screens.
- Call screen button row: centred under the band-centred avatar.
- Login intro (legacy RMIntroViewController): its Start button stays in the band, so the phone entry's button widens
  as it animates in from it.
- SheetComponent's landscape band, emoji keyboards and the business intro emoji panel (grows to 540pt in search),
  PeerInfoPaneContainer, the chat's footer panels and input media, toasts.

Runtime-checked (folded): Text Size Cancel/Set span 0..466 (portrait-only modal); wallpaper preview Apply 30..436;
language sheet spans in FP, screen-centred in FR, clear of the bottom-right block in FL; sticker pack button spans in
FP and FR and stops at 564 in FL; the share sheet stays in the band in all three. `TabBarLayoutTests` pins the edit
toolbar: it spans FR's left strip (the block is at the top) and keeps FL's right inset.

## Known gaps

- Unfolded checks need the user's Simulator window (the fold cannot be driven from the command line); most unfolded
  landscape fixes are code-only.
- Screens reachable only by taps or with account state this account does not have (subscribe buttons on a Premium
  account, chat import, live calls) are code-only.
