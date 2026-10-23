# News tab

The News tab (`NewsScreen`) draws its own header (`NewsHeaderView`) over two CoreList feeds (For you, Added) of
`NewsFeedPostComponent` rows. Pure decisions (row geometry, refresh model, swipe rules) live in `NewsFeedSupport`,
which has a host-free `ios_unit_test` (`//submodules/TelegramUI/Components/News/NewsFeedSupport:NewsFeedSupportTests`,
run via `Make.py test --target`).

## Compact / Expanded posts (2026-10-23)

The "…" menu's last section switches every post row between **Compact** (channel line, up to three lines of
text, thumbnail) and **Expanded** (a feed as in Threads/X). The choice is `NewsFeedSettings.displayMode`
(`TelegramUIPreferences`, shared data key `newsFeedSettings`), read by `NewsScreenNode` and applied to both feeds
and search results through `NewsFeedItemEnvironment.displayMode`.

- **The menu morphs out of the "…" capsule** because its source view is the capsule, not the button: the
  header's button action resolves it through `ChatListHeaderComponent.View.navigationButtonContextContainer(sourceView:)`,
  exactly as Contacts → Sort does. `NavigationBarComponent` sets `morphsIntoContextMenu` on that capsule; nothing in
  News sets it (docs/context-menu-liquid-morph.md).
- **One component, two layouts.** `NewsFeedPostComponent` keeps its compact layout untouched in `updateCompact`
  and adds `updateExpanded`; the avatar, channel name, badge and time are the *same* `ComponentView`s, restyled
  and moved. A mode change is one animated CoreList pass (`NewsScreenNode.displayModeTransition`, the 0.5 s
  spring) in which the row's height rides the spring while its content **crossfades**: the row as it was is
  snapshotted, the new layout is applied at once, and the snapshot fades out over it. Do not give the two modes
  different item identities or component types: CoreList would replace the row instead of animating its height.
- **The bubble is the chat's own.** The expanded text, link preview, polls and files are a real
  `ChatMessageItemImpl` node from `SharedAccountContext.makeChatMessageFeedItem`, the preview factory with
  `ChatMessageFeedItemActions` (links, media, peers, Instant View, click-through) routed to the screen. Three
  flags on `ChatMessageItemAssociatedData` make it a feed bubble: `hidesBubbleBackground` (no background, so the
  row's shows in both themes), `hidesAuthorHeader` (the row draws the channel line; without it a channel post
  shows the channel's name inside the bubble too) and `hidesShareButton` (no share arrow beside the bubble). Its
  **status line (views, time) is hidden by passing bubble corners with `hasTails: false`**: the text and link
  preview content nodes draw no `ChatMessageDateAndStatusNode` then (that is their own rule, no flag), and the
  row shows the views, with the chat's `Chat/Message/ImpressionCount` icon, and the time in its channel line.
  It is **not** a preview (`isPreview: false`): a preview hides a link preview's action button, and the feed
  shows Instant View. The item lays itself out for the chat's rotated list: `bubbleContainerNode.subnodeTransform`
  turns it back (as `RankChatPreviewItem` does).
- **Bubble geometry is placed by constants, not measured** (`NewsExpandedPostMetrics.bubbleTextLeadingInset`,
  `bubbleTextTopInset`, `bubbleWidthOverhead`): an incoming bubble's text starts 20 pt into its item and 6 pt under
  its top, and the item's width is the wanted text width plus 40. The 40 is specific to channel posts: a
  broadcast channel's bubble is allowed the full width (`allowFullWidth` in `ChatMessageBubbleItemNode`), so the
  36 pt `maximumWidthFill` inset of an ordinary chat never applies, and the item takes only 3 (no share button)
  + 9 edge insets + 6 content inset + 22 text insets. Assuming the ordinary 73 let text run past the column by
  up to 33 pt. If those constants change in the bubble, the column shifts.
- **Photos and videos never reach the bubble.** `newsExpandedPostParts` strips them into the horizontal gallery
  (`newsExpandedGalleryLayout`: one photo keeps its aspect, several share the 270 pt height) and gives the bubble a
  copy of the message with the rest of its media; the reactions and comments-thread attributes are stripped as
  well, and the row draws neither: the feed shows no reactions line and no comments pill, by design. The
  gallery is a full-width scroll view whose content starts at the column, so scrolled content passes under the
  avatar's column.
- **The avatar floats, as a group chat's gutter avatar does.** An expanded row hides its own avatar and
  publishes `NewsFloatingAvatarAttachedItem` through `CoreListComponentItem.attachedItems`, keyed by the
  channel: CoreList's run attachments (`CoreListAttachedItem`, the mechanism behind the chat's date and avatar
  headers) make one avatar for adjacent posts of one channel, clamp it into the display area while the run is on
  screen (`.overlay`, `.top`, `isFloating`) and park it at the run's end. The row learns its attachment views
  through `CoreListComponentAttachmentsReceiver` and hands each a closure returning its gallery's frame and
  scroll, so an avatar over a gallery scrolled under its column moves aside (`newsExpandedAvatarOffset`, applied
  on every stick update). Do not draw the avatar in the row again: two avatars, one of them not floating.
- **Show more.** While a post is collapsed its text is cut to its first ten lines as plain text, measured with a
  `TextNode` at the bubble's font and width (`newsCollapsedText`), and the entities are dropped: formatting and
  links come with Show more (`NewsScreenNode.expandedTextPosts`, per post identity, for the screen's lifetime).
- **Taps.** The row's tap and highlight ignore touches on the bubble, the strips, the pills and Show more
  (`NewsExpandedPostContentView.hasInteractiveContent`); a tap on plain bubble text comes back as the item's
  click-through and opens the post. The screen's page swipe yields to a strip that can scroll
  (`NewsFeedListView.hasHorizontalScrollingRow`), otherwise the gallery could never be scrolled left.

## The tab without the server's feed (2026-10-23)

`isNewsFeedEnabled` (the tab) now follows only the `news_feed_enabled` kill switch; the server's feed is a
separate question, `isNewsFeedServerAvailable` (the app config's `dev == 1`, as before). The server grants
`dev` per authorization and only to sessions created by the official app: a build signed with a personal team
and api_id never gets it, and the official api_id/api_hash in such a build is refused at login. So without
`dev` the Added page runs on `AddedFeedSource.localChannels` (`LocalChannelsFeedContextImpl` in TelegramCore): the
40 most recently active subscribed broadcast channels (main and archived chat lists), each one's latest 10 posts
through the account's view tracker (holes are filled with `messages.getHistory` as a chat does), merged newest first
by `EngineFeedPosition`, live, and handed to the screen as its newest 100 (history updates merged at most every 0.4 s
after the first window). Load older widens that window by 100 and, when the merged posts run short, asks every
channel for 10 more, up to 60; nothing is ever "newer" than the live window, so the New posts pill never shows; the
read mark is kept under its own cache key (`localChannelsFeedFilterId = -1`) and never sent to the server. The screen
opens on Added in that case; For you stays the server's and shows its error row for accounts without the feed. The UI
is the same in both modes: `NewsAddedFeedBinding` chooses the source, nothing else changes.
