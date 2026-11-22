# Handoff: account state sync refactor (TelegramCore), 2026-10-16

You are taking over a long-running, owner-approved project. Everything you need is in this repository; you do not
have the previous agent's memory. Read this file first, then the documents in "Read before doing anything".

**On master:** the branch was squashed onto origin/master and pushed on 2026-10-26, the second truth-server round
included (section 3). Master carries the code, the map and this file, not the plans and specs.

**Commit SHAs:** the branch was squashed on 2026-10-24 (section 6g). Every SHA this file, `docs/state-sync.md` and the
plans cite from before the squash resolves on the branch `refactor/state-sync-unsquashed` (tip `95d61fc151`), not on
`refactor/state-sync`.

## 1. What the project is

**The owner's request (2026-10-14, verbatim):** "Use a separate worktree. The task is to map and understand how state
syncrhonization works in this app (begin with getDifference). It is very likely that it contains issues. Explore it
carefully, and refactor in a way that's more understandable. Later there will be a task to optimize state sync. Use
workflows with 5 agents max."

"State sync" is TelegramCore's `AccountStateManager` and `Sources/State/Sync/`: how pushed updates, `updates.getDifference`,
`updates.getChannelDifference` and the account reset keep the local Postbox consistent with the server.

**How it was decided to proceed (with the owner):**
1. A behaviour-preserving refactor in stages, every step proven equivalent by an end-to-end harness; clear-cut bug
   fixes as separate commits, each flipping a pinned test. Design-level changes wait for the later optimization task.
2. No Swift concurrency (TelegramCore is shared with Telegram-Mac, macOS 10.13 target).
3. The fixes (stage 7) were moved ahead of stages 3-6 (2026-10-15), so stages 3-6 restructure the fixed code.
4. Correct `differenceTooLong` handling was added (it had been avoided because it left stale or deleted messages
   in regular chats).
5. A follow-up plan closed the review findings parked along the way.
6. **Stages 3-6 run straight through** (owner, 2026-10-15/16): for each stage, write the plan and execute it
   subagent-driven without asking for a plan review. Stop only for a decision the approved spec does not settle,
   an irreversible or destructive action, a security-sensitive action, or anything outside the worktree (merge,
   push, publish).

## 2. Owner rules (binding on every change)

- **Never give up.** Verbatim: "notion in the state update path should ever give up, unless it's a log out kind of
  situation. We always continue trying to sync" (read "notion" as "nothing"). It applies to this project in general:
  use retries with backoff, never a terminal give-up arm. Restated 2026-10-24: "we never abandon syncing or message
  history loading" (history fills included; a fallback that is never asked again is giving up).
- **"The notification extension should not perform resets."** (`standalonePollDifference` never resets the account;
  a `differenceTooLong` there is reported as done and the app resets.)
- Stages 3-6 are **behaviour-preserving** relative to the fixed code. A behaviour change found mid-stage is reported,
  not made.
- **At most 5 agents per workflow invocation.**
- **Nothing is pushed or merged without the owner's go-ahead.** The owner has not yet chosen merge / PR / keep; the
  branch stays as it is.
- Owner decisions from the follow-up plan (D1-D4) are recorded in
  `docs/superpowers/plans/2026-10-15-state-sync-followups.md`; do not reopen them.

Repository-wide constraints that apply here (CLAUDE.md has the full text):
- TelegramCore and Postbox are shared with Telegram-Mac: no UIKit/Display, no new availability-gated API, public API
  changes in place only (AccountStateManager's public declarations must stay identical), persisted encodings
  (PostboxCoding, `AuthorizedAccountState`, `ChannelState`) byte-identical.
- Builds use `-warnings-as-errors`.
- `Queue.async` and `deliverOn` run **inline** when already on the target queue (`SwiftSignalKit/Source/Queue.swift`).
  Ordering depends on it (a `differenceSlice` continuation runs before update groups pushed mid-poll). No step may add
  a real dispatch where an inline call happens today, or remove one. An always-on-queue `queue.async` may become a
  direct call only with `assert(queue.isCurrent())` and a caller list.
- Dictionary iteration order feeds branch-merge order in channel recovery: keep container types.
- Swift 6.4 miscompile: never write a local `let` closure with a `[weak x]` capture list that also captures a
  mutable local and never escapes (CLAUDE.md, "Swift 6.4").
- No new `import Postbox` / `.postbox` access outside `submodules/Postbox/AllowedImporters.txt` /
  `AllowedPostboxAccess.txt` (TelegramCore itself is exempt from the import check).
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` (or your own model's trailer
  as your harness instructs).

## 3. Where the work is

- **Worktree:** `/Users/isaac/build/telegram/telegram-ios/.claude/worktrees/state-sync`, branch `refactor/state-sync`.
  Work only there; never edit the main checkout at `/Users/isaac/build/telegram/telegram-ios`.
- **Base:** forked from master `171825ce49`; master `c3fcf41452` merged in (`2723861064`, 2026-10-17). Squashed
  into `f1c0728549` (parent `c3fcf41452`) and local master `ef00982a6e` merged in (`00174d6bdd`, 2026-10-24), so the
  branch was 0 behind master then (section 6g). origin/master `d987d8c350` merged in (`03960a647e`, 2026-10-25,
  section 6i), then origin/master `9b9d2a1e60` (`873002c928`). **Squashed onto local master** as `fab57187eb`
  (2026-10-25, owner: "squash to master without plan/spec md files"): the tree of `873002c928` without the 157 plan
  and spec files the branch added, the six test-running scripts the docs name kept. Master's history does not
  include this branch's; the plans, specs and the history stay here. Local master was later rebased (outside this
  branch's sessions) onto origin's `8118594d36`, the squash becoming `40b47bc99a`, unpushed. **Pushed** on 2026-10-26
  (owner: "Squash to master and push"): origin/master `bf0a4a9253` merged in (`a2c2a85c50`), the branch was squashed
  again onto `bf0a4a9253`, without the 158 plan and spec files it added (the same six scripts kept), and that commit
  was pushed, replacing `40b47bc99a`.
- **HEAD:** the docs commit that records the second truth-server round (section 6k). The last production-code changes
  are `f862115ee2` (an around fill asks `min_id` 0) and `1ef6b0874b` (the chat-list fill's hole), both after the first
  squash and on master since the pushed one; before them `921221c323` and `6d12b53a1d` (an edit made while a fetch was
  in flight is kept) and `90e043a22c` (an upward fill asks for its range's end id); before them the merge `03960a647e`
  (section 6i), `fb7830bddf`, the revert of the third of the second review's six commits (`a6c08d574f`..`a984930c63`,
  section 6h), the review's fixes to the earlier merge (`5f2052fa10`), that merge `00174d6bdd` and the squash
  `f1c0728549`.
  Before the squash (on `refactor/state-sync-unsquashed`): `0f993ea6d5` (the confirmation's channel half removed),
  `99c7fabc20` (the reset deletes its ghost tail without asking), the merge `2723861064` and stage 5's `6843ce1736`.
  Stage 6 closed at `6aec0bd878`, stage 5 at `7f2be2cb79`, stage 4 at `657bf38223`; at the first handoff:
  `8d988ffb25`.
- **Uncommitted:** nothing (the stage-4 appendix, the four helper scripts of section 8 and this file are committed).

## 4. Read before doing anything

In this order:
1. `docs/state-sync.md` — the living map of state sync as the code is now (layout, paths, invariants with what pins
   each, cost model, open issues, how to change it safely). `docs/state-sync-audit-2026-10.md` is the dated audit
   behind it (issue ids G*, Q*, C*, R*, D*, each marked fixed or open).
2. `docs/superpowers/specs/2026-10-14-state-sync-refactor-design.md` — the approved refactor spec: stages, sections
   2 (typed seams, done), 3 (operation queue, stage 4), 4 (replay phases, stage 5), 5 (order, verification, docs).
3. `docs/superpowers/plans/2026-10-16-state-sync-stage5.md` — the most recent plan (with its appendix, including the
   architect's binding `design.md`); its shape is the model for stage 6.
4. `docs/superpowers/plans/2026-10-16-state-sync-stage5/research-notes.md` — the stage-5 checker's notes.
5. `docs/superpowers/plans/2026-10-14-state-sync-foundation/followups.md` — parked items and design decisions, incl.
   "Parked from stage 3", "… stage 4" and "… stage 5" (wording for the stage-6 docs pass).
6. CLAUDE.md: the build/test sections, and the `Tests/StateSync` paragraph under "Project Structure".

Background, read when needed:
- `docs/superpowers/specs/2026-10-15-difference-too-long-design.md` (+ `-exploration.md` in `reports/`): the
  differenceTooLong design (every regular-chat history fill confirms stored messages the server no longer returns
  with `messages.getMessages` before deleting them; since 2026-10-24 the reset deletes every stored message above a
  fetched dialog's top without asking, and the chat-list fill leaves them; `pts_total_limit` from app config, default
  10000).
- `docs/superpowers/reports/2026-10-15-state-sync-q13-poll-result-loss.md`: the Q13 wedge investigation.
- Plans already executed: `2026-10-14-state-sync-foundation.md` (stages 0-2), `2026-10-15-state-sync-fixes.md` (stage 7),
  `2026-10-15-difference-too-long.md`, `2026-10-15-state-sync-followups.md`, `2026-10-16-state-sync-stage3.md`, each
  with an appendix directory of task pages.

## 5. What is done

| Phase | Commits | Result |
|---|---|---|
| Audit + spec | `edf897053c`, `6de76d061d` | map, 45 verified issues, 7-stage spec |
| Stage 0: harness | `776dfdebd4`..`76ab288616` | `Tests/StateSync`: the real `AccountStateManager` over a temp Postbox and a `ScriptedServer` fake `NetworkEngine` (`Network.makeForTesting`); characterization tests named by audit ids |
| Stage 1: dead code | `6058f00925`..`7005701e8d` | the audit's safe dead code, 28 commits (one per group) |
| Stage 2: split | `99dfa95c4f` | `AccountStateManagementUtils.swift` split into `Sources/State/Sync/` |
| Stage 7: fixes | `69939c45c0`..`dd60e8fe42` | Q13, Q1, Q2, Q11, Q12, Q4, Q3, G4, R1, R2, R6, C2, C3, C11, G1, G2 (one commit each, each flips its pin) |
| differenceTooLong | `06918f6b7c`..`2ffe3d39aa` | correct handling: confirm-before-delete in the reset and the fills, reset continues the cycle with backoff, `pts_total_limit` from app config, Debug Settings override, chain logs |
| Follow-ups | `b0cace5902`..`6c34438d9f` | 24 tasks (dead code, fill retries, deletion record, min-copy rule, `getHole(containing:)` semantics, deletion events after commit, pins) |
| Stage 3: typed seams | `39893d49f7`..`8d988ffb25` | `SequenceSpan`, `ChannelRecoveryRequests`, `SyncChannelRecovery.swift`, `DifferenceOutcome`, `AccountFinalState.followUp`, `ReplayPolicy` + `FinalStateReplayer.applyReplay`, `ChannelPollOutcome`, `struct UpdateInterpreter` with 11 `UpdateInterpreter+<Family>.swift` files, `AccountFinalStateEvents` init without defaults; final fixes + 4 new pins |
| Stage 4: queue and collaborators | `84ce7f51f8`..`657bf38223` | `StateOperationQueue` (13 unit tests), `AccountStateEventHub`, `ChannelResetCoordinator`, `DifferencePolicy` + `fetchAndApplyDifference(policy:)`, `finishPollCycle` the single `isUpdating = false`, the spec's operation names, `Impl` internal with one runner per kind in `AccountStateManager+<Kind>.swift`, `addOperation` a direct call + assert; final-review fixes (a re-entry pin, docs) |
| Stage 5: replay phases | `37e526ba9f`..`866500fa01` | `ReplayRejection` (verify), `ReplayPrepass.prepare`, `final class ReplayContext` (61 members; the loop, `finalize`'s 24 named steps in `StateReplay+Finalize.swift`, `buildResult`), 84 per-operation methods in 12 `StateReplay+<Family>.swift` files, `batchContentAndDeferStateOperations` + `StateAdvance` + `applyStateAdvance`, `StoreMessage(updating:attributes:tags:)`; 16 unit tests, strengthened after the mutation check; comment fixes |
| Stage 6: documentation | `6c6b08516f`..`6aec0bd878` | `docs/state-sync.md` (the living map; fact-checked sentence by sentence against the code), a CLAUDE.md section "Account state sync (TelegramCore)" after "Project Structure", the wording parked by stages 3-5 (comment lines only), one test's data restored |
| Merge with master | `2723861064`..`dce1a6a79f` | master `c3fcf41452` merged (section 6d): its two edits of the deleted `AccountStateManagementUtils.swift` re-applied in `Sync/`, 3 replay tests for the non-member read-state skip, map invariant 30 |
| Ghost tail without asking | `99c7fabc20`..`b31b90ba6b` | owner, 2026-10-24 (section 6e): the reset deletes every stored message above a fetched dialog's top in its own transaction, with no `getMessages`; the chat-list fill leaves them |
| Confirmation without channels | `0f993ea6d5`..`95d61fc151` | owner, 2026-10-24 (section 6f): `confirmStoredMessages` asks only `messages.getMessages`; its unused channel half is removed |
| Squash, merge with master | `f1c0728549`..`9262d6658e` | owner, 2026-10-24 (section 6g): the branch squashed into one commit; local master `ef00982a6e` merged (`00174d6bdd`), its `Holes.swift` and deleted-file edits ported; the review's fixes (`5f2052fa10`) |
| Second review's fixes | `a6c08d574f`..HEAD | owner, 2026-10-25 (section 6h): six defects, one commit and one first-failing test each; the third (only `messageEmpty` deletes) reverted on the owner's ruling, `fb7830bddf` |

**Verified at the end of stage 3:** TelegramCoreTests 510, 0 failures, three runs in a row at `162509cba2` (and 20
consecutive runs at `c8f03248d4`, the last task commit, 506). PostboxTests 209. Full app build green. TelegramCore's
public declaration lines identical to the stage's base (11,561). Every group review and the final review (on the most
capable model) approved; the fix round's re-review found everything addressed.

**Still open for the owner (not yours to decide):**
- Merge / PR / keep for the branch. Telegram-Mac's preferences key 52 (`stateSyncDebugSettings`) was closed by the owner
  on 2026-10-17: app-specific keys are offset by 1000, no other TelegramCore preference uses 52, and a second case with
  raw value 52 would fail to compile. The changed semantics of Postbox `Transaction.getHole(containing:)` (it now
  answers exactly the hole that contains the id; `1063ed2c33`) were accepted by the owner on 2026-10-17. Master is
  merged into the branch (sections 6d, 6g); a later master needs another merge, and master has since been rebased
  (section 6h).
- Before users get it (the agent's recommendation, 2026-10-24): a signed device build, and internal testers on real
  devices for a while; Telegram-Mac has not been built against this TelegramCore.

The manual simulator checks are done (section 6g): a cleared chat is not listed with `top_message` 0.

**Left for the later optimization task (do not fix during the refactor):** Q5 (gap-wait drops date groups merged
during the wait), Q6 (a refused replay or mid-request state change re-polls without delay; pinned as-is by
`DifferenceCharacterizationTests.testStateChangedDuringGetDifferenceAppliesNothingAndPollsAgainFromTheNewState`), Q9's
replay-twice race and its AUTH_KEY_DUPLICATED half, C1, the Q4 delivery order (preserved and pinned by `e28b87763f`),
and the rest of the spec's list (section 5, "Left for the optimization task"). The audit marks each.

## 6. Stage 4: done (2026-10-16, second session)

Executed exactly as below, then closed: plan `docs/superpowers/plans/2026-10-16-state-sync-stage4.md` (plan base `84ce7f51f8`), tasks Q1
`ff70d77058`, E1 `afa749634b`, E2 `e0fbc53c1b`, D1 `bfa01cc432`, D2 `bd49a63843`, Q2 `c4a7a5c594`, N1 `5ec13a1356`, N2 `f77e7a63a7`, N3
`05869707ef` (added: `addOperation`'s always-inline `queue.async` → direct call + assert, spec 3.2), final-review fixes `91d771782b` +
`03fee4886b`, bookkeeping `657bf38223`. Each task commit was reproduced byte for byte from the appendix scripts on its parent; no compile fix
was needed anywhere. Verified: TelegramCoreTests 529/0 after every task; app build green; PostboxTests 209; 20 consecutive runs at
`05869707ef` (529) and 20 at `03fee4886b` (530); every one of the 20 new unit tests seen failing under a scratch break of its rule;
public declaration lines identical (11,561); SwiftPM `swift build` fails as at baseline. Four group reviews and the final review (opus)
approved; one fix round, re-review all addressed. Leftovers: `followups.md` "Parked from stage 4".

**Rulings taken in stage 4 (owner-visible record; each: what — why — cost if wrong):**
- N3 added (spec 3.2), callers re-checked on the composed tree — cost: an off-queue caller the list missed would race in release.
- E1/E2 teardown-only lifetime changes accepted — cost: a teardown-time event ordered differently.
- `addPollCompletion`/`removePollCompletion` keep their names (public `pollStateUpdateCompletion`) — cost: a non-spec name to stage 6.
- Old names in test prose and log strings left for stage 6 — cost: stale wording meanwhile.
- Q4 delivery order preserved (pinned by `e28b87763f`) — cost: unchanged until the optimization task.
- N2's duplicated `private typealias SignalKitTimer` accepted — cost: cosmetic.
- No compile-RED Bazel cycle for Q1/E1/E2/Q2; D1 ran its characterization tests on the old code — cost: none.
- Execution in groups with one review per group — cost: a review sees several commits.
- N1/N2 commit messages kept although three clauses are inexact on the executed tree (rewording = rewriting history the ledger cites) —
  recorded in followups.
- Final review I1 fixed with a re-entry pin + doc; M1/M2/M5 doc fixes; M3 (hub hops always inline, not converted) and M4
  (`currentIsUpdatingValue` internal since N1) parked; the deferred-minor triage followed the final reviewer.
- Re-review leftovers (a grammar slip, an unpinned order on the replay branch that the harness catches) parked for stage 6.

## 6b. Stage 5: done (2026-10-16, second session)

Plan `docs/superpowers/plans/2026-10-16-state-sync-stage5.md` (plan base `37e526ba9f`; the architect's binding
`design.md` and the drafted pages in its appendix). Tasks V1 `e32422e0af`, P1 `4cb7dfcce9`, C1 `6b4607ac23`, M1
`24c1904134`, B1 `3b9cb99304`, F1 `fb84a45e17`, S1 `6843ce1736`; fix round `a118ed1f1f` (tests) + `866500fa01`
(comments). Every task commit was reproduced byte for byte from the appendix scripts on its parent; no compile fix was
needed. Verified: TelegramCoreTests at each task's count (536, 539, 539, 539, 545, 545, 546; 0 failures); app build
green; PostboxTests 209; 20 consecutive runs at `6843ce1736` (546) and 20 at `866500fa01` (546); public declaration
lines identical (11,561); SwiftPM `swift build` fails as at baseline. Five group reviews and the final review (opus)
approved with no Critical/Important finding; the base `replayFinalState` was rebuilt from the final files and matches
except the designed edits. The mutation check saw all 16 new tests fail under a break of their rule and found 15
surviving variants; the fix round strengthened the tests to kill 13 of them (the other two are unpinned by design).
Leftovers: `followups.md` "Parked from stage 5" (incl. a release build before a merge).

**Rulings taken in stage 5 (owner-visible record; each: what — why — cost if wrong):**
- The architect's design (section 0's ten rulings) is binding: `ReplayContext` a `final class` (an escaping optional
  callback mutates an accumulator), exactly three rewrites of moved lines (`self.` in the `.DeleteMessages` callback,
  value-copy capture lists in the two account-manager closures), all 86 switch labels kept, `ReplayRejection`
  precedence (account state over channels, every channel still logged), entry-point signature and log strings
  unchanged, four `private` helpers internal — cost: a task's rework.
- Design open questions answered "no" (the rejection does not travel up through `applyReplay`; the log line does not
  name it; test prose left for stage 6; `walletStoreMessage` untouched; `applyUpdatedThemes` not split) — cost: items
  parked in followups.
- M1's six family-doc wraps over 120 columns approved; F1's doc-wrap reading kept — cost: none.
- No compile-RED Bazel cycle for any task; a failing NEW test with an IDENTICAL reproduction would be ruled a
  test-authoring defect (none failed) — cost: none.
- Execution in groups G-V, G-PC, G-M, G-B, G-FS with a review per group running beside the next implementer — cost: a
  review saw up to two commits.
- The fix round strengthened the stage's own tests to kill the mutation survivors (they are the only guard for most
  of these rules: the harness caught none of 14 rule mutations) — cost: none found; the clean run passed.
- The read order of `verify` and the channel logging when both checks fail stay unpinned (logs only) — cost: a log
  regression unseen.
- Seven comments corrected after review (some were `design.md`'s exact text, which stays as written); two extra
  fire-and-forget entries in `finalize()`'s doc accepted after checking they are asynchronous starts — cost: none.

## 6c. Stage 6: done (2026-10-17, second session)

Plan `docs/superpowers/plans/2026-10-16-state-sync-stage6.md` (plan base `6c6b08516f`). W1 `01e7488a99` (the parked
wording), W2 `43960db9d8` (`ReplayPrepassTests` test 2 pins the activity timestamp's raise again), D1 `9cfc8fbaf2`
(`docs/state-sync.md` + the audit's dated-record line), C1 `2eca07d0aa` (CLAUDE.md), fix round `25b0d62565` (comments)
+ `e201d3fdcc` (map, CLAUDE.md, audit line). The map was drafted by a workflow (four readers returning
evidence-backed claims, one writer), fact-checked by four adversarial checkers (503 sentences, 43 corrections), the
corrections re-checked (6 more), then reviewed as a whole. Verified: Sources changed in comment lines only (each file
hashes the same with comment lines removed; the log-line multiset is unchanged); TelegramCoreTests 546/0 after each task
and 3/3 at the stage end; app build green; public declaration lines identical (11,561); the CLAUDE.md section merges
with master's CLAUDE.md without conflict (`git merge-file`). Leftovers: `followups.md` "Parked from stage 6", which also
records the **merge hazard** the final review found (master's `updateReadFeed` removal and its edits of the deleted
`AccountStateManagementUtils.swift`).

**Rulings taken in stage 6:**
- Comment lines only in Sources; unused imports stay (a code change) — cost: harmless unused imports remain.
- Non-wording leftovers (the hub's always-inline hops, `currentIsUpdatingValue` internal, two unneeded `@escaping`,
  `addPollCompletion`'s name) are documented in the map instead of changed — cost: none.
- Plan documents and commit messages are history and stay as written — cost: some describe drafts, not the result.
- W2 was in scope (the stage-5 fix round had moved one rule's coverage) — cost: none.
- No 20-run loop (comment-only Sources, one test's data): 3 runs — cost: a flake in that one test would show later.
- The map was workflow-drafted and adversarially fact-checked; a fix of the fixes was re-checked before commit — cost:
  none.
- The CLAUDE.md section moved after "Project Structure" (the first placement conflicted with master) — cost: none.
- The merge hazard is recorded, not resolved: merging is the owner's decision — cost: the merge needs manual work.

## 6d. Merge with master: done (2026-10-17, second session, owner's go-ahead)

Master `c3fcf41452` merged in `2723861064` (its message lists the port). The one conflict, modify/delete of
`AccountStateManagementUtils.swift`, keeps the deletion; master's `868c10a93c` and `ed476ab8b5` are re-applied where
their code now lives: `.updateReadFeed` and `applyReadFeed` behind `TELEGRAM_NEWS_FEED_API` (UpdateInterpreter),
`cloudReadInboxMarks` in the prepass, the non-member skip at the top of `applyContentOperations`'s loop,
`localReadMarkIsAheadOfServer` in `applyResetReadState`. `75ed6c6d1f` adds `NonMemberChannelReplayTests`; `843c401875`
is the review's map wording. Verified: TelegramCoreTests 624/0 (546 + master's 75 + 3; 3 runs), PostboxTests 222/0 (209
+ master's 13), debug app build green, `release_sim_arm64` app build green; and the same app build with release_arm64's
Swift features (`swift.opt_uses_wmo`, `swift.opt_uses_osize`: `-Osize -whole-module-optimization`, confirmed on
TelegramCore's compile with `aquery`) green, no SimplifyCFG crash. A review on the most capable model of the resolution
(`git show --remerge-diff`) and of the map: nothing blocking, four nits, three fixed.

**Rulings taken in the merge:**
- A merge commit, not a rebase — the commit SHAs the docs cite stay valid — cost: a merge commit in history.
- The port is in the merge commit, so every commit builds — cost: review it with `--remerge-diff`, not `git show`.
- `cloudReadInboxMarks` and master's comments copied verbatim, `cloudReadInboxMarks` into `StateReplayPrepass.swift`
  — cost: master's comment "the way the replay below judges it" overstates the agreement (the map states the rule).
- `applyReadFeed` guarded whole (its parameter type is gone at layer 232) — cost: none.
- Master's `NonMemberChannelReadStateTests` lost its `.UpdateIsContact` line (the branch removed that operation as
  dead code) — cost: none, the two assertions beside it pin the same rule.
- `NonMemberChannelReplayTests` added (not asked for): master's tests pin the helpers, not the hand-applied wiring —
  cost: three tests to maintain.
- The release check is a simulator build with release_arm64's Swift features, not a signed device build — cost:
  device-only steps (Rust fat LTO, device code generation, stripping) were not exercised here; CI's device build is.
- Review nit 4 (a whitespace-only line made empty) left — cost: none.

## 6e. The reset's ghost tail without asking: done (2026-10-24, owner's decision)

The owner's question was whether the branch could ship to everyone at once. The review behind the answer found a stall:
the reset confirmed its ghost tail with `messages.getMessages`, which retried every error but CHANNEL_PRIVATE and
CHANNEL_INVALID without limit, and the poll waits for the reset. A definite answer there (a `TL_` parse failure, or
FROZEN_METHOD_INVALID on a frozen account) would have stopped syncing for the session and again on every launch, and
the app configuration (the server's `pts_total_limit` off switch) is fetched only after the first finished sync
(`AccountTaskManager`). The owner's ruling, in two steps:
- "We should simply delete all messages in that chat that are later than its top id": the reset deletes every stored
  Cloud message above a fetched dialog's top in its own transaction, as a received deletion (cached media and deletion
  events included), with no request. Safe because the reset moves pts to the one differenceTooLong carried, which
  precedes the dialogs answer: anything newer is delivered again by the follow-up getDifference (pinned by
  `testResetDeletesAMessageNewerThanTheAnswerAndTheFollowUpDifferenceBringsItBack`; the replay never consults the
  record of recent deletions, only history fills do). A reply sent during the reset disappears for a moment, with the
  chat's delete animation, and returns in the same cycle; its cached media is deleted with it and downloaded again (by
  construction: the tests use text messages).
- "I would skip this chat-list complication": the chat-list hole fill does nothing about the ghost tail. It moves no
  pts while updates keep being applied, so deleting would lose a message that arrived while its page was in flight; a
  chat beyond the reset's first page keeps its ghost tail when that page is fetched later (the pre-fix behaviour).

`99c7fabc20`: `confirmStoredMessagesAboveTopMessages` and `ConfirmedGhostTail` removed; the deletion half of
`applyStoredMessageConfirmation` is `deleteStoredMessagesAsReceivedDeletion`, shared with the reset;
`storedCloudMessagesAboveTopMessages` returns ids only and is read inside the reset's transaction after the page is
stored; a stale reset or chat-list fill writes nothing. Tests: 12 new or rewritten, all red before the change (the old
code sent `getMessages`), green after; the stale-answer tests are delayed by a held `getPinnedDialogs` instead of the
confirmation. TelegramCoreTests 619/0, 3 runs (624 less the 5 chat-list ghost-tail tests). Mutation checks (scratch edits,
reverted): a reset that deletes nothing fails the 9 tests that pin its deletion and nothing else; a chat-list fill that
deletes above the top fails its 2 pins; a replay that skips recently deleted messages fails the comes-back pin. The spec
(section 3 point 3, its test plan), the map (the reset, invariants 12, 14 and 15, the cost model, a new open issue) and
CLAUDE.md are updated.

**Rulings taken:**
- The deletion happens after both stores, where the confirmation was applied, before the read states are reset — cost:
  a reply target stored above its chat's top would be deleted at once (the server's top says it cannot be there).
- `deleteStoredMessagesAsReceivedDeletion` reports the deletion events before the history fill's refresh instead of
  after it — cost: none (disjoint ids; the report defers its pipe to `afterCommit`).
- The history fill's definite-answer stall is listed, not fixed — it was not asked for; the owner then decided to keep
  it (section 6f).

## 6f. The definite-answer stalls kept, the confirmation's channel half removed (2026-10-24, owner's decisions)

A history fill's confirmation (`confirmStoredMessages`: `messages.getMessages` through `retryRequest`) retries a
definite answer forever, and the fill writes nothing until it answers. `ManagedMessageHistoryHoles` never cancels a
pending fill (its removal is commented out) and starts no second one for the same peer, thread and space, so that part
of the chat stays loading for the session, with a request every 5 s, and again after a relaunch; a stuck preload fill
keeps one of the preloader's three slots. It needs a candidate and a definite answer to `getMessages`; the plausible
case is a frozen account, if `getMessages` is blocked there while `getHistory` is not (a question for the server team).

Owner, 2026-10-24: "we never abandon syncing or message history loading", then "Keep the hole". Options declined:
- treat a definite answer as no verdict, store the page and close the hole: the candidates are never asked about again
  (gives up);
- close the hole and keep confirming in the background from a list saved in Postbox (pending message actions): the chat
  loads, but candidates nobody confirmed show as history, which the confirmation plan exists to prevent (a closed hole
  tells the view its range is complete);
- close the hole only up to the nearest candidate: shows nothing unconfirmed, but helps only as far as that message and
  still needs the saved background check.

No code changed for it; the spec (section 4, amended) and the map (invariant 12, "Open issues") record it.

The reset's own `messages.getDialogs` (`retryRequest`, `FetchChatList.swift`) has the same shape: it retries a definite
answer forever and, since the poll waits for the reset, a definite one stops the whole sync. Owner, 2026-10-24: "Yes,
getDialogs should retry forever." Without a chat list there is nothing to reset from; no code changed, and the map's
"Open issues" records it.

The confirmation's channel half had no caller since `99c7fabc20` (a history fill reconciles only private chats and basic
groups; the reset no longer confirms). On the owner's go-ahead `0f993ea6d5` removed it: the `channels.getMessages`
requests and their access-hash lookup, the CHANNEL_PRIVATE / CHANNEL_INVALID exception and the refused-channel tracking,
and the channel pts stamped on refreshed copies; a channel id is skipped and logged. Kept:
`deleteStoredMessagesAsReceivedDeletion`'s channel arm (the reset uses it) and the forum lookup through `knownPeers`.
Private-chat and basic-group ids get the same requests, retries and parsing as before. Tests:
`testAChannelIdIsSkippedAndNothingIsAskedAboutIt`, red before the change and green after; the four channel tests of
`StoredMessageConfirmationTests` removed. TelegramCoreTests 616/0, 3 runs (620 less 4). No public declaration changed;
the app build was not rerun (TelegramCore-internal; the test target compiles it with the same flags).

## 6g. Squashed, then master merged in again (2026-10-24, owner's request "Squash here, then merge sync with master")

**The squash.** The 198 commits from the fork to `95d61fc151` (master `c3fcf41452` already merged in) are one commit,
`f1c0728549`, whose parent is `c3fcf41452` and whose tree is identical to `95d61fc151`'s. The unsquashed history is kept
on the branch `refactor/state-sync-unsquashed` (tip `95d61fc151`): every commit SHA this file, `docs/state-sync.md` and
the plans cite resolves there, not on `refactor/state-sync`. Do not delete that branch while the docs cite it.

**The merge.** Local master `ef00982a6e` (origin/master `95e6a449c9` plus four unpushed News commits: `f8ec431c66`,
`a3ead22db0`, `326d0f2e6a`, `ef00982a6e`) merged in `00174d6bdd`, 212 commits. The port is in the merge commit, so every
commit builds; review it with `git show --remerge-diff 00174d6bdd`. Three conflicts:
- `AccountStateManagementUtils.swift`, modify/delete: the deletion is kept. Master's two edits re-applied where their
  code now lives: `dd2ac9155f` (API layer 233, the news feed with no switch) removed `TELEGRAM_NEWS_FEED_API`
  everywhere, so the two guards the earlier port had added (`.updateReadFeed` in `UpdateInterpreter.swift`,
  `applyReadFeed` in `UpdateInterpreter+ReadStates.swift`) are gone (the tree has no `TELEGRAM_NEWS_FEED_API` left, as
  master); `51c8a7e596` extracted `storeFetchedForumTopic`, now at the end of `Sync/SyncResolve.swift` and called from
  `resolveForumThreads(additionalPeers:ids:)` as master does.
- `Holes.swift` (`fetchMessageHistoryHole`), from `51c8a7e596` (one round trip; skeletons for late references):
  - the branch's structure stays: the filled range is decided from the answer before anything is written, a private
    chat's or basic group's fill confirms first, `storeAndCloseHole(transaction, confirmation, peers)` keeps the answer
    age check, the recent-deletion filter and `historyFillAnswerToStore`;
  - master's replacement of the version-guarded re-add is taken whole: no `StoredVersions`; `missingReferences`
    registers the stored messages waiting for a reply target or story in `PendingMessageReferences`, and the follow-up,
    started inside the store transaction, releases them and rewrites them from their current rows
    (`storeMessageRewritingCurrent`);
  - a forum or monoforum stores first unless a message's topic info is neither stored nor in the answer
    (`forumFillStoresFirst`); the answer's missing topics are stored with the messages;
  - kept from the branch: the confirmation's peers win (D3) for every write, the follow-up included (reply stories
    too); reply targets deleted meanwhile are not stored (D2); the follow-up's answers are stored only while none is
    older than the deletion record, otherwise it fetches again (now a recursive `referencedDataFollowUp()` signal, so
    the registration is released only when it has stored).
  Only channels are forums, and only private chats and basic groups confirm, so no fill both confirms and decides
  store-first by topics.
- `CLAUDE.md`: master's rewrite (subsystem notes go beside their code) is taken. The branch's "Account state sync
  (TelegramCore)" section moved to `submodules/TelegramCore/Sources/State/CLAUDE.md` (with the cleared-chat fact and the
  confirm-first exception to master's "a history fill stores before it resolves"), and the root lists it under
  "Subsystem guides". `submodules/Postbox/CLAUDE.md` names `UpdateInterpreter` for the web-page media removal.

Auto-merged and checked: `ManagedMessageHistoryHoles.swift` (master threads `pendingReferences` through; the
never-cancel and one-fill-per-key rules are unchanged), `Account.swift` (the same plumbing), `Network.swift` (HLS's
`downloadThroughputMeter`, unrelated). Master moved the `submodules/TgVoipWebrtc/tgcalls` gitlink; its checkout was
updated to `ea0f24e32f` before building. The map's history-fill passage describes the merged behaviour.

**The review** (one agent, given the merge commit, not these conclusions) found nothing blocking; `5f2052fa10` fixes
what it raised:
- Master's debug cold-load resets (`-resetCommentsCache`, `-resetForumCache`) clear a chat's stored messages locally
  and add a hole; the branch's record of recent deletions then kept the next fills from storing them for five minutes
  while they closed the hole (an empty thread measured; a dropped post never back). Postbox gained
  `Transaction.forgetRecentlyDeletedMessages(peerId:)` (`RecentlyDeletedMessages.forget`), which both resets call
  after their local removal; two PostboxTests pin it. Debug builds only.
- The guides said more than the code: the never-give-up rule names today's exceptions again (invariant 12), the
  recent-deletion filter covers history fills and their follow-up but not yet the forum-topic resolution's topic
  messages, and forums are not said to store first always. Two forum test headers and the map's file list updated.
- Left as they are (noted here): `missingReferences` and the follow-up read the whole answer, not what was stored, so
  a message the deletion filter left out can be registered and its reply target fetched (harmless: `updateMessage`
  skips a missing row, `release` is idempotent; a wasted request); and `redrawMessages` bumps a message's
  `stableVersion`, so a confirm-first fill of the same chat that read it before can skip deleting it (narrow, the
  same kind as the old version-guarded re-add).

**Verified** at `5f2052fa10`: debug_sim_arm64 app build green; TelegramCoreTests 688/0, three runs in a row (616 +
master's 65 net + 7 feed tests the removed `TELEGRAM_NEWS_FEED_API` guard used to compile out; the merge commit alone
also ran 688/0 three times); PostboxTests 228/0 (the two new tests included); `release_sim_arm64` app build green;
and the same app build with release_arm64's Swift features (`swift.opt_uses_wmo`, `swift.opt_uses_osize`: `-Osize
-whole-module-optimization`, confirmed on TelegramCore's compile with `aquery`) green, no SimplifyCFG crash. Not a
signed device build.

**The two manual simulator checks are done** (K1, 2026-10-24, against the real server, at `95d61fc151`):
- A 40-pts gap with Debug Settings ▸ "Difference limit" = 10: `differenceTooLong`, the reset (chat list, pinned
  chats, archive), pts moved, the follow-up getDifference final; the preloader refilled the gap's chats within seconds.
- A chat cleared from another client (a 4773-pts gap): the server does not list it with `top_message` 0. It keeps the
  old top id and date as a `messageService(messageActionHistoryClear)`, so the reset deletes nothing there and the
  history fill's confirmation empties the chat (438 stored messages: 200, 200, 38; one `FLOOD_WAIT_30` waited out).
- K1 has Debug Settings ▸ "Skip read history" on: nothing is read there, so local service notifications ("New login"
  in 777000) stay unread. Not a defect.

## 6h. The second review's fixes (2026-10-25, owner: "Yes, do it"; one reverted)

A second review of `master...refactor/state-sync` (the code-review skill at xhigh; each of its 15 findings checked
against the code before it was reported) found six defects in the branch's own code. The owner had them fixed, one
commit each, each with a test that failed first (all six were seen failing for the reason they name, then passing).
The owner then declined the third (below), which `fb7830bddf` reverts:
- `a6c08d574f`: the confirmation parses each `messages.getMessages` answer in a transaction, its chats merged with the
  stored copies (`AccumulatedPeers(transaction:chats:users:)`), as the fill parses its own. Before, a min channel in
  the answer cleared the stored channel's admin rights, banned rights and restriction info. The review said it also
  lost the access hash and membership; it did not (`mergeChannel` in `updatePeersCustom` keeps both), and the first
  test, written for that claim, passed before the fix and was rewritten for the admin rights.
- `39df5b7cb7`: ManagedMessageHistoryHoles re-evaluates its entries when the 20 s pause of a finished entry ends
  (`ManagedMessageHistoryHolesPause`, a one-shot timer). A fill that ended with nil (a definite answer, an answer too
  old to store) was otherwise never started again in a quiet chat, though the comments said it was.
- `ca177f9d13`, **reverted by `fb7830bddf`**: it made only an id answered as `messageEmpty` missing, leaving an id
  the answer leaves out stored. The owner: "a left out message is considered deleted". Spec §4's "not returned:
  delete" stands; the ruling is now stated in `StoredMessageConfirmation.missing`, the map's invariant 14,
  `State/CLAUDE.md` and spec §§4 and 8. Do not propose it again. The revert restored
  `testMessageEmptyAndOmittedIdsAreMissing` (seen failing on the reverted code first) and the 18 fixtures.
- `3e1a779f8a`: a candidate answered as gone (`messageEmpty` or left out) but written again while the confirmation
  was in flight stays stored and gets a one-message hole, so the next fill asks again; the range used to close over
  it. Pinned: the hole and the message kept; not pinned: the next round that deletes it, which rests on the hole
  manager starting a new hole entry at once and the fill reading 11 as a candidate again.
- `fb712b966a`: the reset and the chat-list fill never lower a channel's `invalidatedPts` (the pts still follows the
  dialog, as in master). `pollChannel`'s too-long arm and `resetChannels` still set it to the dialog's pts, as master
  does; not touched.
- `a984930c63`: `RecentlyDeletedMessages.forget` also drops the chat's recordings from the capacity order.

Kept as they are (reported to the owner): Q5 and the channel reset's reference cycle while a reset is in flight
(master's own shapes); the `pts_total_limit` default of 10000 (spec §5: an account more than 10000 updates behind now
resets instead of fetching slices; worth confirming with the server team) and the confirmation's endless retry ("Keep
the hole"), both owner decisions. For the optimization task: the deletion record also holds local-only deletions (a
future local cache trim must call `forget`, or the record could hold server deletions only); a deletion sequence
number instead of the 5-minute window would remove the four "answer too old" restarts; the deleted-message id mapping
is written three times; the reset and the chat-list fill repeat the same restart code; `Network.makeForTesting` is
compiled into release builds.

**Verified** at `a984930c63` (all six): debug_sim_arm64 app build green; TelegramCoreTests 692/0, three runs in a row
(688 + the four new tests; two rewritten in place); PostboxTests 229/0; `release_sim_arm64` green; the same build
with `swift.opt_uses_wmo` and `swift.opt_uses_osize` green. The intermediate commits were not built one by one (each
fix's files are its own; the shared files were split by exact replacements, checked to reproduce the tested tree).
After the revert, at `fb7830bddf`: TelegramCoreTests 692/0; the full set ran after the next merge with master
(section 6i). Not a signed device build; no simulator check of these fixes.

**Master moved after the merge:** it was rebased, and the four News commits merged in `00174d6bdd` (`f8ec431c66`,
`a3ead22db0`, `326d0f2e6a`, `ef00982a6e`) are on master as other commits (`bbac62cc8c`, `300df05632`, `8b451f59e4`,
`39c805ed7e`, pushed), on top of four new ones. The branch therefore carries the old copies; before it goes into
master, merge the new master in (or redo the merge on it) and check that the old and new copies' trees agree.

## 6i. origin/master merged in again (2026-10-25, owner: "do the sync now")

`03960a647e` merges origin/master `d987d8c350` (14 commits since the merge base `95e6a449c9`). It is origin's, not local
master's: local master then had three unpublished commits, and local master's unpublished commits merged in
`00174d6bdd` had been rebased before they were pushed (section 6h), leaving the branch with old copies.
- **The duplicated News commits.** The branch's old copies (`f8ec431c66`, `a3ead22db0`, `326d0f2e6a`, `ef00982a6e`)
  and origin's rebased ones (`bbac62cc8c`, `300df05632`, `8b451f59e4`, `39c805ed7e`) make the same changes. origin
  then dropped the feed-rows spec and plan (`044d09550b`, "master stays code-only"), which a merge keeps from the old
  copies, so the merge deletes both. Checked: every file the branch's own work (`ef00982a6e..41ba546f8b`) does not
  change is identical to origin/master's; the one other difference is the new `ShortSentMessageTests.swift`. The old
  copies stay in the branch's history.
- **`e6d99316c6`** ("fix(share): ignore pts update in share extension") conflicted in `Account.swift` and
  `AccountStateManager.swift`. `ignoresShortSentMessages` is threaded through the branch's manager (`Impl` keeps it;
  `reset()` hands it to `UpdateMessageService`, which drops `updateShortSentMessage`), `Account` passes `supplementary`
  and `standaloneStateManager` `true`, as on master. The outer init takes it before the branch's defaulted
  `gapWaitTimeout`, so master's call sites are unchanged. The harness passes `false` unless asked;
  `ShortSentMessageTests` pin both cases; the map's ingress section names it.
- TelegramCore's public declarations differ from origin/master's exactly as they did from `ef00982a6e` before the
  merge (`public-diff.sh`): the branch's `StateSyncDebugSettings` and the removed `getDelayNotificatonsUntil()`.
- No submodule pointer moved.

**Verified** at `03960a647e`: debug_sim_arm64 app build green; TelegramCoreTests 698/0, three runs in a row;
PostboxTests 229/0; `release_sim_arm64` green; the same build with `swift.opt_uses_wmo` and `swift.opt_uses_osize`
green.

## 6j. The truth server, and edits kept over older answers (2026-10-25)

Owner: "we need to make everything to make sure this works no worse than before" (the outcome to avoid: "messages
missing"), then "write your own server for testing and run all these test sessions", then, for the race it found,
"Remember recent edits of messages the app hasn't loaded".

- **The truth server**, `Tests/StateSync/TruthServer/`: plan
  `docs/superpowers/plans/2026-10-25-state-sync-truth-server.md` (`e4f7f089ef`), executed inline, tasks 1–5 in
  `16d01163a7` … `2be3e61864` and `342f7a1b67`. How it works and how to run it: the map's "Changing state sync
  safely". The run and every model ruling: `docs/superpowers/reports/2026-10-25-state-sync-truth-run.md`.
- **Results.** No message missing in 5000 branch seeds or 500 master seeds. Master gets 6 of 500 wrong that the branch
  gets right (deleted messages stored again by a late fill; the Q13 wedge). The branch had two branch-only results
  (seeds 1540, 4967), both a stale edit, now fixed (below).
- **`90e043a22c`**: an upward history fill asks `max_id` one past its range's end (exclusive on the server); a one-id
  hole `1 ... 1`, which the reset leaves under a top of 2, lost message 1 (17 of 5000 seeds). The other request kinds
  keep exclusive bounds (reported, not changed).
- **`6d12b53a1d`, `921221c323`: a fetch stores an edit made while it was in flight.** Postbox records every edit the
  replay receives (`RecentlyEditedMessages`: latest per message, 5 minutes, 1000 messages, in memory), and every fetch
  that filters recent deletions stores, in place of an answer message, its edit recorded since the request went out
  (`fetchedMessagesWithRecentEdits`; invariant 14). Two calls past the owner's wording, both in the report: the edit is
  stored rather than a one-message hole left (a hole is a missing message until the next fill), and stored messages'
  edits are recorded too (4967's message was stored; the first diagnosis, which said it was not, was wrong).
- **The master baseline** lives in `.claude/worktrees/state-sync-truth-master`, branch `test/state-sync-truth-master`
  (local, never merge or push): the harness ported to master (`01b9335521`), the wedge cap (`9af9ef4fec`), the opt-in
  server-side limit and reset count (`f50a7164c9`), reports for passing seeds (`51d7dabffc`). Only the four bazel-rules
  submodules are cloned there.
- **Open:** whether the real server keeps a cleared chat's history-cleared service message in history (the oracle does
  not judge it; one check against the server); the harness does not run `HistoryViewStateValidation`, so channel
  messages below `invalidatedPts` are reported as validation pending, not judged.

**Verified** at `921221c323`: debug_sim_arm64 app build green; TelegramCoreTests 740/0 (1 skipped, the long run);
PostboxTests 234/0; `release_sim_arm64` green; the same build with `swift.opt_uses_wmo` and `swift.opt_uses_osize`
green; truth seeds 1–5000 with no failing seed (4162 exact, 838 validation pending only; 9 stale before the fix).
Not a signed device build; no simulator check of the fix.

**Final review** of `03960a647e..921221c323` (a fresh reviewer, the plan's last step): no Critical. Its two Important
findings: the docs commit, now made; and, for a stored message, the raw recorded edit written over the replay's merged
copy on the paths without a confirmation, which loses what the merge kept (the user's live-location local tag, a kept
translation). Kept as it is: those stores wrote the answer's raw copy over the same messages before, and skipping a
stored message would leave the hole above a skipped top message in the reset and the chat-list fill. Its five minors
were done afterwards (owner: "Do the deferred minors"): comments on the downward `getHistory` `min_id` and on an early
`since`, and the doc comment's line break (`1f1d844b04`, comments only); a test that a retry resets the fill's `since`
(`d0fb7f302f`, failing first on a mutant without the reset); the truth driver reporting a fill that never answers as no
convergence at once, instead of filling the chat again (`de6209a021`, its test failing first). Store sites that apply
neither filter (pinned-chats sync, history validation, the in-cycle dialog resolution) are outside D2's scope;
widening it is the owner's call.

## 6k. A more representative truth server, and two fixes it found (2026-10-25)

Owner: "continue refining the server model into a more representative one to be more sure", after the squash onto
local master `fab57187eb` (section 3). Plan `docs/superpowers/plans/2026-10-25-state-sync-truth-server-2.md`
(`ba4a0f4b4d`), executed inline; ledger in `.superpowers/sdd/2026-10-25-state-sync-truth-server-2/progress.md`. The
run, the results table and every model ruling: report section 9.

- **The model gained** the app's channel revalidation in `converge` (`2f16405faf`; edits now carry `edit_date`,
  `ba409db1ab`), a large world of 129 chats with two long chats opened at a message and scrolled (`dc8f588d56`), the
  chat list in the oracle (`0c32e943bc`) and 0–50 ms jitter on every answer and push (`35b3f7ba50`). Every one of the
  838 seeds that ended validation pending before ends exact.
- **`1ef6b0874b`: the chat-list fill leaves a hole above a private chat's or basic group's fetched top** (owner chose
  "Leave a hole"). Large-world seeds 698 and 916: a chat beyond the reset's first dialogs page kept a message deleted
  while offline as its last message for good, which the owner's 2026-10-24 ruling (section 6e) had accepted. The fill
  still deletes nothing; the chat's next history fill confirms.
- **`f862115ee2`: an around history fill asks `min_id` 0.** Large-world seed 1667: a channel opened at its first post
  asked with `min_id` 1 (exclusive) and closed the hole over the post it left out. On master too, since at least
  2020. The seven sibling around requests (`getReplies`, `getSavedHistory`, mentions, reactions, poll votes, the two
  searches) send `min_id` 1 the same way and were left alone (ledgered ruling: no model path drives them).
- **Both fixes are on master** since the squash pushed on 2026-10-26 (section 3).

**Verified.** At `35b3f7ba50` (the model's four tasks, before both fixes): small 1–5000 and jittered small 1–2000 exact.
At `1ef6b0874b`: debug, `release_sim_arm64` and `-Osize`/WMO builds green; TelegramCoreTests 755/0 (1 skipped);
PostboxTests 236/0; large 1–2000 1999 exact (1667, fixed next); jittered large 1–300 exact. At `f862115ee2`: the same
matrix green (TelegramCoreTests 757/0, 1 skipped; PostboxTests 236/0); large 1–2000 all 2000 exact. At `836b57550a`
(production code as `f862115ee2`): TelegramCoreTests 758/0 (1 skipped); small 1–5000 all 5000 exact; jittered small
1–2000 all 2000 exact. At `a2c2a85c50` (origin/master `bf0a4a9253` merged in; TelegramCore, Postbox and TelegramApi as
`836b57550a`, so the truth runs carry over): the same matrix green (TelegramCoreTests 758/0, 1 skipped; PostboxTests
236/0); the squash pushed on 2026-10-26 is its tree without the plans and specs.

**Final review** of `f588f9a2dc..f862115ee2` (a fresh reviewer): no Critical. Its Important finding, the model's
dialogs paging ignoring `offset_peer` on a tie of date and id (a test the plan asked for), fixed in `6e55155434`
(test failing first; no seed changes, every message has its own date). Deferred minors: the chat-list hole costs one
extra `getHistory` when the newer message is a legitimate push (the view shows its messages meanwhile); `settle`
under jitter can call rest one hop early (a flaky seed, not a false exact); `ScriptedServer.cancel` records only
held cancellations.

## 6a. Stage 4 as it was planned (kept for reference)

**Status:** drafted, not started. A drafting workflow (4 area agents + 1 checker) wrote the appendix
`docs/superpowers/plans/2026-10-16-state-sync-stage4/`:
- task pages `task-Q1.md`, `task-E1.md`, `task-E2.md`, `task-D1.md`, `task-D2.md`, `task-Q2.md`, `task-N1.md`,
  `task-N2.md` (design, today's code with file:line, edits, tests with full code, equivalence checks, commit message);
- exact edits `tasks-{Q,E,D,N}.json` applied by `apply_task.py` (`python3 <appendix>/apply_task.py . <ID> --check|--tests|--prod`);
- self-checking move scripts `move_E1.py`, `move_E2.py`, `move_Q2.py`, `move_N1.py`, `move_N2.py`
  (`python3 <appendix>/move_<ID>.py . [--dry-run]`; each verifies the moved lines are identical as a multiset, every
  unit present once, order preserved, and writes nothing on failure);
- `research-notes.md` from the checker. `n_impl_switch.py` is an N-area scratch helper; drop it unless a page uses it.

**Tasks, in order (one commit each), with the expected TelegramCoreTests count on today's HEAD:**

| # | ID | What | Count |
|---|---|---|---|
| 1 | Q1 | `StateOperationQueue`: the operations array and its placement rules leave `AccountStateManager.Impl` (12 unit tests) | 522 |
| 2 | E1 | `AccountStateEventHub`: the event pipes, subscriber contexts and the `processEvents` fan-out (`move_E1.py`) | 524 |
| 3 | E2 | `ChannelResetCoordinator`: the asynchronous channel resets (`move_E2.py`) | 526 |
| 4 | D1 | `DifferencePolicy` + `fetchAndApplyDifference(policy:)` for the app's poll and the extension's | 528 |
| 5 | D2 | `isUpdating` changes only through `finishPollCycle` | 528 |
| 6 | Q2 | operation kinds take the spec's names; `gapWait` has no payload; `gapWaitTimeout` an init parameter (`move_Q2.py`) | 529 |
| 7 | N1 | `Impl` visibility (`private final class` → internal) (`move_N1.py`) | 529 |
| 8 | N2 | one runner per operation kind in `AccountStateManager+<Kind>.swift` (`move_N2.py`) | 529 |

The pages were drafted against `c8f03248d4` (count 506). The checker re-composed on `162509cba2` (510): every task
applies and type-checks, and the counts above are the drafted counts + 4. **Nothing has been built or run yet; the
19 new unit tests have never executed.**

**Checker's equivalence summary (research-notes.md has the full tables):** no public change (swift-api-digester dumps
identical); queue hops `queue.async` 20 → 20, `deliverOn` 14 → 13 (the app's and the extension's
`finalStateWithDifference |> deliverOn(queue)` became one line in a shared function; each path still makes exactly one
hop), others unchanged; teardown-only lifetime changes in E1 (two disposables disposed in the hub's deinit) and E2
(the first reset transaction retains the coordinator, not the Impl).

**Rulings still to record before execution (the previous agent's proposals; the spec settles the first):**
1. Spec 3.2 asks for `addOperation`'s `self.queue.async` to become a direct call with `assert(queue.isCurrent())`. The
   drafts left it out; `task-N2.md` gives the exact replacement and the 9 callers, all on the queue. Add it as its own
   task N3 after N2 (re-check the callers on the composed tree; backed by
   `DifferenceCharacterizationTests.testSliceContinuationRunsBeforeGroupsPushedMidPoll` and
   `testResetFollowUpRunsBeforeGroupsPushedDuringTheReset`).
2. Accept the two teardown-only lifetime changes; the reviewers confirm them.
3. Keep `addPollCompletion`/`removePollCompletion` (they serve the public `pollStateUpdateCompletion`).
4. Prose mentions of old names in test doc comments and strings are left for stage 6 (log strings stay by design).
5. Q4 delivery order is preserved (behaviour-preserving stage; already ruled 2026-10-16).

**Next actions:**
1. Read `research-notes.md` ("Remaining", "Equivalence risks per task") and skim each page.
2. Write `docs/superpowers/plans/2026-10-16-state-sync-stage4.md` in the shape of the stage-3 plan: header, goal,
   architecture, global constraints (section 2 above), rulings, review focus (from "Equivalence risks per task"), how
   every task runs, the task table with counts, the stage-end checklist. Commit it with the appendix.
3. On a fresh scratch copy of HEAD (`git archive HEAD submodules/TelegramCore | tar -x -C <dir>`), run every task's
   `--check` and move script `--dry-run` in order to confirm it still applies.
4. Execute (section 7). Suggested groups: G-Q1 (Q1), G-E (E1, E2), G-D (D1, D2), G-QN (Q2, N1, N2, N3). Use a capable
   model for the implementers of the move-script groups.
5. Stage end: full app build, PostboxTests 209, 20 consecutive TelegramCoreTests runs at the final count,
   public-declaration diff against the plan base, SwiftPM `swift build` recorded as-is (it fails at baseline:
   it expects Telegram-Mac's checkout layout). Then the final review, one fix round, a scoped re-review.

## 7. How the stages have been executed (keep doing this)

**Planning:** a plan = a main document + an appendix directory. Exact edits go into `tasks-<AREA>.json`
(`{"id","title","testReplacements","newTestFiles","prod","newProdFiles"}`, each replacement `{"file","old","new"}` with
`old` occurring exactly once) applied by `apply_task.py`; large verbatim moves go into deterministic self-checking
`move_<ID>.py` scripts. Drafting was done by one workflow: up to 4 area agents in parallel plus one checker that
composes all tasks in order on a scratch copy, fixes collisions in the later task, runs `xcrun swiftc -parse`, diffs
public declarations and hops, and writes `research-notes.md`. Every grep a page specifies must be checked to detect
what it claims on the tree before the task (git grep's `-E` ignores `\b`/`\s`: use `-P`).

**Execution (subagent-driven):**
- A ledger at `.superpowers/sdd/<plan-name>/progress.md` (git-ignored; first line names the plan file). It records
  every dispatch, commit, review result and ruling as `Ruling: <what> — <why> — <cost if wrong>`. After any
  interruption, trust the ledger and `git log` over recollection; never re-dispatch a task that has a commit.
- Tasks run in groups: one implementer per group, one commit per task, the suite green after each at the page's
  count. Only one writer in the worktree at a time; read-only reviewers may run concurrently but must read fixed
  commits (`git show <commit>:<path>`), never the working tree.
- Implementers must read each page in full, run `--check` / `--dry-run` first, run the page's equivalence checks,
  fix compile errors minimally and report each, **never edit a test to make it pass** (a failing harness test after
  a refactor means behaviour changed: stop and report), and never dispatch subagents.
- After each group: an equivalence review (a capable model) that maps old branches to new handlers, checks hops,
  iteration order, optional-valued dictionary writes, error paths, Signal semantics, lifetimes, public lines, and the
  plan's review-focus paths. Reviews so far also reproduced each commit byte for byte from the JSON/scripts on the
  parent commit, which is a cheap, strong check.
- After the stage: the full-stage review on the most capable model, one fix dispatch carrying every ruled finding,
  a scoped re-review. New pin tests are mutation-checked (break the pinned line in a scratch edit, see the test fail,
  revert). Leftover wording goes to `followups.md`. Then delete the plan's `.superpowers/sdd/` workspace.

**Current step: the owner's decision.** Stages 0-6, the fixes, the merge with master and the ghost-tail change are done
(sections 5, 6, 6b, 6c, 6d, 6e, 6f; also the confirmation's channel half removed). The branch waits for the owner: merge
into master locally, push and open a PR, or keep it. Still open before that: section 5's "Still open for the owner" (the
differenceTooLong simulator check). After that, the later optimization task starts from the map's "Open issues".

## 8. Commands

All from the worktree root.
- TelegramCoreTests: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh test` (a few minutes;
  reads the codesigning password from `~/.zshrc` itself). Judge a run by the **last** `Executed N tests, with 0
  failures` line in `bazel-out/*/testlogs/submodules/TelegramCore/TelegramCoreTests/test.log` plus exit 0; per-suite
  lines also say "with 0 failures" and do not count.
- Full app build: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-make.sh build`.
- PostboxTests: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-postbox.sh`.
- N consecutive suite runs: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/run-loop.sh 1 20 <outdir>`
  (stops at the first failure; per-run logs in `<outdir>/run-N/`).
- Review package for a reviewer: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/review-package.sh <outdir> <name> <base> [head]`.
- Public-declaration diff: `bash docs/superpowers/plans/2026-10-14-state-sync-foundation/public-diff.sh <base> <head> <outdir>`.
- Harness logging: `STATE_SYNC_LOG=1` shows TelegramCore's log in a test run. A test whose Postbox is still retained
  5 s after `close()` fails (set `retainedPostboxAtCloseReason` only when a test leaves work in flight on purpose).

## 9. Environment gotchas seen in this project

- The previous session's Bash guard refused `git -C`, `source ~/.zshrc`, and compound one-liners mixing git with
  shell variables or loops. Put multi-step shell into a script file and run `bash <path>`; run plain git commands
  from the worktree root.
- Subagents' writes of report files into `.superpowers/sdd/` were usually refused ("Subagents should return findings
  as text"); the controller copied each hand-back into the workspace.
- Agents occasionally died mid-run (an API 400 "advisor_tool_result", and once an account spend limit, HTTP 429,
  which killed every agent at once). Recovery: check `git status`/`git log`, resume the agent by message where the
  harness allows it, or dispatch a fresh one with the remaining work; a workflow can be resumed by run id.
- The disk filled once (ENOSPC) while other worktrees built; the owner freed space. Retry; never delete caches.
- The stage-end SwiftPM `swift build` of TelegramCore fails at baseline (dependency resolution:
  `FlatSerialization` custom path, `ssignalkit` identity conflict); record it, do not try to fix it.
- XCTest traps on `assert`, so the queue's assert-only mismatch paths have no tests; the harness cannot read log
  lines (no log observer).
