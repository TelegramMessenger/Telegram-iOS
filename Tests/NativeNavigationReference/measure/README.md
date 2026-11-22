# Measuring a capsule change against native (2026-10-13)

How the bar's glass capsules were compared with iOS 27's own, frame by frame. The films the numbers below came from
were not kept; re-film to compare. Needs `ffmpeg`, Python 3 with Pillow, and the AXe CLI (`axe`) for touches.

## Filming

Both simulators were iPhone 18 Pro on iOS 27 (402 x 874 pt; screenshots and video frames are 3x). The coordinates
below are in points for that size. The simulator ids are from the original machine.

- **Native:** the reference app in the parent directory (`build.sh <udid> <outdir>` builds and installs it). On the
  original machine it is installed on simulator "iPhone 18 Pro K2" (`E643A78E-DB62-4DA4-9F54-BD0836F434AF`), shut down
  on 2026-10-14: `xcrun simctl boot` it first.
  Launch with `xcrun simctl launch <K2> org.telegram.NativeNavigationReference -systemDone 1`, so that tapping Edit
  shows the system Done checkmark circle. Its Edit button is at (362, 84) pt.
- **Ours:** go to Settings > Notifications and Sounds > Private Chats in Telegram (on the original machine, simulator
  "iPhone 18 Pro", `3A36B4F5-C2D0-41AA-8203-E46EA58CD43D`, logged in).
  Its Edit button is at (366, 85) pt. After a fresh launch, this AXe batch got there:
  `touch 341,819` (Settings tab), `swipe 200,680 -> 200,280 --duration 2.0`, `touch 173,741`, `touch 125,533`,
  with ~1.2-1.5 s sleeps between steps. Check with a screenshot: the scroll position can differ.
- **Recording:** `xcrun simctl io <udid> recordVideo --codec=h264 --force out.mp4 &`, then `kill -INT` it. The video
  has a variable frame rate (only changed frames are stored), so always read frame pts, never assume 60 fps.

## AXe traps

- **Every AXe call costs ~0.8-2.5 s,** even inside `axe batch`. Taps closer together than that cannot be produced, so
  tapping during the ~0.5 s animation is covered by a unit test
  (`test_inPlaceItemChange_newItemsTakeTapsMidAnimation`), not by footage.
- **`axe tap` (zero-duration down/up) does not fire our bar buttons, but it does fire native ones.** Use
  `axe touch -x X -y Y --down --up --delay 0.05` for a quick tap, and `--delay 0.45` for a held press. Release
  timing is unreliable: one 0.45 s hold came out as ~0.1 s.

## Tools

These need PIL, so run them with plain `python3`, not `python3 -I`.

1. `blue.py <framesdir> <video> <t0> <t1> > b.txt` extracts frames with their pts and counts blue pixels. Run it
   first.
2. `bbox.py <framesdir> b.txt` gives the tinted capsule's width, height and centre in points, per frame. It is the
   most reliable shape measure.
3. `delta.py <framesdir> | paste - b.txt` gives the per-frame change, which shows when motion starts, and the mean
   blue-minus-red, which tracks tint progress (mixed with area).
4. `sheet.py <framesdir> out.png <first> <last> [step]` makes a contact sheet to look at.

Measuring capsule size by thresholding against the white-glass background did not work; bbox only works once the
capsule is tinted.

## Measured, all times from the first blue frame

| Case | Native | Ours |
|---|---|---|
| 50 ms tap, shape | 52 -> 54 pt at +48 ms; above 50 pt for ~120 ms; 44 pt at +233 ms; no dip | At d311ca6fa7: 55 -> 60.7 pt at +38 ms; 44 pt at +200 ms; dips to ~42.7; settles ~46 (bbox reads ~0.7 pt high on ours) |
| 0.5 s press, shape | Holds the 57.3 pt press bulge (76 x 57), then only shrinks to 44 x 44 over ~0.2 s | At b5a9a01bea: the bulge flows into the checkmark with no step, but grows to ~62.7 pt (pulse x bulge) |
| Untouched change (earlier film) | Height 45 -> 54.3 at 0.10-0.12 s -> 44 at 0.30 -> 45.3; width 63.7 -> 44.3 by 0.30 | — |
| Tint | Full ~0.13 s after the change starts | At 0.1 s response: ~0.1-0.13 s. At 0.3 s response it took ~0.25 s, because UIKit starts drawing our effect change ~30 ms late |
| New checkmark sharp | ~+0.15 s | ~+0.2 s (not tuned) |

## Frame-by-frame layer probes (2026-10-14)

Films can only measure a tinted capsule, and during a press their bbox also takes in the press glow
(`_UIFlexInteractionLittleGlowView`, an 85 pt blue halo), so every film height measured during or right after a
press is inflated. The 50 ms tap "52 -> 54 pt" above is that, plus the press still growing toward its target: it is
not a pulse. Read presentation geometry instead:

- **Native:** launch the reference app with `-probe 1` (`CapsuleProbe` in `../main.swift`). Every frame it writes the
  right capsule's glass (`CABackdropLayer`) window frame, its bounds, and the transform of UIKit's press view
  (`UIPlatformGlassInteractionView`) to `<app data>/tmp/probe.txt`, with a `MARK` line at each item change.
  `-noopEdit 1` makes Edit do nothing, so a press shows the press and its release alone; `-scenario editCheck` gives an
  untouched change (the pulse alone). `python3 probe_series.py <probe.txt>` prints the series around each `MARK`.
- **Ours:** `inject_probe.py` (usage in its header) injects the same kind of sampler into Telegram through lldb. Our
  pulse is the container's transform and UIKit's press is a transform on the effect view's `_UIMultiLayer`, so
  `probe_series.py <probe3.txt> --ours <t0>` splits them: press = visible height / 44 / pulse. A breakpoint on
  `NavigationBarComponent.View.startInPlaceChange` printing `time.clock_gettime(time.CLOCK_UPTIME_RAW)` gives `t0` on
  the probe's clock (`CACurrentMediaTime`).

What they showed (iPhone 18 Pro simulator, iOS 27, 60 Hz):

| | Native | Ours |
|---|---|---|
| Press scale | uniform (L + 16) / L of the longer side: 1.2567 at 62.3 pt, 1.3636 at 44, overshoot ~1.27 | the same (1.2909 at 55 pt) |
| Release (normalized, from its first frame) | 0.98, 0.89, 0.77, 0.62, 0.42, 0.30, 0.12, 0.01, -0.12, -0.18, -0.24, -0.27, -0.28 (trough ~0.2 s), back to +0.07 at ~0.45 s | 0.96, 0.87, 0.74, 0.58, 0.42, 0.26, 0.12, -0.01, -0.12, -0.19, -0.25, -0.27, -0.28: the same curve |
| Pulse alone (height) | 1.20 at ~0.12 s after the change starts, 0.977 at ~0.33 s | 1.2018 at +0.105 s: the same |
| Composition | pulse x release (SwiftUI composes both into the glass's bounds) | pulse x release (container transform x effect-view transform) |
| Change starts after the items are set | +0.082 to +0.116 s (layout, platter update, SwiftUI's async update; no `ScheduledDelay` fires) | +0.015 s |
| Peak after a 0.5 s press, Edit -> Done | 49.4 pt (release trough x pulse peak) | 61.7 pt (pulse peak while the press is still ~1.12) |

So the two differ only in when the change starts relative to the touch-up: natively the pulse peaks in the
release's undershoot. Release timing under AXe varies (one native 0.5 s press released ~0.15 s after the action, and
there the native capsule grew past the press, 55.3 -> 56.8 pt).

## Push and pop against native Settings (2026-10-14)

`segments.py` gives how long each push or pop takes to come to rest, and `sidebyside.py` puts two films' bars next to
each other from their own first motion frames. Native Keyboards -> Text Replacement against our Notifications ->
Private Chats (back kept, a trailing capsule appearing): push 0.39-0.48 s native, 0.43 s ours; pop 0.40 s both. The
back circle stays put, titles ride their screens, and Edit materializes and dematerializes on the same frames, ours
going sharp (push) or vanishing (pop) about one frame (~33 ms) later. Our Settings root is a profile-style screen, not
a `NavigationBarNode`, so Settings -> Notifications still slides the whole bar: compare from Notifications down.

## A touch during a running transition (2026-10-14)

`axe swipe` moves the touch in ~60 pt jumps and never starts the native edge swipe; use `axe drag --steps 60`. AXe
cannot place a second touch inside a 0.45 s transition, so either:

- launch with `-touchTrigger push` (or `pop`, with `-startDepth n`): the transition starts on the drag's own
  touch-down, so the drag is moving while it runs. Start at depth 1 or more for a push: a touch that begins with only
  the root screen is never taken by the native recognizer;
- or slow every animation ×10 with the Simulator's own switch, `xcrun simctl spawn <udid> notifyutil -s
  com.apple.UIKit.SimulatorSlowMotionAnimationState 1` then `notifyutil -p` the same name (0 turns it off). UIKit reads
  it through `UIAnimationDragCoefficient`, and so do our transitions (`UIView.animationDurationFactor()`), so it works
  on Telegram too. The tracking spring slows with everything else, so read offsets in real time, not slowed.

`-probe 1` writes `CARDS` lines: each `_UIParallaxTransitionCardView`'s window minX, each screen's window minX, the
touch, whether a transition is running and `topViewController`. The findings are in the screen transition RE notes,
§6b.

Bar items during a drag: launch at `-startDepth 1 -longRight 1` (the pushed screen's right item is "Select Messages",
the root's "Edit") and film an `axe drag --steps 180` from the left edge: the capsules do not change while the finger
drags, only on release. `-twoText 1` adds a second text item, which iOS 27 gives its own capsule.


## The keyboard during push and pop (2026-10-14)

Findings: `docs/superpowers/specs/2026-10-14-native-navigation-keyboard-re.md`. Launch the reference app with
`-textField 1 -probe 1` plus `-focusAt <depths>` (and `-focusWhen willAppear`, `-startDepth n`, `-customInputView 1`,
`-guideBar 1`; see the header of `../main.swift`). The probe then writes `KB` lines (keyboard host frame, the
transition's keyboard wrapper views and edge shadow, first responders, keyboard-layout-guide bars) and `ANIM` marks
with each wrapper animation's parameters. `keyboard_run.sh` films one scenario and saves its probe;
`keyboard_table.py <probe> [t0 t1]` prints cards, host, wrappers, shadow alpha and first responder per frame.

The simulator sometimes comes up in hardware-keyboard mode (keyboard frames of height 0 or 270 below the screen) and
the software keyboard then never shows. Either run with `-customInputView 1` (a striped input view that goes through
the same machinery and always shows), or press Cmd-K in K2's Simulator window (Toggle Software Keyboard; it writes that
device's keyboard preference, so do not do it from code).

## Search bar on push and pop (2026-10-15)

`-searchBar 1` gives the root screen a stacked `UISearchController` search bar; `-searchBarAt 1` puts it on the pushed
screen instead. Tap Push at (201, 506) pt and the back button at (38, 85) pt. Per frame, the magnifier's leftmost dark
column in the search row (y 127–148 pt) gives its x, its minimum luminance its opacity, and the luminance range of a
column through the field at x = 250 pt the glass capsule. Results (spec
`docs/superpowers/specs/2026-10-15-chat-list-header-transitions-design.md`, "Results"): a field only the leaving bar has
stays put and fades as 1 − progress; one only the arriving bar has rides its screen at full opacity, its glass capsule
appearing on the last frame.
