# Handoff: navigation bar transitions and glass capsules (2026-10-14)

This is for an agent taking over branch `navbar/transitions`. It assumes no memory of earlier sessions: everything you
need is here, in the repo's `CLAUDE.md`, or in the documents this file names. Read it top to bottom once. After that,
"Open decision" and "What is left" are the working sections.

## Status at a glance

- **Branch:** `navbar/transitions`. The last code commit is `b8b5da2451`: an accent right button's own circle (spec
  `docs/superpowers/specs/2026-10-15-accent-right-button-circle-design.md`, plan
  `docs/superpowers/plans/2026-10-15-accent-right-button-circle.md`) and its merge into the outermost platter (one glass
  container at smoothness 12, see the spec's "A platter without a partner"), after the user's corrections to plan 2
  (below). Before plan 2:
  push and pop on Core Animation keyframes (spec `docs/superpowers/specs/2026-10-14-navbar-keyframed-transitions-design.md`,
  plan `docs/superpowers/plans/2026-10-14-navbar-keyframed-transitions.md`, all 11 tasks done), that work's
  whole-branch review fixes (`65d148a74c`), the bake-cost fix (`b72e9d3b5f`), and two bar-button fixes: Chat Themes'
  right button through node loans (`db28321bae`) and the moon/sun icon hosted only in a window (`aa40fbbd4a`). The branch is stacked on `navbar/component`
  (tip `23fc25b2d5`).
  - On the original machine both live in the worktree `.claude/worktrees/navbar-component` of the main checkout.
    Its submodules are populated.
  - Nothing is merged into master and nothing is pushed.
  - Local master has moved past `navbar/component`'s base, so expect a rebase before any merge.
- **Plan 2 (the chat-list header)** landed on top, through its whole-branch review fixes (`82c0863b33`) and the
  user's two corrections (`6680ef10ec`).
- **Tests** at the plan-2 tip, all green:

  | Target | Result |
  |---|---|
  | `//submodules/TelegramUI/Components/NavigationBarComponent:NavigationBarComponentTests` | 137/137 |
  | `//submodules/TelegramUI/Components/NavigationBarNode:NavigationBarNodeTests` | 75/75 |
  | `//submodules/Display:DisplayTests` | 225/225 |

- **Build:** `debug_sim_arm64` and `release_arm64` are green after the accent circle's merge rework (`2db63d7124`,
  release 431 actions); `debug_sim_arm64` green at the search fix and the review fixes.
- **Simulator:** the debug build is installed on the original machine's "iPhone 18 Pro" simulator
  (`3A36B4F5-C2D0-41AA-8203-E46EA58CD43D`); the native reference app on "iPhone 18 Pro K2".
- **Open from the keyframes work (2026-10-14):**
  - the keyboard: it follows the screens as keyframes, unverified with the software keyboard (both simulators are in
    hardware-keyboard mode). UIKit does it differently (see "Keyboard" under "Resolved after the keyframes review");
    the user chose to keep today's rule;
  - the edge effect between bars of different backdrop heights (laid out at the taller height and moved) is pinned by a
    unit test but not checked by eye;
  - the legacy glass (below iOS 26) under keyframes is unverified;
  - films were not compared frame by frame with the per-frame build; the curves' exactness rests on the unit tests
    (keyframe samples equal the curve, the curve equals the stepped springs to 1e-9);
  - the push's first origin is the commit's, adopted by the model: a catch or retarget before that commit's read-back
    resolves uses the bake's now.
- **Open:** the deferred minors of both whole-branch reviews (see "Deferred minors"); from the
  2026-10-14 glass work: native's leaving outline loses contrast faster than its spring in the first frames, the
  labels' movement with a growing capsule, the push's ~0.08-0.1 s glass delay, the in-place path's critically damped
  appear/leave, and a push/pop layer seen frozen once at ~0.96 (not reproduced); then the merge decision.

## Ground rules from the user

- **Never push.** Committing is fine. When the work is done, offer "merge into local master" or "keep the branch" and
  let the user choose.
- **Don't touch the main checkout's uncommitted work.** Other sessions work in it and on local master. Never run
  `git checkout`, `git restore` or `git reset` over uncommitted changes.
- **Full app builds run in the main agent, never in subagents.** There is no per-module build; see "Build" in
  `CLAUDE.md`.
- **Simulator installs:** the standing default is "build only, the user installs and verifies". For this work the
  user asked for launches on "iPhone 18 Pro" and accepted reinstalls there after each build. If unsure, ask.
- **Specs and plans live in-tree** under `docs/superpowers/specs/` and `docs/superpowers/plans/`.
- **Reproduce iOS exactly.** The user's direction for this feature was to adopt the native timing, bounce and
  animations, taken from reverse engineering of UIKitCore and SwiftUICore (iOS 26 and 27), checked against film of
  native apps. Every constant comes from those sources, not from eyeballing.
- **TDD, with a behavioural RED.** Each change gets a failing test first. A test that only fails because the new API
  doesn't compile does not count: break the implementation in place, watch the test fail, then restore it. Record
  decisions as rulings: what was decided, why, and the cost if wrong.

## What the feature is

`NavigationBarImpl` was replaced by one glass bar for every screen: `NavigationBarNode`, rendered by
`NavigationBarComponent`. That work is on `navbar/component` and has three phases (spec
`docs/superpowers/specs/2026-10-13-navigation-bar-component-design.md`). This branch makes the navigation container
animate between two bars the way `UINavigationBar` does on iOS 26/27.

- **Titles** ride their screens in clips, like UIKit's matching views.
- **Screens:**
  - tap push and pop run on UIKit's critically damped spring, played by the render server as Core Animation keyframes,
    so main-thread work cannot make them hitch (a dragging finger stays per frame);
  - swipe back follows UIKit's tracking, flick and finish rules, except that it stops at either end instead of
    rubber-banding and its springs do not overshoot (a decision, see "Rulings");
  - both screens are drawn as cards with UIKit's shadow and dim.
- **Glass capsules** (back, left and right buttons) are drawn once above both screens and animate like SwiftUI's
  toolbar glass. Matched capsules morph; one-sided capsules materialize or dematerialize; a kept capsule whose items
  change pulses and cross-fades its tint.
- **In-place changes:** when a bar's own items change (Edit <-> Done, back <-> edit mode), its capsules animate the
  same way, on the bar's real capsule.
- **Slow Animations** (`UIView.animationDurationFactor()`) slows all of it.

### Documents (all committed)

- **Spec (what):** `docs/superpowers/specs/2026-10-13-navigation-bar-transitions-design.md`.
- **Plan 1 (infrastructure):** `docs/superpowers/plans/2026-10-13-navbar-transitions-1-infrastructure.md`. Done,
  reviewed and fixed.
- **Plan 1b (native behaviour):** `docs/superpowers/plans/2026-10-13-navbar-transitions-1b-native.md`. Tasks 1-3 are
  done; 4 and 5 are left.
- **Reverse-engineering notes:**
  - `docs/superpowers/specs/2026-10-13-native-navigation-bar-transition-re.md` (the bar);
  - `…-native-navigation-screen-transition-re.md` (screen slide, interactive pop);
  - `…-native-navigation-glass-platters-ios27-re.md` (SwiftUI glass: springs, materialize, scale pulse).
- **Keyframes work:** spec `docs/superpowers/specs/2026-10-14-navbar-keyframed-transitions-design.md` (its §6 has the
  spike's measured answers), plan `docs/superpowers/plans/2026-10-14-navbar-keyframed-transitions.md`. Done.
- **Keyboard RE note:** `docs/superpowers/specs/2026-10-14-native-navigation-keyboard-re.md` — what UIKit does with
  the keyboard during push, pop and swipe on iOS 27 (read in Hopper, measured on the reference app). Not adopted, by
  the user's decision.
- **Native reference app:** `Tests/NativeNavigationReference/` holds a minimal UIKit app (`main.swift`, `build.sh`)
  used for film and lldb comparison. `measure/` beside it has the frame-measuring scripts and every measured number
  (`measure/README.md`).

## Code map

- **Display:** `submodules/Display/Source/`
  - `NavigationTransitionCoordinator.swift`: runs a push or pop, owns the screen cards, shadow and dim, lifts both bars
    and drives progress.
  - `NavigationTransitionSpring.swift`: `NavigationTransitionSpring` (an exact damped-oscillator step;
    `.noninteractive` ζ1/r0.3, `.interactive` ζ0.85/r0.3, `.tracking` ζ0.85/r0.08; `init(duration:bounce:)` is SwiftUI's
    conversion). `NavigationTransitionProgressDriver` now drives only a dragging finger.
  - `NavigationSpringCurve.swift`: a spring as a function of time (value, velocity, rest time, stop-at-target, retarget,
    re-base).
  - `NavigationKeyframes.swift`: the keyframe timing (120 Hz, linear, Slow Animations as `speed`), the animation
    factory, and `NavigationAnimationClock` (one layer-local now per bake, a commit-resolved first origin the model
    adopts, explicit origins for retargets and releases; a group ends at its clock animation's completion).
  - `NavigationTransitionTimeline.swift`: the progress sampled once, for the bar layer, the renderer and the container
    (keyboard keyframes, the status bar's scheduled flip).
  - `NavigationInteractivePopTracker.swift`: swipe-back rules (the target clamped to 0...1, 3-sample statistics,
    edge flick, the finish decision). Used by `Navigation/NavigationContainer.swift`.
  - `NavigationBarTransitionLayer.swift`: holds the lifted bar contents in clips that follow the screens, baked as
    keyframes from the timeline (set per frame while a finger drags).
  - `NavigationBarTransition.swift`: the source and renderer protocols. The renderer has
    `beginTransition(isInteractive:toTop:)` and `endInteraction(towardTop:)`.
- **NavigationBarComponent:** `submodules/TelegramUI/Components/NavigationBarComponent/Sources/`
  - `NavigationBarComponent.swift`: the bar's row (title, capsules, iPhone Duo column, the `.slide` secondary content,
    `plattersDetached`). `update(...)` decides in-place changes. The `.morph` style is gone.
  - `NavigationBarGlassAnimation.swift`: the shared glass model. `NavigationBarGlassSettings` has the transition
    spring 0.416/bounce 0.25, materialize 0.416/0, blur 10, the pulse springs and delays, a 1.2 cap and the tint
    cross-fade; also `NavigationBarGlassSpring`, `NavigationBarGlassPulse` and
    `navigationBarGlassMaterializeScale`.
  - `NavigationBarPlatterTransitionView.swift`: the capsules during a push or pop, with their own glass views, as curves
    baked into keyframes on their own clock; iPhone Duo's column is three more capsule roles.
  - `NavigationBarInPlaceAnimation.swift`: in-place changes on the bar's own capsules (details below).
  - `NavigationBarContentView.swift`: one content's buttons and title. `update(..., itemsTransition:)` lets the bar
    swap items at once while the title keeps its transition.
- **NavigationBarNode:** `submodules/TelegramUI/Components/NavigationBarNode/Sources/`
  - `NavigationBarNode.swift`: the screen's bar, a transition source with roles.
  - `NavigationBarTransitionRenderer.swift`: draws the shared backdrop (baked at the taller bar's height) and the
    platter view, on every phone.
- **Tests:**
  - Display: `NavigationBarTransitionCoordinatorTests`, `NavigationTransitionSpringTests`,
    `NavigationInteractivePopTrackerTests`.
  - Component: `NavigationBarComponentViewTests`, `NavigationBarPlatterTransitionViewTests`.
  - Node: `NavigationBarNodeTests`.
- **Elsewhere:** `ItemListController` now animates bar-button changes after the first state (it passed
  `animated: false` before).

### How in-place changes work (the most recent work)

- **When a side changes in place:** `NavigationBarComponent.View.update` checks the side when the transition is
  animated, a previous primary content exists, neither the old nor the new state has a secondary content or an iPhone
  Duo column, and the platters are attached.
  - The left side changes when `back` changed or its button's id or content changed. A badge change is not an item
    change.
  - The right side changes by `navigationBarCapsuleItemsDiffer`. A change of `isEnabled` only, or a `.custom`
    content's own state, does not count.
- **Before the content updates:** the leaving items are snapshotted from the content view's buttons container
  (`inPlaceLeavingItems`). The content view then takes the new items with `.immediate`.
- **Changed capsule:** it stays the same `GlassContextExtractableContainer`. Its frame springs to the new frame on the
  transition spring, and it pulses (`NavigationBarGlassPulse`, applied as the container's transform). The old snapshot
  dematerializes in place while the live items materialize (scale up to 1.2, at most 16 pt larger; alpha; blur 10). A
  tint change is handed to UIKit once, through an animated `update` at a 0.1 s response
  (`NavigationBarGlassSettings.uikitTransition(for: .inPlaceTint)`).
- **New capsule:** created invisible, then `isVisible: true` animated, plus a scale from the materialize scale.
- **Removed capsule:** `isVisible: false` animated, scaling up as it goes. It stops taking touches and leaves at rest.
- **Driving:** one display link per bar drives all of this, divided by the duration factor. A later layout retargets
  the springs (`retargetInPlace`). Detaching the platters (a push or pop starting) or an update that cannot be in
  place ends every in-place animation at its final state (`finishInPlaceAnimations`).
- **Why it is on the real capsule:** it used to run as an overlay with the real capsules removed from the hierarchy.
  That made UIKit's press bulge jump back to rest at the swap, and dropped every tap for ~0.5 s. See "Pitfalls".

## Resolved: the swell after a tap (2026-10-14)

The open decision about our capsule swelling more than native after a tap was investigated (option (a), the binaries
plus frame-by-frame layer probes) and closed: native multiplies the press and the pulse exactly as ours does; only its
change starts later. The user chose to keep ours as it is. See "Rulings" (Pulse and items) and the glass RE notes §6.
The film table that used to stand here (54/57 pt native) was inflated by the press glow; the probe values replace it.

## Resolved after the whole-branch review (2026-10-14)

The review of `89abe64512..d311ca6fa7` raised 15 findings. The user had five fixed first:

- **Items arriving mid-push** (`2391069afd`). A list screen applies its bar buttons just after its push begins, so
  its Done appeared without animation (Notifications -> Private Chats). A capsule that had begun to leave is taken
  over when its bar's items arrive, as SwiftUI's resolver reuses a removed entry, and items that change mid-transition
  cross-fade in the kept capsule from a rendered copy of what they showed.
  - `ItemListController` does wait for its first state before it reports `ready`, but it applies the bar buttons in
    `afterNext`, after the list node's first transaction, through `Queue.mainQueue().async`. So `ready` fires and the
    push starts ~13 ms before the buttons exist. Making list screens wait for their buttons would only remove the
    morph's cause, not its need: any screen can change its items during a transition.
- **The first frame** (`42c8895c50`). Every frame-driven clock (the progress driver, the platter view, the in-place
  animation) advanced its first frame by the time since the display link's previous frame, which can be long. The
  first frame now advances nothing.
- **Reduce Motion** (`9bdcb21160`), as SwiftUI's glass does it: no scale or blur when materializing, no pulse, and
  the shape moves on the materialize spring, which has no bounce (`NavigationBarGlassMotion`).
- **Overshoot in the swipe** (`bbbf52bf06`), by the user's direction: see "Rulings" (Swipe back).
- **A press that starts a push or pop** (`355068071c`). The bar measures the press UIKit is drawing on each capsule
  when it hands the capsules over, and the transition's capsule releases it on UIKit's release spring
  (`NavigationBarGlassSettings.pressRelease`, ζ 0.375, response 0.4, read at run time from `_UIFlexInteraction`).
  Measured: the release matches native frame for frame. A pop ends at ~0.55 s while the release is still at 44.74 pt,
  so the bar's own capsule takes over 0.74 pt off its rest size (see the minor findings).
- **The pulse on push and pop**: the code already pulses a kept capsule whose items change; the ruling below was
  corrected to say so.

- **Catching a running transition**: see "Rulings" (Swipe back).

Still open from the review: the ten minor findings.

## Resolved after the keyframes review (2026-10-14)

The fresh review of the keyframes work (`0875d94f93..929e46da7d`) graded it "with fixes". Fixed in `65d148a74c`,
each with a test that failed first:

- **iPhone Duo column capsules took the row's press and glow.** They start at rest; only the row capsules carry the
  bar's measured press (`test_rowPress_staysOnTheRowCapsule_besideAColumn`).
- **The Duo column was drawn twice during a linger.** A held glass now keeps the bar's own column hidden, as it does
  its row capsules (`test_heldGlass_keepsTheColumnHidden`).
- **Keyboard keyframes outlived a forced ending.** An immediate keyboard edge removes the transition's keyboard
  keyframes (`applyNavigationKeyboardLeftEdge`, `test_immediateKeyboardEdge_removesTheTransitionsKeyframes`).
- **Screen keyframes outlived a dropped transition.** They are removed when the group ends (a no-op at a natural end,
  since they are `removedOnCompletion`; it matters when Core Animation ends the clock early because the container left
  the screen) and in the coordinator's `deinit` (reachable only through a cancel, which holds its coordinator weakly).
  Each is stamped with its coordinator (`addNavigationKeyframes(…, owner:)`, `removeNavigationKeyframes(from:key:owner:)`)
  so one transition never removes the next one's.

**Bake cost** (spec §6 Q1's budget: under 4 ms at push start in the simulator). Measured with temporary logs on the
iPhone 18 Pro simulator, `debug_sim_arm64` (`-Onone`), Settings → Appearance → Chat Wallpaper three times:

| | Capsules | Coordinator | Total |
|---|---|---|---|
| Push start | 0.2-0.35 ms | 0.8-1.0 ms | 1.0-1.4 ms |
| Pop start, two capsules | 1.6-3.0 ms | 0.7-1.2 ms | 2.3-4.0 ms |
| Retarget mid-push (the screen applies its buttons) | up to 1.4 ms | | |

Before `b72e9d3b5f` every push also spent 3.7-4.2 ms (once 8.4 ms) in the keyboard step, keyboard or not: the push
rule asked `viewTreeContainsFirstResponder` once per sample (63 tree walks). The rule is now decided once per bake
(0.1-0.2 ms). No release simulator build was measured.

**Keyboard.** UIKit never moves the live keyboard (RE note above): it parks it at y + 4000 and slides a snapshot in a
full-window wrapper inside `UIRemoteKeyboardWindow`, clipped at the moving card's edge with a 9 pt edge shadow, on
its own spring (ζ 1, response 0.2667 s, duration 0.5) for tap transitions and linearly with progress for swipes. On a
push that covers it the keys move by the parallax (121 pt), where ours move the whole width (402 pt) unclipped on the
screens' curve; it also resigns the responder at the push's start and restores it on pop back. The user chose to keep
today's rule (2026-10-14). If it is taken up later: geometry and timing are one plan (the clip, the shadow view with
`isUserInteractionEnabled = false`, the offset rule, the own spring, moving the forced-ending removal with the
mechanism); responder restore is a separate plan with an audit of `ChatController`'s own input focus.

## What is left, in order

1. ~~The decision above~~ (resolved, kept as is).
2. ~~**Plan 1b task 4: the backdrop transparency keyframe.**~~ Done (see "Rulings", Backdrop). When one bar's backdrop is transparent and the other's is
   not, UIKit fades it over 0-0.3 or 0.7-1.0 of progress instead of linearly. The plain cross-fade along progress
   exists. See the bar RE notes.
3. **Plan 1b task 5:**
   - ~~build `release_arm64`~~ and ~~run the suites~~: green at `6680ef10ec` (2026-10-15);
   - get a fresh whole-branch review of everything from `89abe64512` (plan 1's reviewed tip) to the branch tip;
   - do a film comparison against native Settings;
   - ask for the user's visual pass, including iPhone Duo, which has never been checked by eye.
4. ~~**Plan 2:** `ChatListNavigationBar` (the chat list's own header) as a transition source.~~ Done 2026-10-15:
   spec `docs/superpowers/specs/2026-10-15-chat-list-header-transitions-design.md` (with its native search-bar
   measurement and the in-app results), plan `docs/superpowers/plans/2026-10-15-chat-list-header-transitions.md`. The
   8 chat-list-style screens morph; the glass hold, a lifted-scroll gate and a two-content bar's visible content are
   shared helpers in `NavigationBarComponent`. After the user's pass (`6680ef10ec`), two corrections that override
   UIKit: a search field rides its screen whether its bar leaves or arrives (the hold-and-fade contract is gone), and
   the header keeps its own edge effect on its screen next to a bar without one (a chat) instead of the transition
   fading it.
5. ~~**An accent right button in its own circle** (Chats' new message).~~ Done 2026-10-15: UIKit's prominent-item
   sections, 12 pt `interSectionSpacing`, and platters paired by `SectionID` index from the edge, read in Hopper and the
   live reference app; a leftover capsule collapses into, or grows out of, the other bar's outermost platter, its glass
   merging with that platter's (smoothness 12), with SwiftUI's resolved delay, kick direction and anchored pulses. Open:
   on the pop iOS keeps the two joined by a neck until ~0.28 s, ours until ~0.15 s.
6. ~~**A chat opened from Chats' search (a typed query)**~~ (reported 2026-10-15). Fixed in `57654ee294` (see git log
   "a bar whose row is hidden contributes no capsules"): the renderer morphed the search-hidden row's capsules and hid
   that by fading the whole capsule view, which is the glass's ancestor, so the chat's glass was not drawn through the
   push and its linger (it appeared ~1 s late), and on the pop the capsules flew up to the hidden row. A hidden row now
   contributes no capsules; the chat's back and avatar materialize and dematerialize in place, and the capsule view is
   never faded. Unmeasured: whether iOS morphs the search's X (close, its own trailing section) into the avatar, which
   needs a `UISearchController` scenario in the reference app. Pre-existing and untouched: the push waits for the
   keyboard to go down (~0.2 s) before it starts.
7. ~~**The chat header pill as a second right button in transitions**~~ (asked 2026-10-15). A title view drawing a glass
   pill (`NavigationBarGlassPillTitleView`: the chat's `ChatNavigationBarTitleView`) is reported in the bar's
   transition state and becomes its bar's second right platter (`.trailingInner`) when that slot is free: Chats'
   story/proxy capsule morphs into it and back, pill into pill between chats, and without a partner the existing rules
   apply. The transition draws the pill and a still copy of its contents while the title view hides them; on a swipe
   back the pill stays put until release, like the buttons (user's choice). Without an avatar the pill is still second
   right (user's choice). The story grids' older `ChatTitleView` is not included.
8. ~~**Split Edit and Search into two glass pills**~~ (asked 2026-10-15). Done on branch `navbar/split-buttons`: right
   buttons group by UIKit's rule, and a pill that comes or goes merges with its neighbour as one shape. See
   `docs/superpowers/specs/2026-10-15-navbar-split-right-buttons-design.md`, "Results", for what was filmed, the
   two fixes it led to (the stuck-pale Done on single-pill changes, the Chats title snapping in Edit mode) and what was
   not filmed (iPhone Duo, Removed Users, dark and clear glass).
9. **Deferred minors** (next section), then the merge decision for both branches.

## Deferred minors (known, not fixed)

From the accent circle's final review (`884f86f897..2db63d7124`, fixed: legacy glass and the inline-slide tint in
`2ae63d866c`):

- **Merge guard timing:** `mergesGlass` is read at the bake's end, so it never sees an outermost still fading (rare
  double late apply: the inner's glass opacity jumps for a frame).
- **Retargets:** a matched collapse keeps its old target if the destination's outermost changes frame mid-push; a
  destination outermost arriving a frame late never re-matches an inner already fading in place; `setSides`'
  changed-items path replaces an anchored matched pulse with a centred one.
- **Merged container:** takes `isDark` from whichever platter applied last; never removed between transitions. The old
  tint's fading glass sits above the merged union and cuts across the neck (natively the tint cross-fades in one
  element; also the thin blue ring at the start of the pop).
- **Inline forum, tap path:** the circle fades in place and its glyph slides 44 pt left while fading; during the
  per-frame slide its corner radius (22) exceeds half its width.
- **Items identity:** a bar gaining or losing its circle mid-transition can show the capsule's live view in the
  `.trailing` platter.
- **Dead code:** the matched delay's distance term (`resolvedMatchedOffset` makes it zero or nil for every bar platter).
- **Test gaps:** the outermost's glass back in its own container after a collapse; a cancelled swipe with a matched
  inner; a release mid-collapse.
- **Open from the films:** on the pop iOS keeps capsule and circle joined until ~0.28 s, ours ~0.15 s.

From plan 1's final review:

- **Rotation:** the transition layer's frame is set once, so a rotation or resize mid-transition leaves the backdrop
  and glass at the old width (fix: set `layer.frame` in `updateProgress`).
- **Layout lag:** the lifted content's origin can lag one layout (`applyNavigationBarLayout` lays out before setting
  the bar frame). It is harmless while every eligible bar sits at (0, 0).
- **Snaps:** theme, strings and `isDark` snap at f = 0.5 between differently themed screens. A one-sided Duo column
  switches by `isHidden` rather than fading.
- **Test gaps:**
  - nothing tests that a new transition puts back the previous one's content;
  - `test_complete_putsBothBack` exercises `complete()`, which has no production caller;
  - the cancel test ends directly.
- **Unreachable branch:** the layer's "vanished source" branch, because the coordinator holds sources strongly.
- **Per-frame cost:** every frame builds a new `NavigationBarComponent`, copies the buttons, runs a full two-content
  update, and has blur filters on ~10 containers. Do one Instruments pass on an older device.
- **Non-animated top change:** a non-animated `topTransition` does not end a live coordinator (pre-existing). The old
  lifted bars stay above the new top screen until the old animation or gesture ends.
- **Split mode:** `updateMorphCapsules` never resets the shared capsule's alpha and scale on its non-morph branch. It
  is unreachable today.

From the in-place work:

- **Dimmed label:** the leaving "Edit" snapshot keeps the press-dimmed label. Native restores it to full black for
  ~3 frames before the swap.
- **Late checkmark:** the new checkmark goes sharp ~0.05 s after native's (+0.2 s against +0.15 s).
- **Instant taps:** a zero-duration `axe tap` does not fire our bar buttons, though it fires native ones. A 50 ms
  touch works. Not investigated; no real finger makes a zero-duration touch.

From the keyframes review (2026-10-14):

- A release exactly at the target with velocity overshoots and returns (pre-existing).
- The platter view reads "now" twice per retarget.
- `NavigationAnimationClock.finish()` does not bump the generation, so a pending marker fires after an end (benign:
  markers re-check state).
- The bar transition layer's frame is not resized in `containerSizeUpdated` (pre-existing).
- A catch then a release before the commit's cut jumps ~2 frames forward.
- `rowAlpha`'s layer opacity also scales the iPhone Duo column capsules.
- Dead or stale code: `NavigationBarTransitionLayer.isAnimating` is unused, `hasDisplayLinkForTesting` is always
  false, and `NavigationBarContentView.swift:17` still mentions `updateMorphTransition`.
- Nothing automated checks what Core Animation draws; the bake is pinned by sampled values only.

From plan 2's whole-branch review (2026-10-15):

- `ChatListNavigationBar.View.takeView()` checks only its own alpha and `isHidden`, not its window or a faded ancestor.
- `updateStoryUploadProgress` bypasses the lifted-scroll gate (harmless for progress ticks).
- The hold's backgrounding path is not pinned by the named test; release relies on the linger's own completion or the
  1.6 s cap.
- Put-back sizes the content view from its bounds while `update()` uses the returned size (equal in every host today).

From `navbar/component` phase 3 there were 7 minor items, of which two are known here: busy-spinner swaps move between
the row and the Duo column, and the push dim on Communities at scroll top. The full list was not kept.

## Rulings already made (don't relitigate without new evidence)

**Transition clock**
- **Push and pop run on Core Animation keyframes** (user's direction, 2026-10-14; spec
  `2026-10-14-navbar-keyframed-transitions-design.md`). Decided because main-thread work must not make them hitch:
  with the app paused 0.3 s mid-pop in lldb, the film kept a frame every ~16 ms and the screens kept moving. A
  mid-transition change rebuilds the keyframes from the state at now, synchronously, which is earlier than the next
  frame the old per-frame sampling read it on. Cost if wrong: a change shows the old curve until the next rebuild,
  visible as a blink in the Notifications → Private Chats film (not seen).
- **Endings come from Core Animation's completions, not timers** (user's direction, 2026-10-14). Core Animation calls
  them in every case: finished on screen, unfinished at once for a layer off screen or leaving it (measured). The bar's
  1.6 s hold cap is the one timer left (a completion would fire on the remove-and-re-add a finished swipe does).
- **A transition's keyframes belong to it.** They are stamped with their coordinator and removed when its group ends
  or it is released, never by another transition.
- **Screens' model frames are their final ones while a transition runs** (spec choice). Whatever must follow the drawn
  frames (the swipe's restrictions) shifts by `presentedDisplacement`.
- **The keyboard keeps today's rule** (user decision, 2026-10-14, after the keyboard RE note). It is decided once per
  bake, never per sample.
- **Endings have no DEBUG watchdog**: Core Animation's completion behaviour was measured for every way a group ends.
- **The 80-120 Hz frame-rate range** is gated on `UIScreen.main.maximumFramesPerSecond` (the cover screen on an
  unfolded iPhone Duo; both screens of a ProMotion device report the same maximum).
- **Glass opacity goes on layers, never `UIView.alpha`**: a view alpha below 1 on a glass ancestor makes UIKit stop
  drawing the glass at once, whatever keyframes run (measured).
- Settle when |p − target| < 0.0005 and |v| < 0.005/s.

**Swipe back**
- Sample time is `CACurrentMediaTime()` at the handler.
- **A swipe back takes over a transition running toward the top screen** (user's direction, 2026-10-14, reversing
  "a running transition is never caught"; measured on native, screen RE notes §6b). A tap push is caught where it is
  and at the speed it has, and the finger steers a pop counted from 0; a pop springing back after a cancelled swipe is
  caught at its progress. Both keep the one coordinator (`catchBySwipe`). A pop running to the screen beneath is not
  caught: native starts a second pop alongside it, which the container does not do (one transition at a time). Cost
  if wrong: that double-back gesture is ignored until the first pop ends, as before.
- Content touches stay swallowed during a transition (the container's `hitTest`), as native swallows a tap that begins
  mid-push. A swipe that begins then is still held to the restrictions of the screen under the finger
  (`gestureRestrictionsHitTest`).
- A swipe catches a push only when the screen it would show is the one beneath in the stack (not after a replace or a
  multi-push), and a stack change under the finger ends the swipe's hold (the caught transition is completed as any
  running one is).

**Capsules outlive the screens' transition**
- UIKit's capsules run on their own clock (measured 2026-10-14: a swipe let go at the edge morphs them for ~0.5 s
  after the screens settle; the press glow fades past a pop's end). Glass still animating when the transition ends
  lingers above the bar it ended on until it settles, that bar holding its own capsules out
  (`NavigationBarTransitionLayer.putBack(lingering:)`, `NavigationBarTransitionSource.holdGlass`). It hands over at
  once on a touch on the bar, a change of its content or row frame, a new transition, an immediate stack change to
  another screen, the bar leaving the screen (another tab selected), or a 1.5 s safety cap. Cost if wrong: a capsule
  animation is cut, as before.
- **Only a touch on the bar hands over** (its bounds, or the Duo column; a touch, not a pointer hovering). UIKit asks
  the bar about every touch on the screen since it is the screen's topmost subnode, so before the 2026-10-14 review
  fix scrolling the list right after a swipe cut the morph, which iOS does not.
- **The bar never depends on the transition to get its capsules back.** A hold its transition did not release (the
  navigation container replaced mid-linger, e.g. an iPad resize across the compact/regular boundary) is released by
  the bar itself on the hand-over triggers above, and by its own 1.6 s cap. Not a `deinit` on the layer: an
  ASDisplayNode may be deallocated off the main thread.
- A press that starts a transition carries UIKit's whole press look: the scale (`pressRelease`) and the glow, drawn as
  UIKit draws it (BigGlow and LittleGlow under `vibrantColorMatrix`, matrices in glass RE §6) and fading on
  `pressGlowRelease` (ζ1, response 0.5). The content's own press dim (our buttons' 0.6, faded over 0.2 s) is not
  carried yet. The LittleGlow is centred, since the touch point is not known.
- The press scale is sampled during the touch, not read at the hand-over: on a short tap UIKit has already removed it
  when the button's action starts the pop (glass RE §6). Measured in the app: the Back capsule held 60 pt through the
  hand-over and shrank 58, 55, 53, 50, 47 pt over the next frames, where it had snapped 60 -> 44 pt in one frame.
  Sampling starts at the touch (the bar's `hitTest`), runs 1.5 s, and runs on while the glass reads pressed, so a long
  hold is sampled to its end (a 1.6 s hold of Back snapped before that). Cost if wrong (a UIKit change that keeps the
  press on the model, or ends it later): the current reading wins whenever it is not at rest, so the sample is used
  only when the glass already reads 1.

**Capsules appearing and leaving in a push or pop run on the transition spring**
- A capsule only one screen has materializes or dematerializes on `Spring(0.416, bounce 0.25)`, not the critically
  damped `.materialize` resolution the RE inferred (measured with the reference app probe, glass RE §2.2: the scale
  follows the bouncy spring to within 0.005 at 1-12 frames, with its overshoot). On the critically damped spring a
  leaving capsule kept a ~20% ghost at 0.2 s and its outline was visible to ~0.4 s, outliving a near-edge swipe's
  screens; on film it now fades with them (outline under 10% 23 ms before the screens settle; native 15 ms).
  Cost if wrong: the capsule's scale overshoots 0.6% that native would not.
- Still open, measured on the same probe: native's outline loses contrast faster than its scale progresses in the
  first frames (0.64 one frame in, ours 0.79), so an opacity curve is not linear in the spring there; and in a push the
  native glass starts ~0.08-0.1 s after the screens. The bar's own in-place changes (`NavigationBarInPlaceAnimation`)
  still use the critically damped spring for a capsule that appears or leaves; not measured.

**Items swapped in a kept capsule are matched**
- When a capsule both screens have changes its items (Edit -> Done, the back chevron -> Close), the old items shrink
  to 0.2 and the new ones grow from 0.2, transparent and blurred at that end, on the transition spring
  (`AppearanceSettings.match`, glass RE §2.3; measured with the reference app probe: the new label's scale 0.200 ->
  1.000 with an overshoot to 1.034, its opacity on Spring(0.416, 0.25) to the frame, the old one's overshooting to
  -0.024). This was the 1.2 materialize scale on the critically damped spring before. The same applies to items a bar
  changes mid-transition. Cost if wrong: items swap at a different scale from native; the probe numbers are in glass
  RE §2.2.
- Open, from the same measurement: natively both labels move with the capsule as it grows (-104 pt for Edit -> Select
  Messages), where ours stay where their bar has them; how that offset is anchored is not read. And in a push the
  native glass starts ~0.08-0.1 s after the screens.

**Bar items during a swipe**
- **A dragging finger does not affect the bar items** (user correction, 2026-10-14; measured on native: a "Select
  Messages" capsule kept its width over a whole drag toward a screen with "Edit"). The capsules stay as they are while
  the finger drags, including a caught push's, which carry on to the top bar's, and switch to the bar the swipe ends on
  at release. iPhone Duo's column capsules are capsule roles and behave the same. This replaces the earlier reading of a halfway pull
  (glass RE notes §4, now marked superseded). Cost if wrong: none found; native shows no pull.
- **The swipe stops at either end and its springs do not overshoot (user decision, 2026-10-14).** UIKit rubber-bands
  the target past 0 and 1 (extent 0.5, coefficient 0.55) and releases on ζ 0.85, which overshoots. Here the target is
  clamped to 0...1 and the tracking, release and cancel springs stop at their target. A tap push or pop is unchanged
  (ζ 1 does not overshoot). Cost if wrong: only feel, against native.

**Screens**
- The card shadow uses the largest screen corner radius uniformly.

**Capsules**
- **A screen's node in a bar button is lent to the transition's capsules, never snapshotted** (user's direction,
  2026-10-14). A snapshot of a node that draws only once on screen was blank (Appearance → Chat Themes' animated
  switch) because the bar hides its capsules during a transition. `NavigationBarNodeLoan` keeps one owner at a time:
  the bar's button (the home) does not take a lent node back, even when it is rebuilt; the platter view's content views
  borrow it (`borrowsNodes`); the renderer's `end()` (at the transition's end, or its linger's) and its `deinit` give it
  back at the home's layout.
- **A button never moves a screen's node out of the window** (2026-10-14). A new button for a new item (a screen
  re-applying its state) or a capsule not yet on screen takes the node only once it is in the window
  (`NavigationButtonComponent.View.host`, `didMoveToWindow`): Lottie pauses a view that leaves its window, which froze
  Chat Themes' switch at its first frame on every tap, so dark showed the moon and light the sun.
- Capsules are matched by role (leading, trailing), not per item.
- There is no cross-role matched geometry, so there is no delay or kick.
- A capsule pulses whenever its items change: in place, and on a push or pop that keeps the capsule but changes what
  it shows (user, 2026-10-14; an earlier line here said the pulse was for in-place changes only, which neither the
  code nor the user intended). A capsule whose items are the same on both bars only morphs.

**Backdrop**
- A transparency change (one backdrop alpha below 0.3, the other not) fades over the 0.3 of the fraction next to the
  opaque bar, linearly within it, as a `UIView` keyframe would (`navigationBarTransitionBackdropAlpha`). UIKit's hybrid
  animator may instead run it as a 0.09 s spring fired at the threshold (INFERRED); the fraction form holds for
  scrubbing and needs no clock. Cost if wrong: the fade lands up to ~0.05 s apart.

**Pulse and items**
- Pulse peak = min((L + 16) / L, 1.2) per axis, fitted to two native films. The RE's own per-axis reading and a
  longer-side model both failed.
- An item replaced in a kept capsule enters with `.materialize`, not `.match`.
- **The taller swell after a tap stays (user decision, 2026-10-14).** Measured: press, release and pulse are the
  same curves on both sides and multiply on both. Native's change starts ~0.08-0.1 s after its items are set (60 Hz
  simulator), so its pulse peaks in the release's undershoot (49 pt for Edit -> Done) where ours peaks over the press
  (62 pt). A uniform start delay would match it; not done because the delay is probably frame-based and unmeasured on
  a 120 Hz device. Cost if wrong: only this peak, only after a tap. Evidence: RE notes §6 and the measure README's
  "Frame-by-frame layer probes".

**Tint**
- The platter view's tint cross-fade is frame-driven at a 0.3 s response (measured untouched native).
- The in-place tint is handed to UIKit at a 0.1 s response: UIKit starts drawing it ~30 ms late, and at 0.3 s it
  took ~0.25 s against native's ~0.13 s.

## Build, test, install

Commands are in `CLAUDE.md`. Prefix each with `source ~/.zshrc 2>/dev/null;`, which loads the codesigning
password.

- **Build:**
  `python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --continueOnError --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64`
  (or `release_arm64`). Read the build's own exit status: a wrapper's last command can hide a failure.
- **Tests:** the same, with `test` and `--target <label>`, and no `--buildNumber` or `--configuration`. Per-test
  output is in `bazel-testlogs/<package>/<target>/test.log`; grep it for `Executed` and `error:`.
- **Install:** the whole-`.app` copy from the unzipped `bazel-bin/Telegram/Telegram.ipa` (`CLAUDE.md`, "Updating the
  running simulator after a rebuild"). A same-build-number `simctl install` silently keeps the old app.

## Verifying against native

`Tests/NativeNavigationReference/measure/README.md` covers:
- the reference app (launch it with `-systemDone 1` so a hand tap on Edit shows the system checkmark);
- getting to Settings → Notifications and Sounds → Private Chats in Telegram;
- recording with `simctl io recordVideo` (variable frame rate: read the pts);
- the scripts;
- every number measured so far.

The films themselves were not kept.

Simulators are driven with the XcodeBuildMCP tools (`mcp__XcodeBuildMCP__*`) or the AXe CLI. With AXe:
- **Use `axe touch -x X -y Y --down --up --delay 0.05`.** A zero-duration `axe tap` does not fire this bar's buttons.
- **Expect ~0.8-2.5 s per AXe call, even in `axe batch`.** Two taps inside the ~0.5 s animation cannot be produced;
  that case is pinned by a unit test instead.

## Pitfalls learned on this branch

**Glass and capsules**
- **Alpha does not hide native glass** inside a glass container. Remove the view, use `isVisible:` on the glass, or
  fade the container itself.
- **Glass effect changes:** `GlassBackgroundView` reassigns its effect only when shape, tint, darkness, interactivity
  or visibility change. So per-frame `update(..., transition: .immediate)` calls at a constant height don't cancel an
  animated tint change, but changing the corner radius would.
- **`rightButtonsContainer` has anchor point (1, 0).** Position it through `setInPlaceFrame`, which scales about the
  centre whatever the anchor.

**Taps and hit testing**
- **Taps need the capsule attached.** `NavigationBarContentView.hitTest` finds row buttons by converting the touch
  point to them, so the capsule holding them must stay in the view hierarchy. A detached capsule makes the conversion
  wrong and every tap misses.
- **Unit tests hide that failure.** Test views have no window, so a detached view shares coordinates with the bar by
  coincidence. `test_inPlaceItemChange_newItemsTakeTapsMidAnimation` puts the bar in a host view at y 100 so a detached
  capsule fails.
- **No `UIApplication` in `ios_unit_test`.** `UIControl.sendActions(for:)` goes nowhere; call the control's action
  selector directly. There is no window and no Metal.

**Build**
- **Warnings are errors** in almost every module: an unused local fails the build.

**Tooling**
- `python3 -I` cannot see Pillow, so run the measuring scripts with plain `python3`.
- This machine's ffmpeg rejects `-vsync`; use `-fps_mode passthrough`.
- The shell is zsh: an unquoted `=====` argument fails ("not found").
