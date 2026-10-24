# News feed rows without AsyncDisplayKit: the swipe host and AvatarComponent — design

**Date:** 2026-10-24
**Status:** approved by the user 2026-10-24 ("proceed"), including Part 1's copy-not-shared-core shape

## Why

Flings in both News feeds (For you and Added) hitch on a fast phone (user, 2026-10-24). A post row that comes on
screen mid-fling is built on the main thread inside a scroll tick, and today it creates about five AsyncDisplayKit
nodes, each with its node, view and layer:

- the row's swipe wrapper `NewsPostRevealNode` (an `ItemListRevealOptionsItemNode`, i.e. a `ListViewItemNode`) with
  its `contentNode` and `highlightNode`;
- the avatar: `AvatarComponent` hosts an `AvatarNode` (outer node, `ContentNode`, `ImageNode`);
- the post text: `MultilineTextWithEntitiesComponent` → `ImmediateTextNodeWithEntities`.

This design removes the first two. **The post text stays on its current component** (user: "We will rewrite that one
later"). It is also the first step before the feed moves from CoreList's `.stepped` deceleration to `.keyframe`,
which is a separate, later design; whatever main-thread work goes away here also helps there.

No measurement has attributed the hitch to node creation yet. The user chose to do this rewrite directly.

## Goals

1. The post row's swipe wrapper is a plain `UIView`, with `ItemListRevealOptionsItemNode`'s mechanics **preserved
   exactly** (user): every threshold, spring, haptic, highlight and separator behaviour, and every gesture
   arbitration rule.
2. The shared `AvatarComponent` renders with plain `UIView`/`CALayer`, no `AvatarNode` (user: "enhance the shared
   AvatarComponent class"), with appearance and behaviour unchanged **at every one of its 43 call sites**, not only in
   the feed.

## Non-goals

- The post text (`MultilineTextWithEntitiesComponent` / `ImmediateTextNodeWithEntities`).
- `ItemListRevealOptionsNode`, the action buttons. It stays an `ASDisplayNode`; that is acceptable to the user because it
  is created only when a swipe starts (`setupRevealNode`, `ItemListEditableItem.swift:548-563`) and removed when the
  motion closes (`:625-630`), so it never exists during a fling.
- `ItemListRevealOptionsItemNode` itself and its other subclasses across the app: unchanged.
- `AvatarNode` as a class: it keeps working for its own users. Its only change is that the drawing and parameter
  logic `AvatarComponent` needs becomes a shared, public routine (Part 2).
- CoreList `.keyframe`, the outside position tracking it needs, and any other hitch source (state pushes rebuilding
  items, page arrival, per-tick followers).

## Anti-goals (a failure even if it works)

- Any visible or felt difference in the swipe on any feed row: open/close feel, the commit threshold and its haptic,
  the full swipe, tap-to-close, scroll-to-close, the press highlight and its 0.4 s fade, the separators fading.
- Any pixel or timing difference in an avatar on any of the 43 screens: placeholder letters, gradient, icons, clip
  shapes, the cutout, the photo's fade-in and crossfade, the moment anything first appears.
- The letters placeholder being drawn on the main thread where ASDK drew it on a background queue today
  (`synchronousLoad == false`, which is what feed rows built during scrolling use). That would move work *into* the
  fling.
- A second press-highlight implementation for rows that do not swipe (Added, search results).

## Part 1: `ItemListRevealOptionsItemView`

### Where and how

- New file `submodules/ItemListUI/Sources/Items/ItemListRevealOptionsItemView.swift`:
  `open class ItemListRevealOptionsItemView: UIView, UIGestureRecognizerDelegate`.
- It must live in ItemListUI: `ItemListRevealMotion`, `ItemListRevealMotionParameters`,
  `ItemListRevealTouchGestureRecognizer`, and `ItemListRevealOptionsNode`'s `motionParameters(width:sideInset:displayScale:)`,
  `render(motion:)` and `containsActionPoint(_:)` are all internal to it.
- **A line-by-line port of `ItemListRevealOptionsItemNode`** (`ItemListEditableItem.swift:61-755`): same stored
  properties, same methods in the same order, same bodies, changed only by the substitutions below. The node class
  is not touched. *(My call; the user heard "copy vs. extract a shared core" and didn't pick. A copy keeps every other
  item-list row in the app off the diff. The cost is two copies to keep in step; each file gets a one-line comment
  naming the other.)*

### Substitutions (the only allowed differences)

| Node | View |
|---|---|
| `super.init(layerBacked:rotated:seeThrough:)` | `super.init(frame:)` |
| `didLoad()` (recognizers, `disablesInteractiveTransitionGestureRecognizerNow`, reduce-motion observer) | done in `init` |
| `didExitHierarchy()` | `didMoveToWindow()` when `window == nil`. ASDK maps it exactly this way (`_ASDisplayView.mm:164-171`) |
| `recognizer.delegate = self.wrappedGestureRecognizerDelegate` | `recognizer.delegate = self` |
| `override func gestureRecognizerShouldBegin(_:)` (ASDisplayNode) | `override func gestureRecognizerShouldBegin(_:)` (UIView), same body. Today the node's method is reached **both** as the recognizers' delegate (through `WrappedGestureRecognizerDelegate`, `Display/Source/GestureRecognizerDelegate.swift`) **and** as the view's own UIView hook (`_ASDisplayView.mm:440-444`), so it is also asked about ancestor recognizers whose touches start in the row (CoreList's pan, the pager). It returns `true` for any recognizer it does not own, as UIView's default does. The view keeps both roles by being its own delegate and overriding the UIView method |
| `controlsContainer: ASDisplayNode` + `addSubnode(node)` | `controlsContainer: UIView` + `addSubview(node.view)`. `ItemListRevealOptionsNode` stays a node, and `bounds`/`position`/`measure` are used on it exactly as now |
| highlight background `ASDisplayNode`, `insertSubnode(_:aboveSubnode:)` / `insertSubnode(_:at:)`, `supernode` | `UIView`, `insertSubview(_:aboveSubview:)` / `insertSubview(_:at:)`, `superview` |
| separator `ASDisplayNode`s in `updateRevealOptionsSeparatorNodes` | `UIView`s |
| `self.view` | `self` |
| `isNodeLoaded ? self.view.traitCollection.displayScale : UIScreen.main.scale` | `self.traitCollection.displayScale` |
| `previousRevealOptionsItemNode()` over `supernode?.subnodes`, `index` branch first | the frame-based branch over `superview?.subviews` (a plain view has no ListView `index`). In the feed this returns nil, as the node's does today: the node has no supernode, because its view is added with `addSubview`. *(My call: kept for an eventual ListView-like host rather than dropped.)* |

**`updateAlpha(..., delay:)`:** the node's highlight fade-out passes `delay:` to the node variant of
`ContainedViewLayoutTransition.updateAlpha`. Keep the delay in the port, adding a view/layer variant with `delay:` to
Display if none exists. The delay is 0 in the feed, but the port must not assume it.

**Dropped:** the overrides of `ListViewItemNode` hooks that only `ListView` calls and CoreList never does. Each base
implementation is empty (`ListViewItemNode.swift:195-200, 404, 632-636`). They are `setHighlighted(_:at:animated:)`,
`selected()`, `canBeSelected`, `reuse()`, `preventsTouchesToOtherItems` and `touchesToOtherItemsPrevented()`. The
stored state they touch (`selectionHighlightEndTime`, `highlightFadeGeneration`) stays, because other methods use it.
In the feed `selectionHighlightEndTime` is always 0 today, since `selected()` is never called, so behaviour is
identical. *(My call.)*

### News side

- `NewsPostRevealNode` (`NewsFeedComponents/Sources/NewsPostRevealNode.swift`) becomes `NewsPostRevealView:
  ItemListRevealOptionsItemView`.
  - `contentNode`/`highlightNode` become `contentView`/`highlightView` (`UIView`).
  - The overrides keep their bodies, including the `shouldBeRequiredToFailBy` rule that makes CoreList's pan wait,
    with `self.view` read as `self`.
  - `update(size:options:highlightColor:)` keeps the same geometry (`contentView` bounds/position follow `revealOffset`).
- `NewsFeedPostComponent.View` swaps the node for the view everywhere it uses it: `:187, 215-216, 300, 315, 328, 343-362,
  389, 395, 408, 622-623`. The fade's alpha and blur filter go on `revealView.layer`.
- **Every post row keeps the wrapper, including rows that do not swipe.** The press highlight of every row, Added's
  included, runs through `updateRevealOptionsHighlightedBackgroundNode` → `applyRevealOptionsHighlight`. A row with
  no options has its recognizers disabled (`updateRecognizerAvailability`), as today. This reverses an idea floated
  in conversation.
- `NewsFeedComponents/BUILD` keeps `AsyncDisplayKit` only if something else in the module still needs it.

## Part 2: `AvatarComponent` without `AvatarNode`

### What happens today (the contract)

`AvatarComponent.View.update` sets `avatarNode.frame`, then calls
`AvatarNode.setPeer(context:theme:peer:overrideImage:clipStyle:synchronousLoad:displayDimensions:cutoutRect:)`, which
forwards to `ContentNode.setPeer(context:…)` (`AvatarNode.swift:791`). Line numbers below are in `AvatarNode.swift` (AN),
`PeerAvatar.swift` (PA) and `Display/Source/ImageNode.swift` (IN).

- **Mapping (AN:808-849):** `overrideImage` maps to a `representation` plus an `AvatarNodeIcon`. With no override, the
  representation is `peer.smallProfileImage`, unless `restrictionText(...)` is non-nil, in which case the peer gets
  letters.
- **State key (AN:853-854):** work happens only when this changes: `(peerId, nameColor, displayLetters, representation,
  clipStyle, cutoutRect)`, plus `overrideImage` and theme identity. **`displayDimensions` is not in it**, so a size
  change alone does not re-fetch the photo, and the old bitmap is stretched.
- **Photo path (AN:863-890):**
  - The content node's own contents are cleared and its drawing is suspended.
  - The photo comes from `peerAvatarImage(account:…)` (PA:169/186) into an `ImageNode(enableHasImage: true,
    enableAnimatedTransition: true)` (AN:442).
  - The signal delivers inline when it is synchronous: `synchronousLoad` plus a cached photo or a thumbnail. In that
    case the image is set with no animation.
  - A `nil` image is ignored, so the view stays **transparent, with no letters,** until the photo arrives.
  - The first non-nil image that arrives asynchronously fades 0→1 over 0.18 s (IN:178-183).
  - Each later image crossfades over 0.2 s, ease-in-ease-out, through a temporary sublayer (IN:184-195).
  - IN's `first` flag is never reset.
- **Letters/icon path (AN:891-917):**
  - `AvatarNodeParameters` is built with `calculateAvatarColors(context:…)`, the letters and the font.
  - Then `setNeedsDisplay()`, plus `recursivelyEnsureDisplaySynchronously(true)` when `synchronousLoad` is true.
  - `displaysAsynchronously = true` (AN:447). Otherwise the draw runs on ASDK's background queue: the first display is
    transparent for at least a frame, and on a redraw the old contents stay until the new ones land.
  - A frame-size change re-renders through `setNeedsDisplay`, which is asynchronous (AN:482-492, 1271-1278).
- **Draw (`ContentNode.draw`, AN:958-1162):**
  - clear, then clip: an ellipse, or a rounded rect with radius `floor(w*0.25)`;
  - a vertical gradient;
  - letters (a two-emoji pair collapses to one; glyph-path bounds; pixel-floored centring; +1 pt for "B"), or an
    icon scaled by `w/60`;
  - a `.copy`-cleared `cutoutRect` ellipse.
  - `cutoutRect` is in bottom-left space; `AvatarComponent.swift:126` pre-flips it.
- **`AvatarComponent` quirks, to keep:**
  - the font is set to `avatarPlaceholderFont(size: ceil(42*w/100))` on the first update only;
  - the `transition` argument is ignored;
  - an `icon` view is never removed once `icon` becomes nil;
  - nothing on the root `layer.mask` (`AlertTransferHeaderComponent.swift:123-133` sets one on the avatar view);
  - `accessibilityIgnoresInvertColors = true` on the content (AN:477-478);
  - `peer == nil` (`GiftViewScreen.swift:4503`) draws the red gradient with no letters.

### Design

1. **No copies of AvatarNode's logic.**
   - In `AvatarNode.swift`, extract the body of `ContentNode.draw` into a public free function, and have
     `ContentNode.draw` call it.
   - Extract the override→representation/icon mapping and the parameter building (colors, letters) the same way, used
     by both `ContentNode.setPeer(context:…)` and the new view.
   - Make public exactly what those need: `AvatarNodeParameters`, or plain arguments in its place; the color constants
     (AN:332-346); the icon constants (AN:18-28).
   - `AvatarNode`'s behaviour does not change.
2. **`AvatarComponent.View`:** a `UIView` with a placeholder layer (letters/icon) and a photo layer.
   - **Placeholder:** drawn by the shared routine. It renders **off the main thread** whenever ASDK would have drawn
     asynchronously, which is every redraw except a `setPeer` state change with `synchronousLoad`. Deliver on main,
     and guard by generation so a stale render never lands. The previous contents stay until the new ones land.
   - **Its queue matches ASDK's priority:** a concurrent queue that targets `.userInitiated`, like ASDK's display queue,
     which targets `DISPATCH_QUEUE_PRIORITY_HIGH` (`_ASDisplayLayer.mm:123-133`). Do not use
     `Queue.concurrentDefaultQueue()` (`.default` QoS): every row's photo decode competes there (`peerAvatarImage`),
     and placeholders could land later than they do today. *(My call, settled after the builder check.)*
   - The placeholder renders **inline** where ASDK called `recursivelyEnsureDisplaySynchronously`.
   - The drawing context must be oriented as ASDK's draw context is, so that the `cutoutRect` and the letters'
     flipped CTM land where they do today.
   - **Photo:** the same signal with the same arguments, applied with ImageNode's `setSignal` semantics above:
     synchronous delivery means no animation; the first asynchronous image gets the 0.18 s fade; later images get the
     0.2 s crossfade; nil is ignored.
   - **Path switching:** the photo path clears and stops the placeholder; the letters path clears the photo contents.
   - **State key:** identical to today's, with `displayDimensions` still excluded.
   - The `AvatarComponent` quirks listed above are carried over unchanged.
3. **BUILD:** `AvatarComponent` adds `//submodules/SSignalKit/SwiftSignalKit`, plus `//submodules/Emoji` if it calls
   `isSingleEmoji` directly, and drops `AsyncDisplayKit` once nothing uses it.

**Blast radius.** "Unchanged" is a promise to all 43 `AvatarComponent` call sites:
- **clip styles:** `.roundedRect` at 20/92/100 pt in the Community and RecentSessions screens and
  `AuthConfirmationScreen`;
- **`overrideImage`:** only `DeleteChatPeerAlertScreen`;
- **`icon`:** `AlertPeerComponent`, `WebAppLocationAlertController`, `ChatListControllerLeaveChatConfirmation`;
- **sizes:** 20–100 pt;
- **`synchronousLoad: false`:** only the two News components.

## Verification

- **Build and tests:**
  - `Make.py build` green after each part;
  - `//submodules/TelegramUI/Components/News/NewsFeedSupport:NewsFeedSupportTests` green;
  - the Postbox import guard runs as part of the build.
- **Port review (Part 1):** a diff of `ItemListRevealOptionsItemView.swift` against `ItemListRevealOptionsItemNode`
  that shows only the substitution table's rows and the dropped hooks. Produce it and read it before recording.
- **Recorded frames (AGENTS.md, "Visual features and animations"):**
  - Record on the iPhone 18 Pro simulator (3A36B4F5, where agents may install), **before** (a build of the current
    master) **and after**.
  - Write down what each clip must show before recording it, then compare the before and after clips frame by frame
    with `tools/animation_sheet.py`.
  - **Swipe, For you:**
    - a partial drag released, then the open swipe and its settle;
    - the full swipe through the commit threshold;
    - tap-to-close, and scroll-to-close;
    - opening a second row while one is open;
    - the separator above and below fading.
  - **Press highlight:** on a For you row and an Added row: a quick tap's flash, a hold, a hold cancelled by scrolling.
  - **Avatars:**
    - feed rows during a fast fling (placeholder → photo fade);
    - the "Post hidden" panel (22 pt, async);
    - at least three other screens that cover the variants: a `.roundedRect` one (e.g. Recent Sessions), an `icon`
      cutout (`AlertPeerComponent` or the leave-chat confirmation), and the `overrideImage` icons
      (`DeleteChatPeerAlertScreen`, e.g. deleting Saved Messages).
- **Pixel parity (Part 2):** take screenshots of those screens at rest, before and after, and compare them pixel-wise.
  Any difference is a defect until it is explained.
- **Each part separately:** build and record after Part 1, then again after Part 2, so that a regression points at
  one part.
- *(My call, optional, not committed:)* time the main-thread cost of building a post row before and after, with
  temporary signposts on the simulator, to show what the change buys.

## Order

Part 1, then Part 2, as one commit each.

## Left to the builder

- Names of new symbols.
- The exact signature of the extracted draw and mapping functions.
- How the placeholder's off-main render is cancelled.
- How the port diff is normalised for review.
- Which reachable screens stand in for each avatar variant.
