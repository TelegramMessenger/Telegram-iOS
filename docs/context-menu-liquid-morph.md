# Custom context menu liquid morph

## Scope (2026-09-29): single-button header capsules only

The morph is opt-in per source view. `ContextControllerExtractedPresentationNode` morphs a `.reference` menu only when its reference view has `morphsIntoContextMenu` set (a `UIView` property in `Display/ContextContentSourceNode.swift`); every other source uses the standard presentation.

Only navigation-header glass capsules that hold exactly one button set it, and they recompute it on every layout:

- `NavigationBarImpl`: left capsule (back button or the single left item) and right capsule, counting visible `NavigationButtonNodeImpl` items.
- `ChatListHeaderComponent` (Contacts → Sort): back button plus buttons of the content views currently visible, so a primary/secondary crossfade counts both.
- `PeerInfoHeaderNavigationButtonContainerNode`: distinct visible keys; normal and expanded sets crossfade with `expandFraction`, and the back button appears in both but is one element.
- `GiftStoreScreen`'s balance pill, which is always a single element.

A morphing menu takes the source's place instead of opening below it. Its top edge sits on the source's top edge (for a `.top` source, its bottom edge on the source's bottom edge, growing upward), and it shares the source's left edge in the left half of the screen or its right edge in the right half. The screen-edge clamp still applies. The height limit is measured from that anchor edge, so the menu also gets the space the source occupied. In a two-list menu, the morphing main list sits on the source and the additional list follows it in the growth direction. `customPosition` is ignored. The placement is decided when the menu opens and kept for its lifetime (`hasActiveLiquidMorph`), even if the header relayouts and the capsule stops opting in. The morph still pivots on the source's center, which now lies inside the menu.

Menus opened from a capsule shared by several buttons, and from any other source, do not morph and keep the standard placement. The profile action row (More / Mute, `PeerInfoHeaderButtonNode`) does not opt in either. Its live-extraction support described below is intact but unused, and its `prepareForContextMenu` (which cancels the release fade) runs only for an opted-in source. To re-enable it, set `morphsIntoContextMenu` on those buttons' `referenceNode.view`. The simulator gallery opts in its own sources so it still covers every shape.

Current profile sources use live foreground extraction and a matching live backdrop. The snapshot sections below describe earlier iterations, superseded by the final live-source section.

## UIKitCore investigation

Inspected the `UIKitCore` document in Hopper MCP. The disassembly matches the symbols/offsets in the installed iOS 26.5 simulator image. Addresses below identify investigation sites; the app does not call absolute addresses or access private ivar offsets.

- `0x4af1a4`, `_UIContextMenuLiquidMorphPresentationAnimation.prepareTransitionToView:` → `sub_4aea18`: installs menu/preview containers, applies final layout, and prepares animatable properties.
- `0x4b0b70`, `performTransition` → `sub_4af1f8`: resolves source and destination previews; creates `_UILiquidMorphAnimation(morphables:)`; chooses direct versus attachment-point morph; coordinates completion with the menu controller.
- `0x4b11b8` → `sub_4b11e8`, `morphPreviewFromAttachmentPoint`: a clear **10×10** UIView, corner radius **5**, targeted at the menu attachment point in the platter container. It inherits interface style. This is distinct from scaling the full source rectangle.
- `0x467324`: exported Swift dispatch thunk for `morph(from:to:through:alongsideAnimations:completion:)`.
- `sub_45d91c`: attachment morph path; checks Reduce Motion, selects shapes by area, uses a pivot, hiding assertions, morph views, portals and lensing machinery, then arranges cleanup.
- `_UIMagicMorphAnimation`, `_UIMagicMorphView`, and `_UIMorphAnimationSettings` carry independent position/size/content springs, cross-blur, intermediate shapes and lensing. Calling the native coordinator preserves these details instead of approximating them with sampled keyframes or guessed filter constants.

The original app gate was `!"".isEmpty` plus equal width/height and an iOS 26.2 check. Its animation manually sampled SDF displacement/keyframes; source content was physically extracted and restored on a fixed timer. The replacement uses custom views and targeted previews, without UIKit's context-menu controller or interaction.

### iOS 26.0 compatibility audit

Installed Apple's iOS 26.0 runtime (23A343) and inspected its UIKitCore separately in Hopper (`UIKitCore-iOS26`). The `through` entry point is absent in this release; the initial availability test failed and exposed the need for the older native path.

- `0x4664d8`, `performTransition` → `sub_464f20` → `sub_41dcf8`: calls `morph(to:parameters:alongsideAnimations:completion:)`.
- Its context-menu path sets `manageViews = false`, enables intermediate shapes for the button-to-menu transition, and leaves kick/smoothness nil. `manageViews = true` removes the source from its parent; the round-trip test caught that difference.
- The original bridge used exported Swift dispatch thunks and the resilient Parameters initializer. This has been replaced by the Objective-C coordinator adapter below: UIKit itself selects and calls the appropriate native Swift implementation.
- `UITargetedPreview.init(view:parameters:)` centers on `visiblePath.bounds` and preserves the view transform. Using the full source bounds with an identity target was incorrect for cropped/transformed buttons; the new regression failed on both center coordinates and transform before the fix. Dismissal resolves the current parent and uses the presentation-layer transform, matching UIKit's dismissal preview preparation.

## ABI and lifecycle

`LiquidMorphTransition` delegates to the UIKit-only `LensTransitionRuntime` Objective-C module. It dynamically subclasses `_UIContextMenuLiquidMorphPresentationAnimation`, instantiates it using `initWithUIController:previousAnimation:`, and calls `performTransition`. A small context adapter supplies the host and destination preview. Overrides supply the source and pivot previews, disable accessories/background management, and skip standard-menu layout mutation. No UIKit context-menu controller, interaction, or menu list is created.

The coordinator calls its own version-specific Swift implementation. The bridge contains no mangled-name lookup, Swift weak imports, `dlsym`, `_typeByName`, `_openExistential`, private memory offsets, or copied Swift struct layout. It checks the complete Objective-C signatures of the base methods it invokes/overrides and of the source visibility assertion; missing or incompatible contracts leave the existing custom fallback available. Signature checks cannot detect behavioral changes in a future UIKit implementation.

Both directions use presentation semantics with reversed previews on close. UIKit's dismissal mode would remove the caller's host. A distinct detached transition container selects the intermediate-pivot branch on newer runtimes. The destination is the underlying `UIVisualEffectView`; targeting its wrapper previously left the backing glass at full size.

The adapter installs both alongside animations and completion before starting. UIKit invokes `performAllCompletions` on the adapter from its native completion closure (`sub_4b0b20` in the inspected 26.5 image). Installing `addCompletion:` after `performTransition` misses synchronous completion when UIView animations are disabled, even though registration returns YES; the new regression reproduced this before the fix. Completion drains the stored closures exactly once. The Swift wrapper retains the coordinator and hands views back on the next main-queue turn, after UIKit cleanup. The Objective-C dynamic initializer explicitly transfers its consumed receiver and retained result; the test verifies the native coordinator and context deallocate.

### Runtime identifiers

Private class and selector names, including selectors implemented by the adapter, are encoded in `Bridge/Sources/Identifiers.inc`. All adapter methods are registered dynamically, so conventional Objective-C method metadata does not reintroduce those names. A no-inline decoder reads volatile bytes to prevent compiler constant folding. The development-only `prototypes/ContextMenuMorph/Tools/runtime_identifiers.py` contains the readable mapping, regenerates the table with `--write`, and checks compiled artifacts with `--binary PATH`. It is not bundled in either app.

The optimized simulator framework and arm64 device object were checked for all mapped identifiers and old Swift morph symbols; neither contained them. `nm -u` on the device object shows only public UIKit/Foundation and Objective-C runtime imports. This removes static plaintext references; the identifiers necessarily exist at runtime after decoding.

Telegram accepts an optional `ContextControllerReferenceViewInfo.sourcePath` in source bounds coordinates. It also recognizes extractable-container radii, affine CAShapeLayer masks, and layer corner radii. Otherwise UIKit infers its own preview shape. Rectangular dimensions have no square restriction. Dismissal retargets the source's current position. If the source has left the window, the custom menu fades out and still completes. Unsupported runtimes retain the existing custom presentation fallback.

## Objective-C adapter validation

- Eight prototype XCTest cases pass in optimized Release on iOS 26.0, 26.5, and 27.0, including source visibility, cropped/transformed previews, released-highlight pixels, round trips, disabled animations, and coordinator/context deallocation.
- All eight also pass with actual Reduce Motion enabled on iOS 26.0 and 27.0; logs confirm the setting and original preferences were restored.
- The bridge compiles for arm64 iOS devices. Physical-device runtime behavior has not been exercised.
- Full Telegram simulator build passes. All 26 production gallery checks pass on each of iOS 26.0, 26.5, and 27.0, including composite profile sources and repeated navigation-button menus.
- The iOS 27 [production recording frames](../prototypes/ContextMenuMorph/Evidence/objc-adapter-ios27.png) show the glass/content morph and composite source return. The new build is installed and running on the requested iPhone 18 Pro, with app data preserved and the installed TelegramUI framework hash verified.
- The packaged TelegramUI framework contains neither the old morph Swift symbols nor the new coordinator class/initializer names as plaintext.

## Earlier animation validation

- Standalone prototype built and ran on iOS **26.0**, **26.5**, and **27.0**.
- **18 round trips on each of those OS versions**, six source shapes, menus above and below the source, repeated presentation, dismissal requested during presentation: all assertions passed.
- Four XCTest cases on each OS: real native round-trip/hierarchy restoration, accessory animation and concurrent rejection; detached-container rejection; removed-preview rejection; cropped/transformed preview geometry. All passed.
- Actual Reduce Motion tests passed on iOS 26.0 (all four tests, optimized Release build) and iOS 26.5. Logs confirmed `ReduceMotion=true`; preferences were restored. The iOS 26.0 suite also passed optimized Release without Reduce Motion.
- iOS 26.5 screen recording inspected as a contact sheet: expanding circular intermediate geometry, text deformation, glass refraction and return to the source are present.
- Full Telegram debug simulator build passed using the repository-required Make.py/Bazel workflow.
- Production Telegram gallery: **14 checks on iOS 26.0, 26.5 and 27.0**, including source removal, menu resize, rotated/scaled and off-center cropped buttons, and six dismissals requested during presentation; all passed.
- Production recordings inspected on all three OS versions: the glass backdrop and content morph together, with lensing and a reverse transition. See [iOS 26.0 frames](../prototypes/ContextMenuMorph/Evidence/ios26.0.png), [cropped/transformed iOS 27 frames](../prototypes/ContextMenuMorph/Evidence/cropped-ios27.png), [iOS 26.5 frames](../prototypes/ContextMenuMorph/Evidence/ios26.5.png) and [iOS 27 frames](../prototypes/ContextMenuMorph/Evidence/ios27.png).

The minimum requested version (iOS 26.0) is now exercised directly, as are iOS 26.5 and 27.0. UIKit chooses its native implementation through the checked Objective-C coordinator interface, without an OS minor-version dispatch table. Physical-device and untested OS-release behavior remain outside this simulator validation; private API stability is not guaranteed by a version check.

## Separately rendered source backgrounds

Profile header buttons put their icons/text in `ContextReferenceContentNode`, but draw their backgrounds through individual mask views in a shared `NavigationBackgroundNode`. The reference node supplies the mask's rounded path in source coordinates, including its changing visible bounds during partial header collapse.

The header also identifies the common ancestor containing foreground and backdrop. Before opening hides either, the transition captures a cropped composite image in source coordinates. Opening continues to use the original live source preview. Closing morphs the menu into the composite preview at the source's current position, carrying its background and foreground together; the actual separate mask stays hidden until the final handoff. Native visibility assertions suppress the real source and the temporary target independently. Completion removes the temporary preview and restores the real source in the same update. A detached source takes the existing fade fallback without adding a ghost target.

This replaces the in-place backdrop fade, which restored visibility at the right time but did not move the background with the menu. The snapshot deliberately preserves the button appearance captured when opening. More-button activation restores full foreground opacity, cancels the press-release fade, and captures the composite with `afterScreenUpdates: true` **before** presenting the menu. The reference node hands that prepared image to the transition once. Capturing later with `afterScreenUpdates: false` was still dim even after clearing the fade: LLDB showed model opacity 1.0 but presentation opacity 0.4 at capture time. Subsequent gesture cancellation cannot restart the fade, and the next press still receives normal highlight feedback. The pixel regression reproduces the old 102/255 brightness and passes with the committed capture; all seven tests pass in optimized Release on iOS 26.0 and 27.0. The full Telegram build passed. On the actual More button, LLDB confirmed presentation opacity 1.0 after prepared capture, and a recording without animation breakpoints confirmed the dots and label are fully bright before the closing spring finishes, with no brightness jump at handoff. The build is installed on iPhone 18 Pro.

The gallery covers composite sources with normal dismissal, a partially collapsed source and immediate dismissal, and a removed source. It checks that the actual backdrop remains hidden during the closing morph and that its original hidden state and opacity are restored afterward. A pixel regression verifies that the captured image includes a separately rendered sibling backdrop rather than only foreground content. The composite snapshot test passed on iOS 27.0, and all six XCTest cases passed in optimized Release on iOS 26.0. All 26 production integration checks passed on both runtimes after this change. The iOS 27.0 recording was inspected for the moving composite backdrop, the full Telegram build passed, and the build was installed on the requested iPhone 18 Pro.

## Navigation button source glass

Contacts → Sort resolves its source to `GlassContextExtractableContainer`. Targeting that wrapper left its nested effect backdrop on screen during the morph. The container now exposes its underlying transition view, and `LensTransitionContainer` uses that native effect as the source preview, including the button content and backdrop together.

Three regression cases use the actual navigation glass container for normal, rapid, and removed-source dismissal. All 20 integration checks passed on iOS 26.0 and 27.0, and the full Telegram simulator build passed. The updated build was installed on the requested iPhone 18 Pro, where the user manually confirmed Contacts → Sort works correctly.

## Source visibility across menu lifetime

UIKitCore `-[_UIContextMenuUIController hideSourcePreview:]` (`0x1522ed4` in the iOS 26.5 image) takes `[preview.view _vendAssertionForOverrideAlpha:0]` and retains it separately from the animation. `endSourcePreviewHidingIfNeeded` releases that assertion. The selector is also present in iOS 26.0. The morph coordinator alone releases its temporary suppression when presentation completes, which previously revealed the button while its menu was still open.

The custom menu now retains the same native assertion from presentation's alongside callback until dismissal cleanup. It leaves the source's model alpha and hidden state intact and lets multiple assertions coexist, so cleanup of an older transition cannot reveal the source of a newer one. Owner teardown releases the assertion as well.

A regression test failed without the retained assertion and passed with it. It checks retention after native cleanup, overlapping claims, and preservation of the source's model visibility. The gallery additionally reopens the same navigation glass source six times without the usual delay between menus, alternating normal and immediate dismissal. Five XCTest cases passed on iOS 27.0 and optimized Release on iOS 26.0; all 26 integration checks passed on both runtimes. The repeated-source recording confirms the button stays suppressed while the menu is open and returns during dismissal. The final full Telegram build passed and was installed on iPhone 18 Pro.

## Telegram integration gallery

A simulator-only gallery exercises the production `ContextController` while signed out. Launch Telegram with `--context-menu-morph-gallery` to inspect six shapes manually. Add `--context-menu-morph-checks` to run 26 automatic presentation/dismissal checks, including a resized menu, removed source, top/bottom placement and dismissal during presentation. Each completion checks the source frame, hierarchy and visibility. No account actions or messages are performed.

## Rapid profile-menu reopening

Profile source masks used to be saved/restored independently by each menu. A new regression (`--context-menu-morph-gallery --context-menu-morph-overlap`) reopens the same composite source 150 ms into its previous dismissal. Before the fix, the new menu acquired an already hidden mask, then the old completion restored it to visible beneath the new menu; the regression failed at that handoff. The newer menu could subsequently restore the saved hidden state, leaving the button background missing. Capturing a fresh return image during that overlap also captured a suppressed backdrop.

`ContextMenuSourceLease` now counts active claims per decoration and restores the original hidden state only after the last claim ends. Claims preserve originally hidden decorations and do not mutate alpha. The source's clean composite image remains available across overlapping menus, and More activation reuses it instead of capturing the suppressed source. The last owner discards the image so subsequent independent presentations capture current content. Unit coverage includes overlapping sources, reverse completion order, duplicate decorations, original hidden/alpha state, and snapshot lifetime.

Validation: ten optimized prototype tests pass on iOS 26.0, 26.5, and 27.0. The production overlap regression passes on all three runtimes after failing on the prior code. The full Telegram build and all 26 standard production checks on iOS 27.0 pass.

## Native handoff during rapid reopening

A separate pixel regression exposed the remaining flash: 350 ms into a second opening, the source region was still solid red even though the real source's presentation opacity was zero. UIKit had installed a returning `_UIReparentingView` / `_UIPortalView` beside the source. Hiding the real source or the caller's old animation host did not remove those pixels.

UIKitCore `initWithUIController:previousAnimation:` (`sub_4ae5b4` in 26.5) copies the previous coordinator's native `morphAnimation`. Passing nil on every transition created independent returning and opening renderers. The adapter now finds the active driver through a weak-key/weak-value map and passes its coordinator to this initializer. Only an already started driver with an outstanding native completion is eligible. UIKit handles the ongoing morph and its portals itself; the app does not locate or remove UIKit's private views.

Opening and closing use the real source view as their shared identity, including when a profile closes into a separate composite snapshot. The existing source/mask leases still cover both owners until cleanup. Optimized pixel regressions for both direct and composite returns pass on iOS 26.0, 26.5, and 27.0, checking the source area during overlap as well as both completion callbacks and restored hierarchy. All twelve prototype tests pass on those runtimes, and the private-identifier binary audit passes.

The full Telegram build passed. The production overlapping-profile check and all 26 standard menu checks passed on iOS 26.0 and 27.0. The recorded second opening takes over without leaving the returning button visible. The build is installed on the requested iPhone 18 Pro; the installed framework hash matches the tested artifact.

## Dismissal during presentation (2026-09-29)

A close requested while the menu is still opening starts immediately and takes over the running morph. Before this, `LensTransitionContainer.animateOut` held the close until the opening's completion, and `ContextControllerNode.animateOut` disables interaction at the first dismiss request, so an outside tap left an open menu that ignored every tap until the opening finished. That wait is long. UIKit reports a morph complete only when every spring has settled: on the iOS 27 simulator the opening completes 1.27 s after it starts and a close 1.67 s after it starts, while the menu reaches full size in about 0.25 s.

The takeover uses the same native handoff as rapid reopening. `LiquidMorphTransition.animate(..., interruptingCurrent: true)` starts a second driver while the first runs; the driver finds the in-flight coordinator by source identity and passes it as `previousAnimation`, so UIKit reverses the running morph from where it is. A plain second `animate` is still rejected. Both completions fire (together, in the measurements, when the close finishes). Only the newest transition clears `isAnimating`, and the container ignores a superseded opening's completion, so its deferred layout is never applied to a closing menu. If the source has left the window, the close fades at once instead of after the opening. UIKit still completes and releases the interrupted opening even after its host leaves the window (measured).

The morph itself does not block touches. It adds no Core Animation animations to app views (UIKit renders it through `_UIReparentingView` / `_UIPortalView`), so UIKit's hit-test rule for views with non-interactive UIView animations never applies, and the menu's model frame is final from the first frame. Rows hit-test normally from about 0.1 s into the opening, and the dismiss area throughout.

Coverage: `testCloseRequestedDuringOpenTakesOverImmediately` (close 0.3 s into the opening) and `testCloseRequestedAsOpenStartsTakesOverImmediately` (same run-loop turn) failed on the deferring code and pass on iOS 27.0, along with the other twelve prototype tests. The prototype app's 18 cycles, 12 of them dismissed as they open, pass. The gallery checks that dismiss 50 ms into presentation exercise this path in production.

Still open: the controller's dismissal completion, and therefore any action run from `dismiss(completion:)`, waits for the close to settle.

## Live profile sources

Profile reference nodes now provide a live transition-content factory. `ContextMenuSourceLease` shares its result across overlapping menus. The container reparents the actual foreground into an unpressed ancestor with a matching `NavigationBackgroundNode` (same color, blur, saturation, rounded geometry, and Reduce Transparency treatment). The source's shared-background mask stays hidden until the last lease ends. Both animation directions target the same live view; UIKit receives the original reference view as the logical source identity for interruption handoff.

The foreground continues to receive real icon/text updates while its menu is open. The last lease restores it to its original parent/index and removes the temporary backdrop. Dismissal retargets the current source position/affine transform; a removed source uses the existing fade fallback. Both More and Mute clear press/release opacity. The prepared UIImage, composite capture, snapshot cache, and PeerInfo dependency on LensTransition are removed.

A failing prototype pixel regression demonstrated the old behavior: after the foreground changed from pressed red to green, the return preview remained red at 102/255. Live extraction shows current green at full brightness. Coverage also exercises shared extraction ownership, restored hierarchy, a separate live backdrop, moved/transformed/removed sources, and native overlapping handoff. Twelve optimized tests pass on iOS 26.0, 26.5, and 27.0.

Actual profile validation caught an ASDisplayKit-specific extraction failure that plain UIView tests missed. Despite a comment in `_ASDisplayView.didMoveToSuperview`, this fork's `_removeFromSupernode` also removes the view. Direct reparenting from a node-backed parent into a plain UIView therefore detached the just-extracted foreground. The live-content container now explicitly removes the foreground from its old parent before inserting it into the new one, and does the same on restoration. The production gallery now uses real ASDisplayNode foregrounds and asserts both view and node restoration after overlap. Those checks and all 26 standard checks pass on iOS 26.0 and 27.0; the full Telegram build passes.

The corrected build was recorded on the actual profile More and Mute buttons, including a real Mute press and rapid close/reopen of both sources. Closing carries the rounded backdrop and full-brightness foreground together. After repeated dismissals, LLDB confirmed each actual foreground view is back under its reference node with alpha 1 and one restored child. The installed iPhone 18 Pro TelegramUI framework SHA256 matches the tested artifact. The optimized private-identifier audit also passes; no new private runtime identifiers were added.

## Frame rate (2026-10-02)

The morph is not a Core Animation animation. Its only CA animations are infinite `CAMatchPropertyAnimation`/`CAMatchMoveAnimation`s, which make UIKit's SDF and portal layers follow `AnimationKit.MagicMorphLayer`s. Those layers are owned by `UIViewInProcessLayerAnimationCoordinator`, and their model geometry never changes. `UIKit.InProcessAnimationManager` ticks the motion itself, by default from a display link on a background thread (the main-thread variant is behind the `AllowMainThreadInProcessAnimationManagers` default).

That link requests a range, not a rate. The morph closures wrap their animations in `_modifyAnimationsWithPreferredFrameRateRange:(48, 120, 0)`, with reasons 0x100038 and 0x10003e, and a probe showed these are identical for a native `UIButton` menu. The manager raises `preferred` from `-[CADisplay preferredFrameRateRangeForMaximumVelocity:]` (`sub_4a2148` in the 26.5 image). On a 120 Hz iPhone the morph still visibly ran slower than Telegram's own animations. `LiquidMorphTransition` therefore pins one display link at exactly 120 Hz while a morph moves, on screens whose `maximumFramesPerSecond` reaches 120. CoreList pins its scroll flights the same way (`PhysicsScrollEngine.maxRefreshRange`), after measuring that a range with a low floor let the system throttle to about 80 Hz. `SharedDisplayLinkDriver`'s `.max` (`30, 120, 120`) is such a range, which is why the morph does not reuse it. The difference was confirmed by eye on device. The simulator reports 60 fps and cannot show it.

Each morph's claim on that link ends at its completion or one second after it starts, whichever comes first. UIKit reports completion only once every spring has settled, about 1.3 s after an opening starts and 1.6 s after a close. Recordings put the visible motion's end at about 0.75 s and 0.7 s; the remaining frames differ only by anti-aliasing noise. The deadline also means a completion UIKit never delivers cannot keep the display at 120 Hz.

## Closing handoff

UIKit delivers a morph's completion from a main-queue drain and then, synchronously, removes its `_UIReparentingView`/`_UIPortalView`/`MagicMorphView` hierarchy. That cleanup puts the morph's source back on screen. When closing, that source is the menu, fully open. `LiquidMorphTransition` hands the completion over on the next main-queue turn, after the cleanup, so any frame committed in between showed the open menu once. With the hand-over stretched to 1.5 s in the prototype, the open menu stayed on screen for the whole gap.

The close therefore takes a visibility assertion on the menu in its alongside callback, the same way opening holds the button for the menu's lifetime. `finishDismissal` releases it after setting the menu's alpha to 0. Recordings with and without the assertion show the same closing morph frame for frame; it only keeps the menu hidden after UIKit's cleanup.
