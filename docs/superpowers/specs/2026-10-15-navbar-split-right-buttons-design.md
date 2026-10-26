# Split right buttons: UIKit's sections in the glass navigation bar

Asked on 2026-10-14: "ChannelAdminsController and the like are a good example. Do the following: 1. Split Edit and
search into two different glass pills. 2. Animate pop-up/pop-in when Edit is pressed, and the search button is sucked
in/ejected out of the Edit button." Restated on 2026-10-15: "support split buttons in ItemListController screens (like
Channel Administrators where we have search and Edit/Done)".

Decisions taken with the user while designing:

- **Scope: UIKit's rule, everywhere.** The bar groups right buttons into pills exactly as UIKit groups bar button items
  into sections, on every screen, not only `ItemListController` pairs and not as an opt-in.
- **Approach: merge on the bar.** The bar's own pills merge and split in place; the push/pop transition view is not
  used for in-place changes, and the two animators are not rewritten into one engine.

## What UIKit does (measured 2026-10-15, iOS 27 simulator)

### Which items get a pill of their own

`-[UINavigationItem _addImplicitTopBarSectionsFromItems:toSections:forPlacement:]` walks the bar items in order: an item
whose `_requiresOwnSection` is true closes the current section and gets one of its own, an item whose
`_requiresPartitionBetweenOtherItem:` against the previous one is true starts a new section, any other item joins the
current section (read in Hopper for the accent circle, 2026-10-15). Asking UIKit itself, from a scratch binary run in
the K2 simulator's runtime:

| Item | `_requiresOwnSection` |
|---|---|
| text (`title:`, `.plain`) | **true** |
| text, `.done` style | **true** |
| text, `.prominent` | **true** |
| image, `.plain` (`magnifyingglass`) | false |
| image, `.prominent` | **true** |
| system `.add`, system `.search` | false |
| system `.done` (the checkmark) | **true** |
| custom view | false |

`_requiresPartitionBetweenOtherItem:` was false for every pair tried (text/image, image/text, image/image, text/text,
image/custom view): it partitions only items whose glass overrides differ. `sharesBackground` is true and
`hidesSharedBackground` false by default on all of them.

So: **a text item and a prominent item (the Done checkmark included) each get a pill of their own; consecutive image,
system-image and custom-view items share one.** This is why `[Edit, +]` is two pills on the reference app
(`-scenario oneTwo`) while Chats' story and proxy icons share a capsule.

### How a pill comes and goes in place

Filmed on the reference app, `-scenario oneTwo` (`[Edit]` <-> `[Edit, +]`, a new `UIBarButtonItem` each time):

- **Removal:** the `+` pill moves into the Edit pill joined by a neck, is absorbed within ~0.08 s, then Edit swells and
  its items blur, settling ~0.3 s after the change.
- **Insertion:** Edit first swells with its items blurred (~0.2 s), then `+` emerges from Edit's left edge on a neck,
  separates ~0.3 s after the change and settles at ~0.4 s.

**Measured, the Administrators case (2026-10-15).** Reference app `-scenario editDone -adminsRight 1` (right items
`[Edit, search]` <-> `[the system Done item]`, new items each change), filmed at 60 fps on K2, driven by the
scenario's timer without a touch (for a real tap see below); times from the first changed frame:

- **Edit -> Done (search sucked in).** 0 s: Edit's items swap (blur) and the Edit pill swells (its item-change pulse);
  **both** pills cross-fade to the accent tint, the search pill included (re-measured 2026-10-16 at fixed points, not
  ~0.07 s as first noted: white <-> accent takes ~0.25 s each way, on the glass transition spring; see Results). ~0.10 s: search starts
  shrinking toward Done (SwiftUI's minimum delay, 0.083 s, plus a frame). ~0.15 s: a neck joins them. ~0.23 s: search is
  absorbed. ~0.25 s: the Done circle is at rest.
- **Done -> Edit (search ejected).** 0 s: Done's items swap and it swells. ~0.03-0.05 s: search already bulges out of
  Done's left side: the insertion does not wait. It starts in Done's accent tint and both pills fade to the plain glass
  by ~0.15 s. ~0.13 s: the magnifier is visible in the bulge. ~0.27 s: the neck breaks and search separates. ~0.30 s:
  at rest, 12 pt apart.
- `[Edit]` <-> `[Edit, +]` (`-scenario oneTwo`) showed `+` emerging only after Edit's ~0.2 s swell. With a different
  partner item and the system add item, that case is not the Administrators one and is not reproduced; the measured
  Administrators order above is what the bar implements.
- **New finding:** a pill merging with its partner takes the partner's tint on the way (the leaving search pill turns
  accent as it goes into Done; the arriving one starts accent and turns plain).
- **With a real tap (filmed later the same day).** The film above was driven without a touch. Tapping Edit (`axe touch`,
  reference app with `-scenario none -adminsRight 1`), Done starts as the pressed white glass and fades to accent
  through pale blues over ~0.2 s, straight mixes of white and accent (sampled: f6fbfc, c3def7, 8ccafc, 52b9fc, 14a2fd,
  0094fc); the search pill, already accent, merges into it as one shape, and nothing is left inside Done afterwards.

**How glass behaves in a glass container (probed 2026-10-15, a plain-UIKit app on the iOS 27 simulator).** Two
`UIGlassEffect` views in one `UIGlassContainerEffect`, one absorbed into the other:

- They render as **one shape** whatever the nesting (effect view in plain wrapper views), the corner (`cornerRadius`
  or `cornerConfiguration`), the motion (frame or transform, every frame) or the content.
- An **animated effect change** (`UIView.animate { view.effect = … }`, the tint cross-fade) draws a **dark band where the
  two shapes meet** for as long as it runs. Setting the effect again without animation does not cancel it. Setting a new
  effect every frame, without animation, merges cleanly.
- A glass **under UIKit's press** (`_UIFlexInteraction`, interactive glass) keeps its own edge inside the merged shape:
  the other shape reads as a darker disc within it. Re-adding the view keeps the press; removing the interaction ends
  the glow but leaves the press's lift and tint; a **new effect view** with the same effect is clean. UIKit keeps the
  press glow in a `GlowContainerView` inside its own `_UIMultiLayer`, not among the content view's subviews.

## Where the bar stands (master 8157d4300d)

- `navigationBarButtonPlacement` (`NavigationBarRowLayout.swift`) puts the first accent right button in a circle of its
  own (`rowCircleItem`) and every other right button in one capsule.
- `NavigationBarContentView` hosts them in `rightButtonsContainer` and `rightCircleContainer`;
  `NavigationBarComponent.View` gives each its own glass container.
- `NavigationBarInPlaceAnimation.swift` animates in-place changes on those containers through fixed slots (`.left`,
  `.right`, `.rightCircle`): frame springs, item swaps, pulses, tint cross-fades, a press carried on, materialize and
  dematerialize in place. It cannot merge two pills.
- `NavigationBarPlatterTransitionView` (push/pop) pairs right platters through two fixed roles (`.trailing`,
  `.trailingInner`); a leftover inner platter collapses into, or grows out of, the other bar's outermost platter with
  its glass merged (one `GlassBackgroundContainerView` at smoothness 12), SwiftUI's resolved delay, the kick and an
  anchored pulse. The pure rules live in `NavigationBarGlassAnimation.swift` (`NavigationBarGlassSettings
  .resolvedMatchedOffset`, `.matchedDelay`, `.transitionAnchor`, `NavigationBarKickCurve`,
  `NavigationBarGlassPulseCurve`); the morph itself (`startMatchedMorph`, `hostGlass`) is private to the transition
  view and baked to keyframes.
- `NavigationBarComponentTransitionState` carries a bar's press per fixed role (`trailingPressScale`,
  `trailingInnerPressScale`, …), filled by `NavigationBarNode`, `ChatListNavigationBar` and `NewsHeaderView`.
- `ItemListController` sets `rightBarButtonItems` to `[secondary, primary]`; `navigationBarButton(for:)`
  (`NavigationBarItemContent.swift`) maps each item to a button (text, image, node, the `___done` checkmark with the
  accent tint).

## Design

### 1. Structure

- **One rule, one pure function.** `navigationBarRightSections(_ buttons:)` returns the row's right pills, outermost
  first, from the buttons in UIKit's item order (`rightButtons[0]` is the outermost): a `.text` button or a button whose
  tint is not `.generic` (accent, accent-disabled: UIKit's prominent items and the Done checkmark) closes the current pill
  and gets one of its own; `.icon`, `.image`, `.node`, `.custom` and `.more` buttons join the current pill. It replaces
  `rowCircleItem`. Chats keeps its look: compose (accent) and the story/proxy pair come out as the same two pills.
- **The row draws any number of right pills**, index 0 outermost, `navigationBarInterSectionSpacing` (12 pt) apart, each
  its own glass container with its own items container, replacing the fixed capsule and circle. A pill takes a
  non-generic tint only when all its buttons share it (`navigationBarCapsuleTint`, unchanged). The title's room is
  measured from the innermost pill's leading edge (`navigationBarRightButtonsExtent` over all pills). A pill with a
  single button morphs into that button's context menu (`morphsIntoContextMenu`), decided per pill from its own buttons.
- **An inline forum sliding over Chats keeps today's slide.** While the bar shows two contents (`secondaryContent`),
  each content's pills are paired **from the inner end** and their widths interpolated by `secondaryTransition`, each
  pill's tint that of the content it mostly belongs to. That is exactly today's slide: Chats' story/proxy capsule turns
  into the forum's capsule while Chats' compose circle narrows away at the edge, keeping its accent glass. (Pairing from
  the edge instead would morph the compose circle into the forum's "…" and change a shipping animation.)
- **Screens change nothing.** `ItemListController` keeps passing `[secondary, primary]` bar items; the bar applies the
  rule, so Channel Administrators, Members and Removed Users split by themselves, as does every other screen with the
  same mix of items.
- **iPhone Duo.** The side column (its capsule and trailing circle) is untouched. Text buttons already stay in the row
  there, and the rule applies to what stays in the row.
- **Push and pop.** Right platters pair by index from the edge for any count, as UIKit pairs `SectionID(index, owner)`:
  the fixed `.trailing`/`.trailingInner` roles become an index. The title pill (`NavigationBarTransitionTitlePill`, a
  chat's header) still takes the second slot, and only when its bar has at most one right pill. A leftover platter
  merges into, or grows out of, the other bar's **nearest** platter (SwiftUI's `sourceElement`, the best
  `geometryResult` among the other side's entries) rather than always its outermost. The transition state carries the
  press per right index instead of per fixed role. `ChatListNavigationBar` and `NewsHeaderView` are built on the same
  component and fill the same state, so they follow.
  *Update 2026-10-18:* a title pill is never a leftover that merges. Without a platter in its slot on the other bar
  (Contacts has only its "+"), it materializes or dematerializes in place (asked by the user). It still morphs with a
  platter in its slot (Chats' story/proxy capsule, another screen's title pill).

### 2. Animation of an in-place change

The old and new right pills are compared by index from the edge, as UIKit compares section IDs.

- **The same index on both sides:** as today. The shape springs to its new frame, its items swap with a centred pulse,
  its tint cross-fades (Edit -> Done turns it accent), a press in progress carries on.
- **A pill that goes** (search, when Edit becomes Done): it collapses into the nearest remaining pill on that side, after
  SwiftUI's resolved delay, kicked away from its partner; its items leave into the partner; its glass and the
  partner's share one container at smoothness 12 until it is gone, then the partner's glass goes back to its own
  container; both pulse about SwiftUI's transition anchor (`transitionAnchor`: a right pill's trailing edge, so the partner swells toward the leaving pill). This is the "sucked in".
- **A pill that comes** (search, when Done becomes Edit): it grows out of the nearest pill, kicked outward, its glass
  merged with the partner's until they separate, its items materializing. This is the "ejected".
- **No pill left on that side** (Chats entering Edit mode takes both right pills away): dematerialize in place, as today.
- **Interruptions.** A change mid-animation retargets every spring from where it is. A pill that was leaving and comes
  back is the same pill, reused, as SwiftUI's resolver reuses a removed entry matching an insertion. A push or pop that
  starts while a merge runs finishes the in-place animation first, as today (`finishInPlaceAnimations`).
- **Without native glass merging** (`GlassBackgroundContainerView.mergesShapes` false: before iOS 26, or the custom
  glass setting): the leaving pill fades in its own container, and an arriving one appears in its own, as push/pop
  already does there.
- **Reduce Motion:** opacity only, no scale, kick or blur, as today.
- **Taps:** an arriving pill takes taps at once; a leaving one takes none.
- **Shared rules, not copies.** The delay, kick, anchored pulse and partner choice come from the functions push/pop
  uses; the partner choice moves out of the transition view into `NavigationBarGlassAnimation.swift` so both call it.
  Only the time model differs: push/pop bakes keyframes, the in-place animator steps live springs on a display link.
- **How two bar pills merge.** Unlike push/pop's platters (bare glass shapes with the items in a separate host), a bar
  pill (`GlassContextExtractableContainer`) keeps its items inside its own glass view. So for the duration of a merge
  the container **lends its glass view, items included**, to a merging `GlassBackgroundContainerView` at smoothness 12
  in the bar view (a new `lendGlass()` / `reclaimGlass()` pair on the container), and takes it back once the leaving
  pill is gone or the arriving one has separated. While lent, the animator places the glass views at the pills'
  frames; the items stay live, so the arriving pill takes taps and the partner keeps its buttons. Both pills' glass is
  lent, the leaving or arriving one and its partner, since only shapes in one container merge.
- **A press on the partner.** A glass under UIKit's press does not merge cleanly (above), and the tap on Edit that
  started the change is still releasing. So in a layout where a pill comes or goes, a right pill UIKit is pressing gets
  a new effect view before the layout touches its glass (`GlassBackgroundView.renewNativeView`, the content moved
  over), and the animator continues the press's scale as its own spring (`NavigationBarGlassSettings.pressRelease`),
  multiplied with the pulse, as push/pop does with a bar's press. Its glow is not continued: push/pop's glow view,
  drawn over an already tinted glass, turns an accent pill cyan (sampled 99eefc, 3bd8fa) where native fades through
  pale blues, so the merge fades the tint alone.
- **Order and tint, as measured** ("How a pill comes and goes in place"): the partner's item swap and pulse start at
  once; a leaving pill starts moving after the resolved delay and an arriving one at once; the moving pill cross-fades
  to its partner's tint as it leaves, or from the partner's tint to its own as it arrives, on the in-place tint
  spring. In a layout where pills merge, every in-place tint change, the partner's included, is cross-faded by the
  animator, a new effect each frame (`NavigationBarInPlaceCapsule.tintFade`), never by UIKit's animated effect change,
  which bands the merged shape (above). Other in-place changes keep UIKit's cross-fade.
- **Items travel with a matched pill.** An in-place change leaves items where they rest while the shape morphs around
  them; a pill going into, or coming out of, its partner carries its items, placed in the pill they were laid out in
  (`Matched.itemsPill`), so the magnifier stays inside the shape it fades in.

### 3. Testing and verification

**Native first (Task 1).** A reference-app scenario (`Tests/NativeNavigationReference`, a new flag) with right items
`[Edit, search]` <-> `[Done]` (the system Done item), filmed and probed on K2: the order of the partner's pulse, the
neck and the item swap, the delays, and the separation time, for both directions. Results go into "How a pill comes
and goes in place" above before any animation code.

**Unit tests, each failing first** (`//submodules/TelegramUI/Components/NavigationBarComponent:NavigationBarComponentTests`
unless noted):

- **Rule:** `[Edit, search]` -> two pills; `[search, +]` -> one; an accent button alone in its pill; `[text, text]` ->
  two; node and custom buttons join their neighbours; outermost first; Chats' buttons -> today's two pills.
- **Layout:** pill frames with 12 pt gaps, the title's available width, each pill's tint, a single-button pill morphing
  into its context menu; the inline-forum slide's existing tests stay unchanged and pass (pairing from the inner end).
- **In place:** a leaving pill's frame converges on the nearest pill; both glass views are in one merging container
  while it collapses and each is back in its own after; the pair's pulse is anchored at the right pills' trailing edge (`transitionAnchor`); an
  arriving pill starts at its partner and separates; a pill that comes back while leaving is the same pill; without
  native merging the leaving pill fades in its own container; Reduce Motion is opacity only; the arriving pill takes a
  tap at once.
- **Push and pop:** three right pills pair by index; the title pill takes the second slot only beside at most one right
  pill; a leftover merges into the nearest platter of the other bar.
- **Bar node** (`//submodules/TelegramUI/Components/NavigationBarNode:NavigationBarNodeTests`): an
  `ItemListController`-style pair (a search image item and an Edit text item) maps to two pills.

**In the app,** on the logged-in iPhone 18 Pro simulator, filmed frame by frame:

- Channel Administrators of the user's test channel (https://t.me/qwefqwfeqwfqwe), reached without opening any chat with
  unread messages: Edit <-> Done, a fast double tap, a push to an admin and back by tap and by swipe.
- Channel Members and Removed Users.
- Regression: Chats and its Edit mode, a chat, News, one iPhone Duo pass.
- A survey of every screen whose look changes under the rule (a text button beside another right button), with
  screenshots, for the user to review.

**Builds and suites:** `debug_sim_arm64` and `release_arm64` builds (the framework export lists are computed only in
release); the bar component and bar node suites.

## Out of scope

- Left items: the bar has one left button beside the back button, so there is nothing to group.
- The side column's own grouping on iPhone Duo.
- Grouping overrides (UIKit's `hidesSharedBackground`, `sharesBackground`, glass overrides): no screen asks for one.
- The open items recorded for the transitions (the pop's shorter neck, a search's close button) stay open.

## Success criteria

- Channel Administrators shows search and Edit as two pills, 12 pt apart; Edit -> Done sucks search into the Done pill
  and Done -> Edit ejects it, matching the reference app's film in order and timing.
- Every bar groups its right buttons by UIKit's rule; Chats looks exactly as before.
- Push and pop between bars with any number of right pills morph by index, with nothing sliding or popping.
- The suites and both builds are green.

## Results (2026-10-15)

Filmed on the logged-in iPhone 18 Pro simulator with real taps (`axe touch`), frames sampled for colour where it
mattered; native references are the reference app's films, the touch-driven one included.

**Channel Administrators** (`t.me/qwefqwfeqwfqwe`, Administrators):

- Search and Edit are two pills, 12 pt apart.
- **Edit -> Done:** search goes into Done as one shape, and nothing is left inside Done. The first films showed a
  dark band where the shapes met (0064c5 against 0083f9) and a dark disc in Done after the absorption. The causes
  (probed, see "How glass behaves in a glass container") were UIKit's animated tint change and UIKit's press on the
  tapped glass. Fixed in `95c1b8f8f1`; filmed since, the junction is within 4 levels of the body and Done settles on
  the plain accent (0085fa) every time.
- **Done -> Edit:** search comes out of Done as one shape. The pressed Done is native's exact colour (5ebcfd). At the
  change it shows the plain accent for one frame before fading to white; native holds it for ~0.085 s.
- **Two taps in a row:** even sent back to back, the second touch arrives ~0.55 s after the first change, once the
  merge has ended, so a tap inside a running merge could not be filmed (unit-tested instead). The films did catch a
  press on a pill still lent to a merge snapping back (fixed in `f2039f1601`).
- **Push and pop** between the channel profile and Administrators, by tap and by a cancelled swipe: the bar moves with
  its page (the profile draws its own header), with the pills intact.

**Elsewhere:**

- **Subscribers** (2 members): Edit alone (search joins at 200 members). Edit -> Done left Done **white with a blue
  edge**: the stuck-pale Done seen on master too, caused by UIKit's press and a change of effect on the same glass.
  Fixed in `692a6aa217`: before any in-place retint, a pressed pill gets a new effect view and its press's scale goes
  on as the bar's own. Filmed three times since, Done settles on the accent (0085fa, was f7f7fc).
- **Chats:** looks as before. Edit mode: the pills dematerialize and materialize in place. The title beside the story
  avatars used to snap across as the right buttons went (it overlapped the story/proxy capsule for ~0.07 s); the
  story list now eases its title bound on a spring of the update's duration (`503f5448e5`). Filmed: the title glides
  388 -> 446 px over 0.4 s and back, in step with the buttons.
- **A chat** (Peter Isaac) and **a News "For you" post:** push and pop morph as before.
- **Not filmed:** Removed Users (no entries on this channel), Members with 200+ (no such channel at hand), the iPhone
  Duo (its simulator renders nothing), the dark appearance and the clear glass style (the tint blend is unverified
  there).

**Differences from native left as they are** (kept by decision, 2026-10-16, "prefer ours"):

- Our pills join at the change, where native's join on the centre row ~0.2 s after its change starts.
- For a few frames after the change ours shows a neck between still-white pills.
- At Done -> Edit after a tap ours shows the plain accent for one frame; native holds it ~0.09 s.

**The tint's speed now matches** (user request, 2026-10-16): merging pills fade on the glass transition spring (duration
0.416, bounce 0.25), which fits native's fade at fixed points of four reference films (Edit <-> Done, tapped and on a
timer) within 0.012 of the way; the old 0.1 s critically damped spring was off by 0.19 (white <-> accent in ~0.07 s
against native's ~0.25 s). Filmed after the change, at the same points: Done -> Edit follows native's curve frame for
frame (its fitted start 0.013 s before the first changed frame, native's 0.012 s); Edit -> Done follows the same curve
but starts ~0.057 s (three frames) later than native's relative to the first changed frame. The items' dematerializing
is late by as much there, so the whole in-place animation starts late in that direction (not measured: likely the
list's edit-mode work holding the main thread, since the animator's clock starts at its first display-link frame).

Measured why (2026-10-16, the reference app's `-probe 1` and both tapped films): UIKit starts an animated bar-item change
~0.1 s after the action runs (one tap: touch up +0.008 s, action +0.009 s, label fade +0.105 s, glass pulse +0.122 s),
items and glass together, so the press has had time to release and native's text pill (which does not grow on a short
tap) is at rest when search starts toward it. Ours starts at once, over a pill UIKit's press has already grown (1.29x
for a text pill after an 8 ms tap), 2 pt from search, so they join immediately. The held accent is that same ~0.1 s. A
slower fade alone would only lengthen the white joined frames, so it is not done. (Note: `axe touch --delay 0.08`
makes an 8 ms touch, not an 80 ms one.)

**Survey** (`secondaryRightNavigationButton` / `rightBarButtonItems`):

| Screen | Right buttons | Look |
|---|---|---|
| Channel Administrators | search + Edit/Done | changes: two pills |
| Channel Members / Subscribers | search (200+) + Edit/Done | changes at 200+ members |
| Removed Users | search + Edit/Done | changes when it has entries |
| Saved Messages chat | more + avatar | unchanged (one capsule) |

The channel profile's [add story, Edit] capsule is PeerInfo's own header, not the bar component, and is unchanged
(UIKit would split it).

**Whole-branch review** (Opus, fresh context): ready with fixes, no Critical. Fixed in `4280c582bd`: a relayout
mid-merge sent the leaving pill toward its partner's old frame, and an item change on a still-lent pill went through
UIKit's animated effect change. Nine minors were deferred (the tenth, b, was fixed before the merge) and were dealt
with on 2026-10-16 (`fa790829b8`, `fd9620e6ea`, `c643afc56b`, and a review fix after them): a partner that only moves springs from where it is with its items (with three pills an insertion had
left it at its old frame for good); a non-animated removal of a lent pill ends its merge; the press is read only by
in-place layouts; a container that takes its glass back ends the loan; `renewGlass` waits out a context menu; a push
mid-merge carries the bar's own press, once and with no glow; a touch on a lent glass is sampled; the merging container follows the
appearance; stale docs. Measured rather than changed: the pulse anchor needs no refresh (it is a unit point), and the
per-frame glass effect costs ~14 us on the simulator and was already paid by every in-place frame (the shape is in the
glass's params).

**Builds and suites:** `debug_sim_arm64` OK. `release_arm64` OK on the split-buttons branch tip (81 actions), not re-run
after the 2026-10-16 follow-ups. `NavigationBarComponentTests` 190/190 (180 before the follow-ups),
`NavigationBarNodeTests` 77/77.
