# TelegramEngine/Messages — agent notes

How a history fill stores, forum fills, skeletons and the News feed open: `../../State/CLAUDE.md`.

## Opening a post's comments (one round trip)

A channel post's comments, a `?comment=` link and a group reply thread each open after one round trip.

- **`getReplies` goes out beside `getDiscussionMessage`, not after it.** `messages.getReplies(peer: channel, msg_id:
  post)` answers with the discussion group's comments (`.threadFromChannel`); a group thread is requested by its own
  id.
  - `replyThreadOpenPlan` decides what to send from the head's stored `ReplyThreadMessageAttribute`. The anchor is the
    link's comment, else `read_max_id`, else the oldest 40.
  - `replyThreadReconcile` keeps the fill only when `getDiscussionMessage` names the same thread and anchor; otherwise
    the sequential fill runs, cache first.
  - "Same thread" differs by target (`replyThreadFillMatchesServerThread`). A post's fill matches unless its comments
    name another thread. A group thread's fill matches only when the thread the client chose is the server's: an empty
    answer names no thread, and a `.direct` fill has already closed holes on the thread it asked for, so treating an
    empty answer as a match closes every hole of the real thread on disk.
  - Both are pure and tested (`ReplyThreadOpenPlanTests`).
- **A `.threadFromChannel` fill cannot close its own holes**, because it does not know the thread id. The opener
  removes its full `removedIndices` on the server's thread, exactly what a `.direct` fill of the same answer closes.
- **A cached reopen sends `getDiscussionMessage` alone.** The cache probe needs the post's thread id. It takes it from a
  cached comment (the anchor or the newest), else from the group's copy of the post, found by the post's date and its
  `SourceReferenceMessageAttribute` (`cachedDiscussionThreadId`). Keep the second lookup: a long thread opened at its
  oldest end has neither comment cached, and without it every later reopen sends an extra `getReplies`.
- **`getDiscussionMessage` is sent before the probe runs.** The probe runs beside it and only decides whether
  `getReplies` goes out too.
- **The fill's `pts` is the group's**, so `ChannelMessageStateVersionAttribute` is stamped as for `.direct`.
- **The thread context's own `getDiscussionMessage` is skipped** within 30 s of the opener's
  (`RecentDiscussionMessageFetches`); both returned the same read state in every case measured.
- **A comment link fetches its thread once.** The resolver fills around the linked comment and hands the thread to
  `openMessageReplies(resolvedThread:)`, which only preloads. A post that is not cached is fetched in the same turn.
- **Debug builds have three measurement aids:**
  - `-resetCommentsCache <username/post,…>` clears those posts' discussion groups at launch.
    `-resetCommentsCacheDropPosts` also drops the posts and leaves a hole in their place; without the hole the channel
    reads the post as never having existed.
  - `-debugOpenUrl <url>` opens a link through the universal-link path.
  - The `ReplyThreadOpen` log tag times each step. The `[MT] … add request` lines show what reached the wire.

## Marking a whole chat read from the chat list

The swipe, "Mark as Read" and reading a folder read up to the **server's** newest message, not the newest stored one
(`_internal_readPeerHistoryToTopInteractively`). The read state keeps the dialog's `top_message` as `maxKnownId`, and its
count includes that message even when this device never stored it; a read short of it leaves it unread on the server,
which answers with `still_unread_count` (or the validation the push runs) and the chat comes back unread (issue #98).
Postbox clears the count for such a read: an interactive read past the newest stored message and at or past
`maxKnownId` reads every counted message (`MessageHistoryReadStateTable.applyIncomingMaxReadId`); tests in
`Tests/StateSync/ChatListMarkReadTests.swift` and Postbox's `MessageHistoryReadStateTableTests`.
