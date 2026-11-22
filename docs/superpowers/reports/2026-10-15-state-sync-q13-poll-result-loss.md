# Flake: `DifferenceCharacterizationTests.testDifferenceTooLongResetsAccountAndStaysUpdating`

> Investigation report (2026-10-15) behind audit id Q13. The run logs and the diagnostic patches it
> cites lived in a session scratchpad and are not preserved; the deterministic pins are in
> `submodules/TelegramCore/Tests/StateSync/PollResultLossCharacterizationTests.swift`. Line numbers
> are at commit 99dfa95c4f. Flow 3 was later made deterministic (2a9a090588: 0 stalls in 1200
> in-process iterations, was 22).

**Fixed** in 69939c45c0 (main path) and 95dfbca87a (notification extension).

**Status: PRODUCTION_FINDING (classification B).** The test reproduces at ~2%. The cause is a real
ordering race in production code: `pollDifference` can drop its own result and wedge the operation
queue. The harness's instant scripted answers make that race reachable. Nothing was changed to hide
it. One commit pins it deterministically: `1294e48a29`, on top of `99dfa95c4f`. It touches tests
only.

## 1. Runs

| Run | What | Result |
| --- | --- | --- |
| run-1 … run-9 | `run-make.sh test`, full target (341 tests), diagnostics on | 9/9 green |
| stress-full-j4 | bazel `--runs_per_test=20 --local_test_jobs=4 --test_env=STATE_SYNC_LOG=1`, full target | 20/20 green |
| inproc-1 | temporary test that repeats the class's preceding test and the flaky test in one process, with a fresh fixture each time (200 iterations, stops at the first stall) | stall at iteration 16, in both the preceding scenario and the tooLong scenario |
| inproc-2 | same, continues after a stall | 3/200 tooLong stalls, 0/200 preceding |
| inproc-3 | same, 4 processes × 300 in parallel, account state printed | **22/1200 tooLong stalls (1.8%)**, 0/1200 preceding |
| inproc-4-pred | preceding scenario only, 6 processes in parallel (all hit bazel's 300 s timeout) | 0 stalls in ~3,500 iterations |
| proof-1 | forced interleaving vs. free, alternating, 40 iterations | forced **20/20** stall, free 19/20 pass (1 natural stall) |
| run-10 … run-12 | `run-make.sh test` on the final tree (344 tests). run-10 ran on the identical uncommitted tree; run-11/12 on `1294e48a29` | 3/3 green |

Logs: `/private/tmp/claude-501/-Users-isaac-build-telegram-telegram-ios/9ae333e4-0d4b-4eb3-b1f1-7eacdf630830/scratchpad/flake/`
(`run-N/`, `stress-*/`). The diagnostics and stress tests are dropped from the branch. They are kept
as patches in `…/scratchpad/diag-patches/` (3 files, apply on `99dfa95c4f`).

The suite runs never failed (0/29 for me). The rate only shows in-process, because each suite run
executes the scenario once.

## 2. Failing-run evidence (identical in every stall, inproc-1/2/3)

```
TOOLONG stalled: drain 3.0 s names ["updates.getDifference"]
  state=(pts: 100, qts: 5, seq: 10, date: 1700000000)   # seeded state, untouched
  isUpdating=[true]
  request [0] +0.011 updates.getDifference
  deliver [0] +0.011 updates.getDifference result        # the answer WAS handed to Network
  cancelled=[]  unused one-shot handlers: [getState, getDialogs, getPinnedDialogs]
raw probe (help.test through the same Network/server): answered in 0.05 ms
```

The first failure dump (inproc-1) also shows:
- **No queue is stuck.** These all answered in under 1 ms: `Postbox.sharedQueue`, a Postbox
  transaction, `engineQueue`, `MTContext.contextQueue`, the manager's queue (an `isUpdating`
  subscription), and the global queues.
- **No thread is stuck.** `/usr/bin/sample` shows only the main thread and one idle thread.
- **The main thread is not involved.** Spinning the main run loop for 1 s changed nothing.
- **Nothing retains the chain.** The Postbox was released at once in `close()`.

So the value is lost, not stalled. This matches the original failure exactly:
- names `[getDifference]` gives 5 failed assertions: the timeout, prefix, Set, count and state.
- `isUpdating == [true]` and `significantUpdates` empty still pass.
- The 10.3 s duration is the 10 s drain plus a fast close.

## 3. Root cause

`pollDifference` (`submodules/TelegramCore/Sources/State/AccountStateManager.swift:799-917`) is:

```
postbox.transaction {…}            // :799
|> deliverOn(self.queue)           // :822   (D1)
|> mapToSignal { … network.request(getDifference) … |> retryRequest |> mapToSignal { tooLong → .single(…) } }   // :823-913
|> deliverOn(self.queue)           // :915   (D2)
signal.start(next: { … resetState → _internal_resetAccountState … })   // :917, :921
```

Two facts about SwiftSignalKit cause the loss:
- `deliverOn` uses `Queue.async` for every event (`Signal_Dispatch.swift:3-21`). `Queue.async` runs
  the block inline when the caller is already on the target queue (`Queue.swift:60-66`) and
  dispatches it otherwise.
- `Subscriber.putNext` ignores a terminated subscriber (`Subscriber.swift:152-163`).

The interleaving:
1. The transaction (Postbox thread) sends its value and its completion through D1. That queues two
   blocks back to back on the manager queue Q: **A** (value) and **B** (completion).
2. Q runs A. `mapToSignal` starts the inner signal, which sends `getDifference`. `ScriptedServer`
   answers on `engineQueue` at once.
3. The engine thread then runs the whole inner chain synchronously. It maps `differenceTooLong` to
   `.single((nil, nil, false, true))`, and the value reaches D2 from the engine thread. D2 dispatches
   it to Q as block **C**, which is queued behind B. The inner signal completes, and `mapToSignal`'s
   state records that nothing is executing (`Signal_Meta.swift:60-104`). This all happens **before Q
   gets to B.**
4. Q runs B. The outer completes, and `beginCompletion` sees nothing executing, so it completes the
   whole signal (`Signal_Meta.swift:106-116`) on Q. D2's completion handler calls `Queue.async`, which
   runs **inline**, so the final subscriber terminates.
5. Q runs C: `putNext` on a terminated subscriber does nothing. The `start(next:)` closure never runs:
   - no `_internal_resetAccountState`, so no `getState`;
   - no `operations.removeFirst()`.

**Consequence.** The poll stays at the head of the operation queue, marked running, for good:
- `replaceOperations` keeps running operations (`:542`).
- `startFirstOperation` returns on a running head (`:781`).
- So `reset()` cannot recover it. Later pushes, polls and barriers are queued and never run, and
  `isUpdating` stays true. In the app, that is "Updating…" forever and no updates processed until
  relaunch. The pin test checks reset, a push and a barrier after the stall.

**Proof (forced vs free).** A new harness hook, `ScriptedServer.answerBeforeCallerContinues(name,
after:)`, forces step 3 to finish before B runs:
- `add` blocks until `engineQueue` has run a `Postbox.sharedQueue.sync {}` barrier and delivered the
  answer.
- The barrier guarantees B is already queued.

Result: forced 20/20 stall with the original signature (names = 1, pts 100, isUpdating [true]);
unforced 19/20 normal (names = 4, pts 500). The operator-level mechanism also reproduces 100% in a
pure SwiftSignalKit test, with a control that keeps the value when the inner finishes after the
outer completion.

### Classification: B (production race), exposed by the harness's timing

- **Boundary 1, the one that flakes.** The answer must beat one hop on the manager queue. Over a
  real network that practically never happens: the RTT is far longer than A→B. The scripted server
  answers in microseconds on another thread, so it happens 1.5–2% of the time, more under load.
- **Boundary 2, independent of the server.** Inside the same chain:
  `finalStateWithDifference |> deliverOn(queue) |> mapToSignal { postbox.transaction { replayFinalState } }`
  (`:860-899`) has the same shape. The replay transaction on the Postbox thread races Q going from
  that `deliverOn`'s value block to its completion block. If the replay wins, the result is dropped
  **after** the replay committed: the state advances, events are lost, and the queue is wedged as
  above.
  - In production, Q only has to be descheduled, or other blocks queued between those two, for the
    length of a replay transaction. That is rare, but the outcome is permanent.
  - Evidence: inferred from the code. It was seen once (inproc-1, iteration 16, the preceding
    `differenceEmpty` scenario stalled with only `getDifference` logged and delivered) in ~5,000
    iterations. By elimination it is this boundary: boundary 1 cannot drop an empty difference,
    whose inner signal needs another Q hop that sits behind B. The account state was not captured
    in that run.
- `processUpdateGroups` (`:1002-1036`) does not have the hazard. Its last `deliverOn` is inside the
  inner signal, so value and completion reach the subscriber in Q's FIFO order. `standalonePollDifference`
  and the rest of TelegramCore were not audited.

Not environment (C): the stall is a lost value with every queue idle, and it reproduces on demand
when forced.

## 4. What was committed

`1294e48a29` — *TelegramCore tests: pin the pollDifference result loss behind the differenceTooLong flake*
(tests only, no production change):
- `Tests/StateSync/ScriptedServer.swift`: `answerBeforeCallerContinues(_:after:)`, a one-shot per
  name, off by default. Every existing test is unaffected.
- `Tests/StateSync/PollResultLossCharacterizationTests.swift`:
  - `PollResultLossCharacterizationTests.testDifferenceAnsweredBeforeThePollContinuesIsDroppedAndWedgesTheQueue`.
    Deterministic part: after `server.flush()` and one manager-queue round trip, the request log is
    `[getDifference]`, the state is the seed, and `isUpdating` is `[true]`. A delivered result would
    have sent `getState` synchronously from the block that received it. Wedge part: `reset()`, an
    in-order push and a barrier get nothing done. This uses a 0.3 s negative wait, the same pattern
    as the Q12 test.
  - `DeliverOnOrderingCharacterizationTests`: the SwiftSignalKit hazard alone (the value is lost) and
    its control (the value is kept). Fully deterministic, using gates rather than sleeps.
- Verified: run-10/11/12 green, 344/344 each.

Neither DIAG commit (`5bb0a54260`, `3daaf2ec54`) nor the third diagnostic commit is on the branch.
They were dropped with a reset to `99dfa95c4f` before the commit above. `99dfa95c4f` and earlier
commits are untouched.

## 5. What is NOT done, for the caller to decide

- **The existing test still flakes** at its measured rate (~2% per execution of that test) until
  the production defect is fixed. When it is fixed, the fix commit flips the pin (Q13) like the
  other Q-pins.
- **Harness option (not implemented; arguably papering over).** Make every scripted answer arrive
  only after the requesting manager queue has drained what it already had queued. This would remove
  boundary-1 interleavings that a real RTT never produces. It cannot remove boundary 2. With the
  forced pin in place it would no longer hide the defect, but it is a decision about what the
  harness models.
- **Production fix options** (a behaviour change, so a later task). The plan's constraint keeps
  `Queue.async`/`deliverOn` inline.
  - (a) In `pollDifference`, drop the trailing `deliverOn(self.queue)` and have `start(next:)` hop
    with `queue.async` itself. The value is captured in the block, so an earlier completion cannot
    drop it.
  - (b) Make SwiftSignalKit's `deliverOn` order-preserving: an event that arrives on the target
    queue while an earlier dispatched event for the same subscriber is still pending is dispatched
    too, not run inline. This is broad; audit the users.
  - Either way, consider a watchdog for a poll that never completes. Q11 (`.never()` on
    `dialogsNotModified`) wedges the same way.
- Proposed audit entry: **Q13 (Medium)** — "`pollDifference`'s result can be dropped by `deliverOn`
  reordering (an inline completion overtakes a dispatched value), wedging the operation queue
  permanently (survives `reset()`). M:799-917, 860-899; `Signal_Dispatch.swift:3-21`;
  `Queue.swift:60-66`."
