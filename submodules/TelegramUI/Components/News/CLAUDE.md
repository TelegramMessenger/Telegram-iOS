# News tab

The News tab (`NewsScreen`) draws its own header (`NewsHeaderView`) over two CoreList feeds (For you, Added) of
`NewsFeedPostComponent` rows. Pure decisions (row geometry, refresh model, swipe rules) live in `NewsFeedSupport`,
which has a host-free `ios_unit_test` (`//submodules/TelegramUI/Components/News/NewsFeedSupport:NewsFeedSupportTests`,
run via `Make.py test --target`).

## Parked: News is off while the feed API is (2026-10-30)

Layer 233 as the server serves it has no feed API, so News is parked (`submodules/TelegramApi/CLAUDE.md`, "Parked
APIs"). `isNewsFeedEnabled` and `isNewsFeedServerAvailable` take `apiIsAvailable` (default `newsFeedApiIsAvailable`,
false in this build) and are false while it is, before `dev` and `news_feed_enabled`: the tab, the channel bar's News
states and the title's mute badge are gone for every account, the device-built Added feed included, though it needs no
feed API. `NewsScreen` is still created, like the hidden Calls tab, and never loads, so no feed context starts. The
app's News code has no `#if`: it compiles and its tests run; the parameter exists so the tests can pin the app-config
rules as they apply with the API.

## Compact / Expanded posts (2026-10-23)

The "…" menu's last section switches every post row between **Compact** (channel line, up to three lines of
text, thumbnail) and **Expanded** (a feed as in Threads/X). The choice is `NewsFeedSettings.displayMode`
(`TelegramUIPreferences`, shared data key `newsFeedSettings`), read by `NewsScreenNode` and applied to both feeds
and search results through `NewsFeedItemEnvironment.displayMode`.

- **The menu morphs out of the "…" capsule** because its source view is the capsule, not the button: the
  header's button action resolves it through `ChatListHeaderComponent.View.navigationButtonContextContainer(sourceView:)`,
  exactly as Contacts → Sort does. `NavigationBarComponent` sets `morphsIntoContextMenu` on that capsule; nothing in
  News sets it (docs/context-menu-liquid-morph.md). Its Compact / Expanded items show the size icon on the left
  and the current mode's check on the right: `icon` with `iconPosition: .left`, and the check as
  `additionalLeftIcon`, which `ContextControllerActionsStackNode` lays out on the RIGHT despite its name (the
  rich-text editor's list items use the same pair).
- **One component, two layouts.** `NewsFeedPostComponent` keeps its compact layout untouched in `updateCompact`
  and adds `updateExpanded`; the avatar, channel name, badge and time are the *same* `ComponentView`s, restyled
  and moved, so a mode change is one animated CoreList pass (`NewsScreenNode.displayModeTransition`, the 0.5 s
  spring) in which their frames travel and the row's height rides the spring. `morph(from:to:transition:)` adds
  the rest: the compact text scales 15 pt → the bubble's font size and travels to the bubble's text origin while
  the bubble fades in over it, and the row's own avatar grows 16 → 36 pt while it flies to where the list has
  placed the floating one (`aimAvatarHandOff`); the reverse plays the same paths back. The list places attachments
  only after the row's update, and again at every pass and display-area change of the turn (the header's fold):
  `attachedItemsUpdated` re-aims the flight until it is committed. The floating avatar takes over in the frame the
  flight lands: in the row's slot, stuck at the header's edge, or parked at its run's end. A later post of a run
  fades its own avatar out as it grows. On a join, the own avatar slides under the run's avatar already on screen.
  Back to compact, the own avatar starts where the floating one is on screen. **The thumbnail and the gallery's
  first photo travel as one picture.** Both draw the whole picture and show it aspect-filled: the thumbnail's
  drawing covers its square with an even overflow (`newsThumbnailDrawingSize`), so at rest it is as sharp as a
  square drawing, and the gallery photo's node is `scaleAspectFill`. They take one path on the pass's spring
  (`morphFirstGalleryItem`, inside the clipping strip, which cuts only what the thumbnail covers). The thumbnail
  holds over the first 55 % and dissolves into the photo, and "▶ 0:12" rides the corner. Back to compact, the
  thumbnail stands in the photo's place with the photo's pixels, opaque, the photo hides at once, and the
  thumbnail travels home. A gallery scrolled away from its first photo, a first item that is another media, a
  panorama wider than 4:1 or a thumbnail with no image yet gets a fade. The morph's blur is everything's but the
  first photo's: blurred, the photo travelling under the thumbnail would ring it with a halo. **A morph starts
  from what is on screen** (`MorphOrigin`, read from the layers' presentation while they animate), so a switch
  flipped back mid-flight turns around where it is instead of jumping to the end of the first path. Do not give the
  two modes different item identities or component types: CoreList would replace the row instead of animating it.
  The expanded content view lays its subviews out immediately the first time (`hasLaidOut`): it is made inside the
  morph's animated pass, and its gallery, a scroll view, would otherwise grow out of a corner.
- **The end of a morph's animations is its end state.** A view's model value is what shows once the render server
  drops its animations, which happens frames before their completions run on the main thread. A completion may only
  clean up what is already invisible: a thumbnail left at model alpha 1, for a frame animation's completion to hide,
  shows for those frames, zoomed to the gallery photo's size.
- **A row clips itself while its height animates** (`clipWhileHeightAnimates`): its layouts take the new height at
  once while the host animates its frame on the pass's spring, so a growing row reveals its new content and a
  shrinking one cuts its old content (a switch, a row's Expand / Collapse, Show more). Unclipped, a growing row
  draws its new content at full height over the rows below, which ride the same spring and draw nothing behind
  themselves. The clip is lifted when the pass ends: at rest a handed-off avatar may stand partly outside the row.
  **A morphing row takes no touches until it lands** (`isMorphInFlight`, `NewsPostRevealView.suspendsInteraction`):
  no tap, highlight, long press (it would hand the avatar over mid-flight) or new swipe, and its content (links, the
  gallery, Show more), which may be drawn far from its frame meanwhile, takes none. The list's scroll and the pager
  still begin on it: a touch on a row whose content takes none lands on the reveal view, which UIKit asks about
  those recognizers too, so it refuses only its own.
- **The bubble container never animates its height.** The item inside is turned by π about the container's
  centre, so a height that animates shows the item above its place by the growth at first (Show more pushed the
  text up). Its origin never changes between layouts, so an immediate frame keeps the content put while the
  rows below move.
- **The bubble is the chat's own.** The expanded text, link preview, polls and files are a real
  `ChatMessageItemImpl` node from `SharedAccountContext.makeChatMessageFeedItem`, the preview factory with
  `ChatMessageFeedItemActions` (links, media, peers, Instant View, reply headers) routed to the screen. Four flags
  on `ChatMessageItemAssociatedData` make it a feed bubble: `hidesBubbleBackground` (no background, so the row's
  shows in both themes), `hidesAuthorHeader` (the row draws the channel line; without it a channel post shows the
  channel's name inside the bubble too), `hidesShareButton` (no share arrow beside the bubble) and
  `hostHandlesGestures` (the row's long press is the menu, and the bubble's tap recogniser fails on what the bubble
  does not act on: it would otherwise begin on the lift to wait for a double tap and the row's tap would never
  fire). Its **status line (views, time) is hidden by passing bubble corners with `hasTails: false`**: the text
  and link preview content nodes draw no `ChatMessageDateAndStatusNode` then (that is their own rule, no flag),
  and the row shows the views, with the chat's `Chat/Message/ImpressionCount` icon, and the time in its channel
  line. It is **not** a preview (`isPreview: false`): a preview hides a link preview's action button, and the feed
  shows Instant View. The item lays itself out for the chat's rotated list: `NewsBubbleSlot.containerNode`'s
  `subnodeTransform` turns it back (as `RankChatPreviewItem` does).
- **Bubble geometry is placed by constants, not measured** (`NewsExpandedPostMetrics.bubbleTextLeadingInset`,
  `bubbleTextTopInset`, `bubbleWidthOverhead`): an incoming bubble's text starts 20 pt into its item and 6 pt under
  its top, and the item's width is the wanted text width plus 40. The 40 is specific to channel posts: a
  broadcast channel's bubble is allowed the full width (`allowFullWidth` in `ChatMessageBubbleItemNode`), so the
  36 pt `maximumWidthFill` inset of an ordinary chat never applies, and the item takes only 3 (no share button)
  + 9 edge insets + 6 content inset + 22 text insets. Assuming the ordinary 73 let text run past the column by
  up to 33 pt. If those constants change in the bubble, the column shifts.
- **Photos and videos never reach the bubble; round videos do.** `newsExpandedPostParts` strips photos and videos
  (not `isInstantVideo`) into the horizontal gallery (`newsExpandedGalleryLayout`: one item keeps its aspect,
  several share the 270 pt height; a video shows its thumbnail with "▶ 0:12", as the compact row does, and opens
  the viewer) and gives the bubble a copy of the message with the rest of its media, which the chat's nodes draw
  and play as in a chat (the feed item gets the user's autoplay settings, and each item node is told it is
  `.visible`). Left in the bubble, a video would sit above the text, as in a chat, while the photos sit under the
  text in the gallery. The reactions and comments-thread attributes are stripped as well, and the row draws
  neither: the feed shows no reactions line and no comments pill, by design. The gallery is a full-width scroll
  view whose content starts at the column, so scrolled content passes under the avatar's column. A gallery photo
  is a `TransformImageNode`, so the media viewer zooms out of it and back into it (`NewsGalleryTransition` →
  `OpenChatMessageParams.transitionNode`), as from a chat's photo.
- **The avatar floats, as a group chat's gutter avatar does.** An expanded row hides its own avatar and
  publishes `NewsFloatingAvatarAttachedItem` through `CoreListComponentItem.attachedItems`, keyed by the
  channel: CoreList's run attachments (`CoreListAttachedItem`, the mechanism behind the chat's date and avatar
  headers) make one avatar for adjacent posts of one channel, clamp it into the display area while the run is on
  screen (`.overlay`, `.top`, `isFloating`) and park it at the run's end. The row learns its attachment views
  through `CoreListComponentAttachmentsReceiver` and hands each a closure returning its gallery's frame and
  scroll, so an avatar over a gallery scrolled under its column moves aside (`newsExpandedAvatarOffset`, applied
  on every stick update). Do not draw the avatar in the row again: two avatars, one of them not floating. The
  row hides the floating avatar (`updateFloatingAvatarVisibility`) only while its own stands in for it: flying into
  its place in a morph from compact (only a new floating avatar), or pressed / lifted into a context menu. It shows
  in the frame the own one hides, gliding the rest of the way if a scroll moved it meanwhile (`takeOver`). A view
  another row's flight lands on stays hidden for that row (`landingRow`). On a morph to compact it is hidden at once
  while the list fades the departing attachment out.
- **Show more.** While a post is collapsed (until Show more: `NewsScreenNode.expandedTextPosts`, per post identity,
  for the screen's lifetime) its text is cut to its first ten lines (`newsCollapsedCut`: laid out at the bubble's
  text width with its entities in the chat's fonts; `newsCollapsedTextLength` keeps its start and trims only the
  spaces and breaks ending the cut). The cut keeps the entities over the kept text (`newsCollapsedTextEntities`):
  … joins an entity running across the cut, a bare URL cut in two keeps its whole target, a mention cut in two is
  left plain, and a code block keeps its language only while it is whole (the bubble caches a block's highlight on
  the message under its text, and a cut block's would replace the whole block's). It is drawn exactly as the start
  of the whole text, so Show more changes only its last line; a cut that dropped the entities or trimmed the text's
  start would ghost its plain glyphs over the bold and link-coloured ones. Links in the cut are live. Show more
  never sits under a link preview: a collapsed message with a webpage is split (`newsCollapsedMessageParts`) into
  the cut text's bubble and a second, preview-only bubble after Show more (`NewsBubbleSlot`, one per bubble).
  Toggling it is an animated list pass (`displayModeTransition`). **Show more reveals the rest**: the bubble sits in
  `bubbleClipView`, whose height grows on the pass's spring from the cut's bottom to the whole text's while the
  bubble container stays put. The gallery, the separator and the rows below ride the same spring; Show more rides
  with them under a clip whose top is the reveal edge, so the revealed text covers it and never crosses it. Only the
  cut's last three lines crossfade (the …, a word it pushed down), on the row's colour, so the glyphs both drawings
  share stay exact (not on a fresh row's tint, nor under the row's highlight, which a tap on the text flashes only
  after its action has run the pass: an opaque band would hide them), and the text is drawn synchronously for that
  pass: the chat's text draws a frame after its layout. A bubble with anything under the text (media, an inline
  keyboard, a fact check) or above it, a link preview, a width change or the reverse (no UI) still crossfades in
  place (`fadeOutSnapshot`: what was there fades out as a snapshot over the new content). Crossfading every Show
  more would dim the lines both drawings share and fade the new ones in at once, past the row's growing bottom. The
  rows below stay loaded through the pass: the list's margin grows by the post's hidden lines (`textExpansionGrowth`,
  `prepareHeightChange`). Without that, a pass that only reconfigures rows carries nothing out of CoreList's window,
  and they would vanish in the first frame. Only the list on screen animates, the others take the change at once;
  in search that is the search's own list.
- **Taps.** The row's tap and highlight leave the gallery, Show more and whatever the bubble owns
  (`NewsExpandedPostContentView.ownsGesture`, asking the item's `ChatMessageItemView.ownsGesture`: a link, a
  mention, the bubble's media), and take the rest, the bubble's plain text included, as the space beside it; the
  row's `open()` then shows a cut post's rest first and opens a whole one in its chat. A cut post's entities are the
  bubble's, as in a whole post: a tap on a link or a mention by name opens it. A tap on an `@username` mention, a
  hashtag, a quote or code does nothing, because the feed item's `openPeerMention`, `openHashtag` and `copyText` are
  empty and the bubble still owns those taps. A tap on its plain text shows the rest, and so does a tap on a
  collapsible quote: the bubble does not own it, and its text toggles the quote as well. **The feed item has no
  `tapMessage`** (`makeStandaloneChatMessageItem` passes nil for the feed): with any closure there the bubble
  answers a tap on its plain text with an empty action of its own, so the row's tap never fires, and reply
  headers stop navigating (they are gated on `tapMessage == nil`); a reply header's tap reaches the screen as
  `ChatMessageFeedItemActions.navigateToMessage` → `NewsFeedPostExpandedContent.openMessage`, which opens the post
  once its chat's peer is known. That alone is not enough: on the lift the bubble's recogniser goes `.began`
  (`.waitForDoubleTap`) and the row's tap fails with it, so with `hostHandlesGestures` the bubble's
  `tapActionAtPoint` answers `.fail` when nothing of the bubble's is under the finger, and the row's tap recogniser
  allows simultaneous recognition with everything but a pan. The gallery strip is full width: only its items are
  its own, the space beside them is the row's. The bubble's own click-through is not used.
  **A long press is a context gesture** (`ContextControllerSourceView` around the row's content, as the chat
  list's rows): activating it fails the row's tap and the swipe, so nothing opens under the menu, and the bubble's
  own context gesture is off (`ChatMessageItemAssociatedData.hostHandlesGestures`), so it cannot race the row's. It
  does not begin where the bubble owns the long press (a link's copy / open menu). The menu lifts the row's content
  (`contextContentView`, a `ContextExtractedContentContainingView` holding `contentView`; `.extracted` source,
  `NewsPostContextExtractedContentSource`) over the blurred screen; lifted, the content is scaled to leave 16 pt
  at each side (`extractedScale`, a transform on `contentView`, never a narrower layout; `contentRect` is the
  scaled rect, which the menu lays itself out around), gets the list's background (opaque; faded only on a fresh row,
  over its tint) with corners that round to 26 pt on screen with the lift and square off with the put-back, and the
  swipe is closed. **The avatar is handed over on the press's first frame** (`applyPressScale`, the source view's
  `customActivationProgress`, which re-does its default scale about the content's centre): the row's own avatar takes
  the floating one's place (`handedOffAvatarFrame`, in `lensView`) and the floating one hides, so the press scales it
  with the cell and the lift takes it along with no jump of either; a row the floating avatar is not over shows none.
  A release without a menu restores it on the next turn (the activation follows the `.ended` at once and keeps it,
  `pressActivated`), and so does a release before the press's first progress update, which gets no `.ended`
  (`endPressIfReleasedEarly`); the end of the put-back restores it (`finishPutBack`, once the menu has put the content
  back and the scale has landed), unless a new press has begun meanwhile (`isPressing`). **The put-back runs on the
  menu's own 0.2 s** (its travel and its dim; the transition it hands the row is 0.35 s), so the content lands at full
  size and square as the dim clears. Handed back at the put-back's start instead, the list's floating avatar, which
  lies under the dim, would show through it unscaled and away from the card's avatar, and the card would vanish
  over the dim in one frame. A press that opens the menu is ended twice (the source view's `.ended(0)` at
  activation, then the menu's `endPressedAppearance` as it lifts the content); the second must not re-animate the
  release, or the press drops in one frame. The menu (`NewsPostMenu`): For you's Interesting / Not Interested, Show
  in Chat, Forward through the share screen. A long press on the tab bar's item shows the "…" menu
  (`tabBarItemContextAction`). The screen's page swipe yields to a gallery that can scroll
  (`NewsFeedListView.hasHorizontalScrollingRow`), and so does the row's own swipe
  (`NewsPostRevealView.hasHorizontalScrollingContent`, asked in `gestureRecognizerShouldBegin`: the control's
  recognizer makes every scroll view's pan wait for it, the gallery's included), otherwise the gallery could never
  be scrolled.

## The header's search folds as the chat list's (2026-10-28)

The search field sits 6 pt under the top row, where `ChatListNavigationBar` puts its own, and folds the same way as
the list scrolls (`newsHeaderSearchExpansion`, `newsHeaderSearchLift`): the field shrinks and fades through
the node's `expansionProgress` while the node lifts 8 pt, instead of scrolling away as a list row did. The block's
offset (`newsHeaderBlockOffset`, 1:1 up to `blockHeight`) still drives the header's bottom edge, the snap and the
pill; the pager blends offsets up to `blockHeight`. **The header's geometry is measured from the field while it is
whole** (`newsHeaderWholeSearchField`). The node lays its field's frame lower inside itself as it folds (y 8 → 52),
so a layout pass taken with the search folded (a tab switch or pager swipe away from a scrolled list, a theme
change, any container layout) would put the resting search up to 44 pt too high: behind the top row, over an empty
band above the first post, and under the refresh drop when pulled. The header's offset is in step with the list
throughout, so the re-syncs at the pager's end, at scrolling's end and `reportOffsetOnceSettled` cannot correct
that; they stay as cheap guards. A post arriving live while Added rests at its top is another matter, and
consistent: Added's live updates keep the visible content in place (`.preserveVisibleContent` never pins the loaded
top), so the post goes in above the first row, under the header, and the search folds with the list.

## The tab without the server's feed (2026-10-23)

`isNewsFeedEnabled` (the tab, Add to News) is `dev || news_feed_enabled` while the feed API is compiled in (parked,
above): dev accounts always, any other account
only when the server sends the switch true or nonzero (missing means off). The server's feed is a separate question,
`isNewsFeedServerAvailable`: `dev == 1`, unless the same switch is false or 0 (for dev it stays a kill switch). The server grants
`dev` per authorization and only to sessions created by the official app: a build signed with a personal team
and api_id never gets it, and the official api_id/api_hash in such a build is refused at login. So without
`dev` the Added page runs on `AddedFeedSource.localChannels` (`LocalChannelsFeedContextImpl` in TelegramCore): the
40 most recently active subscribed broadcast channels (main and archived chat lists), each one's latest 10 posts
through a plain Postbox history view, merged newest first by `EngineFeedPosition` (off the main queue), live, and
handed to the screen as its newest 100 (history updates merged at most every 0.4 s after the first window).
**Never through `viewTracker`**: its history views poll each channel (`polledChannel`, a `getChannelDifference`
every server timeout), 40 at once for every account that opened News. A Postbox view still fills its holes with
`messages.getHistory`, and these channels' new posts arrive as the chat list's do. Each channel keeps its own view:
a reorder of the chat list adds and drops channels, it never reopens the others. The merge stops at the frontier,
the newest of the oldest posts loaded from each channel that has older ones left: below it a busier channel's posts
are not loaded yet, and a quieter one's listed there would be out of order (Load older would insert rows above
them, already counted read). Load older widens that window by 100 and, when the merged posts run short, asks every
channel for 10 more, up to 60; nothing is ever "newer" than the live window, so the New posts pill never shows; the
read mark is kept under its own cache key (`localChannelsFeedFilterId = -1`) and never sent to the server. The screen
opens on Added in that case; For you stays the server's and shows its error row for accounts without the feed. The UI
is the same in both modes: `NewsAddedFeedBinding` chooses the source, nothing else changes.

## Pinch, per-row expansion, and what a mode switch animates (2026-10-26)

- **A pinch on the feed switches the modes** (`NewsFeedPinch` in NewsFeedSupport): the lists' container
  follows the fingers to 0.8 in (1.25 out), switches there, and rubber-bands past it; on release it springs back
  to 1. Out expands and in compacts, as Photos zooms its grid; a pinch toward the mode on screen only gives. Every animated switch, of the feed (the pinch, the menu) or of one row (the swipe), taps `.medium`
  haptics in `applyDisplayMode` / `postSwipeAction`. The pinch first folds the search block under the top row (a
  scroll by the block's height), or the scaled feed would pass through it. That fold is the pinch's, not the user's: a
  list that rested at its top with the search open goes back to its top on the 0.5 s spring once the pinch is over and
  the list rests (no finger on it and no momentum: the list's pan rides the pinch and can outlive it), as long as it
  still rests within the fold, and the search comes back (`openSearchFoldedByPinch`, at the release or at
  `onScrollingEnded`). The scale is a `sublayerTransform` and so is about the container's centre — a translation to
  "scale about the fingers" drifts, because the transform is applied about the layer's anchor point. The pinch
  recognizes alongside the list's scroll pan but never with the pager, which takes one touch anyway. **A pinch beats a
  long press**: the rows' context source views are not exclusive-touch and take several touches (a
  `ContextControllerSourceView` is exclusive by default, which blocked a second finger landing on another row, so the
  pinch never got it and the menu opened), a row cancels its context gesture when it sees a second finger, and the
  pinch's `.began` cancels every loaded row's (`NewsFeedListView.cancelContextGestures`). **A switch of the feed's
  mode keeps each list in place in its own morph pass**, by the anchor where the list rests picks
  (`NewsScreenNode.restsAtTop`), with no scroll of News's own. **A feed resting at its top stays there**, either way:
  when its first post rests under the open search, or under the tabs with the search folded, the first row keeps its
  place and the rows below it grow or shrink downward (`.preserveVisibleContent`, whose witness is that row). The
  centred rule there would grow the rows above the centre upward and fold the search. Anywhere else **the row
  through the visible area's centre keeps its centre** (`CoreListAnchorMode.preserveCentredContent`): the row
  crossing the centre line keeps its midpoint's distance from it, and CoreList keeps the ends, so a shorter layout
  near the top rests the first row on the top inset and no gap opens below the last row. Position and height ride
  one spring, and a fling carries on. Do not re-centre with a scroll after the morph: it halts momentum, replaces
  the pinch fold's viewport track and runs on a later clock. The widening pass (`prepareHeightChange`) and the morph
  pass run in one turn; CoreList measures each row against its committed base, so the morph starts every row where
  it is drawn (`SameTransactionResumeTests`). A switch flipped back mid-flight resolves its anchor against the first
  one's settled layout, so it returns to the same picture, except where an end clipped the first: a list it brought
  to its top stays there.
- **A swipe from the left expands one row** (`NewsPostSwipeAction.expand` / `.collapse`, the control's one left
  option, performed on a full swipe — the left side's primary is the FIRST option). The row's mode is
  `NewsFeedItemEnvironment.rowDisplayMode(identity)`: the feed's, inverted for `NewsScreenNode.rowModeOverrides`,
  which a change of the feed's mode clears. Same identity, same component type, so the row morphs as the feed's
  switch does. **The swiped row keeps its top** (`.preserveItem(identity)`, `NewsScreenNode.rowModeAnchor`), so it
  grows or shrinks downward where it was swiped, and one partly under the header lands on the list's top inset, in
  view. That inset is the resting header's edge, the search's height below the header's while the search is folded,
  so a row whose top shows between the two keeps it as `.preserveVisibleContent`'s witness instead of dropping onto
  the lower edge. Only the swiped list's pass takes that anchor: a post's identity is the same in both feeds, so
  `.preserveItem` would also lower that post in the other list onto its top inset, scrolling a list whose rows keep
  their heights. **An Expand / Collapse swipe closes at its commit** (`NewsPostRevealView.closeForMorph`, in one
  `CATransaction` with the row's pass: the control renders in explicit transactions of its own, and one alone could
  show the closed row ahead of the morph). The surface and the action button leave with the commit, the control takes
  the new size and options in that same pass, and the content springs back from the swipe's offset on the morph's own
  spring (`NewsMorphMotion`; an additive position animation keyed `newsSwipeContentReturn`), landing with the row. A
  switch of the feed's mode closes an open row it morphs the same way, in one commit with its passes
  (`closeSwipedRowsForMorph`); a row already in the new mode slides closed, with the floating avatar on it. Left to
  itself, the control would close on its slower body spring from 75 % of the width, its grey surface and pill over
  the morphing row past the commit, and the expanded layout would ride that slide back partly off the screen.
  **Nothing opens a row on a layout it has not taken.** `ItemListRevealOptionsItemView` resets a swipe in one frame
  when its size or its buttons change, so when such a layout reaches a row open for any other reason (an edited
  post, an expanded row measured again), `NewsPostRevealView.update` holds it back while the control is active
  (`NewsPostRevealLayout.resetsSwipe`: another size or other buttons, the control's own reset conditions, with no
  tolerance; new titles and colours go through at once), slides an open or dragged row closed for it, and hands it
  over on the next main-queue turn once the content is back at 0 and the surface has faded. Until then the row's own
  recognizers do not begin and its old buttons do nothing: a swipe would open the old buttons, laid out for the old
  height (after a Collapse, over the next post), and an open control never reports closed, so the row would stay
  open on them. Waiting for the control to report closed instead would hold the layout until its last spring rests,
  about 1.24 s after a full swipe, where the row looks closed at about 0.7 s. The control sets
  `disablesInteractiveTransitionGestureRecognizer` on every render (true with left options), which would leave the
  pager only the screen's edges over every row; `NewsPostRevealView` clears it in
  `revealRecognizerAvailabilityUpdated`, which the control calls right after (cleared anywhere else, it comes back
  with the next render, and the pager loses the middle of a row after any swipe). Its `…Now` closure blocks the pager
  over an active row, as the control's does, but not over one only sliding closed for a pending layout. Added's
  rows swipe only for Expand / Collapse (`NewsPostSwipe.hasFeedbackActions` is false), and there the pager's rule is
  mirrored: a rightward swipe from a row's left-edge zone (`newsPagerDefersToRowLeftReveal`) is the row's, one from
  the middle pages back to For you. The row keeps the same rule itself (`newsRowRevealAllowed`, in
  `gestureRecognizerShouldBegin`): a swipe from the middle of a row never reveals, so in For you a rightward middle
  swipe does nothing (the chat list with folders at its first folder). The floating avatar sitting on a swiped row
  slides with it (`NewsFloatingAvatarView.swipeOffset`, set from the control's offset by the row it is over). A
  floating avatar standing still at the header's edge (its top at the list's floating top inset, to the point)
  stays crisp: the screen cuts a hole for it out of the header's soft edge and gradient
  (`NewsHeaderView.updateEdgeHoles`, from `NewsFeedListView.stuckFloatingAvatarFrames`, re-asked on every scroll
  and whenever an avatar moves), while an avatar riding its run, up under the header with the run's end or down at
  its start, passes under them as content does (CoreList's stick distance is no test for that: it is positive while
  the avatar is parked at the run's end too). Overrides are kept per tab, so a post in both feeds expands in one.
- **Every row the switch carries across the screen morphs.** CoreList animates only the union of the old and the
  new loaded window (a screen + `preloadMargin` each), and a pass that only reconfigures rows carries nothing out of
  it: rows a taller layout pushed beyond it left with their old content, rows a shorter one pulled in were made fresh
  at their final size (no morph, a fade). Before an animated pass that changes heights
  `NewsFeedListView.prepareHeightChange(travel:preloadsRows:duration:)` (or `screens:`) raises `preloadMargin` by
  how far rows may travel, until the pass has run. A growing layout only raises it: the switch to Expanded 3 screens,
  or 4 for a list kept at its top (all its rows travel downward), a row's Expand 1.5, Show more the post's hidden
  lines. A shrinking one also runs an immediate pass **with the items handed over again** (CoreList skips a pass with
  nothing changed before it builds a window), so the rows it will pull in are laid out first, in their old layout: the
  switch to Compact 4 screens, a row's Collapse 1.5. A margin already that wide (a switch flipped back mid-flight)
  changes nothing, so no extra pass re-bases rows in flight. The cost is laying out several expanded bubbles below the
  screen synchronously before an Expanded → Compact morph.
- **Compact text is secondary-coloured**: the preview reads grey; the post reads in full, black, once expanded.
