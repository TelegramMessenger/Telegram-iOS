# TelegramCore/Sources/State — agent notes

Opening a post's comments (one round trip) is `../TelegramEngine/Messages/CLAUDE.md`.

## Opening a channel at a post (history fill and the poll gate)

The Postbox `MessageHistoryView` issues no request; every round trip before the chat shows messages comes from
TelegramCore around it. Four rules keep the critical path at one `messages.getHistory`:

- **A history fill stores before it resolves.** `fetchMessageHistoryHole` stores the messages and closes the hole in
  its first transaction; reply targets, custom emoji files and stories follow, and the follow-up rewrites the messages
  that waited for them from their current rows, so a view (which watches its own chat only) re-renders them. Forums and
  monoforums store first too when their topics are known (below).
- **The around fill learns the top from the server.** `offset_id_offset` is the 1-based position of the anchor from
  the newest message and the server does not fill downward, so the hole closes to the top exactly when the newer ids
  returned number one less than it (`aroundHoleFillRange`, `AroundHoleFillRangeTests`). `inexact` vetoes it; the bottom
  is never inferred.
- **Plain channels request no forum topics.** Every channel post is stored with `threadId = 1`; `resolveForumThreads`
  skips peers that are neither forum nor monoforum (`peerCanHaveForumThreads`).
- **An unjoined channel's view does not wait for the poll.** `wrappedMessageHistorySignal` still resets the read state
  and adds the full hole first, and `keepPollingChannel` still runs (1.0 s start delay), but the Postbox view is
  created at once. The profile warmup (`keepPeerInfoScreenDataHot`, eight tag views) starts after the first loaded
  history view. The full hole is added once per unpolled period (a flag on the channel's polling context), and a fill
  that closes the hole to the top advances the channel state's `synchronizedUntilMessageId`, so the chat's
  re-subscription after a fill does not wipe it and the poll does not seed a gap hole over it.

## Forum topics, and references that arrive late (skeletons)

A cold topic shows its messages after one round trip (`getReplies`).

- **A forum fill stores first when every fetched message's topic info is known** (`forumFillStoresFirst`); monoforums
  follow the same rule.
  - Known means stored, or carried by the answer itself (`topics`; both `getHistory` and `getReplies` carry them).
  - The answer's missing topics are stored **in the same transaction as the messages** (`storeFetchedForumTopic`): a
    topic info stored alone is dropped at commit, because `MessageThreadIndexTable.replay` keeps an info only while the
    topic has a stored message.
  - A message of a still-unknown topic resolves before storing, because topic headers read thread infos while drawing.
- **Forum fills store the reply targets they fetch** (the topics branch of `withResolvedAssociatedMessages`).
- **Messages waiting for references that arrive after the store are registered** in
  `AccountViewTracker.pendingMessageReferences`.
  - The registry is keyed by the **referencing message**, so the set that draws skeletons is exactly the set the fills
    redraw. A message drawing a skeleton is always a source of a pending registration.
  - A fill registers the messages it stored that reference a missing reply target or story, in the transaction that
    stores them. A forum message's own topic root is excluded (`pendingReplyTargets`): it is usually not stored and
    never draws as a header.
  - The follow-up is **started inside that transaction**, so a fill disposed right after (ReplyThreadHistory disposes
    on the hole change the store causes) still releases.
  - The follow-up also fetches reply-header stories (`ReplyStoryAttribute`, which `resolveAssociatedStories` skips).
  - When it ends, whatever came back, it releases the registration and **rewrites its source messages from their
    current rows**, so each one redraws. Do not bring back a version-guarded re-add: the view counter rewrites channel
    posts on screen, so the guard skips exactly those and a skeleton stays.
  - Fills with nobody looking (preload, sparse lists) pass nil and register nothing.
- **Skeletons draw only for a missing reference of a registered message** (`hasLoadingReferences(messageId:)`);
  anything else missing draws as before. A reply header (`ChatMessageReplyInfoNode.Arguments.isLoading`) shimmers its
  author and text bars at the real header's height (a quote shows its own text); a forwarded story or story link
  preview shimmers its media area, already at the story's final size (`ChatMessageInteractiveMediaNode`); a story
  mention shimmers its circle.
- **Forum debug reset:** `-resetForumCache <username,...>` clears the history and also marks the topic list unloaded,
  because a topic's list entry, and the topic info stored in it, live only while the topic has a stored message.

## Opening a post from the News feed: the cached post first

The feed stores every post it shows into the channel's history (inside the hole).

- Opening a post from the feed passes `cachedAnchor: true` in `ChatControllerSubject.message`, which the history view
  turns into `includeAnchorWhileLoading`: a Postbox view opened around a message that is stored but still inside a hole
  then carries that message and its album as entries while it reports `isLoading`
  (`MessageHistoryView.isAnchorOnlyWhileLoading`, `PostboxTests` `MessageHistoryViewAnchorWhileLoadingTests`). Views
  without the flag keep no entries while loading.
- The chat applies the partial view with the post at the bottom (top edge at the top when taller), measured without
  its date header's space (`ChatMessageItemView.attachedDateHeaderInset`,
  `ListViewScrollToItem.excludesAttachedHeaderSpace`): alone in the view the post carries its day's header, which moves
  to an older post of the same day once those load and would move a post held by its top edge.
- The partial view is reported as loading early so the placeholder stacks its skeleton bubbles above it, and the
  loaded view is applied in place (`ChatHistoryViewScrollPosition.pinnedAnchor` / `.keepInPlace`, resolved in the
  history node from the post's relative offset).
- The partial view reports the history as still loading (`historyState`), so the profile warmup and the
  pinned-message view start after the fill as for any other open, and it makes no read claim (`maxReadIndex` is nil,
  so no unread separator lands above the post).
- While the post is pinned and its surroundings have not loaded, the view reports no hole-fill restart, so no hole
  operation on the channel (the poll's or any other) can restart the history around a post still inside the hole.

## Channels the account is not a member of: no read state

A channel the account is not a member of (For You channels; channels added only to News, which stay `.left`) has no
read state on the server, so the client keeps none either (`NonMemberChannelReadState.swift`):

- Opening one installs a fixed state with nothing unread and nothing counted (`maxKnownId: Int32.max - 1`);
  interactive reads do nothing, the server's read-state operations for it are skipped in replay, the synchronizer
  confirms anything queued for it without sending, and dialogs fetched for chat folders store no read state for it.
- The state's `maxIncomingReadId` is 0 on purpose: replaying `.ResetReadState` and validation both keep a local mark
  that is ahead of the server's while it reports unread (`localReadMarkIsAheadOfServer`), so a higher one would block
  the state a join brings in, which can itself be 0.
- **A join does not reliably fetch the dialog:** `initialStateWithPeerIds` judges the stored, still non-member channel
  and builds its chat info from stored notification settings (fetched when the chat was opened), so
  `resolveMissingPeerChatInfos` asks for nothing. A stored channel that becomes a member therefore queues a read-state
  validation itself (`channelJoinNeedsServerReadState` in `updatePeersCustom`).
- Monoforums (a user's direct messages with a channel) keep their read state whatever the participation status.
- A chat opened from News shows no unread badge on its back button
  (`NavigateToChatControllerParams.showsUnreadChatsBackBadge`).
