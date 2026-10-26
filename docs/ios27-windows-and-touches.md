# iOS 26/27: keyboard window, window levels, and touch delivery

Verified on the iPhone 17 Pro simulator running iOS 27.0 (`UIKit-9127.0.66.1.105`) and on iOS 26,
by decompiling UIKitCore and by small standalone probe apps that dump window/view state and ask
`-hitTest:` directly. Everything below is measured, not inferred — most of it contradicts a plausible
guess, which is why it is written down.

## Getting the keyboard window

Do **not** call `+[UIRemoteKeyboardWindow remoteKeyboardWindowForScreen:create:]`. As of iOS 27 it
traps:

```objc
if (!dyld_program_sdk_at_least(/* iOS 27.0 */)) {
    os_log_fault(..., "BUG IN CLIENT OF UIKIT: %@ is directly calling private method %s");
    /* ...returns the window... */
} else {
    _bs_set_crash_log_message(...); __builtin_trap();      // brk #0
}
```

The gate is the **linked SDK**, not the OS version: built against the iOS 27 SDK (which this project
is, Xcode 27), the call crashes on iOS 27. Built against an older SDK it still works but emits a
public os_log fault naming our bundle id.

Use the keyboard scene delegate instead — no such guard on that path:

```objc
// UIViewController+Navigation.m, -[UIApplication internalGetKeyboardForScene:]
id keyboardSceneDelegate = [windowScene keyboardSceneDelegate];   // scene component
UIWindow *keyboardWindow = [keyboardSceneDelegate keyboardWindow];
```

It returns nil before the keyboard has ever been created for that scene, and also whenever the
keyboard UI is hosted out of process — `-[UIKeyboardSceneDelegate keyboardWindow]` returns nil unless
`+[UIKeyboard isInputSystemUI]`, so in that configuration an app has no in-process keyboard window at
all. Treat nil as "no keyboard surface" rather than assuming a window.

Two related facts, both measured on iOS 27 with `+[UIKeyboard inputUIOOP] == 0`:

- The keyboard lives in an internal `_UIKeyboardInputScene` (role `_UISceneSessionRoleKeyboardInputScene`),
  as a `UIRemoteKeyboardWindow` whose root view controller is a `UIInputWindowController`. The window
  is flagged `isInternalWindow`, so it appears in **neither** `UIWindowScene.windows` nor
  `UIApplication.windows` (both filter internal windows since iOS 16 — the filter keys off the linked
  SDK, in `-[UIRemoteKeyboardWindow isInternalWindow]`).
- `keyboardView` still resolves the old way inside that window: `UIInputSetContainerView` →
  `UIInputSetHostView`, whose bounds are the real keyboard height.

## Window levels: an app can never draw above the keyboard

- `UIRemoteKeyboardWindow` sits at level **1e7 + 1**.
- `-[UIWindow _adjustedWindowLevelFromLevel:]` clamps any non-system app's window level to a ceiling
  of exactly **1e7**. Requesting `1e7 + 1` yields `1e7`.

So a window of ours can tie the keyboard's level but never beat it. Measured: a view in an own window
at the clamped level draws *behind* the keyboard (its colour only bleeds through the translucent
keys). Adding a subview to the keyboard window itself does draw on top of the keyboard.

Because of that clamp, "put it in a window above the keyboard" is not an available strategy; content
that must appear over the keyboard has to live *in* the keyboard window. `NavigationController`
already does this: with the keyboard up it re-parents `globalOverlayContainerParent` into the keyboard
window (`NavigationController.swift`, the `statusBarHost.keyboardWindow` branch), and
`GlobalOverlayPresentationContext.currentPresentationView` does the same for its own overlays.

Note that `UIRemoteKeyboardWindow` declines points that are not over the keyboard's own content: its
`-hitTest:` returns nil there rather than itself, so a touch above the keyboard falls through to the
window below unless something in that window's hierarchy claims it.

### Never convert coordinates between the app window and the keyboard window (iOS 27)

Because re-parenting puts content in a second window, it is tempting to convert a frame from the app
window into it. **On iOS 27 that conversion fails and produces NaN**, because the keyboard window is
hosted on a *different `UIScreen` object* than the app's window (same bounds, same `UIScreenMode`
object - it is the same physical display, just a second `UIScreen` instance). UIKit routes
`-[UIWindow convertPoint:toWindow:]` through both windows' screens and refuses a cross-screen
conversion:

```
Invalid UIScreen coordinate space conversion: Attempting to convert rect {{347, 379}, {0, 0}}
from <UIScreen: 0x103e00140; bounds: {{0, 0}, {375, 667}}; mode: <UIScreenMode: 0x10dd40540; ...>>
to <UIScreen: 0x10ddb5a40; bounds: {{0, 0}, {375, 667}}; mode: <UIScreenMode: 0x10dd40540; ...>>,
which is not a valid conversion; returning CGRectNull
```

It only *logs* - the returned point comes from `CGRectNull`, whose origin is infinite, and the app dies
one assignment later with `CALayerInvalidGeometry: CALayer position contains NaN`. This killed the
voice/video-message recording overlay: `-[TGModernConversationInputMicButton updateOverlay]` positioned
its circles by converting the mic button's centre into the overlay container, which
`ChatTextInputMediaRecordingButtonPresenter.present()` parks in the keyboard window whenever the
keyboard is up. It runs on every display-link tick while recording, so the log came at frame rate.

Predict the mismatch (`parentWindow.screen == selfWindow.screen`) rather than detect the bad result
afterwards, and relate the two windows through their `frame`s in the mismatched case - for two
full-screen windows on the same display that is the identity, which is the answer
`-convertPoint:toWindow:` would have given had it accepted the pair. Note the `screen` *getter* is not
deprecated (only `-setScreen:` is), so reading it does not trip `-warnings-as-errors`.

In Swift, use `UIView.convertAcrossWindows(_:to:)` (Display, `UIKitUtils.swift`), which does exactly that
and falls back to a plain `convert` when the two views share a window or a screen. It was written for the
second victim: sending a voice message, a round video or media with the keyboard up. Those send animations
(`ChatMessageTransitionNode`, sources `.audioMicInput`, `.videoMessage`, `.mediaInput`,
`.groupedMediaInput`) run in a global overlay, which is the keyboard window while the keyboard is up, and
converted the sent bubble's rect from the app window into it: `CGRect.null`, then an invalid-frame assertion
in `-[ASDisplayNode setFrame:]` (debug) or a skipped frame and a misplaced animation (release). Text sends
animate inside the item node and never cross windows; so do sticker sends, which are the other users of the
file's layer-level `convertAnimatingSourceRect…` helpers.

## A layer that renders nothing receives no touches

**`-hitTest:` is not the whole story.** A view whose layer renders nothing at all — `backgroundColor`
never assigned (so `layer.backgroundColor == nil`) and no `contents` — does not receive real touches,
even though `-hitTest:withEvent:` returns it perfectly normally. Verified on iOS 26 and iOS 27.

Probe results (plain `UIView`s, no overrides, asked via `-hitTest:` in both the app window and the
keyboard window): `nil` background, `.clear`, `alpha 0.0001`, `alpha 0.4`,
`layer.hitTestsAsOpaque = YES`, and a transparent `UIImageView` **all** return the view. So the filter
is in touch delivery, against what the layer actually renders, and cannot be reproduced by calling
`-hitTest:` yourself.

Consequences when a transparent view exists to catch taps:

- Giving the layer fully transparent `contents` (a 1x1 empty image) is enough, and is the preferred
  fix — it depends on no threshold.
- A near-zero background alpha also works, but only above some undocumented opacity threshold:
  `alpha 0.0004` worked where `0.0001` did not. Don't rely on it.
- Beware `NavigationBackgroundNode`: `updateColor` early-returns when the colour is unchanged
  (`Display/Source/NavigationBackgroundView.swift`), so a node constructed with `.clear` and then told
  `.clear` never assigns a background colour even once, and its layer stays completely empty. That is
  how `ContextSourceContainer`'s full-screen background silently stopped catching the tap-outside that
  dismisses a context menu — visible only with the keyboard open, because that is when the menu is
  re-parented into the keyboard window and the tap has nowhere else to land.

There are ~24 other `NavigationBackgroundNode(color: .clear)` sites in the project; any of them relied
upon for touches rather than decoration has the same latent problem.

## The keyboard rotates only by following the app window (iOS 26)

`UIRemoteKeyboardWindow` is a `UIApplicationRotationFollowingWindow`. On iOS 26 it has exactly one
resize path on rotation, and it is driven by a notification the **application** window posts:

```
__HandleWindowContentRotationNotification_block_invoke
  → -[UIApplicationRotationFollowingWindow applicationWindow:didRotateWithOrientation:duration:]
  → -[UIRemoteKeyboardWindow _setRotatableClient:toOrientation:updateStatusBar:duration:force:isRotating:]
  → -[UIWindow _rotateWindowToOrientation:updateStatusBar:duration:skipCallbacks:]
```

A window posts `UIWindowWillRotateNotification` / `UIWindowDidRotateNotification` only if it has a
registered rotation client, and **UIKit registers one inside `-[UIWindow setRootViewController:]`,
only when the window already belongs to a `UIWindowScene`.** A window whose root view controller was
assigned while `windowScene == nil` therefore never posts them, and the keyboard never learns that
anything rotated: it keeps its launch orientation and bounds, pinned to the pre-rotation bottom edge,
and the `keyboardWillChangeFrame` the app subsequently receives still carries the old height.

The window itself is unaffected — it resizes through the scene-geometry path
(`UIWindowSceneDidUpdateEffectiveGeometryNotification`), so the app's own layout is correct and only
the keyboard is wrong. That asymmetry is what makes this read as a keyboard bug rather than a window
one.

This is exactly the app's own shape: the window is built unattached in `didFinishLaunching` (see
`13a2694420`'s message for why it must be) and bound to the scene later, so `AppDelegate.attach`
re-assigns the root view controller once the scene is bound. Measured alternatives that do **not**
work: re-assigning the same controller object (UIKit's setter early-returns and registers nothing),
the same round trip performed before `windowScene` is assigned, re-assigning `windowScene` itself,
resetting `window.frame` to the scene's coordinate space, and
`setNeedsUpdateOfSupportedInterfaceOrientations()`. Only a genuine value change with the scene already
bound works.

**iOS 27 does not reproduce this** — the keyboard geometry comes from elsewhere there (its window is
on a different `UIScreen` object than the app's), and it rotates correctly either way. A fix for this
cannot be verified on a 27 simulator; it passes with and without.

## Reproducing this kind of finding

Neither of the two surprises above is visible from the code, and both were found the same way: build a
~50 line standalone UIKit app, install it on the simulator, and dump the state in question
(`_scenesIncludingInternal:`, `_allWindowsIncludingInternalWindows:onlyVisibleWindows:`, window levels,
`isInternalWindow`, view trees, `-hitTest:` results) from `simctl launch --console`. Emulating touch
delivery by walking windows front-to-back and asking each one's `-hitTest:` identifies which window
would claim a touch without needing to inject one — but note that it will **not** reproduce the
rendering-based filter described above, which only shows up for real touches.
