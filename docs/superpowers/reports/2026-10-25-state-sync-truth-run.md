# State sync against a model server: the branch and master

> Run report (2026-10-25) for Task 6 of `docs/superpowers/plans/2026-10-25-state-sync-truth-server.md`. The model
> server is `submodules/TelegramCore/Tests/StateSync/TruthServer/`. Per-seed results lived in the plan's git-ignored
> workspace and are not kept; every seed replays (section 8). Branch: `refactor/state-sync` at 90e043a22c, and at
> 921221c323 after section 5's fix. Master:
> origin/master d987d8c350 in a local test worktree (`test/state-sync-truth-master`, never pushed) with the harness
> ported to master's API (section 6).

## 1. Result

- **No message is missing** on either side: none in 5000 branch seeds, none in 500 master seeds. The one way this
  server found to lose a message, message 1 under a one-id hole, is fixed on the branch (90e043a22c, section 4). The
  code it fixes is master's too.
- **Two regressions, both a stale edit and neither a lost message, now fixed.** In seeds 1540 and 4967 the branch
  ended with one edited message showing its old text, and master was right. Both are the race in section 5, which
  master has too: seven of the nine seeds where the branch showed it end the same way on master, and 4967 does once
  the model makes master reset. The branch reached the race in more sessions because of two owner decisions:
  - it resets on a gap past `pts_total_limit`, where master downloads the whole difference;
  - it retries a failed history fill instead of dropping it.

  The fix (owner decision 2026-10-25) remembers recent edits and stores them over older answers (section 5).
- **No other regression.** In the 500 seeds both ran, the branch has no other discrepancy that master lacks.
- **Master gets six of the 500 seeds wrong that the branch gets right.** Four keep deleted messages, because a
  history fill that was in flight during the deletion stores them again. Two stop updating a channel (the Q13 wedge).
  Section 3.

## 2. Counts

Each seed is a random session: 20 to 60 steps over three private chats, a basic group, a broadcast channel and a
megagroup, and in a third of the sessions a stretch offline longer than the session's `pts_total_limit` (10 to 40, so
the launch difference is answered too long). The steps are:

- incoming messages, messages sent from another device, edits, deletions and history clears;
- the app killed, launched and restarted;
- chats opened;
- dropped, duplicated and swapped pushes;
- failed requests;
- history fills and fill confirmations held across other steps.

After the steps the app is brought to rest the way a user who opens every chat would bring it. The app is relaunched
once, every channel is polled until its pts is the server's, and every chat is filled until it has no holes. Then the
app's Postbox is compared with the server's messages.

| | seeds | exact | validation pending only | missing | ghost | stale | no convergence |
| --- | --- | --- | --- | --- | --- | --- | --- |
| branch | 1–5000 | 4152 | 839 | 0 | 0 | 9 | 0 |
| branch after section 5's fix | 1–5000 | 4162 | 838 | 0 | 0 | 0 | 0 |
| branch | 1–500 | 414 | 86 | 0 | 0 | 0 | 0 |
| master | 1–500 | 393 | 101 | 0 | 5 | 0 | 2 |

Master's seed 266 is counted under both ghost and no convergence (393 + 101 + 6 failing seeds = 500).

- **missing:** the server has the message and the app does not.
- **ghost:** the app has a message the server does not.
- **stale:** the app has the message with other content.
- **no convergence:** the app did not come to rest. Either a channel's pts was still behind after polling, or holes
  were left after 50 fills.
- **validation pending:** a channel ghost or stale message below the channel's `invalidatedPts`. The app has marked
  that range for revalidation, which `HistoryViewStateValidation` runs when the chat is shown. The harness does not
  run it, so these are reported but are not failures.

Master ran seeds 1–500, not the plan's 1–5000, because a master session takes longer (section 6). A master-only
failure past seed 500 would be a loss the branch fixes, not a regression. The 9 stale seeds above 500 were run on
master separately (section 5).

The two sides do not see the same server. The branch sends the session's `pts_total_limit` (10 to 40) and is answered
too long past it. Master sends no limit, which is master's real behaviour, so master is never answered too long and
never resets. Section 5 runs master with the limit applied on the server's side too.

## 3. Master-only failures: losses the branch fixes

| seed | master | cause |
| --- | --- | --- |
| 114 | ghost channel301 [2] | a fill's answer held, the message deleted meanwhile, then the answer stored |
| 123 | ghost user201 [3, 10, 11, 12, 15, 18] | a fill's answer held across a history clear, then stored |
| 269 | ghost chat801 [3, 5, 6, 10, 12, 16, 21] | the same |
| 359 | ghost chat801 [9, 17, 19, 20, 21, 22, 23, 24] | the same |
| 266 | no convergence channel301 (pts 7 behind after 50 polls); ghost channel301 [2] | Q13: channel polls wedged, so the deletion never arrives |
| 274 | no convergence channel301 (pts 6 behind after 50 polls) | Q13 |

**Deleted messages restored by a late fill.** On the branch, no fetch stores a message that Postbox's record of recent
deletions holds (owner decision D2, 2026-10-15; `fetchedMessagesWithoutRecentDeletions` and `RecentlyDeletedMessages`,
docs/state-sync.md invariant 14; pinned by `HistoryFillRecentDeletionTests`). Master has no such record. A clear or
deletion that lands while a history fill is in flight is undone when the fill's answer is stored, and nothing later
in the session corrects it.

**Q13.** A poll's result is lost to `deliverOn` reordering, the poll stays at the head of the operation queue
forever, and nothing queued behind it runs (`docs/superpowers/reports/2026-10-15-state-sync-q13-poll-result-loss.md`;
fixed on the branch in 69939c45c0). The model answers in microseconds, which makes the race far more frequent here
than over a real network. The Q13 report finds two paths to it: one needs an answer faster than one queue hop, which
"practically never happens" over a real network; the other is independent of the server, rare in production and
permanent when it happens. Which path these polls took was not checked. Across master's 500 seeds, a channel poll
produced nothing within 30 s in 61 sessions: 49 recovered after one empty poll, 10 after two, and these two never did.

## 4. Client fixes this server found

- **90e043a22c: an upward history fill asks for its range's end id.** `fetchMessageHistoryHole` asked `getHistory`
  with `max_id` equal to the range's end, but the server treats `max_id` as exclusive. A one-id hole `1 ... 1` asked
  upward therefore got nothing, and the empty answer closed the hole: message 1 was never loaded. The branch's account
  reset makes such a hole. It stores a chat's top message above a hole over `1 ... top - 1`, so a top of 2 leaves
  `1 ... 1`. Before the fix, 17 of the branch's 5000 seeds were missing message 1, and none after. Pinned by
  `HistoryFillRangeBoundsTests.testUpwardFillIncludesItsEndId` and
  `TruthSessionTests.testSeed148ATopMessageOfTwoAfterAResetKeepsMessageOne`. Master has the same bounds. Master's run
  does not reach them, because master sends no `pts_total_limit`, so the model never answers it too long and it never
  resets. Whether master's own resets (a real server's too-long answer) leave such a hole was not checked.
- **Reported, not changed:** the other request kinds in `fetchMessageHistoryHole` (search, replies, mentions,
  reactions, saved history) keep exclusive bounds. A downward range's `min_id` is its end, so the end id is left out
  at the bottom of tag and thread fills. Nothing in this run exercises them.

## 5. Fixed: an edit lost to a fill in flight

Seeds 887, 1285, 1443, 1540, 2178, 2819, 3160, 4875 and 4967 on the branch ended with one message's old text. Each
time, a history fill's request was in flight, and an edit of a message in its answer was pushed. The answer, produced
before the edit, then stored the old text, and nothing later in the session corrected it. No message was missing or
extra. This is the edit counterpart of section 3's deletions. The message was either:

- **not stored** (887, 1443, 1540, 2819 replayed): under the hole being filled, so the replay had nothing to apply
  the edit to and dropped it;
- **stored** (4967 replayed): the replay edited it in place, and the answer wrote the old text over it, since a fill
  that confirms nothing stores its whole answer.

| seed | branch before the fix | master | master, the session's limit applied by the server |
| --- | --- | --- | --- |
| 887, 1285, 1443, 2178, 2819, 3160, 4875 | stale | stale, same chat and id | not run |
| 1540 | stale user201 [33] | ok | ok (reset once) |
| 4967 | stale user203 [33] | ok | stale user203 [33] (reset once) |

Why the branch reached it where master did not:

- **4967: the reset.** Message 33 arrived before the app went offline and was stored. The launch difference was
  answered too long, so the branch reset: a reset puts a hole over each chat's history and keeps the messages stored
  under it. The fill of that hole was in flight when 33 was edited. Master's launch difference delivered the gap
  instead, so no fill covered 33. Made to reset by a server-side limit, master ended with the branch's stale message.
- **1540: the reset and the retry.** Plain master does not reset, as in 4967. With the server's limit master resets
  too and still ends right, because of what follows the reset: the fill's first request fails (a `failNext` step).
  The branch retries it at once (invariant 12, "never give up on a transient error"; the owner's "we never abandon
  syncing or message history loading"), and the retry is the request in flight during the edit. Master drops the
  failed fill, so its next fill of the hole comes after the edit and gets the new text.

In production the branch sends `pts_total_limit` 10000 when the app configuration has none (task LIM, audit Q14) and
resets on a larger gap. Master sends none: the client used to send no limit because the reset did not revalidate
messages stored in regular chats (audit Q14: "This was why the client sent no `pts_total_limit` (owner, 2026-10-15)").
The branch fixed that and sends it.

**The fix (owner decision 2026-10-25: "Remember recent edits").** Postbox records every edit the replay receives,
the message's latest edit for 5 minutes (`RecentlyEditedMessages`, at most 1000 messages, in memory). Every fetch that
filters recent deletions then stores, in place of an answer message, its edit recorded since the fetch's request went
out (`fetchedMessagesWithRecentEdits`). That covers the history fill's answer and its follow-up's reply targets, and
the reset's and the chat-list fill's top messages and reply targets. An edit recorded before the request went out is
in the answer, which may be newer still, and is left alone. Two choices went past the option as offered:

- **The edit is stored in the answer's place**, rather than leaving a one-message hole for the next fill. A hole is a
  message missing until that fill lands, a frequently edited message (a live location) could keep it open, and a
  comment thread's fill cannot reopen one.
- **Edits of stored messages are recorded too.** The option named messages the app had not loaded; replaying 4967
  showed its message was stored, so that alone would have left 4967 stale.

`RecentEditTests` pins each site: a never-stored and a stored message, a channel post, a reply target, the chat-list
fill, the reset, and an edit made before the request went out. Each failed before the fix ("original" for "edited")
except the last, which guards against replacing a newer answer. `TruthSessionTests.testTheEditRaceSeedsKeepTheirEdits`
replays 887, 1443, 1540 and 4967.

Seeds 1–5000 again at 921221c323: no seed fails, against 9 before, and all nine stale seeds end exact. 4162 are exact
and 838 validation pending only. Seven seeds became validation pending and eight stopped being:

- Six of the seven (1487, 2394, 2833, 3487, 4115, 4317) are channel ghosts of messages that were never edited, which
  the fix does not touch.
- In 1341 a channel post was edited twice, and the second edit's push was dropped. The app then took the channel's pts
  from `getPeerDialogs`, which marks the range for revalidation (`invalidatedPts`), and the post keeps the first edit.
  The fill held across the first edit stored that edit, where it used to store the original text.

Run again on the same code, five of the seven ended exact (1487, 2394, 2833, 3487, 4317): the timing of a session's
pushes and answers varies between runs. 1341 and 4115 ended validation pending again. 1341 is as above. In 4115 the
app never polled channel 301 (no `getChannelDifference` for it) and took its pts from `getPeerDialogs`, so it never
received the deletion of post 8, which no edit touched.

## 6. The harness on master

The port is test-only and stays in the local worktree. Adaptations:

- `Network.makeForTesting` is appended to master's `Network.swift` (the branch's, verbatim).
- The fixture passes master's initializer arguments (`addIsContactUpdates: { _ in }`, no `gapWaitTimeout`).
- `compare()` reads stored messages with `withAllMessages`, because master's Postbox has no `messageIdsInRange`.
- Master's hard-coded 2 s gap wait reads a static (`AccountStateManager.truthBaselineGapWaitTimeout`), set to the
  branch harness's 0.05 s.

Two switches, off by default, serve section 5 (f50a7164c9 and the commit after it):

- `TRUTH_SERVER_TOTAL_LIMIT=1` makes the model answer a gap past the session's limit too long although master sends
  no limit, as a real server answers a gap it will not send. Each seed's `getDialogs` count is printed
  (`TRUTH requests`), which shows that a reset happened.
- `TRUTH_REPORT_OK=1` writes the full report of a seed that found nothing.

Two more adaptations follow from Q13:

- **Settle.** "At rest" is no new request for 0.3 s, not a drain marker. A custom operation never runs while a wedged
  poll holds the queue's head.
- **Polling cap.** Converge ends a channel's polling after 3 polls in a row produce nothing (9af9ef4fec). The 50-poll
  wait took 25 minutes per wedged seed, which pushed one chunk past its one-hour test timeout. Seeds 299–300 and
  395–500 ran with the cap. In seeds 1–394, a session's empty polls numbered one, two, or every poll to the 50th, so
  the cap changes no outcome. It never fired in 395–500.

## 7. Model fixes and rulings

These are harness changes, not client changes, each found by a session's report:

- **Channels are polled to the server's pts.** A DEBUG `pollChannel` asks for 2 entries and `pollChannelOnce` sends
  one request. A single poll left a channel edit stale; an open chat keeps polling (`keepPollingChannel`).
- **Fills go from the newest hole's top down to id 1,** as a view asks (`MessageHistoryViewState`, end id 1). The
  driver's `(top, bottom)` range had made a one-id hole an upward fill, and 6 seeds reported missing channel messages
  that no view would have asked for that way. That finding led to section 4's fix.
- **A history clear deletes every message.** Only the chat list keeps the old top, as a history-cleared service
  message; history and `getMessages` do not have it. This is what a real account showed on a simulator: the reset
  stored the top, and the fill's confirmation deleted it. A chat with no messages and no cleared top is left out of
  the chat list.
- **The oracle does not judge any id that was ever a cleared chat's top.** All 97 ghosts of the first 5000-seed run
  were the reset's stored history-cleared service message, which stays above the hole. **Whether the real server keeps
  that service message in history is unknown, and worth one check against it.** If it does not, the app keeps a
  "History was cleared" line the server has dropped; that is not a user message.
- **Validation-pending messages are reported, not failed** (section 2).

## 8. What the model does not cover, and how to replay

**Not modelled:**

- forum topics, secret chats, media, reactions;
- folders beyond the main and pinned lists;
- a second account and the notification extension;
- real latency: answers are instant or held by a step;
- server limits other than `pts_total_limit` and its slice sizes (difference 20, channel difference too long at 60,
  with 20 messages).

Pushes are `updateShortMessage` and `updateShortChatMessage` for new messages in the private chats and the basic
group, and `updates` carrying new channel messages and every chat's edits and deletions.

**Replay.** Run seeds N to M from a worktree:

```sh
bash docs/superpowers/plans/2026-10-25-state-sync-truth-server/run-truth.sh N M /absolute/outdir 50
```

A failing seed's whole report, with its steps and every request and answer, goes to `/absolute/outdir/seed-N.txt`.
Run `run-make.sh test` once before, as the script says. The fixed sessions and single-fault sessions in
`TruthSessionTests` run with the suite.

## 9. A more representative model (plan `2026-10-25-state-sync-truth-server-2.md`)

Owner: "continue refining the server model into a more representative one to be more sure". The model gained:

- **The app's channel revalidation.** `converge` feeds each channel's history views to
  `HistoryViewStateValidationContexts`, as `AccountViewTracker` does for an open chat, and the oracle then judges the
  posts below `invalidatedPts` like any other. It found a model bug: edited messages carried no `edit_date`, which
  the revalidation compares, so it kept the old text (seed 111). Fixed in the model.
- **A large world** (`TruthShape.large`): 129 chats, 120 of them quiet and old, so a reset lists one dialogs page of
  100 and the chat list's holes bring the rest; a private chat and a channel of 300–400 messages, so fills page;
  sessions open those at a message (an around-anchor fill) and scroll them up.
- **The chat list in the oracle:** every chat the server lists is listed, with the server's top message, and no chat
  is listed by a message the server does not have. The app fills its chat list's first hole at each launch and all of
  them in `converge`.
- **Real timing:** with jitter, every answer and push is 0–50 ms late, so pushes land while requests are in flight
  and answers overtake each other.

| run | seeds | result |
| --- | --- | --- |
| small world, revalidation (ba409db1ab) | 1–5000 | 5000 exact (was 4162 exact, 838 validation pending only) |
| small world, chat list, launch fill (35b3f7ba50) | 1–5000 | 5000 exact |
| small world, jitter (35b3f7ba50) | 1–2000 | 2000 exact |
| large world (35b3f7ba50) | 1–1000 | 998 exact; seeds 698 and 916: a ghost shown as the chat's last message |
| large world, after the ghost fix (1ef6b0874b) | 1–2000 | 1999 exact; seed 1667: a channel's first post missing |
| large world, jitter (1ef6b0874b) | 1–300 | 300 exact |
| large world, after the first-post fix (f862115ee2) | 1–2000 | 2000 exact |
| small world, after both fixes (836b57550a) | 1–5000 | 5000 exact |
| small world, jitter, after both fixes (836b57550a) | 1–2000 | 2000 exact |

Every one of the 838 sessions that ended validation pending ends exact once the app's revalidation runs: what the
first report left unjudged was right.

**A ghost after a reset, beyond its first dialogs page (fixed, 1ef6b0874b).** In seeds 698 and 916 a quiet private
chat's message was deleted while the app was offline. The app came back past `pts_total_limit` and reset. The reset
deletes the stored messages above each top it fetches, but its first page of 100 did not hold this chat. The chat-list
fill of the next page stored the chat's top with `.UpperHistoryBlock`, which removed the hole above it, and deletes
nothing: it moves no pts, so a message newer than its answer may have arrived meanwhile. No fill ever covered the
deleted message again, and it stayed as the chat's last message for good. This was the owner's ruling of 2026-10-24
("I would skip this chat-list complication"); with the model showing it reachable and branch-only (master sends no
`pts_total_limit` and downloads such a gap, deletions included), the owner chose "Leave a hole": the chat-list fill
still deletes nothing, but leaves a private chat's or basic group's stored messages above the top it fetched under a
hole, so the chat's next history fill asks the server about them and deletes only those it no longer has. A channel's
revalidation covers its own. Pinned by
`ChatListHoleFillTests.testChatListFillLeavesMessagesAboveATopUnderAHoleTheNextHistoryFillConfirms` (failed first) and
`TruthSessionTests.testTheLargeWorldGhostTailSeedsEndExact`.

**A chat opened at its first message never loaded it (fixed, f862115ee2; on master too).** In seed 1667 the session
opened channel 301 at post 1. An around fill asks `messages.getHistory` from the anchor, and it sent `min_id` 1;
`min_id` is exclusive, so the server left post 1 out, and the fill closed the hole over its anchor all the same
(`fetchedSpan` starts at the anchor). Nothing asked about post 1 again: the revalidation asks from the lowest stored
post. The fill now sends `min_id` 0, no bound. The shape predates the refactor (in the code since at least 2020):
the model's new open-at-a-message step found it. The other around requests (`getReplies`, `getSavedHistory`, the
mention, reaction, poll and search fills) send `min_id` 1 the same way and are left for their own change. Pinned by
`HistoryFillRangeBoundsTests.testAroundFillAnchoredAtTheFirstMessageAsksForIt` (failed first) and
`TruthSessionTests.testTheLargeWorldFirstPostSeedEndsExact`.

**Model rulings of this round** (the plan's ledger has each with its cost):

- A chat listed with no message (index id 0, a joined channel with no posts) is not extra.
- The launch's chat-list fill changes every existing seed's requests, so runs are compared by kind.
- Answers carry all the world's users and chats, not only those referenced.

**Still not modelled:** messages sent from this device (the send path, `updateShortSentMessage`), forum topics, a
second process polling (the notification extension), secret chats.
