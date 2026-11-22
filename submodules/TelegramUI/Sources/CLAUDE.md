# TelegramUI/Sources — agent notes

## ChatHistoryListNode composition

`ChatHistoryListNodeImpl` (`ChatHistoryListNode.swift`) **composes** `ListViewImpl` (`submodules/Display/Source/ListView.swift`)
rather than inheriting it: an `ASDisplayNode` wrapper holding `private let listView: ChatHistoryListViewBackend`, with a
narrowed surface (the `ChatHistoryListNode` protocol in `AccountContext` plus curated forwarders) instead of the full
`ListView` API. The custom item-delete animation duration reaches the list through `ListViewImpl`'s
`getCustomItemDeleteAnimationDuration` closure hook.

`ChatHistoryListViewBackend` is a chat-specific protocol declaring exactly the members `ChatHistoryListNodeImpl` uses on
its list view. It lives in a module of its own with the CoreList backend
(`submodules/TelegramUI/Components/Chat/ChatHistoryListViewBackend`, made by `makeCoreListChatHistoryBackend`), so the
widget harness hosts the chat's own list. Two implementations:
- `ListViewImpl`, through a retroactive `extension ListViewImpl: ChatHistoryListViewBackend {}` in that file, which keeps
  `Display` free of chat concepts.
- `CoreListChatHistoryBackend` (`CoreListChatHistoryBackend.swift` in that module), on `CoreVirtualListView` in
  `submodules/TelegramUI/Components/CoreList/` (engine, animation model, demo/test project: its
  [`CLAUDE.md`](../Components/CoreList/CLAUDE.md)). Keyed on message `stableId`, it is the **default for the rotated
  history** (`makeListView(rotated:useCoreListBackend:)`); the `rotated: false` lists that share the initializer keep
  `ListViewImpl`. Debug Settings `coreListChatBackend` forces it on; app config
  `ios_killswitch_disable_corelist_chat_backend` turns it off from the server. Read the choice from
  `ChatHistoryListNodeImpl.usesCoreListBackend`; don't re-derive the policy.

Its architecture, the identity-rotation invariant and its open items (per-item animation selectivity,
`stationaryItemRange` bounds; topic-header stacking is implemented but not runtime-verified) are in
[`docs/chat/corelist-chat-history-backend.md`](../../../docs/chat/corelist-chat-history-backend.md).

Contract rules:
- The protocol deliberately does **not** refine `Display`'s `ListView`, though most members overlap: the chat surface
  owns its contract.
- A new `self.listView.<member>` access needs the member added to the protocol (the build checks).
- Construction-only config (`rotated`) is set on the concrete `ListViewImpl` inside the private `makeListView` factory
  before the upcast, so it stays off the protocol; do the same for anything set once at construction. Most other knobs
  (`preloadPages`, `experimentalSnapScrollToItem`) are set at lifecycle points (`viewDidAppear`, post-snapshot animation
  completions); hoisting them into `makeListView` changes behavior.
- `transaction(stationaryItemRange:)` is load-bearing: `.Reload`/`.HoleReload` pass `(0, Int.max)`, the send-animation-v2
  insertion path `(maxInsertedItem+1, Int.max)`.
- **Prefer intent-named members to raw `ListView` state.** A pair of raw members is a pair a backend can half-implement
  (a plausible stub type-checks) or half-sample (two reads from different moments of one animation), and `listView.view`
  is a view a backend can host differently. Current instances:
  - `didInteractivelyDragFromTopOrigin`, not the `trackingOffset`/`beganTrackingAtTopOrigin` pair (private to
    `ListViewImpl`); the chat's keyboard-dismissal snap-back depends on it.
  - `maintainsUnreadItemAlignment`, one parameter rather than measure-then-reapply, because the two halves straddle the
    pass's inset change. The chat layer cannot do it itself: `itemNode.index` is `public internal(set)` to `Display`, so
    it is always nil for a hosted node.
  - `itemNodeFrame(_:)`: `ListViewItemNode.frame` is list-space only on `ListViewImpl`, so every chat-layer geometry read
    goes through the backend.
  - `settledContentOffsets()` returns both offsets in settled geometry, because its one consumer compares them; the
    thresholds stay in the chat layer. There is no separate bottom-offset member.
  - `scrollGestureHostView` (below).

These invariants are **compiler-invisible** and break the app's primary scroll surface silently:

- **The π rotation stays on the wrapper** (chat is bottom-up). The wrapper keeps `transform = π` and a `rotated` flag; the
  child `listView` gets only `rotated = true` (identity transform). `historyNode.view`/`.layer` are the rotated surface,
  so rotation-coupled code (hitTest coordinate conversions, the blur `drawHierarchy` flip, the dust/delete layer, `.layer`
  animations, the overscroll-overlay and snapshot-slide reparenting) stays on `self`, the wrapper.
- **Only scroll-surface concerns go to the child.** Gesture recognizers (the selection pan; external taps via
  `addContentGestureRecognizer`) attach to `self.listView.scrollGestureHostView`, the view the scroll pan is on (under
  CoreList two levels below `listView.view`, on the scroll engine's content host), to share its simultaneity
  environment. UIKit collects a touch's recognizers from the hit view upward and both backends'
  `gestureRecognizerShouldBegin` enumerates `pan.view.gestureRecognizers`, so an ancestor silently breaks
  `ChatControllerNode`'s previewing-mode `hitTest` fallback (no scrolling) and the two-touch selection pan's deferral (a
  selection drag scrolls). Scroll-view access goes through `bounces`/`contentHeight`/`setTopContentInset(_:)`; there is
  no raw `scroller` on the backend.
- **`let _ = self.view` in `init` is load-bearing.** `enqueueHistoryViewTransition` gates the history dequeue on
  `isNodeLoaded`; without the eager load, off-screen nodes (created during thread switches) never become ready and
  `reloadChatLocation`'s completion never fires.
- **Item nodes are one level deeper** (item → child `listView` → wrapper); any `.supernode` chain through the history node
  must count it. `ChatMessageTransitionNode` converts item rects up `supernode?.supernode?.supernode?.view` so the
  wrapper's rotation applies; a missing hop mirrors effect-burst overlays ~180°.
- Child geometry is set in `updateLayout` via `transition.updateFrame(node: self.listView, …)`; nothing relies on
  ASDisplayNode's automatic `layout()`.

## Message send transition (`ChatMessageTransitionNode`)

The send animation (`ChatMessageTransitionNode.swift`) takes its timing from one
`ChatMessageTransitionNodeImpl.AnimationParameters` preset per chat, picked when the chat's node is created.
**The default is `.bezier`**: 0.3 s on two cubic beziers, no scale. `.spring` is opt-in behind Debug
Settings ▸ "Chat: spring send animation" (`ExperimentalUISettings.springSendAnimation`; reopen the chat after toggling).

Under `.spring` the vertical axis, the horizontal axis and the bubble scale each run their own
`ContainedViewLayoutTransitionCurve.customSpring`, tuned through the `SpringParameters` constants on
`ChatMessageTransitionNodeImpl`:
- A text message squashes from 100% to `scaleDipScale` on one spring and returns to 100% on another, as additive
  `transform.scale` phases paired with anchor-keeping position offsets. Remove all four together on completion, or the
  bubble blinks at 90% for a frame.
- `CALayer.makeAnimation` time-scales a spring to settle within its duration, so only the damping ratio shapes a curve.
  The preset's `duration` is the one speed knob; a text message's horizontal spring runs `textHorizontalDuration`, half
  of it.
- When animating a layer directly with these curves, pass `timingFunction: curve.timingFunction` as well as
  `mediaTimingFunction`: the latter is nil for springs and the default silently falls back to ease-in-out (the mic
  button's sent-message decoration is one such consumer). For a bezier the non-nil `mediaTimingFunction` wins, so the
  same call serves both presets.

**Invariant: the history list scrolls on the bubble's vertical curve**, or the new bubble drifts against its neighbours.
- `ChatControllerLoadDisplayNode` passes the preset's `verticalListCurve` to `ListViewScrollToItem` (`.Custom` with the
  bubble's control points under `.bezier`, `ListViewAnimationCurve.CustomSpring` under `.spring`);
  `listViewAnimationDurationAndCurve` maps `.customSpring` to it, not to the system `.Spring`; `ListViewImpl` builds the
  scroll through `CALayer.makeAnimation`, configured exactly like the content springs.
- `ContainedViewLayoutTransitionCurve.solve(at:)` samples the real spring for `.customSpring` (one cached
  `CASpringAnimation` per parameter set), so display-link consumers follow it too; the animated gradient wallpaper
  clamps the overshoot.
- CoreList holds it too: `CoreListChatHistoryBackend` maps `ListViewAnimationCurve.CustomSpring` (scroll and size/inset
  passes) and `ContainedViewLayoutTransitionCurve.customSpring` (item transitions) to
  `CoreListTransition.Curve.customSpring`, which emits the same `CASpringAnimation` Display builds (Float-quantized
  parameters, `duration = settlingDuration`, linear timing, settle mapped onto the pass as `speed`). Its model
  `solve(at:)` is the closed-form oscillator, pinned against CA's solver in `CustomSpringParityTests`, with **no
  overdamped branch** on purpose: Display never sets `allowsOverdamping`, and while it is `false` CA renders any damping
  ratio above 1 as critically damped.
- The reverse bridge (CoreList curve → ComponentFlow `Curve`, for item internals) degrades `.customSpring` to `.spring`:
  ComponentFlow has no custom spring.

## A non-contact's chat before it is accepted (suspicious peer)

While a user's chat shows the report/block panel (`PeerStatusSettings` `canReport`/`canBlock`; the one
predicate is `CachedUserData.isSuspiciousPeer`), their incoming messages are untrusted until the panel is
dismissed or the account sends them a message:

- Links, mentions, hashtags and cashtags, emails, bank cards and TON addresses show as plain text
  (`MessageTextEntity.isShownFromSuspiciousPeer`, also in a link preview's text; `instantPageForSuspiciousSender`
  for rich messages). A link preview opens nothing and has no button.
- Buttons are not shown: reply-markup rows, rich inline pills and button rows. A link-styled rich button keeps
  its label as plain text.
- Their emoji status is hidden in the chat title, in the panel's "is a mark for Premium" note and in the
  profile header, including the cover and colours of a collectible status.
- Reads are not held: their messages, mentions and reactions are marked read and seen as in any other chat.

Non-obvious:

- **Sending clears the flags locally.** `enqueueMessages(transaction:)` drops `canReport`/`canBlock` for a
  non-scheduled send; Add Contact stays. `users.getFullUser` rewrites the settings on every refresh, so if the
  server keeps those flags after a reply, the state returns on the next refresh. Unverified (needs a second
  account); the fallback is `hidePeerSettingsBar` on send, which also drops Add Contact.
- **The rich transform keeps every block's index.** A button row stays with no buttons, which lays out to
  nothing and adds no spacing. Block paths are rich-quote node ids, and quotes are built from the stored page.
  Removing an inline pill drops its label from its node's text, so such a message cannot be partially quoted
  while the state lasts.
- Private chats only. Chat list rows, search, and groups or channels with a report panel are unchanged.
