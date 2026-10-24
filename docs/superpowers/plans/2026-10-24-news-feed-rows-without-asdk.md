# News feed rows without AsyncDisplayKit — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The News feed's post-row swipe wrapper and the shared `AvatarComponent` stop using AsyncDisplayKit nodes, with
no visible or felt difference anywhere.

**Architecture:**
- **Swipe (Part 1):** `ItemListRevealOptionsItemNode` gets a line-by-line `UIView` twin in ItemListUI, and the feed's
  `NewsPostRevealNode` becomes `NewsPostRevealView` on top of it.
- **Avatar (Part 2):** `AvatarNode.swift` exposes the routines `ContentNode` already runs (draw, image resolution,
  parameters, state key). `AvatarComponent.View` re-hosts them on plain views and layers, with ImageNode's
  photo-transition rules.
- **Verification:** before/after simulator recordings and pixel diffs. Unit tests cannot reach these modules (they
  link `AccountContext`).

**Tech Stack:** Swift, UIKit/Core Animation, Display, ItemListUI, ComponentFlow, SwiftSignalKit, Bazel via `Make.py`.

**Spec:** `docs/superpowers/specs/2026-10-24-news-feed-rows-without-asdk-design.md` (approved). Read it first; its
"What happens today" and substitution table are the contract this plan implements.

## Global Constraints

- **Mechanics preserved exactly:** `ItemListRevealOptionsItemNode`'s mechanics are preserved exactly. The only allowed
  differences in the port are the spec's substitution table and its dropped `ListViewItemNode` hooks.
- **Avatar parity:** `AvatarComponent`'s appearance and behaviour are unchanged at all 43 call sites.
- **Off-main placeholder:** with `synchronousLoad == false` the letters placeholder is never drawn on the main
  thread. It renders on a concurrent queue that targets `.userInitiated`, never on `Queue.concurrentDefaultQueue()`.
- **Untouched:** `ItemListRevealOptionsNode` stays an ASDisplayNode, created only when a swipe starts. The post text
  (`MultilineTextWithEntitiesComponent`) and `ItemListRevealOptionsItemNode` are not changed.
- **No copies of AvatarNode's logic:** `ContentNode` and `AvatarComponent.View` call the same extracted functions.
- **Builds and installs are the controller's job:** builds use the root `CLAUDE.md` `Make.py build` command with
  `source ~/.zshrc 2>/dev/null;`. No subagent runs Bazel.
- **Simulator:** install and record only on the "iPhone 18 Pro" simulator `3A36B4F5-C2D0-41AA-8203-E46EA58CD43D`. Use
  the CLAUDE.md whole-`.app` copy from `bazel-bin/Telegram/Telegram.ipa`, with that UDID in place of K3.
- **Recording:** follow `AGENTS.md` "Visual features and animations": `simctl io recordVideo`, then
  `tools/animation_sheet.py`. Keep artifacts in the session scratchpad, never in the repo.
- **Warnings are errors** in these modules: no unused variables, no dead casts.
- **Commits:** one commit for Part 1 (Tasks 1–2) and one for Part 2 (Tasks 3–4), each ending with the attribution line.
  Never push.

## Review Focus

1. **Tab pager versus row swipe.**
   - A leftward drag on a For you row opens its swipe and does not page.
   - On an Added row, which has no options, the same drag pages to For you.
   - With a For you row open, dragging on it moves the swipe, not the pager.
   - Pinned in Task 2 (clip `pager-arbitration`).
2. **A row that leaves the window while open comes back closed.** Switching tabs, or scrolling the row out of the
   loaded window, resets it (`didExitHierarchy` → `didMoveToWindow`). Pinned in Task 2 (clip `exit-while-open`).
3. **A theme switch with the feed on screen:**
   - swipe options recolour and an open row stays open (`setRevealOptions`);
   - letter avatars redraw in the new theme (theme identity is in the avatar's state key).
   - Pinned in Task 2 (clip `theme-switch-swipe`) and Task 4 (screenshots `theme-*`).
4. **A size change without a peer change** (rotating to landscape):
   - letters re-render at the new size, off the main thread;
   - photos keep their bitmap, stretched, as today.
   - Pinned in Task 4 (screenshots `landscape-*`).
5. **Reduce Motion on:**
   - the swipe snaps, as `motion.snapToTargets` does;
   - the highlight fade becomes immediate;
   - otherwise identical to the baseline.
   - Pinned in Task 2 (clip `reduce-motion-swipe`).

---

### Task 0: Baseline build, recordings and screenshots (controller)

**Files:** none in the repo. Artifacts go to `$SCRATCH/baseline/`, where `$SCRATCH` is the session scratchpad.

- [ ] **Step 1:** Build HEAD with `Make.py build` (root `CLAUDE.md` command). Expected: `Build completed successfully`.
  Read the build's own exit status, not the status of a trailing command.
- [ ] **Step 2:** Install it on 3A36B4F5 with the whole-`.app` copy, then launch it. Check that the installed
  `Frameworks/TelegramUIFramework.framework/TelegramUIFramework` md5 equals the one inside the `.ipa`.
- [ ] **Step 3:** Open News, then check that both tabs show posts, some with letter avatars and some with photos.
  - If either tab is empty or the app is logged out, stop and ask the user.
- [ ] **Step 4: Write `$SCRATCH/baseline/expectations.md`.** For each clip and screenshot below, record what it must
  show: the gesture, which elements move, and roughly for how long. The comparison later is after-versus-baseline,
  frame by frame.
- [ ] **Step 5:** Record the swipe and highlight clips at real speed, each with still time on both sides:
  - `swipe-partial`: a partial drag that settles closed;
  - `swipe-open`: a drag past half, released, then the settle open;
  - `swipe-commit`: a full swipe through the commit edge (the haptic point), then the row closing and reporting;
  - `tap-close`: tap on an open row;
  - `scroll-close`: vertical scroll with a row open;
  - `second-row`: open row A, then open row B;
  - `separators`: zoomed with `--crop` on the separators above and below the swiping row;
  - `highlight-tap-foryou`, `highlight-hold-foryou`, `highlight-scroll-cancel-foryou`, and the same three on Added;
  - `pager-arbitration` (Review Focus 1);
  - `exit-while-open` (Review Focus 2);
  - `theme-switch-swipe` (Review Focus 3): toggle with `xcrun simctl ui <udid> appearance dark|light`;
  - `reduce-motion-swipe` (Review Focus 5): turn Reduce Motion on in Settings ▸ Accessibility ▸ Motion, then off
    again afterwards.
- [ ] **Step 6:** Record `fling-avatars-foryou` and `fling-avatars-added`: a fast fling through rows not yet seen, so
  that letters, pending photos and photo fades all appear.
- [ ] **Step 7:** Take still screenshots with `xcrun simctl io <udid> screenshot`:
  - `feed-foryou`, `feed-added`, and the "Post hidden" panel (`post-hidden`, a For you swipe ▸ Not Interested);
  - the chat list (`chatlist`; it uses `AvatarNode` directly, which Task 3 touches);
  - `theme-dark-feed` and `landscape-feed` (Review Focus 3–4);
  - at least one reachable screen per variant: a `.roundedRect` `AvatarComponent` (`roundedrect-*`), an `icon`
    cutout (`icon-*`), and the `overrideImage` icons (`override-*`, e.g. the Delete Saved Messages alert).
  - Write the reached screen and its navigation path into `expectations.md`, so that the "after" shot reaches exactly
    the same screen.

### Task 1: `updateAlpha(view:…)` and `ItemListRevealOptionsItemView`

**Files:**
- Modify: `submodules/Display/Source/ContainedViewLayoutTransition.swift`, next to `updateAlpha(node:…)` at `:1050`
- Create: `submodules/ItemListUI/Sources/Items/ItemListRevealOptionsItemView.swift`
- Modify: `submodules/ItemListUI/Sources/Items/ItemListEditableItem.swift`. Comment only: one line above
  `open class ItemListRevealOptionsItemNode` naming its twin.

**Interfaces:**
- Produces, in Display:

  ```swift
  func updateAlpha(view: UIView, alpha: CGFloat, beginWithCurrentState: Bool = false, force: Bool = false, delay: Double = 0.0, completion: ((Bool) -> Void)? = nil)
  ```

  It sits in the same extension as `updateAlpha(node:…)`.
- Produces, in ItemListUI:

  ```swift
  open class ItemListRevealOptionsItemView: UIView, UIGestureRecognizerDelegate
  ```

  It has the same public/open API as the node, retyped:
  - `revealOffset`, `isRevealOptionsActive`, `isNextRevealOptionsActive`, `revealOptionsSeparatorAlpha`,
    `nextRevealOptionsSeparatorAlpha`, `isDisplayingRevealedOptions`, `revealOptionsHighlightProgress`;
  - `updateRevealOptionsSeparatorNodes(top: UIView?, bottom: UIView?, …)`;
  - `updateRevealOptionsHighlightedBackgroundFrame(_: UIView, frame:tracksRevealOffset:activeCornerRadius:transition:aboveNodes: [UIView?])`;
  - `updateRevealOptionsHighlightedBackgroundNode(_: UIView, isHighlighted:transition:aboveNodes: [UIView?], highlightAlpha:allowsRevealHighlight:)`;
  - `open var controlsContainer: UIView`;
  - `setRevealOptions(_:enableAnimations:)`, `revealOptionAnimationKey(_:)`, `updateLayout(size:leftInset:rightInset:)`,
    `updateRevealOffsetInternal(offset:transition:completion:)`, `setRevealOptionsOpened(_:animated:)`,
    `animateRevealOptionsFill(completion:)`;
  - the open hooks: `updateRevealOffset(offset:transition:)`, `revealOptionsActiveStateUpdated(isActive:transition:)`,
    `nextRevealOptionsActiveStateUpdated(isActive:transition:)`, `revealOptionsInteractivelyOpened()`,
    `revealOptionsInteractivelyClosed()`, `revealOptionSelected(_:animated:)`, `revealOptionsSeparatorAlphaUpdated()`,
    `revealOptionsSurfaceUpdated(progress:)`;
  - `open func gestureRecognizer(_:shouldRecognizeSimultaneouslyWith:)`, `…shouldRequireFailureOf:`,
    `…shouldBeRequiredToFailBy:`, and `override open func gestureRecognizerShouldBegin(_:)`;
  - `init()`, which calls `super.init(frame: CGRect())`.
  - Keep the parameter label `aboveNodes:` (typed `[UIView?]`), so that the News call sites change minimally.

- [ ] **Step 1: Add `updateAlpha(view:…)`.**
  - Its body is `updateAlpha(node:…)` (`:1050-1082`) verbatim, with `node.alpha` → `view.alpha` and `node.layer` →
    `view.layer`.
  - Before using `updateFrame(view:…)` in the port, diff it against `updateFrame(node:…)` (`:250`). Note any
    difference in the task report; if they differ, ask before proceeding.
- [ ] **Step 2: Write the port.**
  - Copy `ItemListEditableItem.swift:61-755` into the new file and apply exactly the spec's substitution table:
    - `didLoad` → end of `init`;
    - `didExitHierarchy` → `override open func didMoveToWindow()`, which calls `resetRevealInteraction(notify: true)`
      when `self.window == nil`;
    - `wrappedGestureRecognizerDelegate` → `self`;
    - `addSubnode(node)` → `controlsContainer.addSubview(node.view)`;
    - highlight and separator `ASDisplayNode` → `UIView`, with `insertSubview(_:aboveSubview:)` /
      `insertSubview(_:at:)`, `superview`, `layer.cornerRadius`;
    - `transition.updateAlpha(node:…)` → `updateAlpha(view:…)` with the same `delay:`;
    - `transition.updateFrame(node:…)` → `updateFrame(view:…)`;
    - `self.view` → `self`;
    - display scale → `self.traitCollection.displayScale`;
    - `previousRevealOptionsItemNode()` → the frame branch over `superview?.subviews`, typed
      `ItemListRevealOptionsItemView`.
  - Drop the six ListView hook overrides the spec lists.
  - Keep the `ItemListRevealOptionsGestureRecognizer` class where it is; do not copy it.
- [ ] **Step 3: Review the port as a diff.**
  - Run `diff <(sed -n '61,755p' submodules/ItemListUI/Sources/Items/ItemListEditableItem.swift) <(sed -n '<range>p' submodules/ItemListUI/Sources/Items/ItemListRevealOptionsItemView.swift)`.
  - Expected: every hunk is a substitution-table row or a dropped hook. Paste the hunk list, one line per hunk, into
    the task report.
- [ ] **Step 4:** Controller runs `Make.py build`. Expected: green, with no new warnings. ItemListUI is
  warnings-as-errors.

### Task 2: The feed's rows on `NewsPostRevealView`

**Files:**
- Modify (rename to `NewsPostRevealView.swift`): `submodules/TelegramUI/Components/News/NewsFeedComponents/Sources/NewsPostRevealNode.swift`
- Modify: `submodules/TelegramUI/Components/News/NewsFeedComponents/Sources/NewsFeedPostComponent.swift:187, 215-216, 300, 315, 328, 343-362, 389, 395, 408, 622-623`
- Modify, only if nothing else needs it: `submodules/TelegramUI/Components/News/NewsFeedComponents/BUILD` (drop
  `AsyncDisplayKit`)

**Interfaces:**
- Consumes: `ItemListRevealOptionsItemView` (Task 1).
- Produces:

  ```swift
  final class NewsPostRevealView: ItemListRevealOptionsItemView
  ```

  - `let contentView: UIView`, `let highlightView: UIView`;
  - `var opened`, `var separatorAlphaChanged`, `var selected`, with the same types as now;
  - `func update(size: CGSize, options: [ItemListRevealOption], highlightColor: UIColor)`.
  - `NewsPostSwipe`, `newsPostSwipeTitle` and `newsPostRevealOptions` are unchanged.

- [ ] **Step 1: Convert `NewsPostRevealNode`.** The overrides keep their bodies, with `self.view` read as `self`.
  `contentNode`/`highlightNode` become `contentView`/`highlightView` (`highlightView.isUserInteractionEnabled = false`).
- [ ] **Step 2: Switch `NewsFeedPostComponent.View` over.**
  - `revealNode` becomes `revealView`;
  - `addSubview(self.revealView)`;
  - `self.revealView.contentView.addSubview(self.contentView)`;
  - the fade's alpha and filters go on `revealView` / `revealView.layer`;
  - the highlight call becomes `updateRevealOptionsHighlightedBackgroundNode(self.revealView.highlightView, …)`.
- [ ] **Step 3: Check for leftovers.** `grep -n "revealNode\|ASDisplayNode\|AsyncDisplayKit" submodules/TelegramUI/Components/News/NewsFeedComponents/Sources/*.swift`.
  Expected: no matches. `import AsyncDisplayKit` may remain only if a remaining symbol needs it.
- [ ] **Step 4:** Controller builds. Then run
  `Make.py test … --target //submodules/TelegramUI/Components/News/NewsFeedSupport:NewsFeedSupportTests`.
  Expected: build green, tests 0 failures, and the test log shows they started.
- [ ] **Step 5:** Install on 3A36B4F5 and re-record every Task 0 Step 5 clip under `$SCRATCH/part1/`, same gesture,
  same rows.
  - Compare each clip with its baseline in `tools/animation_sheet.py` sheets: the same motion start and stop, the same
    overshoots, settle within 1 frame, the same separator and highlight alpha path.
  - Record any difference in `$SCRATCH/part1/comparison.md`. An unexplained difference blocks the commit.
- [ ] **Step 6: Commit Part 1.**
  ```bash
  git add submodules/Display/Source/ContainedViewLayoutTransition.swift submodules/ItemListUI/Sources/Items/ItemListRevealOptionsItemView.swift submodules/ItemListUI/Sources/Items/ItemListEditableItem.swift submodules/TelegramUI/Components/News/NewsFeedComponents
  git commit -m "News: post rows swipe on a UIView twin of ItemListRevealOptionsItemNode"
  ```

### Task 3: AvatarNode exposes what ContentNode runs

**Files:**
- Modify: `submodules/AvatarNode/Sources/AvatarNode.swift`: `:45` (parameters), `:193-210` (state),
  `:791-917` (`ContentNode.setPeer(context:…)`), `:958-1162` (`ContentNode.draw`)

**Interfaces:**
- Produces, all at file scope in `AvatarNode.swift`, so that the file-private icon constants stay private:

  ```swift
  public final class AvatarNodeParameters  // was private; members and init stay internal
  public enum AvatarNodeState: Equatable   // was private, with its == made public
  ```

  - `public func avatarNodeResolvedImage(context: AccountContext, peer: EnginePeer?, overrideImage: AvatarNodeImageOverride?, synchronousLoad: Bool) -> (representation: TelegramMediaImageRepresentation?, icon: AvatarNodeIcon, synchronousLoad: Bool)`.
    Its body is `:806-849` verbatim.
  - `public func avatarNodePeerParameters(context: AccountContext, accountPeerId: EnginePeer.Id, theme: PresentationTheme, peer: EnginePeer?, icon: AvatarNodeIcon, font: UIFont, hasImage: Bool, clipStyle: AvatarNodeClipStyle, cutoutRect: CGRect?) -> AvatarNodeParameters`.
    It builds both of today's constructions; `peer?.id ?? EnginePeer.Id(0)` equals `peer.id` in the photo branch.
  - `public func avatarNodePeerState(peer: EnginePeer?, representation: TelegramMediaImageRepresentation?, clipStyle: AvatarNodeClipStyle, cutoutRect: CGRect?) -> AvatarNodeState`.
    This is the `.peerAvatar(…)` expression at `:851`.
  - `public func drawAvatarNodeContent(bounds: CGRect, parameters: Any?, isRasterizing: Bool)`.
    Its body is `ContentNode.draw`'s body verbatim, drawing into `UIGraphicsGetCurrentContext()`.

- [ ] **Step 1: Extract the four functions.**
  - `ContentNode.setPeer(context:…)` and `ContentNode.draw` call them in place of their inline code.
  - `ContentNode.draw`'s body becomes the single call `drawAvatarNodeContent(bounds: bounds, parameters: parameters, isRasterizing: isRasterizing)`.
- [ ] **Step 2: Diff-review the change.** `git diff submodules/AvatarNode` must show only:
  - moved code, unchanged character for character apart from indentation and the `self.font` → `font` argument;
  - access-level changes on the two types;
  - the call sites.
- [ ] **Step 3:** Controller builds. Expected: green.
- [ ] **Step 4:** Install and screenshot `chatlist` and `feed-*` under `$SCRATCH/part2a/`. Compare pixel-wise with the
  baseline using the Task 4 Step 5 diff script. Expected: identical (0 differing pixels), apart from time-dependent
  content (clock, "now" timestamps), which you mask with `--ignore` rects.

### Task 4: `AvatarComponent.View` on plain views

**Files:**
- Modify: `submodules/TelegramUI/Components/AvatarComponent/Sources/AvatarComponent.swift:75-191`
- Modify: `submodules/TelegramUI/Components/AvatarComponent/BUILD`:
  - add `//submodules/SSignalKit/SwiftSignalKit`;
  - drop `//submodules/AsyncDisplayKit` once unused.

**Interfaces:**
- Consumes: Task 3's four functions and two types.
- Produces: the same `AvatarComponent` API, with no changes to callers.
  - `View` stays `public final class View: UIView`.
  - A private `final class AvatarComponentImageLayer: SimpleLayer` with `func setSignal(_ signal: Signal<UIImage?, NoError>)`.
  - A private `let avatarComponentDisplayQueue = Queue(queue: DispatchQueue(label: "AvatarComponent.display", qos: .userInitiated, attributes: .concurrent))`.

- [ ] **Step 1: Write `AvatarComponentImageLayer.setSignal`.** It is `ImageNode.setSignal` (`Display/Source/ImageNode.swift:171-220`)
  specialised to `enableEmpty = false`, `enableAnimatedTransition = true`, `animateFirstTransition = true`:
  - `deliverOnMainQueue`;
  - a `wasSynchronous` flag cleared after `start`;
  - `first` is never reset;
  - the first non-nil image after an asynchronous delivery fades 0→1 over 0.18 s (`animateAlpha`);
  - later images crossfade over 0.2 s, `easeInEaseOut`, through a temporary sublayer;
  - nil is ignored;
  - one `MetaDisposable`, disposed in `deinit`.
- [ ] **Step 2: Restructure `View`.**
  - A `contentView: UIView` stands in for ContentNode: `isOpaque = false`, `accessibilityIgnoresInvertColors = true`,
    frame `(0, 0, size)`.
  - Its `layer.contents` holds the placeholder bitmap; `imageLayer` is a sublayer filling it.
  - The root gets nothing on `layer.mask`.
  - The icon code is unchanged: it is never removed when `icon` becomes nil, and the cutout is pre-flipped.
  - `font = avatarPlaceholderFont(size: ceil(42.0 * size.width / 100.0))` is set on the first update only, as today.
  - Stored: `state: AvatarNodeState = .empty`, `overrideImage`, `theme`, `parameters: AvatarNodeParameters?`,
    `placeholderSuspended: Bool`, `placeholderGeneration: Int`.
- [ ] **Step 3: Write the update order.** It mirrors `AvatarComponent` → `AvatarNode.frame` → `ContentNode.setPeer`:
  1. **Size changed** (the `AvatarNode.frame` rule, `AvatarNode.swift:1254-1264`): lay out `contentView` and
     `imageLayer`. Then, if `!placeholderSuspended`, schedule an **asynchronous** placeholder render.
  2. **Resolve:** call `avatarNodeResolvedImage(…)`, then `avatarNodePeerState(…)`.
     - If neither the state, the override nor the theme identity changed, stop here.
  3. **Photo branch** (`peer != nil` and `peerAvatarImage(account: context.account, peerReference: PeerReference(peer), authorOfMessage: nil, representation:, displayDimensions: size, clipStyle:, emptyColor: nil, synchronousLoad:, provideUnrounded: false, cutoutRect:)` is non-nil):
     - clear `contentView.layer.contents`;
     - set `placeholderSuspended = true` and bump `placeholderGeneration`, which cancels an in-flight render;
     - `imageLayer.setSignal(signal |> map { $0?.0 })`;
     - parameters get `hasImage: true`.
  4. **Letters branch:**
     - set `placeholderSuspended = false`;
     - clear `imageLayer.contents`, but do **not** dispose its signal (AvatarNode doesn't);
     - parameters get `hasImage: false`;
     - render the placeholder **inline** when the resolved `synchronousLoad` is true, otherwise asynchronously.
  5. **Placeholder render:**
     - every render request, inline or asynchronous, first bumps `placeholderGeneration`, so only the latest request
       lands;
     - draw `UIGraphicsImageRenderer(size: bounds.size, format: .preferred())` (opaque false, scale = main screen
       scale, as `ASGraphicsCreateImage` does) by calling `drawAvatarNodeContent(bounds: CGRect(origin: .zero, size: size), parameters: parameters, isRasterizing: false)`;
     - asynchronously: on `avatarComponentDisplayQueue`, delivered on main, applied only if `placeholderGeneration`
       still matches and `!placeholderSuspended`;
     - the previous contents stay until then.
- [ ] **Step 4:** Controller builds. Expected: green. Then check that `grep -n "AvatarNode(\|addSubnode\|import AsyncDisplayKit" submodules/TelegramUI/Components/AvatarComponent/Sources/AvatarComponent.swift`
  finds nothing.
- [ ] **Step 5: Write the pixel-diff script** at `$SCRATCH/pixdiff.py`, run with `python3 -I`.
  - It uses PIL.
  - Arguments: `before.png after.png [--ignore X,Y,W,H …]` (points, scale 3).
  - It prints the count of differing pixels and their bounding box, and writes `diff.png`.
- [ ] **Step 6:** Install, then re-take every Task 0 Step 7 screenshot under `$SCRATCH/part2/`, reaching each screen
  by the path recorded in `expectations.md`.
  - Expected: 0 differing pixels outside time-dependent rects.
  - Explain any difference before continuing.
- [ ] **Step 7:** Re-record `fling-avatars-foryou` and `fling-avatars-added`, and compare them with the baseline sheets:
  - letters appear, at the earliest, the same frame after a row appears as in the baseline;
  - photos fade in over about 0.18 s;
  - blurred thumbnails crossfade over about 0.2 s;
  - no row shows letters under a photo that is still pending.
- [ ] **Step 8: Commit Part 2.**
  ```bash
  git add submodules/AvatarNode/Sources/AvatarNode.swift submodules/TelegramUI/Components/AvatarComponent
  git commit -m "AvatarComponent: render without AvatarNode, sharing ContentNode's drawing"
  ```

### Task 5 (optional, not committed): what the change buys

- [ ] **Step 1:** On a scratch copy of the tree, add `os_signpost` intervals around `NewsFeedPostComponent.View.update`
  in the baseline and the final tree. Fling each feed 5 times. Report the median and p95 per-row update time,
  before and after. Remove the signposts afterwards; never commit them.
