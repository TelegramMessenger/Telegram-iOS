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
  and adds `updateExpanded`; the avatar, channel name, badge and time are the *same* `ComponentView`s moved and
  restyled, so a mode change is one animated CoreList pass (`NewsScreenNode.displayModeTransition`, the 0.5 s
  spring) in which the shared views travel and the row's height rides the same spring. The expanded-only content
  (`NewsExpandedPostContentView`) fades in under them. Do not give the two modes different item identities or
  component types: CoreList would replace the row instead of morphing it.
- **The bubble is the chat's own.** The expanded text, link preview, polls and files are a real
  `ChatMessageItemImpl` node from `SharedAccountContext.makeChatMessageFeedItem`, the preview factory with
  `ChatMessageFeedItemActions` (links, media, peers, Instant View, click-through) routed to the screen. Two flags on
  `ChatMessageItemAssociatedData` make it a feed bubble: `hidesBubbleBackground` (the bubble draws no background,
  so the row's background shows in both themes) and `hidesAuthorHeader` (the row draws the channel line; without
  it a channel post shows the channel's name inside the bubble too). It is **not** a preview (`isPreview: false`):
  a preview hides a link preview's action button, and the feed shows Instant View. The item lays itself out for
  the chat's rotated list: `bubbleContainerNode.subnodeTransform` turns it back (as `RankChatPreviewItem` does).
- **Bubble geometry is placed by constants, not measured** (`NewsExpandedPostMetrics.bubbleTextLeadingInset`,
  `bubbleTextTopInset`, `bubbleWidthOverhead`): an incoming bubble's text starts 20 pt into its item and 6 pt under
  its top, and the item's width is the wanted text width plus 73 (36 fill inset, 9 edge insets, 6 content inset,
  22 text insets — `ChatMessageItemLayoutConstants` and `ChatMessageBubbleItemNode`'s width rule). If those
  constants change in the bubble, the column shifts.
- **Photos and videos never reach the bubble.** `newsExpandedPostParts` strips them into the horizontal gallery
  (`newsExpandedGalleryLayout`: one photo keeps its aspect, several share the 270 pt height) and gives the bubble a
  copy of the message with the rest of its media; reactions and the comments thread attributes are stripped as
  well, since the row draws them itself in one scrolling line (`ReactionButtonsAsyncLayoutContainer`, the chat's
  pills, plus `NewsCommentsPillView` first). The gallery and the reactions line are full-width scroll views whose
  content starts at the column, so scrolled content passes under the avatar's column; where a strip meets the
  avatar vertically the avatar goes along with the content (`newsExpandedAvatarOffset`).
- **Show more.** While a post is collapsed its text is cut to its first ten lines as plain text, measured with a
  `TextNode` at the bubble's font and width (`newsCollapsedText`), and the entities are dropped: formatting and
  links come with Show more (`NewsScreenNode.expandedTextPosts`, per post identity, for the screen's lifetime).
- **Taps.** The row's tap and highlight ignore touches on the bubble, the strips, the pills and Show more
  (`NewsExpandedPostContentView.hasInteractiveContent`); a tap on plain bubble text comes back as the item's
  click-through and opens the post. The screen's page swipe yields to a strip that can scroll
  (`NewsFeedListView.hasHorizontalScrollingRow`), otherwise the gallery could never be scrolled left.
