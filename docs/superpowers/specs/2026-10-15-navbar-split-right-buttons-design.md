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

Whether Edit's swell before an insertion belongs to the merge or to UIKit swapping Edit's own item (the reference app
creates a new Edit item each time) is not separated by that film. **Task 1 of the plan measures the exact
Administrators case** (`[Edit, search]` <-> `[Done]`, see Verification) and its results are recorded in this spec
before any animation code is written.

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

### 2. Animation of an in-place change

The old and new right pills are compared by index from the edge, as UIKit compares section IDs.

- **The same index on both sides:** as today. The shape springs to its new frame, its items swap with a centred pulse,
  its tint cross-fades (Edit -> Done turns it accent), a press in progress carries on.
- **A pill that goes** (search, when Edit becomes Done): it collapses into the nearest remaining pill on that side, after
  SwiftUI's resolved delay, kicked away from its partner; its items leave into the partner; its glass and the
  partner's share one container at smoothness 12 until it is gone, then the partner's glass goes back to its own
  container; the partner pulses anchored on the side facing it (`transitionAnchor`). This is the "sucked in".
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
- **A press on the partner.** Moving the partner's glass may end the press UIKit is drawing on it (the tap on Edit
  that started the change is still releasing). The animator therefore reads that press (`navigationBarCapsulePressScale`)
  when it lends the glass and continues it as its own spring (`NavigationBarGlassSettings.pressRelease`), multiplied
  with the pulse, as push/pop does with a bar's press. Task 5 films the case in the app and checks that UIKit's own
  press does not also carry on (a doubled press); if it does, the measured continuation is dropped.
- The order and timings above are the starting point. Where Task 1's measurement of the Administrators case differs
  (in particular whether the partner swells before an insertion), the measurement wins and this section is updated.

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
  while it collapses and each is back in its own after; the partner's pulse is anchored on the side facing it; an
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
