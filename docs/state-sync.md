# Account state sync (TelegramCore)

State sync is how an account's local Postbox keeps up with the server. Four mechanisms feed it: pushed updates
(`Api.Updates` from the network, or returned as an RPC result), `updates.getDifference` (the poll), channel recovery
(`updates.getChannelDifference`, `messages.getPeerDialogs`) and the account reset that follows
`updates.differenceTooLong`. `AccountStateManager` runs pushes, the poll, the account reset and the replays of view
polls as a queue of operations (`StateOperationQueue`) on one SwiftSignalKit queue; the asynchronous channel resets
(`ChannelResetCoordinator`) request and replay beside it, outside the queue (the audit's C1). Updates are interpreted
into an operation log (`AccountMutableState`) that is replayed in one Postbox transaction
(`FinalStateReplayer.applyReplay`). The notification extension runs the same code through two standalone calls that
never touch the operation queue. Paths are relative to `submodules/TelegramCore/` unless they start elsewhere.

`docs/state-sync-audit-2026-10.md` is a dated record of this code before the refactor (stages 0-5 and a stage of fixes):
use it for its issue ids (G*, Q*, C*, R*, D*) and their reasoning, not for names or `file:line` references. This map
describes the code as it is and is kept current: a change to state sync updates it in the same commit. The audit's names
map as follows. Operations: `pollDifference` -> `fetchDifference`; `collectUpdateGroups(groups, 0)` -> `batchUpdates`;
`collectUpdateGroups(groups, 2.0)` -> the payload-less `gapWait`; `processUpdateGroups` -> `processBatch`;
`pollCompletion` -> `stateBarrier`; `processEvents` -> `dispatchEvents`; `replayAsynchronouslyBuiltFinalState` ->
`replayPrebuilt`. The poll is `runFetchDifference` + `Impl.fetchAndApplyDifference(policy:)` + `applyDifferenceAnswer`,
its outcome tuple is `DifferenceOutcome`. The replay's `verifyTransaction`/`skipVerification`/`ignoreDate` are
`ReplayRejection.verify` and `ReplayPolicy`; `optimizedOperations` is `batchContentAndDeferStateOperations` +
`StateAdvance`; the pre-pass is `ReplayPrepass.prepare`, the post-loop work `ReplayContext.finalize`.
`AccountStateManagementUtils.swift` (the audit's "U"), `State/ChannelState.swift` and
`AccountFinalState.missingUpdatesFromChannels` no longer exist. The follow-up and stage plans reuse letters such as
C1-C9 and D1-D5 as TASK ids (`followups.md` cites them as "follow-up plan C1"), and the code's "owner decision D1" to D4
are the follow-up plan's owner decisions; those are not the audit's issue ids. The fixes plan's ids (C2, C3, C11, ...)
are the audit's.

## File layout

`Sources/State/` (state sync's files only):

- `AccountStateManager.swift`: the public `AccountStateManager` and its `Impl` (ingress, queue helpers,
  `startFirstOperation`, `finishPollCycle`, `fetchAndApplyDifference(policy:)`, `standalonePollDifference`),
  `defaultGapWaitTimeout`, `consecutiveResetDelay`, `messagesForNotification(...)`; `AccountStateManager+<Kind>.swift`
  (8 files): one runner per operation kind.
- `AccountStateEventHub.swift` (where events leave), `ChannelResetCoordinator.swift`, `UpdateMessageService.swift` (the
  network's update sink), `UpdateGroup.swift`, `DifferenceChainLog.swift`, `PtsTotalLimit.swift`,
  `StateSyncDebugSettings.swift`.
- The reset and confirm-before-delete: `ResetState.swift`, `FetchChatList.swift`, `StoredMessageConfirmation.swift`,
  `StoredMessageConfirmationDeletionReporters.swift`, `HistoryFillReconciliation.swift` (`FetchedAnswerAge`).
- Holes, fills, view polls: `Holes.swift`, `ManagedMessageHistoryHoles.swift`, `HistoryFillRequestRetry.swift`,
  `AroundHoleFillRange.swift`, `ForumThreadResolutionGuard.swift`, `ForumFillStoreFirst.swift`,
  `PendingMessageReferences.swift` (messages waiting for a late reference), `HistoryViewStateValidation.swift`,
  `AccountViewTracker.swift`; secret chats: `ProcessSecretChatIncoming{Encrypted,Decrypted}Operations.swift`.
- Read state: `SynchronizePeerReadState.swift` (validation and push), `NonMemberChannelReadState.swift` (no read
  state for a channel the account is not a member of; invariant 30).
- Elsewhere: `Account/AccountIntermediateState.swift` (`AccountMutableState`, `AccountStateMutationOperation`,
  `AccountFinalState`, `AccountReplayedFinalState`, `AccountFinalStateEvents`), `Account/Account.swift`,
  `SyncCore/SyncCore_AuthorizedAccountState.swift` (`AuthorizedAccountState`: the stored pts, qts, date, seq and
  `invalidatedChannels`), `SyncCore/SyncCore_ChannelState.swift`.

`Sources/State/Sync/`:

- `StateOperationQueue.swift` (a value type with no reference to the manager), `DifferenceOutcome.swift`,
  `DifferencePolicy.swift`.
- Interpretation: `UpdateInterpreter.swift` + 11 `UpdateInterpreter+<Family>.swift`, `SyncSequencing.swift`,
  `SyncSnapshot.swift`, `SyncDifference.swift`, `SyncChannelRecovery.swift`, `SyncResolve.swift`,
  `ChannelPolling.swift`.
- The replay: `FinalStateReplayer.swift`, `StateReplayPolicy.swift`, `StateReplayVerification.swift`,
  `StateReplayPrepass.swift`, `StateReplay.swift`, `StateReplayBatching.swift`, `StateReplay+StateAdvance.swift`,
  `StateReplay+Finalize.swift`, 11 `StateReplay+<Family>.swift`, `StoreMessage+Updating.swift`.

`Tests/StateSync/` (in `//submodules/TelegramCore:TelegramCoreTests`):

- Harness: `StateSyncTestCase`, `StateSyncFixture`, `ScriptedServer`, `StateSyncApi`, `UnusedEncryptionProvider`,
  `AccountFinalStateEvents+Testing`; tested by `ScriptedNetworkTests`, `StateSyncFixtureTests`.
- One type or function: `StateOperationQueueTests`, `SequenceSpanTests`, `ReplayRejectionTests`, `ReplayPrepassTests`,
  `ReplayBatchingTests`, `StoreMessageUpdatingTests`, `AccountFinalStateFollowUpTests`,
  `AccountFinalStateEventsUnionTests`, `ChannelRecoveryRequestsTests`, `ChannelResetCoordinatorTests`,
  `AccountStateEventHubTests`, `BranchMergeTests`, `HolesFromPreviousStateTests`, `FinalStateReplayerTests`,
  `NonMemberChannelReplayTests`,
  `StoredMessageConfirmationTests`, `ConfirmationChannelDeletionTests`, `DeliverOnOrderingCharacterizationTests`
  (SwiftSignalKit's `deliverOn` on two bare queues, no manager).
- A real manager end to end: `DifferenceCharacterizationTests`, `NotificationExtensionPollCharacterizationTests`,
  `PushCharacterizationTests`, `PushOrderingPinTests`, `SeqContainerEdgeTests`, `BranchMergePushTests`,
  `EventDeliveryOrderTests`, `StateBarrierCharacterizationTests`, `PollResultLossCharacterizationTests`,
  `ChannelSyncCharacterizationTests`, `ChannelPollSiteTests`, `PinnedForumTopicsPeerTests`, `EditForumTopicTests`,
  `NotificationExtensionPollOutcomeTests`, `PtsTotalLimit*Tests`, `Reset*Tests`, `ArchivedDialogGhostTailTests`,
  `ChatListRecentDeletionTests`, `RecentEditTests`, `ConfirmationDeletionEventTests`, `StoryUpdateEventTests`,
  `WidgetDataUpdateTests`.
- Holes and fills: `ChatListHoleFillTests`, `ChatListForumThreadsTests`, `HistoryFill*Tests`, `ForumHistoryFillTests`,
  `MonoforumHistoryFillTests`, `PreloadFillConfirmationTests`, `ManagedHistoryHoles*Tests`; outside the directory,
  `Tests/AroundHoleFillRangeTests`, `ForumThreadResolutionGuardTests`, `WebpageUpdateEventsTests`.
- The truth server (`TruthServer/`, below): `TruthRequest`, `TruthWorld`, `TruthAnswers`, `TruthSession`; tested by
  `TruthRequestTests`, `TruthWorldTests`; sessions in `TruthSessionTests`.

## Ingress and the operation queue

### The shell

`AccountStateManager` is a public final class; its state lives in the nested `final class Impl`, held in
`QueueLocalObject<Impl>` on `Queue(name: "AccountStateManager")`. Every outer accessor that reaches Impl forwards
through `impl.with` (`queue.async`) or `impl.signalWith` (`runOn(queue)`), so Impl is always entered on its queue;
`synchronouslyIsMessageDeletedInteractively/Remotely` and the confirmation-deletion report use the lock-guarded
`messagesRemovedContext` directly, and `extractIncomingCallUpdate` is static. `Account.swift` builds it twice: in the
`Account` init and in `standaloneStateManager(...)` for the app extensions (the notification service and the share
extension; no call session manager, `shouldKeepOnlinePresence` `.single(false)`). Neither passes `gapWaitTimeout`, so
both wait `AccountStateManager.defaultGapWaitTimeout` (2.0 s); the harness passes `StateSyncFixture.gapWaitTimeout`
(0.05). The outer init registers with `StoredMessageConfirmationDeletionReporters.shared` under `postbox.mediaBox`, so
confirm-before-delete deletions are recorded in `messagesRemovedContext` inside the confirming transaction and reach the
hub's deletion pipe after commit (`notifyConfirmedDeletions`, not the app-side `notifyDeletedMessages`;
`ConfirmationDeletionEventTests`).

### Ingress points

- `reset()` (hops to the queue): the first call creates `UpdateMessageService` and registers it as the network's update
  sink, its pipe feeding `addUpdateGroups`; every call then does `replaceOperations(with: .fetchDifference(...))`,
  `startFirstOperation()` and re-installs the qts acknowledgement. Its only caller in Sources is
  `Account.resetStateManagement()`.
- `addUpdates(_:)` hops and calls `updateService?.addUpdates`: before the first `reset()` the service is nil and the
  updates are dropped (Q8, `testAddUpdatesBeforeResetIsDropped`). An RPC result takes this path. A push from the network
  does not: the engine calls the sink's `networkSessionDidReceive(message:)`, which calls
  `UpdateMessageService.addUpdates` directly, on the thread that delivers the push, without this hop (the pipe's
  subscriber hops in `addUpdateGroups`); before the first `reset()` no sink is registered, so no push reaches the
  manager. `UpdateMessageService.addUpdates` builds groups with `groupUpdates`, `[.reset]` for `updatesTooLong` and
  `[.updatePts(...)]` for `updateShortSentMessage`, which a manager made with `ignoresShortSentMessages` drops (a
  supplementary account's, such as the share extension's, and `standaloneStateManager`'s; master `e6d99316c6`,
  `ShortSentMessageTests`); the sink's `networkSessionDidReset()` puts `[.reset]` itself; each
  goes synchronously onto its `ValuePipe`. Outside tests about 150 lines call `addUpdates`
  (`grep -rn '[sS]tateManager[!?]*\.addUpdates(' submodules --include='*.swift' | grep -v /Tests/ | wc -l`) and about
  20 outside `AccountStateManager.swift` call `addUpdateGroups(` directly
  (`grep -rn 'addUpdateGroups(' submodules --include='*.swift' | grep -v /Tests/ | grep -v AccountStateManager.swift`).
- `addUpdateGroups(_:)`: `operations.absorbUpdateGroups(groups)`, then `startFirstOperation()`; if not absorbed,
  `addOperation(.batchUpdates(groups), position: .last)`.
- `UpdateGroup` (`UpdateGroup.swift`) has eight cases: `withPts`, `withQts`, `withSeq` and `withDate` (what
  `groupUpdates` makes of a pushed container), `reset`, `updatePts`, `updateChannelPts` and `ensurePeerHasLocalState`.
  The direct `addUpdateGroups(` callers (the second grep above) pass `.updatePts` with the pts an RPC result carries
  (`messages.affectedMessages`, `affectedHistory`, `affectedFoundMessages`), or `.updateChannelPts` after
  `channels.deleteMessages`, except two: `applyUpdateMessage` and `applyUpdateGroupMessages`
  (`ApplyUpdateMessage.swift`) pass `.ensurePeerHasLocalState(id:)` for the sent message's chat right after
  `addUpdates(result)`. That case only adds the chat to the snapshot's peers requiring local chat state
  (`SyncSnapshot.swift`), not to the peers it loads (`peerIdsFromUpdateGroups` skips it), so
  `resolveMissingPeerChatInfos` can fetch a missing chat info only when another group of the same batch carries the
  chat; otherwise the batch is discarded (G5).
- `addReplayAsynchronouslyBuiltFinalState(_:)` (view polls): adds `.replayPrebuilt(finalState, completion)` at `.last`;
  the completion puts `true` whatever the replay returned.
- `addCustomOperation(_:)`: adds `.custom` at `.last`. Disposing the returned signal disposes only its forwarding pipe:
  the operation is neither cancelled nor removed. Callers: `SynchronizePeerReadState.swift` (two) and the harness's
  `drainOperationQueue`.
- `pollStateUpdateCompletion()`: `addPollCompletion` joins the first queued `stateBarrier` or adds one at `.last`;
  disposing removes only the subscriber.
- No operation: `standalonePollDifference`, `standaloneReplayAsynchronouslyBuiltFinalState` (the extension's),
  `processIncomingCallUpdate` (hands an `updatePhoneCall` to the call session manager),
  `removePossiblyDeliveredMessages(uniqueIds:)` (merges into `removePossiblyDeliveredMessagesUniqueIds`, which nothing
  shrinks; each replay gets a copy taken on the queue, the coordinator's gets `[:]`) and the hub-only methods
  (`notifyDeletedMessages`, `modify...`, `inject...`, `forceSend...`, `commitSendPendingPaidMessage`, ...).

### Kinds and placement (`Sync/StateOperationQueue.swift`, one test per rule in `StateOperationQueueTests`)

`enum StateOperation` has eight cases: `fetchDifference(Int32, AccountFinalStateEvents)`, `batchUpdates([UpdateGroup])`,
`gapWait`, `processBatch([UpdateGroup])`, `custom(Int32, Signal<Void, NoError>)`,
`stateBarrier(Int32, [MessageId], [(Int32, ([MessageId]) -> Void)])`, `dispatchEvents(Int32, AccountFinalStateEvents)`,
`replayPrebuilt(AccountFinalState, () -> Void)`. An entry is `Entry { isRunning, content }`.

- `startHead()` marks the head running and returns it, or nil when the queue is empty or the head runs. Its only caller
  is `Impl.startFirstOperation()`, the one place an operation starts (`grep -rn 'startHead()' Sources`).
- `add(_:at:)`: `.first` inserts at index 0 and returns true when the queue is empty or the head is not running, else
  inserts at index 1 behind the running head and returns false; `.last` appends and returns whether the queue was empty.
  `Impl.addOperation` asserts `queue.isCurrent()` and starts the head when `add` returns true.
- `absorbUpdateGroups(_:)`: a trailing `batchUpdates` (running or not) takes the groups; a trailing `gapWait` takes and
  drops them (returns true, stores nothing); any other last kind or an empty queue returns false.
- `replace(with:nextId:)` (`replaceOperations`): running entries first, then queued `processBatch`es, the new content,
  ONE `stateBarrier` under a fresh id carrying every queued barrier's ids and subscribers (only if there is one of
  either), the queued `replayPrebuilt`s, `dispatchEvents` and `custom`s. Queued `fetchDifference`, `batchUpdates`
  (groups included) and `gapWait` are dropped. It starts nothing; every caller then calls `startFirstOperation()`.
- `insertEvents(id:events:)` puts a `dispatchEvents` before the first entry that is neither running nor a
  `dispatchEvents` (ahead of queued polls, batches and barriers), or at the end. `Impl.insertDispatchEvents` skips empty
  events (`AccountFinalStateEvents.isEmpty`).
- Barriers: `barrierStepsAside()` removes the head with no kind check when more than one entry is queued;
  `postponeStateBarrier` re-adds it at `.last` under a new id; `addBarrierSubscriber` joins the first barrier;
  `removeBarrierSubscriber` removes the subscriber everywhere; `addIncomingMessageIdsToBarriers` appends a delivery's
  incoming ids and asserts at most one barrier exists.
- Completion: every `pop<Kind>` calls `removeFirst()` and then checks the kind (and the id for `popCustom(id:)`,
  `popDispatchEvents(id:)`; `popStateBarrier(id:)` only asserts it). All but `popFetchDifference()` call
  `assertionFailure()` on a mismatch; the caller then acts on nothing and starts nothing, though the head is gone; the
  exception is `runReplayPrebuilt`, which still calls `completion()` (and `removeFinishedPoll` has zeroed
  `consecutiveResetCount` either way).
- The `operations` accessor (get and set), `addOperation` and `addPollCompletion` `assert(self.queue.isCurrent())`.

Who places what (check with
`grep -n 'addOperation(\|replaceOperations(with:\|insertDispatchEvents(' Sources/State/AccountStateManager*.swift`):
`.first` only for `processBatch` (the `batchUpdates` timer) and `fetchDifference` (slice continuation, reset follow-up);
`.last` for `batchUpdates`, `gapWait`, `custom`, `replayPrebuilt`, `stateBarrier`; any other `fetchDifference` through
`replaceOperations` (`reset()`, the gap-wait timer, `runProcessBatch`'s poll follow-ups, the restart arm);
`dispatchEvents` only through `insertDispatchEvents` (`finishPollCycle`, the restart arm, `runProcessBatch`,
`runReplayPrebuilt`).

### The runners

Six runners invalidate `operationTimer` on entry; `runStateBarrier` only on its `help.test` branch, `runReplayPrebuilt`
never (`grep -n operationTimer Sources/State/AccountStateManager+*.swift`).

- `runFetchDifference(currentEvents:)`: one getDifference attempt; see "The poll path".
- `runBatchUpdates()`: a 0 s `Timer`; when it fires, `popBatchUpdates()` returns every group absorbed meanwhile and
  `addOperation(.processBatch(groups), .first)` runs them.
- `runGapWait()`: a `gapWaitTimeout` `Timer`, then `popGapWait()`, the log line "timeout while waiting for updates",
  `replaceOperations(with: .fetchDifference(...))`. The gap is never re-checked.
- `runProcessBatch(groups:)`: see "The push path".
- `runCustom`: runs the signal; on its end `popCustom(id:)` and the next operation.
- `runDispatchEvents`: `eventHub.dispatch(events, completed:)`; the completion pops, calls
  `eventHub.dispatchAfterNotificationMessages(events)`, sets `appliedQtsPromise` from `events.updatedQts`, adds the
  incoming ids to the barrier and starts the next operation.
- `runStateBarrier`: steps aside to the end while anything else is queued; alone, it sends `help.test` and, on its
  completion or error, pops itself and calls its subscribers if the queue is then empty, else postpones itself again.
- `runReplayPrebuilt`: stores pre-cached resources, replays `.verified`, pops, queues non-empty events, starts the next
  operation, and calls `completion()` whether or not the pop matched.

### `isUpdating` and the poll cycle

`isUpdating` is the signal of a private `ValuePromise<Bool>(true)` (`isUpdatingValue`), which `currentIsUpdatingValue`'s
`didSet` sets only on a change. It becomes true only in `runFetchDifference` and false only in
`Impl.finishPollCycle(events:)` (`grep -rn 'currentIsUpdatingValue = ' Sources`; the property is internal, so the single
false writer is a convention). `finishPollCycle` is called by the final-difference and AUTH_KEY_DUPLICATED arms and by
`channelResetsEnded`. It offers the events to `channelResetCoordinator.endDifferenceChain(events:)`; with no pending
reset context it then does, in order, `insertDispatchEvents(events)`, `currentIsUpdatingValue = false`,
`eventHub.notifySignificantStateUpdateCompleted()`; the caller starts the queue. It never looks at the queue's head.

A poll cycle spans every chain from the first `fetchDifference` until `finishPollCycle` finds no pending context. Slices
and reset follow-ups continue a chain; the restart arm starts a new chain in the same cycle; a pending reset context
takes the events (`endDifferenceChain` returns true) and keeps `isUpdating` true until the coordinator drops it and
calls `cycleEnded` -> `channelResetsEnded`, which calls `finishPollCycle` again and starts the queue when
`startsFirstOperation` is true (after an asynchronous replay; Q12, fixed). `significantStateUpdateCompleted` fires only
there, once per ended cycle. `isUpdating`'s consumers: `AccountTaskManager` starts the managed tasks at the first false;
`ContactSyncManager` (`.waitForUpdatedState`) and `ManagedSynchronizeInstalledStickerPacksOperations.swift` wait for
false; `Account`'s `networkStateSignal` reports `.updating` instead of `.online` while it is true.
`significantStateUpdateCompleted`'s only consumer is `ContactSyncManager`, which refreshes contact presences on it at
most every 2 minutes. The harness pins boundaries through `isUpdating.values`: `[true, false]` for a launch with slices
or a reset, `[true, false, true, false]` for a push followed by a forced or gap-wait poll, `[true]` while a channel
reset is pending.

### Queue semantics the order depends on

`Queue.async` runs inline when `isCurrent()` (a `DispatchSpecificKey` set by `Queue(name:qos:)`), else dispatches;
`deliverOn(queue)` is a `queue.async` per event; `runOn` starts inline when current; `Timer.start` schedules a
`DispatchSource`, so even a 0 s timer fires in a later block. Consequences:

- A slice continuation and a reset follow-up are queued with a direct `addOperation(.fetchDifference, .first)` in the
  block that pops the finished poll, so they start before groups whose ingress block is already waiting on the queue.
- Groups pushed from a callback on the manager queue join the operation queue before the callback returns
  (`UpdateMessageService` -> `addUpdateGroups`, inline); the harness does this with `ScriptedServer.pushInline`.
- Events queued before a `replaceOperations` land behind the new poll, the merged barrier and the queued
  `replayPrebuilt`s, and a later `insertEvents` lands ahead of those: with a barrier or a prebuilt replay queued, a
  forced poll's newer events are delivered before the forcing batch's older ones (Q4-order under Open issues, left by
  the audit's Q4 fix; open; the barrier case pinned by
  `testForcedPollEventsOvertakeTheBatchEventsWhenABarrierIsQueued`).

## The push path

### Interpretation and sequencing

`runProcessBatch(groups:)` snapshots in one transaction (`initialStateWithUpdateGroups`), then
`finalStateWithUpdateGroups(..., asyncResetChannels: nil)` checks the common-box sequences. `SequenceSpan` is one rule
for pts, qts and seq: `classify(local:afterHole:)` is `.alreadyApplied` when `local >= end`, `.apply` when not after a
hole and `local == end - count`, else `.gap`. A pts update is `(pts, pts_count)`; a qts update `(qts, 1)`
(`apiUpdateQtsRange` matches only `updateNewEncryptedMessage`; `apiUpdatePtsRange` includes `updateMessageWidgetData`,
a message widget's state edit, which before 2026-10-26 was unsequenced and opened a pts gap on every push); an `updates`
container `(seq, 1)`; `updatesCombined`
`init(seqStart:seq:)`, count `seq - seqStart + 1` (`SequenceSpanTests`). Order: pts updates sorted by end (an
`.updatePts` group is a span without an update), qts updates sorted by end, seq groups sorted by end. An applied span
merges its chats and users, collects its updates and advances its own component (a seq group also takes its date); the
first gap of a kind logs "update pts hole" (qts, seq likewise) and every later unapplied span of that kind is a gap. An
already-applied pts span still collects an `updateWebPage`. Date groups follow, sorted by date; `updatesDate` is the
earliest one's date. Each `.updateChannelPts` group becomes a synthetic empty `updateDeleteChannelMessages`.
`shouldPoll` is set by a `.reset` group, `missingUpdates` by any deferred span; deferred spans are not kept anywhere.

`finalStateWithUpdates` reaches `finalStateWithUpdatesAndServerTime` through `network.currentGlobalTime |> take(1)`. It
builds one `UpdateInterpreter`, calls `apply(_:)` for each update in `sortedUpdates(updates)` order (per-channel updates
first, grouped by channel in dictionary order and sorted by pts; then the rest in the order `finalStateWithUpdates` was
given them: for a pushed batch the sequencing order, pts spans by end, qts by end, seq groups by end, date groups by
date; for a difference its `other_updates` order) and hands `updatedState` and `channelRecovery` to
`finalStateWithChannelRecovery`. `UpdateInterpreter` is a struct with no signal or queue. Its `state` is the state it is
handed: on the push path the snapshot with the sequencing's chats, users and state advances applied, on the difference
path with the difference's state, chats, users and messages added. Its channel states are still the snapshot's, which is
all `updateChannelTooLong` reads from it. `UpdateInterpreter.init` requests a hint-less poll for every
`channelsToPollExplicitely`. `apply(_:)` has 115 compiled case labels (117 in the source, two parked; one covers two
constructors) and `default: break`; each
calls one method in a family: Bots 5, Calls 7, Channels 8, ChatList 9, Messages 23, Payments 11, Peers 18, ReadStates
12, Settings 14, Stories 4, Typing 4 (`grep -c 'mutating func apply' Sources/State/Sync/UpdateInterpreter+*`, which
also counts `applyAgentSettings` and `applyReadFeed`: those two and their labels are parked with the agent and feed
APIs, `submodules/TelegramApi/CLAUDE.md`, "Parked APIs"). Typing is kept only when `updatesDate != nil` and
`updatesDate + 60 > serverTime`; a difference passes nil. `updateEditForumTopic` (no pts) edits a stored topic's info
through `.EditForumTopic`, which the replay applies as it applies a `messageActionTopicEdit` service message
(`applyEditForumTopic`, `EditForumTopicTests`); a topic with no stored info keeps none.

The result is an `AccountMutableState`: an ordered `operations` log of `AccountStateMutationOperation` (89 cases) plus
side tables (`peers`, `channelStates`, `storedMessages`, `namespacesWithHolesFromPreviousState`, `displayAlerts`,
`preCachedResources`, ...). Every helper that records an operation goes through `addOperation`, whose switch (no
default) updates the derived tables first (`mergeChats` also writes `apiChats` itself); eight helpers write their side
table directly and append nothing (`addPreCachedResource`, `addPreCachedStory`, `addExternallyUpdatedPeerId`,
`addDisplayAlert`, `addDismissWebView`, `addJoinChatWebViewDecision`, `addSentScheduledMessageIds`,
`setNeedsHoleFromPreviousState`), so batching and `ReplayRejection` never see them and `merge(_:)` copies their tables
on lines of its own; `updateState` records `updatedQts` only when qts differs from the initial state's.

`finalStateWithChannelRecovery` recovers channels ("Channels"), runs `resolveForumThreads` ->
`resolveAssociatedMessages` -> `resolveAssociatedStories` -> `resolveMissingPeerChatInfos` in order, and returns an
`AccountFinalState` with `shouldPoll: shouldPoll || hadError || resolveError`, `incomplete: missingUpdates`,
`discard: resolveError`. `followUp` is `.discard` if `discard`, else `.applyThenPoll` if `shouldPoll`, else
`.applyThenAwaitGap` if `incomplete`, else `.apply` (`testFollowUpForEveryFlagCombination`); only `runProcessBatch`
reads it (`grep -rn '\.followUp' Sources`).

### The batch's follow-up and the gap wait

`runProcessBatch` stores the pre-cached resources unless `.discard`, copies `removePossiblyDeliveredMessagesUniqueIds`
on the queue and replays `.verified` in one transaction (nil for `.discard`). Back on the queue, after
`popProcessBatch()`, a replayed state's non-empty events are queued whatever follows (Q4, fixed;
`testResetInBatchCommitsAndDeliversEvents`); then `(.apply, replayed)` does nothing, `(.applyThenAwaitGap, replayed)`
adds `.gapWait` at `.last`, and `(.applyThenPoll, _)`, `(.discard, _)`, `(_, not replayed)` replace the queue with a
`fetchDifference`. A hole thus costs `gapWaitTimeout` and then always one getDifference chain
(`testCommonPtsHoleAppliesPrefixThenPollsAfterGapWait`). Every group pushed meanwhile is lost to the wait: dropped by
`absorbUpdateGroups` while the `gapWait` is last, or queued as a `batchUpdates` behind it that the timer's replace drops
(Q5, open; `testGroupsArrivingDuringGapWaitAreDropped`).

### The replay

`FinalStateReplayer` (no reference to the manager or the network) is the only caller of `replayFinalState`; it logs
"replayFinalState took ...s" above 1 s and records the deleted ids in `messagesRemovedContext`. `Impl.replayer` builds a
new value per read. `applyReplay` has five call sites
(`grep -rn 'applyReplay(' Sources | grep -v '///' | grep -v 'func applyReplay'`): `runProcessBatch`,
`runReplayPrebuilt`, `standaloneReplayAsynchronouslyBuiltFinalState` (all `.verified`), `applyDifferenceAnswer`
(`policy.replayPolicy`) and `ChannelResetCoordinator` (`.unverifiedChannelReset`).
`ReplayPolicy.verifiesTransaction` is true for `.verified` and `.verifiedKeepingStoredDate`; `keepsStoredDate` only for
the latter. `replayFinalState` runs, in order:

1. `ReplayRejection.verify` (verifying policies only): missing snapshot peers (`.missingPeers`, checked before any
   stored state is read); then, if the log has an `.UpdateState`, the stored account state must equal the snapshot's;
   then each channel moved by `.UpdateChannelState` must have the snapshot's stored pts (`channelStateMatches`: equal,
   or neither has a state). `accountStateChanged` wins over `channelStateChanged`, yet every channel is checked and
   logged. A rejection logs "failed to verify final state" and returns nil before any write; callers see only nil.
2. `ReplayPrepass.prepare`: stores `preCachedStories`; computes each previous-state hole start
   (`synchronizedUntilMessageId + 1` for a cloud namespace with a `ChannelState`, else stored top + 1, else 1); scans
   the unbatched log for `.AddMessages` at `.UpperHistoryBlock` (incoming ids, author activity, conference invitations,
   was-scheduled ids); takes the cloud read maxima from `cloudReadInboxMarks`, which leaves out the operations step 5
   skips, judging each channel by the batch's final peers, then the stored ones (so it disagrees with step 5 when the
   batch changes that channel's membership after the operation; only forum-topic counting reads it); keeps only
   incoming and was-scheduled ids that `filterStoredMessageIds` says are not stored yet; then
   `applyWalletTransferMessageIds`.
3. `ReplayContext` (a `final class`, 61 stored properties: inputs, prepass values, accumulators). A class because
   `applyDeleteMessages` passes `_internal_deleteMessages` an optional, hence escaping, thread-stats callback that
   writes an accumulator through `self`.
4. `batchContentAndDeferStateOperations`: adjacent `.AddMessages` at one location merge; scheduled and quick-reply adds
   accumulate; any of the other 82 content operations is a barrier that emits the pending batches in the fixed order
   AddMessages, AddScheduledMessages, AddQuickReplyMessages, then itself (so their relative order within a run is not
   kept). `.UpdateState`, `.UpdateChannelState`, `.UpdateChannelInvalidationPts` and
   `.UpdateChannelSynchronizedUntilMessage` end no batch and go into `StateAdvance`, last value per kind and channel
   (`ReplayBatchingTests`).
5. `applyContentOperations`: 89 labels, no default. `walletTonConnectEvents(operation:)` runs first for each operation;
   then a read-state operation for a stored non-member channel (not a monoforum) is skipped (invariant 30);
   `.UpdateAttachMenuBots` and `.UpdateWalletTonConnectEvent` do nothing; the four state labels are unreachable; the
   other 83 call one family method: Messages 19, Settings 11, Payments 9, ReadStates 8, Calls 7, Peers 7, ChatList 6,
   Threads 6, Stories 4, SecretChats 3, Typing 3.
6. `applyStateAdvance`, after all content: the account state (`applyUpdateState` force-casts the stored state and keeps
   the stored date under `keepsStoredDate`), then every channel pts, every `invalidatedPts`, every
   `synchronizedUntilMessageId`. Channel writes create a missing `ChannelState` (pts 0 for the last two) and overwrite
   unconditionally.
7. `finalize()`, 24 steps in order: `addHolesFromPreviousState`, `applyForumTopicListResets`,
   `applyMessageThreadStatsDifferences`, `applyPeerActivityTimestamps`, `applyStickerPackOperations`,
   `addRecentlyUsedStickers`, `applySlowModeTimeouts`, `applyRecentGifs`, `addRecentlyUsedGuestChatBots`,
   `invalidatePeerGroupStats`, `addSecretChatTypingActivities`, `processAddedSecretMessages`,
   `clearTypingOfSecretMessageAuthors`, `applyLangPackDifferences`, `applyUpdatedThemes`,
   `applyWebBrowserSettingsUpdates`, `applyUpdatedWallpapers`, `addSecretMessagesToIncomingIds`,
   `reconcileWalletTransferMessages`, `deletePossiblyDeliveredMessages`, `requestChatListFiltersSyncIfNeeded`,
   `synchronizeStoriesOfFeedPeers`, `applyStarsReactionsDefaultPrivacy`, `applyLiveTypingDraftUpdates`.
   `addHolesFromPreviousState` adds, for each prepass start, a hole up to one below the batch's highest
   `.UpperHistoryBlock` id in that peer and namespace (`Int32.max` when the batch stored none there), in `.everywhere`
   and, from 1, in `.tag(.pinned)`; it adds none when that bound is below the start (the batch's top there is at or
   below the start). `deletePossiblyDeliveredMessages` deletes for everyone each outgoing message that the final state
   confirmed (`updatedOutgoingUniqueMessageIds`) and whose unique id is in the caller's
   `removePossiblyDeliveredMessagesUniqueIds`. Fire-and-forget: `applyLangPackDifferences` and `applyUpdatedThemes`
   start account-manager transactions capturing copies (`[langPackDifferences = ...]`, `[updatedThemes = ...]`), never
   the context; decrypted secret media goes through `storeResourceData`; `applyDeleteMessagesWithGlobalIds` and
   `applyUpdateMinAvailableMessage` start `mediaBox.removeCachedResources`, and so, for secret-chat messages, do
   `applyDeleteMessages`, `applyUpdateSecretChat` and `processAddedSecretMessages` through `_internal_deleteMessages` or
   `_internal_clearHistory`.
8. `buildResult`: `AccountReplayedFinalState` (29 stored fields), built last inside the transaction because its wallet
   transfer updates read it; an `updateSentWalletTransaction` with an empty `msgHash` is dropped.

`StoreMessage(updating:attributes:tags:)` rebuilds a stored message with new attributes and tags; its 7 call sites are
all in the replay (`grep -rn 'StoreMessage(updating:' Sources` also hits one comment, in `StateReplay+Messages.swift`;
`StoreMessageUpdatingTests`).

### Secret chats and the qts acknowledgement

`updateEncryption` -> `.UpdateSecretChat`; `updateNewEncryptedMessage` -> `.AddSecretMessages`;
`updateEncryptedMessagesRead` -> `.ReadSecretOutbox`; `updateEncryptedChatTyping` -> `.AddPeerInputActivity`; a
difference's `new_encrypted_messages` -> one `.AddSecretMessages`. `applyAddSecretMessages` appends each message to the
`SecretIncomingEncrypted` operation log and records its chat in `peerIdsWithAddedSecretMessages`, decrypting nothing;
finalize step 12 (`processAddedSecretMessages`) goes through those chats and repeats the encrypted and decrypted passes
until the chat's keychain stops changing, and step 18 adds the decrypted ids to the incoming ids. The harness never
decrypts (`UnusedEncryptionProvider` traps). `reset()` installs the acknowledgement: `appliedQtsPromise` (set only by
`runDispatchEvents`) combined with `shouldKeepOnlinePresence`, nil and offline skipped, `distinctUntilChanged`, 0
skipped, then `messages.receivedQueue(maxQts:)`, errors swallowed (`testAppliedQtsIsAcknowledgedWithOneReceivedQueue`).

### Events

`AccountFinalStateEvents` has 36 stored fields (`testStoredFieldCountMatchesEveryInitAndUnion`); `init(state:)` takes 29
from `AccountReplayedFinalState` and 7 from the mutable state. `union(with:)` treats `other` as the later replay: lists
append, sets unite, flags OR, current-state values (balances, wallet, agent settings and auction state, web pages, typing) take the
later value, read maxima, `updatedMaxMessageId`, `updatedQts`, `delayNotificatonsUntil` the maximum
(`AccountFinalStateEventsUnionTests`). `isEmpty` decides whether a `dispatchEvents` is queued; `delayNotificatonsUntil`
and `updatedMaxMessageId` stay as its terms (`testOwnPresenceOnlyBatchStillQueuesProcessEvents`,
`testAnotherUsersPresenceOnlyBatchQueuesNoProcessEvents`).

`AccountStateEventHub` (built in `Impl.init`, no reference back) has 25 `ValuePipe`s (no replay), 3 replaying `Promise`s
(`termsOfServiceUpdate`, `appUpdateInfo`, `contactBirthdays`) and 6 subscriber contexts (`grep -c '= ValuePipe<'` and
`grep -c '= Promise<'` on the file). `dispatch(_:completed:)` (1) starts the transaction that reads the notification
messages; (2) before returning, in order: `reactionNotificationsPipe` (always; only reactions younger than 20 s),
`displayAlertsPipe`, `dismissBotWebViewsPipe`, `joinChatWebViewDecisionsPipe`, `externallyUpdatedPeerIdsPipe`,
`authorizationListUpdatesPipe`, `deletedMessagesPipe` (each only when non-empty), `updateConfigRequested`,
`isPremiumUpdated`; (3) on the queue, one `notificationMessagesPipe` value per dispatch (empty included: each incoming
id's `messagesForNotification`, then the was-scheduled messages as one entry), then `completed()`.
`dispatchAfterNotificationMessages(_:)` then delivers typing, web pages (a nil page included), balances, wallet updates, agent
settings, revenue and auction states, emoji game info (a Postbox write), calls, call signaling, group calls, stories, thread read
states, sent scheduled ids, delivery reports and conference invitations, in that order (`AccountStateEventHubTests` pins
only that web-page updates, nil removals included, arrive before the sent scheduled ids). The hub's subscription
generators and `modify...` methods hop with `queue.async`, which is always inline (their callers are already on the
queue).

## The poll path

### `DifferencePolicy`: app vs extension

`Impl.fetchAndApplyDifference(policy:)` is one attempt for both pollers: `runFetchDifference` (`.mainApp`) and
`standalonePollDifference` (`.notificationExtension`) are its two call sites. The table on `DifferencePolicy` says what
differs:

- Stored state: `.mainApp` reads in one transaction the `AuthorizedAccountState`, whether the app configuration has the
  key `ios_disable_parallel_channel_reset_v2` (presence disables parallel resets), `currentPtsTotalLimit`, and (unless
  disabled) the `invalidatedChannels` records of an earlier run (`validityMarker != currentValidityMarker`, peer
  stored); after `deliverOn(queue)` those records go to `addAsyncResetChannels` before the request is built.
  `.notificationExtension` waits on `postbox.stateView()` for an `AuthorizedAccountState`, `take(1)`, no hop.
- `pts_total_limit`: fixed for the app's attempt (`ptsTotalLimitBox`; retries resend it), read before every try in the
  extension. Each slice or follow-up poll is a new operation and reads everything again.
- `requestDate(storedDate:)`: stored date vs `Int32.max`; `replayPolicy`: `.verified` vs `.verifiedKeepingStoredDate`
  (`testStandalonePollSendsMaxDateAndKeepsStoredDate`).
- Channel resets: asynchronous in the app (a closure that hops with `queue.async` into `Impl.addAsyncResetChannels`)
  unless the key is set; inline in the extension (`asyncResetChannels: nil`).
- No inner state: the app sends `updates.getState` (plain `retryRequest`: AUTH_KEY_DUPLICATED is retried like any
  error), writes it with `changedState(...)` when a state is stored, and returns `.noInnerState`; the extension returns
  `.noInnerState` with no request.
- Events: dispatched by the app, dropped by the extension.

`requestDifference` sends `updates.getDifference` with the state's pts and qts, `requestDate`, no `pts_limit` or
`qts_limit`, and flags bit 0 exactly when a `pts_total_limit` is given. `retryingDifferenceRequest` turns 406
AUTH_KEY_DUPLICATED into a nil answer and retries every other error through `retryRequest` (0.2 s more per failure, 5 s
cap, no limit).

### Outcomes

`applyDifferenceAnswer` returns `.authKeyDuplicated` for nil and `.tooLong(replyPts:)` for `differenceTooLong`, writing
nothing. Otherwise it snapshots (`initialStateWithDifference`); if the snapshot's state differs from the request state
(pts, qts, date, seq) it logs "pollDifference initial state ... != current state ..." (old name kept in the log) and
returns `.stateChangedMeanwhile`. Else it builds `finalStateWithDifference`, hops with `deliverOn(queue)`, stores the
pre-cached resources and replays in one transaction under `policy.replayPolicy`: `.applied(_, isSlice:)` (true only for
`differenceSlice`), or `.replayRejected` when `verify` refuses. It does not read `followUp` (Q10). `DifferenceOutcome`
has six cases: `applied(_, isSlice:)`, `tooLong(replyPts:)`, `authKeyDuplicated`, `stateChangedMeanwhile`,
`replayRejected`, `noInnerState`.

`runFetchDifference` sets `currentIsUpdatingValue = true`, starts the attempt and handles the outcome in `handleResult`,
run by `queue.async` inside the `next` handler (no trailing `deliverOn`: Q13). Every outcome is handled and there is no
default: five arms, `.applied` split by `isSlice` and the restart arm shared by three outcomes. Every arm but `.tooLong`
starts with `removeFinishedPoll()` (`consecutiveResetCount = 0`, `popFetchDifference()`) and acts only if a poll was
popped; an arm that acts ends with `startFirstOperation()`:

- `.applied(_, isSlice: true)`: union the events; `addOperation(.fetchDifference(id, events), .first)`.
- `.applied(_, isSlice: false)`: union; `differenceChainLog?.logEnd(endPts:)`; `finishPollCycle(events:)`.
- `.authKeyDuplicated`: `logEnd(endPts: nil)`; `finishPollCycle(events: currentEvents)` (Q2, fixed;
  `testAuthKeyDuplicatedEndsTheCycle`).
- `.stateChangedMeanwhile`, `.replayRejected`, `.noInnerState` (the restart arm): `logEnd(endPts: nil)`;
  `insertDispatchEvents(currentEvents)` when non-empty; `replaceOperations(with: .fetchDifference(id, empty))` at once,
  no delay; the cycle goes on (`testStateChangedDuringGetDifferenceAppliesNothingAndPollsAgainFromTheNewState`,
  `testNoInnerStateBootstrapsWithGetState`). No harness test reaches `.replayRejected` on this path.
- `.tooLong(replyPts:)`: the reset, below.

### Slices and the difference's final state

A `differenceSlice` is replayed (its intermediate state stored) and the chain goes on with a new `fetchDifference` at
the head that reads that state; all slices' events are unioned and delivered once at the chain's end
(`testSliceChainContinuesFromIntermediateState`). `finalStateWithDifference` takes the state from `difference.state` or
`differenceSlice.intermediateState` (`differenceEmpty` keeps pts and qts, takes date and seq), merges chats and users,
adds every `new_message` as `.AddMessages` at `.UpperHistoryBlock` with no sequence check, adds `new_encrypted_messages`
as one `.AddSecretMessages`, and passes `other_updates` to `finalStateWithUpdates` with `shouldResetChannels: true` and
`updatesDate: nil`. Its snapshot goes through `initialStateWithPeerIds`, which force-unwraps the stored state (G9).

### `differenceTooLong` and the account reset

The `.tooLong` arm notes the reply pts in the chain log, increments `consecutiveResetCount` and runs
`_internal_resetAccountState(... pts: replyPts)`, wrapped in `delay` when `consecutiveResetDelay(count) > 0` and held in
`accountResetDisposable`. Only the reset's completion pops the poll and adds `.fetchDifference(id, currentEvents)` at
`.first`; until then the poll stays at the head, `isUpdating` stays true and the chain goes on (Q1, fixed).
`consecutiveResetDelay` is a `static var`: 0 for n <= 1, else `min(60, 2^min(n-2, 6))` s, so n = 2...9 waits 1, 2, 4, 8,
16, 32, 60, 60; any other outcome resets the count (`testConsecutiveResetDelayDefaultCurve`,
`testConsecutiveResetCountStartsOverAfterAPollWithoutReset`). `accountResetDisposable` is disposed only in
`Impl.deinit`; `reset()` leaves it because only its completion removes the running poll
(`testAResetWaitingOutItsBackoffDoesNotRunAfterItsManagerIsReleased`).

The reset (`ResetState.swift`) sends no `updates.getState`. `fetchChatList(location: .general, ...)` sends
`messages.getDialogs` (folder 0, limit 100, `retryRequest`) and `messages.getPinnedDialogs` (`retryRequestIfNotFrozen`)
in parallel, then one `messages.getDialogs` (limit 32) per referenced folder; then `resolveUnknownEmojiFiles` and
`resolveForumThreads(fetchedChatList:)`. `dialogsNotModified` completes the reset without writing: pts stays, so the
next getDifference meets differenceTooLong again, on the backoff
(`testDifferenceTooLongWithDialogsNotModifiedRetriesTheReset`).

The ghost tail is deleted inside the reset's transaction, without asking the server (spec section 3 point 3, as amended
2026-10-24). After the top messages and reply targets are stored, `storedCloudMessagesAboveTopMessages` reads, for each
fetched dialog, every stored Cloud id above the higher of its `top_message` and the highest Cloud id the fetched page
carries for it (0 when neither), in pages of `StoredMessageConfirmation.ghostTailPageLimit` (1000), for private chats,
basic groups and channels, and `deleteStoredMessagesAsReceivedDeletion` deletes every one as a received deletion (cached
media and deletion events included). A dialog's `top_message` is its chat's newest message when the server builds the
answer, so such a message was deleted during the gap or is newer than the answer. A newer one (the account's own reply,
sent while the reset was in flight) has a pts above the reply pts the reset installs, so the follow-up getDifference
delivers it again (`testResetDeletesAMessageNewerThanTheAnswerAndTheFollowUpDifferenceBringsItBack`). The chat-list hole
fill does not move pts, so it would lose such a message for good: it leaves the ghost tail alone
(`testChatListFillLeavesStoredMessagesAboveTheTopAlone`), and a chat beyond the reset's first page keeps its ghost tail
when its page is fetched later (`ResetGhostTailTests`, `ArchivedDialogGhostTailTests`,
`testResetGhostTailDeletionFiresTheReceivedDeletionEventsOnce`).

The writes are one transaction inside `withResolvedAssociatedMessages(..., resolveThreads: false)`. Answers older than
`FetchedAnswerAge.maximum` (the 300 s deletion record minus `min(30, lifetime/2)`: 270 s) write nothing and restart
the whole fetch after `FetchedAnswerAge.staleRestartDelay(n)` (1 s doubling to 60 s, no limit). Otherwise:
every non-secret chat with a row in the chat-list index table (`chatListGetAllPeerIds`: every chat whose history or
inclusion Postbox has recorded, listed or not; a stored peer with neither is skipped) is excluded and gets a Cloud hole
over `1...Int32.max-1` (forums and monoforums per thread too); the root and `group(1)` lists are emptied except secret
chats; peers are stored (`updatePeers`), and top messages (`.UpperHistoryBlock`) and reply targets (`.Random`) are
stored through `fetchedMessagesWithoutRecentDeletions`; the ghost tail is deleted; read states are reset; chat-list
holes are rebuilt; a channel's pts and `invalidatedPts` move only when its pts differs, `invalidatedPts` never lowered
(`testResetInvalidatesChannelsWhosePtsMoved`, `testResetNeverLowersAChannelsInvalidatedPts`); unread counters are
reindexed; finally the stored pts becomes the reply
pts with qts, date and seq kept, so the follow-up still fetches the gap's encrypted messages (G10, fixed;
`testDifferenceTooLongFollowUpFetchesTheGapsEncryptedMessage`). Emoji files and stories fetched on the way are stored in
their own transactions first.

### `pts_total_limit`, the Debug override, logs

`currentPtsTotalLimit(transaction:)`: in DEBUG builds `StateSyncDebugSettings.ptsTotalLimitOverride` first (>= 1: that
value; below 1: nil); else the app-configuration key `pts_total_limit` as a finite `Double`: absent or not a number ->
`defaultPtsTotalLimit` (10000); below 1 -> nil (no limit); at or above `Int32.max` -> `Int32.max`; else truncated. A
string value counts as absent. Both pollers read it (`PtsTotalLimitTests`, `PtsTotalLimitNotificationExtensionTests`,
`PtsTotalLimitDebugOverrideTests`). The override is stored under `PreferencesKeys.stateSyncDebugSettings` and written by
`updateStateSyncDebugSettings(engine:_:)`. `DifferenceChainLog` (app only) is created on a chain's first request:
`noteRequest(pts:)` per request, `noteTooLong(replyPts:)` per differenceTooLong (not a chain end), `logEnd(endPts:)`
once per chain; `logDifferenceAnswer` logs each app answer. The extension's own line here is "standalonePollDifference:
differenceTooLong, leaving the reset to the app".

### The notification extension

`standalonePollDifference()` queues nothing and never touches `isUpdating`: false after `.applied(_, isSlice: true)`,
true after every other outcome, the value and its completion delivered in one `queue.async` inside the last inner signal
(Q13). On differenceTooLong nothing is written and it reports done; `_internal_resetAccountState` is called only from
`runFetchDifference` and its own stale restart (Q3, fixed; `testDifferenceTooLongEndsThePollAndLeavesTheResetToTheApp`).
Without an inner state: true, no request (`testNoInnerStateReportsDoneWithoutARequest`). `NotificationService.swift`
polls a CloudChannel push with `standalonePollChannelOnce` and any other with `standalonePollDifference()` under
`restartIfError` (false -> restart, one per slice); both under `timeout(min(pollBudget, remainingBudget()))`,
`pollBudget = 15.0`, `remainingBudget()` = `max(0.5, startTimestamp + 25 - now)`.
`grep -rn '\.reset()\|addUpdates(\|addUpdateGroups(' Telegram/NotificationService` finds nothing.
`standaloneReplayAsynchronouslyBuiltFinalState` (only caller `standalonePollChannelOnce`) replays `.verified` outside
the queue and ignores the result.

## Channels

### Entry points

`pollChannel` is the only `updates.getChannelDifference` call site (`grep -rn 'getChannelDifference(' Sources`).

1. Push gap poll: `finalStateWithUpdateGroups` always calls `finalStateWithUpdates` with `shouldResetChannels: false`;
   `finalStateWithChannelRecovery` polls each channel on its own `updatedState.branch()`, all at once (`combineLatest`),
   merging back in array order; replayed `.verified` while `processBatch` holds the head.
2. View poll: `pollChannelOnce` via `keepPollingChannel`, replayed as a `replayPrebuilt` at `.last`.
3. Extension poll: `standalonePollChannelOnce`, replayed outside the queue.
4. Difference path (`shouldResetChannels: true`): every channel to recover, polls and gaps alike, is reset with
   `resetChannels`, never polled: inline when `asyncResetChannels` is nil (extension, or the app with the key), one
   `resetChannels` call and one `messages.getPeerDialogs` for all, whose state REPLACES the batch's
   (`assert(states.count == 1)`); otherwise through `ChannelResetCoordinator`, called whenever the batch has a channel
   to recover, with an empty list when none of those channels has a peer (which still creates the coordinator's
   context); a difference with nothing to recover does not call it.

A channel to recover whose peer is not in `updatedState.peers` is logged and skipped on both paths.

### Recovery requests

`ChannelRecoveryRequests` holds `polls: [PeerId: Int32?]` (a key is a poll request; the value an `updateChannelTooLong`
pts hint) and `gaps: Set<PeerId>`, both private. `requestPoll(_:ptsHint:)` inserts with `updateValue(_:forKey:)` only
when the key is absent (first hint wins); `noteUnknownChannelState` is a hint-less request; `markGap` reports only a
channel's first gap; `channelIds` is `Set(polls.keys).union(gaps)`, rebuilt per read (`ChannelRecoveryRequestsTests`).
Sites (`grep -n 'requestPoll\|noteUnknownChannelState\|markGap' Sources/State/Sync/UpdateInterpreter*.swift`):
`applyChannelTooLong` (hint), `applyPinnedForumTopics` without an order (CloudChannel peers only), `applyChannelWebPage`
on a pts hole (a poll, not a gap), five `noteUnknownChannelState` (delete, edit, web page, new message, pinned messages
of a channel without a snapshot `ChannelState`), four `markGap` (delete, edit, new message, pinned messages), and
`UpdateInterpreter.init` (G1, fixed; `ChannelPollSiteTests`, `testUpdateForChannelWithoutStatePollsChannelDifference`).

Channel pts rule (the same five updates), against `updatedState.channelStates`: `local >= pts` skipped,
`local + ptsCount == pts` applied (advancing the channel pts), else a gap (a poll request for the web page); skipped,
gapped or unknown-state updates are not applied and the poll's or reset's answer brings the content. An applied new or
edited message gets `ChannelMessageStateVersionAttribute(pts:)`; a new one advances `synchronizedUntilMessageId`.
`applyChannelTooLong` does nothing when a poll is already requested and skips when the channel pts of
`UpdateInterpreter.state` (the batch's STARTING snapshot's) is >= the hint; the hint never sets the poll's pts.

Snapshots: `initialStateWithPeerIds` loads stored `ChannelState.pts` into `channelStates` and puts an active channel in
`channelsToPollExplicitely` when it has no stored Cloud top message or is stored as a non-member.
`activeChannelsFromUpdateGroups` keeps member channels with a `.personal` access hash among the peers requiring local
chat state; `activeChannelsFromDifference` keeps every member channel of the difference (G8, open).

### `pollChannel` and `resetChannels`

`pollChannel` sends `getChannelDifference` with `flags: 0`, `filter: .channelMessagesFilterEmpty`,
`pts: max(pollPts, 1)`, `limit: 100` (2 in DEBUG), `pollPts` being the given state's channel pts or 1; on the push path
that is the batch's interpreted branch. CHANNEL_PRIVATE and CHANNEL_INVALID give `.channelUnavailable`; every other
error is retried by `retryRequest` without limit (C5). A peer without an input channel gives `.noInputChannel`: no
request, no error (`testChannelGapForAChannelWithoutAccessHashAppliesTheBatchWithoutARequest`). Only
`.channelUnavailable` sets `hadError`, making the batch `.applyThenPoll`
(`testChannelPollAnsweredChannelPrivateAppliesTheBatchThenPolls`).

- `channelDifference`: channel pts := the answer's; new messages stamped with it, added at `.UpperHistoryBlock`,
  advancing `synchronizedUntilMessageId`; `other_updates` through `pollChannel`'s own 7-case switch, not
  `UpdateInterpreter` (D4); then `resolveForumThreads(state:)` and `resolveAssociatedStories`. The flags are bound to
  `_` in all three arms: `final` is never read and a partial difference is not continued (C4).
- `channelDifferenceEmpty`: the pts only; the state is still replayed.
- `channelDifferenceTooLong` with a `.dialog` pts: pts and `invalidatedPts` := the dialog pts; previous-state hole; a
  topic-list reset; the top message at `.UpperHistoryBlock` (advancing `synchronizedUntilMessageId`), the rest at
  `.Random`; read state and three tag summaries reset. Without a pts: `assertionFailure()` and `.applied` with nothing
  applied (C8). No harness test answers `channelDifferenceTooLong`.

`resetChannels` sends one `messages.getPeerDialogs`; any error gives nil, no retry, two identical catch arms (C6). Per
`.dialog`: read state, tag summaries (top message non-zero), channel pts and `invalidatedPts` (the dialog pts),
notification settings, chat inclusion, autoremove timeout, a topic-list reset (failing locally with no request for a
channel that is neither forum nor monoforum); top messages at `.UpperHistoryBlock`; previous-state hole and
`synchronizedUntilMessageId`; then `resolveAssociatedMessages` and `resolveAssociatedStories` (C2, fixed:
`testChannelResetStoresFetchedReplyTarget`, `testSynchronousChannelResetRequestsReplyTargetOnce`).

### `ChannelResetCoordinator`

`Impl` owns it as a `private lazy var` with its queue, replayer and validity marker (a random `Int64` per Impl); its
`cycleEnded` holds the Impl weakly and calls `channelResetsEnded`. `Impl.addAsyncResetChannels` asserts that a
`.fetchDifference` is the head and drops the request otherwise. One `ChannelOperationsContext` (`pendingChannels`,
`channelResults`, the chain's `events`, `differenceChainEnded`) serves a cycle and every cycle ending while it exists.

- `addAsyncResetChannels(peers:)` creates the context if needed (even for no peers). A peer is reset when not pending,
  or when both pts are known and the pending one is higher (`currentPts > pts`); a reset writes the peer's
  `InvalidatedChannel` record (fire-and-forget), then runs a one-peer snapshot and `resetChannels`. Replacing a pending
  reset disposes it.
- `endDifferenceChain(events:)`: with a context, marks the chain ended, unions the events, checks completion, returns
  true; without one, false.
- `checkChannelOperationsCompletion()` waits for a context, the chain's end and every reset. With results it merges them
  sorted by `PeerId`, clears EVERY `InvalidatedChannel` record and replays `.unverifiedChannelReset` in one transaction
  (C1); on delivery it drops the context and calls `cycleEnded(events, true)` (`nil` events if the replay returned nil).
  Without results it drops the context and calls `cycleEnded(events, false)` synchronously.

The context is dropped only in those two places (`grep -n 'currentChannelOperationsContext = nil'`), so a cycle ending
between the replay transaction and its delivery replays the results again (Q9, open). Polls queued while a reset is
pending join the context and replay it once (`testPollsQueuedWhileAChannelResetIsPendingReplayItOnce`).

### Channel state

- Replay writes: `StateAdvance` keeps the LAST pts, `invalidatedPts`, `synchronizedUntilMessageId` per channel (not the
  max) and writes them unconditionally after the content (C7, replay half open).
- Other writers: `fetchChatListHole` and the reset create a missing `ChannelState` with the fetched pts and no
  `invalidatedPts`; on an existing state they move the pts only when it differs, raising `invalidatedPts` with it but
  never lowering it, and otherwise leave it alone (C7's write half, narrowed; the pts is still not monotonic;
  `testChannelWhosePtsMovesGetsInvalidatedPtsRaised`, `testPageNeverLowersAChannelsInvalidatedPts`,
  `testResetNeverLowersAChannelsInvalidatedPts`); `ManagedSynchronizePinnedChatsOperations.swift` and
  `ChatListFiltering.swift` create a `ChannelState` only when none exists; `resolveMissingPeerChatInfos` writes none.
- `invalidatedPts` is raised by `pollChannel`'s too-long arm, `resetChannels`, `fetchChatListHole` and the reset. It is
  read lazily by `HistoryViewStateValidation`: a visible Cloud message of a channel view whose
  `ChannelMessageStateVersionAttribute.pts` is below it (or absent) is revalidated in runs of at most 64
  (`messages.getHistory(hash:)`, a tag request, or `getReplies`/`search` for a thread), missing ids checked with
  `channels.getMessages`.
- `synchronizedUntilMessageId` is set by in-order new channel messages, channelDifference messages, a too-long top
  message, `resetChannels`, and `fetchMessageHistoryHole`, which only raises an EXISTING state's value to the max
  fetched id when a plain `.everywhere` Cloud fill of a channel reaches the top. The prepass starts previous-state holes
  at `synchronizedUntilMessageId + 1`.

### View polls and unjoined channels

`AccountViewTracker.polledChannel` keeps one `ChannelPollingContext` per channel; `wrappedMessageHistorySignal`
subscribes it for every CloudChannel view, so all views share one `keepPollingChannel` loop (first subscriber starts,
last stops it). `keepPollingChannel` is `pollChannelOnce(delayCompletion: true) |> restart |> delay(1.0)`: the first
poll starts 1 s after subscription; each cycle snapshots, polls, resolves, queues a `.replayPrebuilt` at `.last`, emits
`timeout ?? 30` and completes that long after. Its snapshot has `initialStoredMessages: Set()`, so every referenced
reply target is requested, stored or not. Each emitted timeout sets `isUpdated` for that long.

On every subscription of a CloudChannel view, the tracker first claims the stale period's hole on its queue: if the
polling context is not updated and `addedHoleWhileStale` is clear, it sets the flag (cleared when `isUpdated` becomes
true), whether or not the channel is listed. Then one transaction runs before the view starts: for a channel with no
chat-list index that is not hidden by a collapsed community, it resets the incoming read state to `idBased(1, 1, 1, 0)`
(`nonMemberChannelReadState` for a stored non-member channel, not a monoforum; invariant 30) and, if this
subscription claimed the hole, calls `resetPeerHoleManagement` and adds an `.everywhere` hole over
`1...Int32.max-1` (C9, narrowed). The view does not wait for the poll; the `addHoleIfNeeded` parameter is never read.

### Holes and history fills

`ManagedMessageHistoryHolesContext` runs at most one fill per (peer, thread, space), skips entries completed less than
20 s ago (`ManagedMessageHistoryHolesPause`) and re-evaluates its entries when such a pause ends, so a fill that closed
nothing starts again while a view still shows its hole (`ManagedHistoryHolesRestartTests`), forgets a peer's on
`resetPeer`, and disposes pending fills in `deinit` (`ManagedHistoryHolesTeardownTests`).
`fetchMessageHistoryHole` asks for `min(100, count)` through `historyFillRequestRetryingTransientErrors`: transient
errors retry without limit (an upward `getHistory` fill asks `max_id` end + 1, since `max_id` is exclusive and the range
it closes includes its end: a one-id hole `1 ... 1` under a top of 2 lost message 1; an around fill asks `min_id` 0,
since it closes over its anchor: `min_id` 1 lost the first post of a channel opened at it;
`HistoryFillRangeBoundsTests`); a definite answer (`TL_` text, CHANNEL_PRIVATE, other 4xx except `FLOOD_`) is logged and
closes nothing (Q15, fixed; `HistoryFillRequestErrorTests`). Channel fills stamp messages with the answer's pts and
never use confirm-before-delete (`historyFillReconciles` covers private chats and basic groups;
`testChannelFillIsUnchanged`). A fill stores and closes the hole in its first transaction and resolves reply targets,
emoji and stories in a follow-up started inside that transaction (master `51c8a7e596`, merged in 2026-10-24): it
registers the stored messages waiting for a missing reference in `PendingMessageReferences` (views draw skeletons for
them), and when it ends it releases them and rewrites them from their current rows so they redraw. Rich messages
with a custom emoji whose file is not stored are rewritten then too, without registering (their previews draw such an
emoji as its alt text, not a skeleton; `HistoryFillRichTextEmojiTests`). The follow-up's
answers are stored only while none is older than `FetchedAnswerAge.maximum` (otherwise it fetches again), and reply
targets deleted meanwhile are not stored. A forum or monoforum fill stores first too unless a fetched message's topic
info is neither stored nor in the answer (`forumFillStoresFirst`); then it resolves first, as before (C3, fixed;
`ForumHistoryFillTests`, `MonoforumHistoryFillTests`), and an answer's missing topics are stored with its messages
(`storeFetchedForumTopic`, `SyncResolve.swift`). Answers older than `FetchedAnswerAge.maximum` are not stored (a
confirmation is still applied) and close nothing.
`aroundHoleFillRange` lets a plain around fill close to the top when `offset_id_offset` matches the newer ids returned,
and close the whole history when the result holds the server's `count` of messages (`inexact` vetoes both; the bottom is
inferred in no other case; `AroundHoleFillRangeTests`); `peerCanHaveForumThreads` keeps plain channels from asking for
threads.

A fill confirms the stored messages its answer leaves out of the range it closes (`HistoryFillReconciliation.swift`)
only where `historyFillReconciles` holds: a private chat or basic group (Saved Messages included), the Cloud namespace,
no thread, neither forum nor monoforum, `.everywhere` or a tag other than `.liveLocation` (never a custom tag). In the
transaction that parses the answer, `historyFillReconciliation` reads the stored ids of `filledRange` nearest the edge
the fill started from (by id, or from the tag's date-ordered index in a tag fill), and each one the answer lacks is a
candidate. `historyFillConfirmationPlan` takes at most `historyFillConfirmationLimit` (200) of them, nearest the edge
first; with more, the fill closes only `closedRange`, cut just before the nearest left-over on each side (it always
holds the edge), and makes the rest of `filledRange` a hole for the next fill, also where it was none: an earlier
fill can have closed part of it over messages since deleted (one held across a cleared history and an account reset).
The same transaction reads the `stableVersion` of each
batch candidate and of each answer message already stored. With candidates, nothing is stored and no hole closes until
`confirmStoredMessages` answers (through the fill's own source, so a preload fill confirms through its download
session); a fill disposed meanwhile writes nothing. Then one transaction stores the answer without the messages deleted
recently (`fetchedMessagesWithoutRecentDeletions`) or written again since they were read (`historyFillAnswerToStore`),
applies the confirmation and removes the hole over `closedRange`, then opens it again over each candidate answered as
gone but written again since, which stays stored (`testClearedHistoryIsConfirmedTwoHundredAtATime`,
`testAroundFillClosesAroundItsAnchor`, `testCancelledFillWritesNothing`,
`testAnswerMessageDeletedOrEditedDuringTheConfirmationKeepsTheNewerWrite`,
`testCandidateWrittenDuringTheConfirmationIsLeftAloneUnderAHole`).

### Container order

The push path's merge order comes from containers: `pollChannelSignals` follows `channelRecovery.channelIds` (a `Set`
from dictionary keys and a set), `combineLatest` over an array emits in index order, and the merge loop applies
`merge(_:)` in that order; the same order sets the inline reset's peer list (`UpdateInterpreter.init` inserts the
explicit polls in the iteration order of another Set, `initialState.channelsToPollExplicitely`). `merge(_:)` depends on
it: operations from `branchOperationIndex` append in merge order, `peers` and `apiChats` keep the LAST branch's copy,
`resetForumTopicLists` and `updatedOutgoingUniqueMessageIds` the FIRST. `branch()` starts with empty alerts, web-view
results and pre-cached resources, so merging does not repeat the parent's (R2, fixed; `BranchMergeTests`,
`testAlertInABatchThatPollsAChannelIsDeliveredOnce`). The asynchronous reset merges in `PeerId` order and does not
depend on dictionary order.

## Invariants

Each: the rule; why; where enforced; what pins it.

1. **Only the head runs; only `startFirstOperation()` starts it** (`startHead()`). Completions pop the head as their
   own; two running operations would pop each other's. Pinned: `testStartHeadStartsTheHeadOnce`.
2. **The operation queue is touched only on the manager queue.** It is an unlocked value type, and placement must happen
   in the block that pops. Enforced: debug `assert(queue.isCurrent())` in the accessor, `addOperation`,
   `addPollCompletion`.
3. **Pop first, then check.** A completion acts only on its own entry (kind; id for `custom`, `dispatchEvents`), so a
   mismatch starts nothing. Enforced: `pop<Kind>`. Pinned: `testCompletionPopsTheHeadThenChecksIt`.
4. **No real dispatch where SwiftSignalKit runs inline.** A slice or reset follow-up queued by a real dispatch lets
   queued groups run against the intermediate pts: a hole, a gap wait, an extra getDifference. Enforced: `Queue.async`
   and `deliverOn` semantics, `addOperation` a direct call, the spec's Constraints. Pinned:
   `testSliceContinuationRunsBeforeGroupsPushedMidPoll`, `testResetFollowUpRunsBeforeGroupsPushedDuringTheReset`.
5. **The poll result hops inside `next` (app) or the last inner signal (extension), never via a trailing
   `deliverOn(queue)`.** An inline completion can overtake a value dispatched from another thread; the lost value left
   the app's poll at the head forever or stopped the extension paging early (Q13). Pinned:
   `testDifferenceAnsweredBeforeThePollContinuesIsDelivered` (app), `DeliverOnOrderingCharacterizationTests` (the
   operator shape; the extension's own path has no pin).
6. **`isUpdating` goes false only in `finishPollCycle`, with no reset context pending.** Task start, contact sync and
   the "Updating" state follow it. Enforced: one `currentIsUpdatingValue = false` (by convention). Pinned:
   `isUpdating.values` in `DifferenceCharacterizationTests`, `PushCharacterizationTests`, `EventDeliveryOrderTests`.
7. **Every `DifferenceOutcome` is decided in one exhaustive switch.** An arm that neither ends nor continues wedges the
   queue or leaves `isUpdating` true (Q1, Q2). Enforced: no `default` in `handleResult`. Pinned: a
   `DifferenceCharacterizationTests` case for every outcome except `.replayRejected`, which no harness test reaches.
8. **A committed replay's events are queued whatever follows.** pts has moved past them (Q4); `replace` keeps queued
   `dispatchEvents`. Enforced: `runProcessBatch` and the restart arm insert before replacing. Pinned:
   `testResetInBatchCommitsAndDeliversEvents`.
9. **The coordinator drops its context before `cycleEnded`; the queue starts after an asynchronous replay.** The second
   `finishPollCycle` would hand a live context the events again, and an idle queue would not run them (Q12). Pinned:
   `testTheCycleEndsAfterTheContextIsDropped`, `testAContextWithoutResetsEndsTheCycleWhenTheChainEnds`,
   `testChannelTooLongInDifferenceResetsChannelAfterTheDifference`.
10. **`replace`'s `nextId` must not touch the operation queue.** It runs while the caller holds the queue's value
    through the computed accessor, so a nested access is lost. Enforced: `replaceOperations` passes only `getNextId()`.
    Pinned: nothing directly; `testReplaceQueuesABarrierOnlyWithSomethingToCarry` pins only when `nextId` is called.
11. **A differenceTooLong reset keeps its poll at the head until done; the follow-up goes in at `.first`.** No batch
    runs against the pre-reset state and the follow-up precedes groups pushed meanwhile. Pinned:
    `testResetFollowUpRunsBeforeGroupsPushedDuringTheReset`.
12. **Never give up on a transient error; back off where a loop is the risk.** A stopped sync leaves the account
    silently stale (owner rule). Only definite answers end a retried request: AUTH_KEY_DUPLICATED on getDifference,
    CHANNEL_PRIVATE and CHANNEL_INVALID on channel polls, FROZEN_METHOD_INVALID on getPinnedDialogs, a fill's definite
    answer (a `TL_` text or CHANNEL_PRIVATE under any code, any other 4xx but a flood wait), after which the fill closes
    nothing and is started again. A history fill's confirmation and the reset's `getDialogs` retry a definite answer
    too, by the owner's decision (Open issues). The resolve stages and `resetChannels` (C6) are not retried at all, and
    the read-state validation confirms a read state without validating it when its `messages.getHistory` fails
    (`dialogTopMessage`, `SynchronizePeerReadState.swift`). Enforced: `retryingDifferenceRequest`,
    `consecutiveResetDelay`, `staleRestartDelay`, the confirmation and fill retries. Pinned:
    `testDifferenceTooLongWithDialogsNotModifiedRetriesTheReset`,
    `testResetThatStaysSlowerThanTheRecordBacksOffBeforeEachRestart`, `HistoryFillRequestErrorTests`.
13. **The notification extension never resets the account, never queues an operation, never touches `isUpdating`**
    (the share extension's standalone manager never gets `reset()`, so it queues nothing either). It shares the
    database on a short budget; its old `preconditionFailure()` crashed every non-channel push (Q3). Enforced:
    `.tooLong` writes nothing; `grep -rn '_internal_resetAccountState(' Sources | grep -v '///'`. Pinned:
    `testDifferenceTooLongEndsThePollAndLeavesTheResetToTheApp`, `NotificationExtensionPollOutcomeTests`.
14. **The history fill (private chats and basic groups) deletes a stored message only after the server answered for
    its id (`messageEmpty`, or left out of the answer: owner, 2026-10-25), and only if it is unchanged; the reset
    deletes, without asking, only the stored messages above a fetched dialog's top message; the chat-list fill
    deletes none, and leaves a private chat's or basic group's stored messages above the top it fetched under a hole,
    for the chat's next history fill to confirm (owner, 2026-10-25); none of them stores a fetched message that
    Postbox's record of recent deletions holds, and each stores, in place of a fetched message, the edit of it that
    Postbox recorded since the fetch's request went out (owner, 2026-10-25).** An error (FLOOD_WAIT included) must not
    look like a deletion; a concurrent write wins; an answer can predate a deletion or an edit that landed while it was
    in flight. The reset
    may delete above the top
    because it moves pts to the reply pts, which precedes its dialogs answer, so whatever is newer than the answer is
    delivered again; the chat-list fill moves no pts, so it may not, and the hole it leaves lets the history fill ask
    instead: after a reset, a chat beyond its first dialogs page is where a message deleted during the gap waits
    (truth server, large-world seeds 698 and 916). Enforced: `confirmStoredMessages` and
    `applyStoredMessageConfirmation` (against the `stableVersion` read with each candidate), reached from
    `fetchMessageHistoryHole`, which reads its candidates with `historyFillReconciliation`;
    `storedCloudMessagesAboveTopMessages`, read by `_internal_resetAccountState` (deleted) and `fetchChatListHole`
    (left under a hole, private chats and basic groups only; a channel's revalidation covers its own);
    `fetchedMessagesWithoutRecentDeletions` (Postbox's `RecentlyDeletedMessages`: 5 minutes, at most 10 000 ids);
    `fetchedMessagesWithRecentEdits` after it at every one of its calls (Postbox's `RecentlyEditedMessages`: the latest
    edit of each message, 5 minutes, at most 1000 messages; recorded by `applyEditMessage` for every edit, whether a
    stored message took it or none was stored, by `applyUpdateMessageWidgetData` for a stored widget whose state it
    changed, and by the shared-widget poller (`WidgetPublicDataPolling`) for a stored widget whose state a poll
    changed, and returned only to a fetch whose request went out before it was
    recorded, `since`: the fill's answered attempt, the follow-up's start, the reset's and the chat-list fill's first
    request).
    Pinned: `testResetDeletesAStoredMessageAboveTheTopWithoutAsking`,
    `testResetDeletesAMessageNewerThanTheAnswerAndTheFollowUpDifferenceBringsItBack`,
    `testChatListFillLeavesStoredMessagesAboveTheTopAlone`,
    `testChatListFillLeavesMessagesAboveATopUnderAHoleTheNextHistoryFillConfirms`,
    `testFillDeletesWhatTheServerNoLongerHasAndRefreshesWhatItStillHas`,
    `testCandidateWrittenDuringTheConfirmationIsLeftAloneUnderAHole`, `HistoryFillRecentDeletionTests`,
    `ChatListRecentDeletionTests`, `RecentEditTests`, `WidgetDataUpdateTests`,
    `testAFillInFlightDoesNotOverwriteAPolledState`, Postbox's `RecentlyEditedMessagesTests`.
15. **Each reset attempt that gets a chat list writes its state in one transaction after every answer; pts moves in it;
    qts, date, seq are kept.** A `dialogsNotModified` answer writes nothing (pts stays, so the next getDifference meets
    differenceTooLong again); answers too old to store (`FetchedAnswerAge`) write nothing, and the reset starts again. A
    process killed midway redoes the reset; the kept qts lets the follow-up fetch secret messages (G10). Pinned:
    `testResetWhoseAnswersOutlivedTheRecordFetchesTheChatListAgain`,
    `testDifferenceTooLongFollowUpFetchesTheGapsEncryptedMessage`.
16. **A replay is one synchronous call inside the caller's transaction.** Postbox disposes a transaction when its
    closure returns and asserts on later use, and only writes made inside commit with the pts they advance; the two
    closures that outlive it capture copies, never the context. Pinned: none dedicated.
17. **A verified replay writes nothing unless the final state holds every snapshot peer (each `initialState.peerIds` in
    its `peers`, stored or carried by the batch) and every state it moves is still at its snapshot value** (the account
    state if the log has an `.UpdateState`, each channel it moves with `.UpdateChannelState`). A stale final state would
    move pts back or skip updates; this decides races between polls of one channel. The asynchronous reset is the one
    unverified replay (C1). A refused replay of a pushed batch or of the app's getDifference is followed by a
    getDifference; a refused replay of a view poll, of the extension's channel poll or of the extension's getDifference
    is followed by nothing (the view poll's next cycle polls again). Pinned: `ReplayRejectionTests`,
    `testAVerifiedReplayOfAStaleStateIsRefusedAndTheChannelResetPolicyReplaysIt`.
18. **State writes follow every content operation** (`applyStateAdvance` after `applyContentOperations`, last value per
    kind and channel); `finalize()`'s writes come after both. Content operations read stored state that must not have
    moved yet. Pinned: `testStateOperationsNeitherEndABatchNorReachTheContent`,
    `testTheLastValueOfEachStateOperationWins`.
19. **Every `AccountStateMutationOperation` case is placed in three switches without `default`**
    (`AccountMutableState.addOperation`, `batchContentAndDeferStateOperations`, `applyContentOperations`), so a new
    operation cannot compile until its index update, batching and replay are decided. Pinned: the compiler.
20. **No overlapping access to `ReplayContext` members.** A class member overlap traps at run time, only on the path
    that reaches it; the `inout` uses (`recordPeerActivityTimestamp(... into:)`, `recordUpdatedWebpage(... into:)`) and
    the re-entrant `applyDeleteMessages` callback do not overlap. Pinned: nothing measures it.
21. **No `[weak]`/`[unowned]` capture list in `Sources/State/Sync/`** (the grep `'\[weak\|\[unowned'` there is empty):
    Swift 6.4 miscompiles one such shape (CLAUDE.md). Pinned: the grep.
22. **A notification fires only for a message not stored before the replay**, or a replayed message notifies twice.
    Enforced: `filterStoredMessageIds` in the prepass. Pinned:
    `testPrepareListsOnlyIncomingTopMessagesThatAreNotStored`.
23. **`AccountFinalStateEvents` keeps 36 fields, each set by `init()`, `init(state:)`, `union(with:)` and the test
    helper; events union in replay order.** A defaulted field compiles and is dropped at every merge; reversed order
    delivers stale state. Pinned: `testStoredFieldCountMatchesEveryInitAndUnion`, `testUnionMergesEachFieldByItsPolicy`.
24. **`followUp` precedence: discard, poll, gap wait, apply.** A discarded batch is never replayed; a forced poll
    supersedes a gap wait. Pinned: `testFollowUpForEveryFlagCombination`.
25. **Poll requests insert with `updateValue(_:forKey:)` behind an absent-key check; `polls` is private.** On an
    Optional-valued dictionary `polls[id] = nil` removes the key, which made seven sites no-ops (G1). Pinned:
    `testAPollRequestWithoutAHintIsARequest`, `testTheFirstPollRequestKeepsItsHint`, `ChannelPollSiteTests`.
26. **`applyChannelTooLong` decides by the channel pts of `UpdateInterpreter.state`, the batch's starting snapshot's.**
    Earlier updates may have advanced `updatedState` without filling the gap. Pinned: not separately.
27. **Keep the containers whose iteration order decides an order:** channel recovery's (`polls` a dictionary;
    `gaps`, `channelIds`, `channelsToPollExplicitely` sets; `pollChannelSignals` merged in index order), which set the
    branch merge order; interpretation's `updatesByChannel` (`sortedUpdates`), which sets the order in which channels'
    updates are interpreted; the replay's `StateAdvance` (`channelStates`, `invalidatedChannelPts`,
    `channelSynchronizedUntilMessageIds`), which sets the order of the channel-state writes. Swift's dictionary and set
    order is per process, so the rule keeps how each order is produced. Enforced: the spec's Constraints, which name
    channel recovery's; the other two only by this rule. Pinned: none can be.
28. **A history fill never creates a `ChannelState`;** it only raises an existing `synchronizedUntilMessageId`. pts is
    the poll's to set; the raise keeps the next previous-state hole off what the fill closed. Pinned: none found.
29. **At most one full hole per unpolled period for a channel outside the chat list** (`addedHoleWhileStale`). A chat
    re-subscribes its view after every fill, and a hole each time wiped what the fill stored. Pinned: none found.
30. **A channel the account is not a member of keeps no read state** (`NonMemberChannelReadState.swift`, from master's
    `ed476ab8b5`): the server keeps none, so the client neither stores nor sends one; a monoforum keeps its own.
    Enforced: `applyContentOperations` skips `.ReadInbox`, `.ResetReadState`, `.ResetIncomingReadState` and a
    main-chat `.UpdatePeerChatUnreadMark` for one (`readStateOperationTargetsNonMember`, judged by the peer stored when
    the operation comes up, so a join merged earlier in the same replay counts); the prepass's read maxima leave the
    same operations out (`cloudReadInboxMarks`, judged by the batch's final peers); `synchronizePeerReadState`
    confirms a queued operation for one without sending it; `updatePeersCustom` queues a read-state validation when
    a stored channel becomes a member (`channelJoinNeedsServerReadState`). Pinned: `NonMemberChannelReadStateTests`
    (the helpers), `NonMemberChannelReplayTests` (the replay's skip, judged when each operation comes up).

## Cost model

Requests per scenario, from the code and the harness's `requestNames`. Transactions only where counted.

- **Push, in order, chat state stored, referencing nothing unstored:** 0 requests
  (`testInOrderPushIsAppliedWithoutRequests`); transactions: the snapshot, the replay, and the notification read when
  the events are non-empty.
- **Push referencing data not stored:** the resolve stages of `finalStateWithChannelRecovery`, one after another, none
  retried (a failed request leaves its data out), while `processBatch` holds the head: thread infos not stored yet
  (`getForumTopicsByID`, or `getSavedDialogsByID` for a monoforum, one per chat, in parallel; forums, monoforums and
  bots with topics); reply targets and other referenced messages (`messages.getMessages` or `channels.getMessages`, one
  per chat and kind, in parallel), then unknown custom emoji (`getCustomEmojiDocuments`, 100 ids each, in parallel) and
  the thread-info stage again, which asks for the same missing infos (C10); stories not stored (`getStoriesByID` per
  chat, up to 100 ids each, in parallel); chat infos ("Peers needing chat info" below).
- **Applied qts, online:** +1 `messages.receivedQueue` per distinct non-zero qts. **Delivery-report ids:** +1
  `messages.reportMessagesDelivery` per peer. **Emoji game info:** +1 Postbox write.
- **Common pts/qts/seq hole:** the prefix, a 2.0 s `gapWait` (0.05 s in the harness), then one getDifference chain;
  groups pushed meanwhile dropped (Q5).
- **`.reset` group, CHANNEL_PRIVATE poll, discarded batch, refused replay:** one getDifference chain at once (a
  discarded batch still opens its replay transaction).
- **Peers needing chat info:** +1 `messages.getPeerDialogs` for all of them.
- **Remote read of a user or basic group** (`updateReadHistoryInbox` without `top_msg_id`, which goes to `readThread`):
  + a read-state validation (Postbox keys it by chat, so one per chat while it is pending), because the replay
  compares the update's pts with the stored pts before `applyStateAdvance` moves it (R3):
  `setNeedsIncomingReadStateSynchronization`, then `managedSynchronizePeerReadStates` (`synchronizePeerReadState`)
  sends `messages.getHistory` (limit 1), then, when that returns a message, `messages.getPeerDialogs`, and applies the
  answer as a `custom` operation.
- **Channel gap or unknown channel state in a push:** +1 `getChannelDifference` per channel, in parallel, retried
  without limit while `processBatch` holds the head; then the resolve stages (thread infos not stored yet, for forums,
  monoforums and bots with topics; reply targets, emoji, stories, `getPeerDialogs`), not retried; no gap wait
  (`testChannelPtsGapPollsChannelDifference`).
- **Channel to recover from a difference:** one `getPeerDialogs` per channel, asynchronous, plus its resolve
  (`testUpdateForChannelWithoutStateInDifferenceResetsChannel`: `[getDifference, getPeerDialogs]`); inline: one for all.
- **`pollStateUpdateCompletion`:** 1 `help.test` each time the barrier reaches the head alone; it holds the head.
- **Launch / `reset()`:** 1 getDifference chain; without an inner state, 1 `updates.getState` first.
- **Long offline within `pts_total_limit`:** one getDifference per slice, each with its own snapshot, resolve, replay.
- **`stateChangedMeanwhile` / refused difference replay:** +1 getDifference at once, no backoff (Q6).
- **`differenceTooLong`:** at least 4: getDifference, `getDialogs` + `getPinnedDialogs`, the follow-up getDifference
  (`testDifferenceTooLongResetsAccountAndPollsAgainFromTheNewPts`; no `getState`, unlike the audit's row). +1
  `getDialogs` per referenced folder (5 with the archive:
  `testResetDeletesTheStoredHistoryOfAnArchivedDialogWithoutATopMessage`); the ghost tail asks nothing. Two in a row: 7
  and a 1 s wait, each further one +3 and a doubling wait to 60 s
  (`testTwoDifferenceTooLongInARowResetTwiceThenFinish`). Answers older than 270 s: the whole fetch again after 1 s
  doubling to 60 s.
- **AUTH_KEY_DUPLICATED:** 1 getDifference. **Other getDifference/getState errors:** retried forever (0.2 s steps,
  5 s cap), holding the head (C5).
- **Extension:** 1 getDifference per call (date `Int32.max`), one call per slice, at most 15 s; differenceTooLong: 1
  request, nothing written, again on every push until the app resets; no inner state: 0; inline channel resets.
- **Opening an unjoined channel:** one transaction; one `messages.getHistory` (up to 100) per hole shown; after 1 s a
  `getChannelDifference` (from pts 1 without state), then one every `timeout ?? 30` s plus the round trip while a view
  stays open, each with `channels.getMessages` for every referenced reply target
  (`testViewPollStoresFetchedReplyTarget`) and a replay even when empty.
- **After a channel too long:** a fill of the previous-state hole; one `messages.getHistory(hash:)` per run of at most
  64 visible stale messages, plus `channels.getMessages` for missing ids.
- **The replay itself:** 0 requests; it may start 2 account-manager transactions, a nested Postbox transaction,
  `removeCachedResources` and `storeResourceData`, none awaited.

## Open issues

Left for the optimization task; each checked in the current code except where marked.

- **Q5** gap-wait drop: `absorbUpdateGroups` (`.gapWait`), `replace`, `runGapWait`; pinned as behaviour.
- **Q6** the restart arm re-polls with no backoff: `handleResult`.
- **Q7** the barrier sends `help.test` only when alone, calls subscribers only if the queue is empty after it, holds the
  head meanwhile: `runStateBarrier`.
- **Q8** `addUpdates` before the first `reset()` is dropped: `Impl.addUpdates`; pinned.
- **Q9** the reset context is dropped only at its replay's delivery (a cycle ending in between replays again), and
  `finishPollCycle` does not check the head, so `channelResetsEnded` can clear `isUpdating` while another poll runs. The
  AUTH_KEY_DUPLICATED half (a context that never completes) is documented on `ChannelResetCoordinator` as a known gap,
  not verified in code here.
- **Q10** `followUp` ignored on the difference paths and the reset replay (`AccountFinalState.FollowUp` doc).
- **Q4-order** newer poll events before the batch's older ones when a barrier or a prebuilt replay is queued (`replace`
  places both ahead of the carried deliveries; `insertEvents`).
- **C1** unverified asynchronous reset replay, outside the queue; **C4** `final` never read; **C5** getDifference,
  getState and the reset's chat-list requests retry forever while the poll holds the head (save the
  definite answers of invariant 12), and so does `pollChannel` on the push path (a view poll or the extension's channel
  poll retries outside the queue); **C6** `resetChannels` never retries and the coordinator clears every record
  regardless; **C7** the replay writes each channel's last pts, `invalidatedPts` and `synchronizedUntilMessageId`
  unconditionally, and `fetchChatListHole` and the reset store any differing pts, lower ones included (narrowed:
  `invalidatedPts` is raised with it); **C8** a too-long answer without a pts applies nothing; **C9** narrowed, the
  window remains; **C10** up to three `resolveForumThreads` passes per batch with a channel poll, each checking only
  stored thread infos.
- **D4** `pollChannel`'s own `other_updates` switch.
- **G3** nothing handles `updatePtsChanged` (`grep -rn updatePtsChanged Sources` is empty), so it falls into `default`;
  **G5** a peer requiring chat state without a peer or input dialog peer discards the batch
  (`resolveMissingPeerChatInfos`); **G6** the earliest date group's date filters the whole batch's typing; **G7** where
  interpretation runs (inside `network.currentGlobalTime`; MtProtoKit not checked here); **G8**
  `activeChannelsFromDifference`; **G9** the force unwrap in `initialStateWithPeerIds`.
- **R3** `applyResetIncomingReadState` compares with stored pts that `applyStateAdvance` has not moved yet; **R4**
  scheduled and quick-reply adds re-add the whole batch per unstored message; **R5** `applyAddMessages` counts an
  incoming message equal to a forum topic's `maxKnownMessageId` as unread in that topic; **R7** the previous-state hole
  covers the batch's own lower messages; **R8** `deleteEphemeralMessages` walks every stored cloud message of the chat
  inside the replay.
- Confirm-before-delete (`followups.md`, "Parked review findings from the differenceTooLong work"): `stableVersion`
  moves on every `justUpdate` (`updateMessage`, a store over a stored message), a server write and a local attribute
  write alike, so it cannot tell them apart (embedded-media and group rewrites keep it): an answer message written
  locally while a fill's confirmation is in flight keeps its possibly stale content (`historyFillAnswerToStore`), and a
  candidate so written is left as it is (under a hole of its own when the server answered it as gone); each answer
  message already stored is rendered twice on a fill's candidate path
  (`getMessage` for `answerVersions` in `historyFillReconciliation`, again in `historyFillAnswerToStore`); a tag fill
  reads its candidates from the tag's date-ordered index (`messageIndicesWithTag`), so a message dated out of order with
  its stored neighbours (imported history) can be missed, and is then left unconfirmed, never deleted; a clear
  (`clearHistory`, with or without a time range, or a `removeAllMessagesWith…`) records every id it removes and
  `RecentlyDeletedMessages` keeps at most 10 000 ids and global ids, oldest dropped first, so a large clear pushes other
  chats' recent deletions out of the record for the rest of their 5 minutes.
- A definite answer to a history fill's confirmation (decided 2026-10-24, owner: "Keep the hole"): its
  `messages.getMessages` (`retryRequest` in `confirmStoredMessages`) retries every error without limit, a definite one
  included (a `TL_` parse failure, FROZEN_METHOD_INVALID, MSG_ID_INVALID), although the fill's own request stops on such
  an answer (`historyFillRequestErrorIsDefinite`). The fill writes nothing until it answers, and
  `ManagedMessageHistoryHoles` never cancels a pending fill and starts no other for the same peer, thread and space, so
  that part of the chat stays loading for the session, with a request every 5 s, and again after a relaunch; a stuck
  preload fill keeps one of the preloader's three slots. Kept so on purpose: closing the hole would show candidates
  nobody confirmed as history, and nothing gives up (owner rule). It needs a definite answer to `getMessages` while
  `getHistory` works (a frozen account, if `getMessages` is blocked there: a question for the server team). The
  confirmation asks only `messages.getMessages` and skips any other id: channels never reconcile, and the reset deletes
  its ghost tail without asking.
- A definite answer to the reset's own `messages.getDialogs` (decided 2026-10-24, owner: "getDialogs should retry
  forever"): `retryRequest` retries it without limit and, since the poll waits for the reset, a definite one stops the
  whole sync until the server answers otherwise. Kept so on purpose: without a chat list there is nothing to reset from,
  and nothing gives up (owner rule).
- Also: `SAVED_DIALOGS_UNSUPPORTED` maps to `.never()` in `_internal_requestMessageHistoryThreads` (server behaviour
  unverified); the intent of `addAsyncResetChannels`' `currentPts > pts` is unrecorded; a string `pts_total_limit`
  counts as absent; G2's edge cases (overlapping container, `seqStart == 0`) are treated as holes
  (`SeqContainerEdgeTests`); `ReplayRejection` is not passed up through `applyReplay`; the stage-5 replay had only a
  `-Osize` SIL pass (exit 0), not a release `Make.py build` (IRGen/LLVM); `currentIsUpdatingValue` could become
  `private(set)` behind a `beginPollCycle()`; `applyUpdatePeer` and `applyUpdateCachedPeerData`
  (`StateReplay+Peers.swift`) mark their closure `@escaping` although they only call it during the replay (the second
  inside `Transaction.updatePeerCachedData`'s non-escaping `update`); `addPollCompletion` and `removePollCompletion`
  keep their old names, though they add and remove a barrier's subscribers (`addBarrierSubscriber`,
  `removeBarrierSubscriber`).
- Fixed: Q1, Q2, Q3, Q4, Q11, Q12, Q13, Q14, Q15, G1, G2, G4, G10, R1, R2, R6, C2, C3, C11.

## Changing state sync safely

```sh
bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh test        # TelegramCoreTests
bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-loop.sh 1 20 <outdir>  # 20 runs in a row
```

`run-make.sh test` is `Make.py test --target //submodules/TelegramCore:TelegramCoreTests` (CLAUDE.md, Build).

- `StateSyncTestCase` runs the real manager over a temporary Postbox (`StateSyncFixture`) and a real `Network` talking
  to `ScriptedServer`: answers by `on(_:_:)` (one-shot, in order), `always`, `.hold` + `release(_:with:)`; pushes by
  `push(_:)`, or `pushInline(_:)` from a manager-queue callback to land at an exact queue position; `requestNames`,
  `requests`, `unscripted` to assert. `drainOperationQueue()` waits on a no-op custom operation (not in tests that watch
  where pushes land); `launchIdle` answers the launch poll; builders are in `StateSyncApi`.
- `STATE_SYNC_LOG=1` in the test environment prints TelegramCore's log.
- `tearDown` fails a test whose Postbox is still retained 5 s after `close()`: answer what it left in flight, or set
  `retainedPostboxAtCloseReason` when it does so on purpose.
- An ordering or runner change passes 20 consecutive full-suite runs (`run-loop.sh` checks the final "Executed N tests"
  line); a stall is a regression.
- Pin a behaviour by seeing the new test fail under a scratch break of the rule (a mutant), restoring by copy, and
  running the suite clean. Unit-test the value types directly; assert `requestNames`, stored state, `isUpdating.values`
  and notifications end to end. Secret-chat crypto is out of reach. Q5 and Q8 are still pinned as defects; a fix changes
  that one assertion in its own commit.
- TelegramCore is shared with Telegram-Mac: no UIKit or Display, public API changed in place, persisted encodings
  (PostboxCoding, FlatBuffers) byte-identical, warnings are errors (`-warnings-as-errors`).

**The truth server** (`Tests/StateSync/TruthServer/`) checks the app against a model of the server instead of scripted
answers. `TruthWorld` holds the account's chats, with account-wide and per-channel pts, in one of two shapes
(`TruthShape`): `.small`, three private chats, a basic group, a broadcast channel and a megagroup; `.large`, 129 chats
(more than a dialogs page) with a private chat and a channel of 300–400 messages (more than a history page).
`truthAnswer` answers what Telegram would:

- `getState`, `getDifference` (empty, slices, `differenceTooLong` past `pts_total_limit`, `updateChannelTooLong` for a
  channel the app has not been sent), `getChannelDifference` (empty, partial, too long);
- `getHistory` with Telegram's bounds (`min_id`/`max_id` exclusive, then `offset_id` and `add_offset`), `getMessages`,
  `channels.getMessages`, dialogs pages (by top date, id, then peer, as `offset_peer` names it) and pinned dialogs;
  an edited message carries its `edit_date`.

A session (`makeTruthSession(seed:shape:)`, 20 to 60 random steps) mixes:

- incoming messages, other-device sends, edits, deletions and clears;
- the app killed, launched and restarted, and long offline stretches;
- chats opened, opened at a message (an around-anchor fill) and scrolled up;
- dropped, duplicated and swapped pushes, failed requests, and fills and confirmations held across steps;
- with jitter (`TruthSessionDriver(jitter:)`), every answer and push 0–50 ms late
  (`ScriptedServer.deliveryDelay`), so pushes land while requests are in flight.

The app starts as after a fresh login and fills its chat list's first hole at each launch. `converge()` relaunches,
polls every channel to the server's pts, fills the chat list's holes and every chat's, and runs the app's channel
revalidation (`HistoryViewStateValidationContexts`, fed views as `AccountViewTracker` feeds them). `compare()` then
reports:

- missing, ghost and stale messages;
- the chat list: a chat the server lists that the app does not, a wrong top message, a chat listed by a message the
  server does not have;
- unanswered requests and no convergence (a fill or poll that never answers is reported at once).

Validation pending (below a channel's `invalidatedPts`) is reported only when the revalidation did not run.

The suite runs the fixed sessions, each fault on its own, a large account's reset, seeds 1–25 and three jittered
seeds. Long runs take seed ranges; `TRUTH_SHAPE=large` and `TRUTH_TIMING=jitter` select the world and the timing:

```sh
bash docs/superpowers/plans/2026-10-25-state-sync-truth-server/run-truth.sh 1 5000 /absolute/outdir 250
TRUTH_SHAPE=large TRUTH_TIMING=jitter \
    bash docs/superpowers/plans/2026-10-25-state-sync-truth-server/run-truth.sh 1 1000 /absolute/outdir 250
```

They write `results.txt` (one `TRUTH seed=` line each) and `seed-<n>.txt` (a failing seed's steps, requests and
world). A change to state sync runs 1–5000 and the large world, and compares with the last runs; a new failing seed
gets a shrunk test before its fix. The comparison with master, and every model ruling, is
`docs/superpowers/reports/2026-10-25-state-sync-truth-run.md`.

## Pointers

- `docs/state-sync-audit-2026-10.md`: the dated audit (issue ids, the original cost model).
- `docs/superpowers/specs/2026-10-14-state-sync-refactor-design.md` (design, Constraints) and
  `docs/superpowers/specs/2026-10-15-difference-too-long-design.md` (the differenceTooLong rules).
- `docs/superpowers/plans/`: the stage plans, kept as history.
- `docs/superpowers/plans/2026-10-14-state-sync-foundation/followups.md`: what each stage parked.
