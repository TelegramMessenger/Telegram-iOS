# Account state synchronization: map and audit (2026-10)

> **A dated record.** This audit's map and evidence describe the code at `171825ce49`, before the refactor and the
> fixes; its issue table also records the fixes (to 2026-10-16). The living map of state sync, kept current with the
> code, is [`docs/state-sync.md`](state-sync.md); use this file for its issue ids and their reasoning.

Scope: how TelegramCore keeps the local database in step with the server's update
sequences (`updates.getDifference`, `updates.getChannelDifference`, `updates.getState`,
pushed `Updates`, pts/qts/seq/date, channel pts). Read at commit `171825ce49`; every
`file:line` below refers to that commit. Method: five readers mapped disjoint regions,
then five adversarial verifiers tried to refute each suspected defect (45 de-duplicated
issues: 29 confirmed, 16 confirmed with narrowed details, 0 refuted). Headline defects
were re-checked by hand.

Abbreviations: `M` = `TelegramCore/Sources/State/AccountStateManager.swift`,
`U` = `State/AccountStateManagementUtils.swift`, `I` = `Account/AccountIntermediateState.swift`,
`G` = `State/UpdateGroup.swift`, `S` = `SyncCore/SyncCore_AuthorizedAccountState.swift`.

## 1. Persisted state

- Account: `AuthorizedAccountState.State { pts, qts, date, seq }` plus
  `invalidatedChannels: [{peerId, pts?, validityMarker}]` (S:11-123). Equality compares all
  four fields, `date` included (S:125-130).
- Channel: `ChannelState { pts, invalidatedPts?, synchronizedUntilMessageId? }`, stored as the
  peer's chat state (`SyncCore_ChannelState.swift:3-60`).
  - `invalidatedPts`: stored messages whose `ChannelMessageStateVersionAttribute.pts` is lower are
    revalidated lazily (`HistoryViewStateValidation.swift:46-66`).
  - `synchronizedUntilMessageId`: newest id with no gap below it; the lower bound of the
    "hole from previous state" added after a channel reset.
- `State/AccountState.swift` and `State/ChannelState.swift` do **not** hold these types (auth-code
  conversions and an unused helper respectively).

## 2. Ingress

- Pushes: MtProtoKit (`MtProtoKitUpdateSinkService`, `MtProtoKitEngine.swift:484-511`) and the
  Rust engine (`RustNetworkSession.swift:386-390, 771-775, 1067-1084`) call
  `NetworkEngineUpdateSink`. `UpdateMessageService` (`UpdateMessageService.swift:7-86`) turns
  every `Api.Updates` into `UpdateGroup`s via `groupUpdates` (G:206-236):
  - `.withPts` for the nine common-box pts updates (G:61-97), `.withQts` for
    `updateNewEncryptedMessage` (G:99-107), and exactly one `.withSeq` (seq != 0) or `.withDate`
    group for everything else, channel updates included.
  - `updatesTooLong` and a session reset become `.reset`; `updateShortSentMessage` becomes a
    content-free `.updatePts`.
- RPC results: ~155 call sites in ~60 files call `stateManager.addUpdates(result)`; it goes
  through the same `UpdateMessageService` on the manager queue (M:491-495), so RPC results get
  the same gap checks as pushes. Before `reset()` creates the service, they are dropped (Q8).
- Other producers: `ApplyUpdateMessage` (`.ensurePeerHasLocalState`), managed operations
  (`.updatePts`), view polls (`addReplayAsynchronouslyBuiltFinalState`), custom operations.

## 3. The operation queue (`AccountStateManager.Impl`, M:156-1918)

A serial queue of operations on the manager's own `Queue`. Only `operations[0]` runs; each
completion pops the head with `removeFirst()` and starts the next.

| Operation | What it does |
| --- | --- |
| `pollDifference(id, events)` | one getDifference cycle; carries events accumulated over slices |
| `collectUpdateGroups(groups, timeout)` | timeout 0: batch groups for one turn, then `processUpdateGroups`. timeout 2.0: a gap wait that **always** ends in `pollDifference` |
| `processUpdateGroups(groups)` | snapshot, interpret, resolve, replay a pushed batch |
| `custom(id, signal)` | serialized external work |
| `pollCompletion(id, ids, subscribers)` | a `help.test` barrier for `pollStateUpdateCompletion()` |
| `processEvents(id, events)` | delivers side effects of a committed replay to pipes and managers |
| `replayAsynchronouslyBuiltFinalState(state, completion)` | replays a state built elsewhere (view polls) |

Placement: `addOperation` (M:615-634) puts at the front, at index 1 when the head runs, or
appends; `insertProcessEvents` (M:1552-1571); `replaceOperations` (M:559-613) is "force a
getDifference": it keeps running ops, keeps queued `processUpdateGroups`, inserts the new op,
merges `pollCompletion`, keeps replays/events/customs, and **drops** queued
`collectUpdateGroups` and `pollDifference`. `addUpdateGroups` (M:497-513) merges into the last
op if it is a collect (keeping its timeout), else appends `collect(groups, 0.0)`.

**Load-bearing:** SwiftSignalKit's `Queue.async` runs the block inline when already on that
queue (`Queue.swift:60-66`), and `deliverOn` is built on it. Every `addOperation` call is made on
the queue, so it is synchronous. That is what makes a `differenceSlice` continuation (M:979) run
before update groups that arrived mid-poll. Replacing these with a real dispatch would reorder
them.

`isUpdating` starts true, is set by `pollDifference` (M:818) and cleared only at M:792, 801, 990.
`AccountTaskManager` waits for its first `false` (`AccountTaskManager.swift:51-59`).

## 4. The pipeline: snapshot, interpret, resolve, replay, dispatch

1. **Snapshot** (`initialStateWithPeerIds`, U:460-558, one Postbox transaction): peers, channel
   pts, explicit-poll channels (no stored cloud message, or locally non-member, U:482-487),
   stored reply targets, peer chat infos, read states, and the account `State` (force-unwrapped,
   U:556). Two front ends with twin extractors: update groups (U:45-206, 560-569) and
   differences (U:214-445, 571-579); the twins have drifted.
2. **Interpret.** `finalStateWithUpdateGroups` (U:581-706) does the common-box gap checks, then
   `finalStateWithUpdates` hops through `network.currentGlobalTime` (U:917-922), which emits on
   the process-wide `MTContext` queue, and runs the ~1130-line switch
   `finalStateWithUpdatesAndServerTime` (U:925-2151) **on that queue** (G7). The result is an
   `AccountMutableState`: an operation log plus derived indexes (I:228-931).
   `finalStateWithDifference` (U:708-783) instead takes the difference's state as authoritative,
   adds `new_messages` unconditionally and passes `other_updates` through the same switch with no
   common-box checks.
3. **Recover channels and resolve** (U:2077-2150): channels needing a poll are polled inline
   (`pollChannel` on `updatedState.branch()`, merged back) for pushes; for differences they are
   reset (`resetChannels` = `messages.getPeerDialogs`, inline or via `asyncResetChannels`). Then a
   strictly sequential resolve chain: forum threads, associated messages (reply targets, custom
   emoji files, forum threads again), stories, missing peer chat infos.
4. **Replay** (`replayFinalState`, U:4057-6440) inside the caller's Postbox transaction:
   - P0 `verifyTransaction` (U:3776-3839) unless `skipVerification`: peers present; stored
     `State` equals the snapshot; each touched channel's stored pts equals its snapshot pts.
     Failure returns `nil` before any write.
   - P2 lower bounds of holes-from-previous-state read before any operation (U:4133-4155).
   - P3/P4 pre-pass over raw ops, then keep only incoming ids not stored yet (for notifications).
   - P6 main switch over `optimizedOperations` (U:3851-3938), which batches adjacent `AddMessages`
     **and moves every `UpdateState`/`UpdateChannelState`/invalidation/synchronizedUntil write to
     the end** (last value per key, not max).
   - P7 post-loop work: previous-state holes, forum topic resets, stats, presences, stickers,
     secret-chat decryption, lang packs/themes (async side transactions started from inside),
     wallet, delivered-message removal, typing drafts.
   - All writes commit atomically with the new pts. pts writes are unconditional; the only
     monotonicity guard is verification.
5. **Dispatch** (`processEvents`, M:1116-1310): pipes for notifications, calls, group calls,
   typing, webpages, stories, deleted messages, thread read states, balances; plus one more
   Postbox transaction to build notification messages.

`AccountFinalState` flags (I:933-939), built non-trivially only at U:2145:
`shouldPoll = hadReset || channel poll CHANNEL_PRIVATE/INVALID || resolveError`,
`incomplete = common-box hole`, `discard = resolveError`,
`missingUpdatesFromChannels = Set()` **always** (dead). Only `processUpdateGroups` reads them
(M:1044-1094); the difference paths ignore them.

## 5. Gap detection

| Sequence | Skip (already applied) | Apply | Otherwise |
| --- | --- | --- | --- |
| common pts (G:61-97, U:605-629) | `local >= pts` | `local == pts - count` | hole; this and every later pts update deferred |
| qts (U:631-649) | `local >= qts + 1` | `local == qts - 1` | hole (a duplicate `local == qts` is a hole, G2) |
| seq (U:651-667) | `local >= seq + count` | `local == seq - count` | hole (`updatesCombined` count is off by one, G2) |
| channel pts (U:968-1145, 1476-1499) | `local >= pts` | `local + count == pts` | gap: poll; unknown state: intended poll is a no-op (G1) |

Deferred updates are not kept: a hole only sets `incomplete`, and `processUpdateGroups` then
re-queues the groups as `collect(groups, 2.0)`, whose timer always calls
`replaceOperations(pollDifference)`. So a hole = fixed 2 s wait + getDifference; groups that
arrive during the wait are merged into that op and discarded (Q5).

Ordering contracts not visible at the call sites: `sortedUpdates` (U:785-915) moves every
channel update first (per channel, by pts); `optimizedOperations` moves state writes last;
`ResetIncomingReadState` compares against stored pts mid-replay and therefore never matches (R3).

## 6. getDifference cycle (`pollDifference`, M:816-1007)

1. Transaction: read `AuthorizedAccountState`, the `ios_disable_parallel_channel_reset_v2` app
   config flag, and `invalidatedChannels` left by another process (validity marker mismatch);
   start async resets for those.
2. No inner state: `updates.getState`, store it, loop. Otherwise `updates.getDifference(pts, date,
   qts)` with no `pts_total_limit` (at the time; since LIM it is sent from app config, see Q14) and `retryRequest` (retries every
   error forever); `AUTH_KEY_DUPLICATED` maps to "skip".
3. `differenceTooLong` → `_internal_resetAccountState` (`ResetState.swift`), with no getState: the
   top 100 dialogs, the pinned chats and the first page of each folder they reference; then the
   ghost tail (the stored Cloud messages above each fetched dialog's top message, all of a dialog's
   stored messages when it has no top) is confirmed with `messages.getMessages` /
   `channels.getMessages`; then one transaction marks every non-secret chat not included with a
   full hole, rebuilds the chat list, deletes the candidates the server no longer has (refreshing
   the rest), raises `invalidatedPts` of each channel whose pts moved, and moves pts to the one
   `differenceTooLong` carried, keeping qts, date and seq (G10). Nothing is written until every
   answer is in. The cycle continues: the poll is re-added with its events and polls again from
   the new pts; a reset that follows another in the same cycle waits first (1 s, doubling to 60 s,
   `consecutiveResetDelay`), and `dialogsNotModified` writes nothing, so the next
   `differenceTooLong` retries the reset.
4. Else snapshot, check the snapshot equals the state read in step 1, interpret, replay.
5. Outcome (an untyped 4-tuple, M:852): slice → continuation at the front; final → complete the
   channel-reset context or clear `isUpdating`; skip → deliver events only; anything else
   (mismatch, verification failure, getState bootstrap) → `replaceOperations(pollDifference)`
   with no backoff.

**Async channel reset** (M:636-804): for channels a difference says are too long, persist an
`InvalidatedChannel` record, run one `getPeerDialogs` per channel in parallel, and when the
difference chain ends (`canComplete`), merge all results and replay them in a direct Postbox
transaction **outside the operation queue with `skipVerification: true`**, then clear every
record.

**Notification extension** (`standalonePollDifference`, M:1435-1550) is a fork of the same
pipeline: state from `stateView`, `date: Int32.max` + `ignoreDate`, inline (sync) channel resets,
events dropped, and `preconditionFailure()` on `differenceTooLong` (Q3). The NSE restarts it while
the result is a slice, bounded by its time budget.

## 7. Channel synchronization: four entry points

1. **Gap polls** inside `processUpdateGroups`: `pollChannel` (U:3473-3774), getChannelDifference
   limit 100 (2 in DEBUG), `final` ignored, retried forever except CHANNEL_PRIVATE/INVALID.
   Replayed with verification.
2. **Resets during getDifference**: `resetChannels` (getPeerDialogs), sync or async (above).
3. **View polls**: every open history view of a channel subscribes `keepPollingChannel`
   (`AccountViewTracker.swift:1885-1936, 2023-2073`) = `pollChannelOnce` restarted every
   `timeout ?? 30` s, replayed through the queue with verification. Unjoined channels also get a
   read-state reset and a full hole once per unpolled period.
4. **NSE channel pushes**: `standalonePollChannelOnce`, replayed outside the queue in another
   process.

(1) vs (3) are safe against each other (verification discards the loser). (2) is not: its
unverified replay can move channel pts, `synchronizedUntilMessageId` and read state backwards
(C1). `fetchChatListHole` also overwrites channel pts unconditionally (C7).

## 8. Invariants

| Invariant | Enforced by |
| --- | --- |
| One operation runs, and it is `operations[0]` | convention |
| `addOperation` from the queue is synchronous (inline `Queue.async`) | convention; ordering depends on it |
| A replay commits pts atomically with the data it covers | Postbox transaction (type system) |
| A replay applies only if stored state equals the snapshot it was built from | `verifyTransaction`; bypassed by the async channel reset |
| A failed verification writes nothing | runtime check |
| Notifications fire only for messages not stored before the replay | runtime check (P4) |
| State writes happen after all other writes of a replay | `optimizedOperations` reordering, undocumented |
| Channel pts never moves backwards | **nothing** (C1, C7) |
| Every committed replay's events are delivered once | **nothing** (C1, Q9; Q4 and R1 fixed, 2026-10-15) |
| Every update group handed in is applied or covered by a later getDifference | **nothing** (Q5; non-sequenced updates are lost) |
| Every poll cycle ends with `isUpdating = false` | holds since 2026-10-15 for every chain that ends (Q1, Q2, Q11, Q13 fixed); C5, C6 and Q9 can still leave it true |
| A channel with unknown pts that receives an update gets polled | the poll request (G1 fixed, 2026-10-15; broken 2023-01-31 to then) |

## 9. Verified issues

Severity is real-world impact; "behaviour" says whether fixing it changes observable behaviour
(all fixes do except where marked "no").

### Medium

| Id | Summary | Evidence | Since |
| --- | --- | --- | --- |
| Q13 | `pollDifference`'s result can be dropped by `deliverOn` reordering: a completion that runs inline on the manager queue overtakes a value dispatched there from another thread, and `Subscriber` ignores the late value. The poll then stays running at the head of the operation queue forever (`reset()` keeps running operations), so no update is processed again until relaunch. Boundary 1 (the answer beats one manager-queue hop; only when the inner chain completes on the network thread) has four branches that return a plain `.single` without a Postbox hop: AUTH_KEY_DUPLICATED (:848), `differenceTooLong` (:852), the initial-state mismatch (:858) and the getState bootstrap (:898-912); it is practically unreachable over a real network, and `PollResultLossCharacterizationTests` pins it deterministically (boundary 1 only). Boundary 2 (the replay transaction against the queue, the replay transaction after `finalStateWithDifference`) is inferred from the code and was seen once, by elimination, in about 5000 iterations; it is server-independent and rare. The notification extension has the same shape in `standalonePollDifference` (:1438-1446 into the `deliverOn` at :1487): there the extension stops paging a `differenceSlice` early, with no wedge. A fix must cover both :915 and :1487 (done). Line refs are at 99dfa95c4f (boundary 2: :891-892), the audit's others at 171825ce49. **Fixed** in 69939c45c0 (main path) and 95dfbca87a (notification extension) (2026-10-15). | M:799-917, 891-892 (at 99dfa95c4f); Signal_Dispatch.swift:3-21; Queue.swift:60-66; Subscriber.swift:152-163 | |
| G1 | `channelsToPoll[peerId] = nil` on `[PeerId: Int32?]` deletes the key, so 7 "poll this channel" sites are no-ops. Pushed posts, edits, deletes and pins for a member channel with a stored message but no `ChannelState` are dropped; `updateChannelWebPage` pts holes are never polled. Likely more frequent now that the News feed stores channel posts. **Fixed** in fe7d9f95a7 (2026-10-15). | U:965, 986, 1024, 1052, 1057, 1142, 1497 | a40ce690ee 2023-01-31 |
| C2 | `pollChannelOnce`, `standalonePollChannelOnce`, `resetChannels` discard `resolveAssociatedMessages`' result (closure uses the pre-resolve state). Reply targets fetched over the network are dropped; replies in open channels, NSE polls and every reset show no quoted target. The main path was fixed alone in 99fa059e08. **Fixed** in 89a6aeff37 (2026-10-15). | U:3185-3187, 3242-3244, 3465-3467 | 434e9dd22d 2023-06-09 |
| C3 | Forum/monoforum history fills fetch reply targets and pass `[]` instead of them (and their peers). **Fixed** in e16a0767b3 (2026-10-15). | `Holes.swift:349-353` | 09c49d47d9 2025-05-16 |
| Q3 | NSE `standalonePollDifference` traps on `differenceTooLong`; pts never advances, so every later non-channel push crashes the extension until the app opens. **Fixed** in da046c94e2 (2026-10-15). | M:1476-1477 | d04f8798c6 2021 |
| Q4 | `processUpdateGroups` with `shouldPoll` (a `.reset` in the batch, or a channel poll CHANNEL_PRIVATE/INVALID) commits the replay, then delivers only `displayAlerts`. In-app notifications, call signaling, deletions, typing, webpages, stories, qts acks are lost; pts already advanced, so getDifference does not redeliver. **Fixed** in a3c26f327d (2026-10-15). | M:1052-1069, 1086-1093 | |
| Q5 | The 2 s gap wait never re-checks the gap and always ends in getDifference; groups merged into it are discarded. Channel posts, deletions, presence, typing, call and group-call updates arriving in that window are dropped. | M:1013-1019, 1083-1085, 585-587 | |
| Q1 | After `differenceTooLong` + reset: `isUpdating` stays true (AccountTaskManager stays gated, "Updating…"), carried events dropped, no follow-up poll, a pending channel-reset context orphaned (later replays stale snapshots). Rare since e543bf1e2e removed `pts_total_limit`. **Fixed** in 57eab89242 (2026-10-15). Superseded by the differenceTooLong work: the cycle now continues after a reset (RS) and retries on dialogsNotModified (RB). | M:958-967 | f66213b63e 2023-02-03 |
| C1 | The async channel-reset replay is unverified and outside the queue: a gap poll or view poll that lands first is rolled back (pts, invalidatedPts, synchronizedUntil, read counts). Self-heals with extra requests and transient badge errors. | M:748-779, U:4925-4939 | a40ce690ee |
| R3 | `ResetIncomingReadState` compares the update's pts with the stored pts, which `optimizedOperations` has not advanced yet: the "trust server count" branch is unreachable for users/basic groups, so every remote read costs a `getHistory` + `getPeerDialogs` validation. | U:4851-4893, 3878-3885 | ddab57db60 2019 |
| G3 | `updatePtsChanged` ("state has to be refetched using updates.getState") falls into `default: break`. | U:2072; schema :370 | |
| G7 | The whole update interpretation runs on the process-wide `MTContext` queue, which main-thread `getApproximateRemoteTimestamp` callers `dispatch_sync` onto: large batches can hitch the UI. Behaviour: no. | U:917-922; `MTContext.m:638-646` | |
| G10 | `differenceTooLong` reset overwrites qts from getState without fetching encrypted messages in between; secret-chat messages in that window are recovered only if the peer sends again. **Fixed** in 6297b4882e (RS) (2026-10-15). | `ResetState.swift:153-158` | |
| Q14 | The `differenceTooLong` account reset does not revalidate messages stored in regular (non-channel) chats: edits made during the gap stay stale and messages deleted during the gap stay stored. This was why the client sent no `pts_total_limit` (owner, 2026-10-15); channels have `invalidatedPts` + `ChannelMessageStateVersionAttribute`, regular chats have nothing equivalent. **Fixed** in 573f2f49c0 (RG), 6e6df25f41 (LF), eb32304208 (F1), 451a84ef8d (F2), 7fd908518f (LIM), with the review fixes 445bbb8f9e and 4b8f041fdf (2026-10-15). | `ResetState.swift`, `HistoryViewStateValidation.swift` (channels only) | |
| Q15 | `fetchMessageHistoryHole`'s request passes `maxRetries: 0`, so a fill gives up on its first error and closes nothing; flagged under the owner's no-give-up rule (2026-10-15). Low. **Fixed** in `a5383365e4` (2026-10-16): a definite answer closes nothing and is logged, and a fill stuck on a genuinely transient error (5xx, flood wait) retries for the session; `fb9720f8e5` made a `TL_` parse error definite and disposes pending fills at teardown. | `Holes.swift:966-985`, `Signal_Catch.swift:164` | |
| C5 | `pollChannel`, getDifference and getState retry every error forever while holding the queue head; a permanent error (e.g. CHANNEL_PUBLIC_GROUP_NA) stops all update processing until relaunch. | U:3488-3498; `Network.swift:1507-1510` | |

### Low

| Id | Summary | Evidence |
| --- | --- | --- |
| Q12 | After an async channel reset is replayed, its events (and the difference's, which were moved into the reset context) are inserted at the head of an idle queue without starting it: nothing runs until the second later push (the first appends an unstarted batch, the merge path of the second starts the queue), an `addOperation(.first)` or `reset()`. Every operation queued meanwhile waits too. Found while planning stage 0; pinned by `ChannelSyncCharacterizationTests.testChannelTooLongInDifferenceResetsChannelAfterTheDifference`. **Fixed** in b7fde4f7b8 (2026-10-15). | M:780-794, 615-634, 497-513 |
| G2 | qts/seq treat an exact duplicate as a hole; `updatesCombined` is encoded `(seq, seq - seqStart)` so an in-order container is a hole. Costs 2 s + a getDifference, no data loss. **Fixed** in 15b9d944c5 (2026-10-15). | U:632, 652; `UpdateMessageService.swift:44` |
| R1 | `AccountFinalStateEvents.union` drops `updatedOutgoingThreadReadStates`, other's typing and emoji-game info, reads delay from self twice, and keeps the older balances; every getDifference goes through it. **Fixed** in d3e48f9f6a (2026-10-15). | I:1095-1167; M:972 |
| R2 | `branch()` copies alerts/web-view decisions into each branch and `merge()` appends them: K polled channels give K+1 copies (duplicate alerts, repeated Mini App URL loads). **Fixed** in b667b731f6 (2026-10-15). | I:310-311, 353-355 |
| Q9 | Channel-reset context: can be replayed twice (duplicate events), drops a channel added during its replay, can clear `isUpdating` mid-difference. | M:719-804, 636-648 |
| Q2 | `AUTH_KEY_DUPLICATED` abandons the poll without clearing `isUpdating`. Per docs the key is dead and a re-login follows. **Fixed** in eb6d445dd8 (2026-10-15). | M:872-880, 994-997 |
| Q6 | State mismatch / verification failure re-polls immediately with no backoff (no deterministic trigger found). | M:998-1004 |
| Q7 | `pollCompletion` sends `help.test` only when alone and fires only if the queue is still empty: can starve under traffic and blocks the queue for an RTT. | M:1311-1344 |
| Q8 | `addUpdates` before `reset()` is dropped (share extension's standalone send, startup window). | M:491-495 |
| Q10 | `discard`/`shouldPoll` ignored on difference paths (mostly misleading code). | M:903-928 |
| Q11 | `_internal_resetAccountState` returns `.never()` on `dialogsNotModified`, which would wedge the queue. **Fixed** in 74e816653f (2026-10-15). Superseded by the differenceTooLong work: the cycle now continues after a reset (RS) and retries on dialogsNotModified (RB). | `ResetState.swift:14-16` |
| G4 | `updateDialogPinned`/`updatePinnedDialogs` `preconditionFailure` on a folder peer (never observed). **Fixed** in a0eb01ccd0 (2026-10-15). | U:1679-1697 |
| G5 | A lone `.ensurePeerHasLocalState` batch can discard itself and force a getDifference (peer not loaded into the snapshot). | U:45-69, 173-178 |
| G6 | `updatesDate` is the earliest date of the whole batch and stamps every typing/read/reaction; equal-pts ordering of count-0 updates. Cosmetic. | U:684-699 |
| G8 | Difference variant of active channels resets member channels that were never referenced. | U:271-302 |
| G9 | `initialStateWithPeerIds` force-unwraps `State` (only nil between login and first getState). | U:556 |
| C4 | `channelDifference.final` is never read; nothing continues a partial difference. DEBUG uses limit 2. | U:3476-3480, 3506 |
| C6 | `resetChannels` has no retry; both catch branches are identical; the async path clears all records regardless of outcome. | U:3276-3281; M:750 |
| C7 | `fetchChatListHole` overwrites channel pts unconditionally; replay writes `synchronizedUntilMessageId` unconditionally. | `Holes.swift:1371-1377`; U:4935-4938 |
| C8 | `channelDifferenceTooLong` without dialog pts reports success with nothing applied. | U:3739-3741 |
| C9 | View polling leaves a sub-second "not updated" window each cycle in which a re-subscription re-adds a full hole for an unjoined channel. | `AccountViewTracker.swift:1901-1913, 2033-2056` |
| C10 | `getForumTopicsByID` for the same missing thread up to 3x per batch while the queue is held. Behaviour: no. | U:2137, 2896, 3643 |
| C11 | Chat-list bot-forum thread resolution never matches (looks in `.peers`, bots are in `.users`). **Fixed** in fea57d174a (2026-10-15). | U:2555-2719 |
| R4 | Scheduled/quick-reply add passes the whole batch per missing message (redundant rewrites). Behaviour: no. | U:4587, 4597 |
| R5 | Forum topic unread count can increment for an already-known message. | U:4383 |
| R6 | `updateStory` event is re-parsed without `existingItem`, so min stories lose views/reaction in story lists. **Fixed** in 544d6a252b (2026-10-15). | U:5548, 5587 |
| R7 | Previous-state hole upper bound is the batch max, so it covers the batch's own messages (one refetch on open). | U:4440-4448, 5755-5771 |
| R8 | `deleteEphemeralMessages` scans every stored message of the chat inside the replay transaction. Behaviour: no. | U:4002-4041 |
| D4 | `pollChannel` has its own 7-case interpreter for `other_updates` (covers every pts-carrying kind). | U:3558-3641 |

Also noted by verifiers (unverified server behaviour): `_internal_requestMessageHistoryThreads`
maps `SAVED_DIALOGS_UNSUPPORTED` to `.never()` (`ForumChannels.swift:775-777`), which would stall a
reset or a gap poll for a monoforum; `addAsyncResetChannels` replaces a pending reset only when the
new pts hint is lower (M:651-655), which looks inverted; `resolveMissingPeerChatInfos` never emits
`updateChannelState`, so a channel first learned that way keeps no `ChannelState` (the
precondition for G1).

## 10. Dead code (safe to delete unless marked)

Stage 1 (commits 6058f00925..7005701e8d) applied this section; each bullet below ends with its outcome. The three it left, unreachable after it (`ContactSyncManager.addIsContactUpdates` and `.updateIsContact`, `HoleFromPreviousState.validateChannelPts`, write-only, and the `let channelPts: Int32 = pts` aliases in `Sync/ChannelPolling.swift`), were deleted by the follow-up plan: `ef25ef7617`, `29cecdaf91`, `54a871c76e`.

- M:857-863 `if !"".isEmpty { ... }` then `flags = 0; ptsTotalLimit = nil`. Deleted in stage 1 (group ptsTotalLimit).
- M:217 `operationDisposable` (never assigned; `reset()` cancels nothing). Deleted in stage 1 (group operationDisposable).
- M:385-386, 449-487 max-message-id branch of the applied-values pipeline (returns `.complete()`). Deleted in stage 1 (group maxMessageId).
- M:173 `ChannelOperationsContext.associatedDifferenceId` (write-only). Deleted in stage 1 (group associatedDifferenceId).
- M:202 `transformOutgoingMessageMedia` (unused). Deleted in stage 1 (group transformOutgoingMessageMedia).
- `delayNotificatonsUntil` chain: replay, events, `Atomic`, `getDelayNotificatonsUntil()` (no callers). Partly deleted in stage 1 (group delay): the Impl's Atomic, its swap and the getter. Kept: `AccountFinalStateEvents.delayNotificatonsUntil` (and the replay field feeding it) is a term of `isEmpty` in AccountIntermediateState.swift; deleting it changes whether a processEvents operation is queued.
- `AccountFinalState.missingUpdatesFromChannels` and the clause at M:1083. Deleted in stage 1 (group missingUpdatesFromChannels).
- The `groups` payload of `collect(groups, 2.0)` (never read; the op itself must stay, it absorbs groups). Kept: the payload is left for stage 4's gapWait op.
- M:1428 `map` before `ignoreValues`; unused tuple elements in `standalonePollDifference`. The `map` was deleted in stage 1 (group standaloneReplayMap); the unused tuple elements are kept, left for stage 3's DifferenceOutcome.
- U:207-219 `associatedStoredStories` (always `[:]`). Deleted in stage 1 (group storedStories).
- U:4121, 4134-4137, 5795-5826 `clearHolesFromPreviousStateForChannelMessagesWithPts` and `validateChannelPts`. The clearing function was deleted in stage 1 (group holes); `validateChannelPts` was kept by stage 1 (write-only after group holes; removing it cascades into `setNeedsHoleFromPreviousState` and three call sites) and deleted, with its parameter and the three call sites, in `29cecdaf91`.
- U:4104, 5455-5456, 6072-6074 `syncAttachMenuBots` (consumer commented out since 2022). Deleted in stage 1 (group syncAttachMenuBots).
  **Keep** the `UpdateAttachMenuBots` op: it is an `AddMessages` batching barrier in `optimizedOperations`; only its replay effect `syncAttachMenuBots` was deleted. Kept.
- U:4369-4371, 4379-4381 `assert(true)` blocks (group assertTrue); U:5426-5432 `previousReactions` (group previousReactions); U:5524-5526 `let _ = pts` (group resetForumTopicPts). All deleted in stage 1.
- `ReadGroupFeedInbox` (group readGroupFeedInbox), `UpdateMessageForwardsCount` (group forwardsCount), `UpdateIsContact` (+ `addIsContactUpdates` chain; group isContact), `addDismissedWebView` (group dismissedWebView; never produced). Deleted in stage 1; `ContactSyncManager.addIsContactUpdates` and `.updateIsContact` were kept (outside state sync, unreachable since) and deleted in `ef25ef7617`.
- U:2899-2900 `missingPeers` (group missingPeers); U:3511-3516, 3657-3662 identical if/else (group identicalIfElse); commented-out loggers (group commentedLoggers). Deleted in stage 1.
- U:595, 598 re-sorting already-sorted pts/qts updates (group resort); duplicated loops at U:347-407 (group duplicatedLoops). Deleted in stage 1.
- `AccountInitialState.cloudReadStates` (group cloudReadStates), `AccountMutableState.referencedStoryIds` (group referencedStoryIds), `AccountReplayedFinalState.addedSecretMessageIds` (group addedSecretMessageIds) (write-only). Deleted in stage 1. `updatedMaxMessageId` (mutable state and events) is kept: a term of `isEmpty`.
- `State/ChannelState.swift` (unreferenced). Deleted in stage 1 (group channelStateFile).
- `if groups.count != 0` in `UpdateMessageService` (never empty). Deleted in stage 1 (group groupsCount).
- **Keep (public or persisted):** `pollStateUpdateCompletion`'s `[MessageId]`, `reactionNotifications`,
  `InvalidatedChannel.pts`. Kept.

## 11. Cost model (for the optimization task)

| Path | Round trips | Postbox transactions |
| --- | --- | --- |
| Pushed batch, no gap | 0 + one per resolve stage that needs data | 3 (snapshot, replay, notification read) |
| Pushed batch, common hole | + fixed 2 s + full getDifference | + getDifference's |
| Pushed batch, channel gap | + getChannelDifference per channel (parallel), queue held | + per-stage reads |
| getDifference, final | 1 + sequential resolve chain; async resets: 1 getPeerDialogs **per channel** | 3 + 1 (events); per reset channel +2, then 1 merged |
| differenceSlice chain | k getDifference, each with its own resolve chain | ~3 per slice |
| differenceTooLong | getDifference + getState + getDialogs + getPinnedDialogs | 1 very large |
| View poll (empty) | 1 getChannelDifference every ~30 s per open channel | 3 including a replay write |
| Remote read (users/groups) | + getHistory + getPeerDialogs validation (R3) | + validation's |

Levers already visible: hop off the MTContext queue for interpretation; re-check holes instead
of the fixed 2 s + getDifference (protocol suggests ~0.5 s); batch async channel resets into one
getPeerDialogs; run independent resolve stages in parallel and de-duplicate forum topic fetches;
stop discarding resolved data (C2, C3); skip the replay for empty channel differences; compare
`ResetIncomingReadState` against the batch's final pts (R3); avoid the second Postbox transaction
in `processEvents`; `pts_total_limit` is sent from app config (`pts_total_limit`, default 10000; LIM); tune it with the State log's per-chain lines (LOG).
