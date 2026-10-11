# Composer harness — operating manual

A standalone iOS app that hosts the **real** Telegram chat composer against a synthetic, loginless
app context, so an agent can drive it and turn every defect it finds into a regression test.

Findings log: [`docs/findings.md`](docs/findings.md).

## What this is, and what it is not

**Real, and therefore worth filing bugs against:** `ChatTextInputPanelNode` →
`RichTextEditorChatInputNode` → `RichTextEngineEditorView`. Every line of composer and editor code
under test is the shipping one.

**Synthetic, and therefore not worth filing bugs against:** the app context (`HarnessAccountContext`
and friends), the fake history, the toolbar, the model readout, and the layout driver in
`HarnessRootViewController`.

**In scope:** the composer panel and a fake message history.

**Out of scope, by decision** — do not extend the harness into these without agreeing it first:
the expanded editor round-trip (`RichTextAttachmentScreen`), the legacy↔native dual-field latch,
and drafts / send-edit round-trips.

> **The one standing caveat.** Telegram lays the panel out with `ChatControllerNode`, which has
> keyboard machinery this harness does not reproduce. **Findings about HEIGHT or INSETS are
> provisional** until reproduced in the real app; record them in `findings.md` as `provisional`.
> Findings about the model, caret, formatting, paste or send run through code the harness does not
> touch and stand on their own.

## Build, test, run

All commands run from the worktree root (`.claude/worktrees/inputdec-backend`).

```bash
BZL=./build-input/bazel-9.2.0-darwin-arm64
CACHE=--disk_cache=$HOME/telegram-bazel-cache

# Build the app
$BZL build $CACHE --ios_multi_cpus=sim_arm64 //Tests/ComposerHarness:ComposerHarness

# The three test targets
$BZL test $CACHE //Tests/ComposerHarness:HarnessAppContextTests   # hostless, model only
$BZL test $CACHE //Tests/ComposerHarness:ComposerHarnessTests     # Tier 1, in the app process
$BZL test $CACHE //Tests/ComposerHarness:ComposerHarnessUITests   # Tier 2, XCUITest

# One class
$BZL test $CACHE --test_output=all --test_filter='HarnessSendTests' \
  //Tests/ComposerHarness:ComposerHarnessTests
```

- **`--test_filter` takes a CLASS name, not a method name.** A bare method name matches nothing and
  the run prints a cheerful pass having executed zero tests. Always read the `Executed N tests`
  line.
- **A bare `bazel build` of a `swift_library` here fails with `no such module 'UIKit'`.** Only a
  top-level `ios_application` / `ios_unit_test` / `ios_ui_test` supplies the iOS platform. Build
  through one of those.
- **Never `//Tests/ComposerHarness:all`**, tempting though it is. The wildcard picks up the bare
  `swift_library` targets and builds them for the host, so the run ends in
  `no such module 'UIKit'` from somewhere deep in `submodules/` — a failure that looks like a
  broken dependency and is only the platform. Name the three test targets.
- **Test simulators are reused, deliberately.** The three test targets set
  `env = {"REUSE_GLOBAL_SIMULATOR": "1"}`, so runs share one `BAZEL_TEST_<device>_<os>` simulator per
  runner. Without it the default runner creates a fresh `New-<device>-<os>` simulator per run and
  leaves it BOOTED (23 after one session, slowing the machine). Other `ios_unit_test` targets in the
  repo still do that; pass `--test_env=REUSE_GLOBAL_SIMULATOR=1` when running them, and delete stray
  booted `New-*` simulators you created. **Reuse has a trap the runners now handle:** installd will
  not replace an installed app at an unchanged build number, so a reused simulator can run the
  PREVIOUS build. Both runners set `pre_action = ":UninstallHarnessFromTestSims"`, which uninstalls
  the harness from every booted `BAZEL_TEST_*` simulator before each run (verified: installed binary
  md5 == fresh .ipa). Don't remove it.
- **The reused test simulator can run a STALE host app.** With the host's version unchanged,
  installd keeps the previously installed `ComposerHarness.app` (hard-link cache, the same trap
  as the root `CLAUDE.md`'s `simctl install`), so a test run after an app-side change can execute
  the OLD code while the built `.ipa` is fresh. Measured 2026-09-23: the installed binary lacked a
  string the built one had, and a fix read as "not working" for three runs. Before a run that must
  see a change to app code, uninstall the host from the Bazel test simulators
  (`xcrun simctl uninstall <BAZEL_TEST_… udid> org.telegram.ComposerHarness`); the runner reinstalls
  it. A green result from before an uninstall proves nothing about a change made since.
- **Repeat a test with a shell loop and `--nocache_test_results`, never `--runs_per_test`.** Bazel
  runs the repeats CONCURRENTLY on the one reused simulator, and the second is killed before it
  starts ("Test crashed with signal kill before establishing connection", exit 12) — a failure that
  says nothing about the test (p16 fix wave).
- Read **the build's own** exit code, not a background task's: grep the output for
  `Build completed successfully` or the `ERROR:` line.

### Install and drive on K1

**K1 only.** K3 carries the user's logged-in Telegram and must never be touched by this work. The
harness's bundle id is `org.telegram.ComposerHarness`, distinct from Telegram's.

```bash
K1=$(xcrun simctl list devices available | grep " K1 " | grep -oE '[0-9A-F-]{36}')
xcrun simctl boot "$K1" 2>/dev/null; xcrun simctl bootstatus "$K1" -b >/dev/null
STAGE=$(mktemp -d)
unzip -q -o bazel-bin/Tests/ComposerHarness/ComposerHarness.ipa -d "$STAGE"
xcrun simctl uninstall "$K1" org.telegram.ComposerHarness 2>/dev/null
xcrun simctl install "$K1" "$STAGE/Payload/ComposerHarness.app"
xcrun simctl launch "$K1" org.telegram.ComposerHarness \
  -harness-scenario two-paragraphs -harness-backend engine
xcrun simctl io "$K1" screenshot /tmp/harness.png
```

**Never trust a written-down simulator UDID, including one in this file.** Xcode updates recreate
the K-sims and change both names and UDIDs. A stale UDID interpolated into `id=` leaves xcodebuild
blocked in `simctl diagnose` for ten minutes at 0% CPU, which reads as a hung build. Re-read them
each session with the `grep " K1 "` above.

## The arrange channel

Setup arrives out of band so a test only ever synthesises the touches and keystrokes it is actually
exercising.

| Argument | Values | Default |
|---|---|---|
| `-harness-scenario` | a name from the registry | `empty` |
| `-harness-backend` | `engine`, `legacy` | `engine` |
| `-harness-theme` | `dark`, anything else | light |
| `-harness-font-size` | a `PresentationFontSize` case name (`extraSmall` … `extraLargeX2`, `medium`) | `regular` |

**One leading dash.** `--harness-scenario` is silently ignored and you get the default — the
scenario label on screen is how you notice.

Scenarios live in `Sources/HarnessScenario.swift`. Current: `empty`, `one-paragraph`,
`two-paragraphs`. Add one there and give it a name a test can spell; "the one with a table" is not
a contract.

The chat is a 1:1 conversation with a synthetic peer, `HarnessPanelHost.chatPeer` ("Harness Chat"),
not Saved Messages; the placeholder and anything else keyed on the rendered peer come from it.

In a hosted test, `HarnessRootViewController.setBackend(_:)` switches arms (and rebuilds the panel);
put it back to `.engine` in a `defer`, because other cases assume the launch arm. Format ▸ Link
shows a harness alert (`harness.linkField`, Apply / Remove / Cancel) standing in for the chat's
link editor; a hosted test answers it with `linkPromptOverride` instead.

The backend control on screen rebuilds the panel from scratch, because
`ChatTextInputPanelNode` picks its backend once in `init` (`:863-881`).

## Width, rotation and keyboard height

- **Width.** The root lays the panel out at `view.bounds.width` (the panel's own `updateLayout(width:)`),
  so a hosted test changes the width by setting `root.view.frame` and running a layout pass. That is the
  path a rotation or Split View takes. Restore 402pt afterwards, because every other case assumes it.
  Read the drawn cursor and highlight off the view's `UITextSelectionDisplayInteraction` (`cursorView`,
  `highlightView.selectionRects`). They can lag the geometry answers by a run-loop turn, so compare them
  both straight after `layoutIfNeeded()` and after a settle.
- **Rotation.** The app supports portrait and both landscapes (p14, 2026-09-24). A hosted test rotates
  for real with `view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations:))`, then
  polls until `root.view.bounds.width` has changed (about 0.5 s). It must rotate back to portrait before
  it returns. There is no command-line rotation for K1: `simctl` and `axe` have none.
- **Keyboard height.** The chat lowers the panel's `maxHeight` when the keyboard comes up; the harness
  does not. `HarnessPanelHost.maxHeight` (default 400) is the knob that stands in for it. Findings that
  depend on it are HEIGHT findings, so they are provisional. The Bazel test simulators have a hardware
  keyboard attached, so no software keyboard ever appears there.
- **Accessibility.** In the hosted process the AX bundle is not active: `isAccessibilityElement` and the
  traits read false / 0 for every text view, stock included, even after a `dlopen` of `UIKit.axbundle`.
  Properties the engine view overrides itself (`accessibilityValue`, and the hint the panel sets) are
  real. For the tree VoiceOver actually sees, run `axe describe-ui --udid <K1>` against the running
  harness.

## External content sets and timing (p15)

- **Two routes into the composer, and they are NOT interchangeable (2026-09-25).**
  - An **external set** — a draft synced from another device, Send's clear, a draft restored on open, an
    edit-message load — is `host.setInputContent(c, selectionRange: r)` (or `host.setInputContent(c)`,
    caret at the end): the interface state is updated and `panel.updateInputTextState` pushes it into
    `setInputContent`, which is what `updateChatPresentationInterfaceState` → `ChatControllerNode` does.
    It EMPTIES the undo stack (`HarnessExternalSetUndoTests`).
  - A **user's edit through the chat** — autocomplete, the emoji keyboard, the date editor, Translate,
    the Commands button — is `host.panel.interfaceInteraction?.updateTextInputStateAndMode { transform }`,
    the chat's `ChatControllerLoadDisplayNode` closure, which the host copies: it runs the transform
    inside `node.performUndoableInputChange` and pushes the result back synchronously, so the engine
    applies it as ONE undo step on top of the stack (`HarnessChatSideEditUndoTests`, which carries the
    chat's own transforms). Until 2026-09-25 external sets were driven through the interaction too; they
    reached the same `setInputContent` then, and a test that still does so now models a user edit.
  To push from INSIDE the editor's own `onChange`, replace `panel.interfaceInteraction` with a
  `ChatPanelInterfaceInteraction` that calls the original (through `withoutActuallyEscaping`: the
  convenience init's closure is non-escaping) and then pushes again; restore the original afterwards.
- The fuzz has a `push` op for external sets (`FuzzOp.push`, on in `runFuzz` only), through
  `host.setInputContent(_:selectionRange:)`.
- The fuzz has a `line` op (p16, `FuzzLineOp`, own stream, on in `runFuzz` only) for checklists and
  whole-line selections, and a bare-U+FFFC-in-the-model invariant. Its `FuzzTextInputConsistency`
  forgives ONE answer a stock `UITextView` also gives (a forward line boundary that is the U+2028 just
  before the anchor, `HarnessLineSeparatorTokenizerOracleTests`): check stock before tightening it.
- The fuzz has a `keyWalk` op (p17, own stream, on in `runFuzz` only): ↑/↓ pressed several times with
  UIKit's arrow-key HISTORY carried from press to press, as `UIKeyboardImpl` does for a held key. The older
  `keyMove` op passes no history, and single presses take a different engine path
  (`position(from:in:offset:)` is only asked with offsets ≥ 2 through the history), so an arrow check
  without history misses a whole class (`HarnessVerticalMoveAtDocumentEdgeTests`). Also p17: a
  `structural` op (table / details commands, one undo and redo each).
- The fuzz has a `chatInsert` op (p18, own stream, on in `runFuzz` only): the chat's emoji-keyboard insert
  (`HarnessChatInserts`) compared with typing the same emoji.
- The fuzz has a `move` op (p19, `FuzzOp.move`, own stream, on in `runFuzz` only): a local drag-and-drop
  move through `makeTextDragContext` / `performLocalMove`; invariants: one undo step both ways, no atom and
  no letter created or lost (`moveLosesContent` was filed and is fixed: a move is Cut + Paste now). Also
  p19: `FuzzTextInputConsistency` asks the selection's GEOMETRY (finite rects, exactly one logical start
  and end, a finite `firstRect`) and `characterRange(byExtending:)` at its ends, document edges included;
  its one exemption left is a line with no extent (a block nested so deep its column collapsed).
- **Every paste the fuzz makes waits `FuzzConfig.pasteSettle`, including the one inside a line op.** A
  missing wait does not look like timing: default seed 80 failed only inside a seed BATCH ("one undo did
  not revert the whole japanese composition") because `.line(.seedChecklist)` pasted without it, UIKit's
  paste landed after the 0.02 s step settle in a slower process, and the next op composed under it (a stock
  `UITextView` breaks the same way). Replaying it with no settle fails every time; nothing leaks between
  seeds (p19).
- **The send-path oracle (p20).** `Tests/HarnessSendPathOracle.swift` (`HarnessSendPath`) sends a model the
  way `ChatControllerNode.sendCurrentMessage` does (text + entities, or a rich `InstantPage` stored through a
  `PostboxEncoder` round trip) and loads it back the way message EDITING does. Every step is a shared
  function the chat calls — since the p20 fix wave including the route decision and the text loop
  (TextFormat `chatComposerSendRoute` / `chatComposerTextMessages`, `ChatComposerSendPlan.swift`), which the
  chat calls too; nothing is mirrored. If the send loop changes, change it THERE and both follow.
  `canonical(_:route:)` lists every documented normalisation; anything else is a loss and fails (no losses
  are filed open). The fuzz checks the CHAT's copy (what Send reads) after every step, requires it to equal
  the node's model in full, and ends each sequence with the edit load done for real.
- **External pastes (p20).** Write the pasteboard as another app would (`UIPasteboard.general.items` with
  `public.rtf`, `com.apple.flat-rtfd`, `public.html`, `public.url`, several items) — never read it first.
  The FIRST HTML paste in a process lands ~1 s late (WebKit warms up); a 0.4 s settle let it land in the
  NEXT case and read as a duplicated paste. Wait for the text to change (the fuzz's `externalPaste` op
  waits up to 3 s). A paste's attributes could survive in engine STORAGE while the model was clean (colours,
  fixed p20): the drift verifier does not see that class, so the fuzz also asks
  `editor.modelUnrepresentableFields(atBlock:)`; read `editor.engine.attributedBlocks` to look yourself. The
  op's sources include an RTFD image, foreign colours and CR / CRLF since the fix wave.
- **The composition oracle compares like with like (p21).** It used to type the final candidate after UNDOING
  the composition, i.e. on a state the undo had re-rendered. An undo restores the MODEL, not every attribute
  the engine keeps beside it (a Return-split separator's strikethrough, `HarnessUndoSeparatorTypingAttributesTests`),
  so typing there could be formatted differently from typing on the state the composition found: default /
  edited seed 73 reported the composition as wrong when it equalled fresh typing. `composeViolation` now
  composes AGAIN on the restored state and compares that second composition with typing (both after an
  undo); the first vs the second composition differing is reported as
  `FuzzSignature.typingDependsOnUndoHistory` (a plain violation since the p21 fix wave: typing over a selection
  from an empty line no longer reads the separator). When a typing-attribute question comes up, ask a stock
  `UITextView` with the same KEYSTROKES (not the same final attributed string): its separators carry what
  typing gave them, and its undo restores them.
  A CANCELLED composition over a selection is compared with typing a letter and taking it back, not with
  Backspace (p21): by decision a deletion from a line's start to a later line's start keeps the LATER
  line's role (p16) while typing — and a composition — takes the FIRST line's, so the Backspace oracle read
  that decision as a defect (edited seed 35, a cancel over whole checklist lines).
- The fuzz has an `undoRedo` op (p21, own stream, after the step's op, `runFuzz` only): undo the last step,
  redo it, the document back exactly (a no-op undo is not checked: stock has them too); the selection is put back so the stream goes
  on. And an `environment` op (p21, own stream, before the op): dark / light theme or a 340 / 402pt width,
  LEFT IN PLACE for the following ops; the sequence returns to light / 402pt before its round trips.
  And a `customInsert` phase (p21, own stream): a CUSTOM emoji through the chat's emoji keyboard
  (`chatInsert(_, custom: true)`); no typing twin exists, so its checks are one undo step, a redo that
  restores it, and every per-step invariant (the bare-`U+FFFC` check now includes code languages).
- The fuzz has a `formatTypeOver` op (p22, own stream, `runFuzz` only): an inline trait over a selection —
  half the time one starting on an empty line — then a character typed over it, judged only in documents of
  top-level body paragraphs (the view axis is then the model's). Its typed marker must be a character the
  document does not hold yet: the first version found the run of an EARLIER op's marker and reported six
  false failures. The `compose` op also checks that nothing can be redone while a composition is open (stock
  clears the redo stack on the first marked edit). The `move` op's letter check counts LOSSES only: text
  moved out of a code language line into its body is uncounted before and counted after, so the old
  equality read a gain as "a local move lost content" (default seed 27). Since the p22 fix wave the count
  includes code LANGUAGE lines (text moved into a language read as lost while they were excluded).
- The fuzz has a `oneLineInsert` op (p23, own stream, `runFuzz` only): text holding `U+2028`, `U+2029`, CR or
  NEL typed at the end of a one-line field (a code language, an author, a details title). It comes with two
  per-step invariants: no line break in a one-line field (`FuzzModel.lineBreaksInOneLineFields`), and no run
  that is inline code AND a mention / date / link (`inlineCodeOverEntities`). Both were open known defects and
  are plain violations since the p23 fix wave (`HarnessNewlineInOneLineFieldCrashTests`,
  `HarnessInlineCodeOverEntityTests`); the op no longer undoes its own hit. (`FuzzKnownDefect` had no case open after p23; p24 opened six, below, and its fix wave closed them.)
- **The fuzz's normaliser keeps atoms apart** (p23 fix wave): `FuzzModel.merged` never merges a custom-emoji,
  button or formula run. Two adjacent identical custom emoji are equal runs, and the edit-reload round trip SENDS
  the normalised tip, so merging them sent a model the editor never makes (default seed 48,
  `HarnessAdjacentCustomEmojiRunTests`). A helper that canonicalises a model for an oracle must not change what
  the oracle then feeds back into the product.
- **p24 fuzz additions.** A `chatMention` op (the avatar menu's Mention through `HarnessChatInserts`, own stream) and a
  `normalisingSet` op (own stream): the model plus a block the editor normalises on a set (`FuzzNormalisingSet`:
  formatting / a mention / a custom emoji in a code body, a language with whitespace, `U+2028`, CRLF, CR, `U+2029` or
  NEL in a body, and the p23 kinds as controls), checked and then SET BACK, so an open defect never lingers in the document and later
  steps judge only what the ops made. A per-step length check (on the text route the panel's `node.text` counts the
  chat copy's plain text) lives in `violations()` only, not `unfilteredViolations()`, because regression tests
  assert the latter empty on documents holding code blocks (a p24 per-step language-edge check lived there too until
  its fix wave). Six `FuzzKnownDefect` cases were open, each naming its red test; the p24 fix wave fixed all six and
  retired them (none is open), removed the language-edge check (the model keeps a language as typed, so the axis
  check compares it exactly) and made the length check compare `FuzzModel.sentPlainText` (folded quotes expanded). `.send` records an external set by the node's own RAW guard (`beforeSend != ChatInputContent()`): an empty
  paragraph cleared to no blocks empties the stack though both read back alike (default / edited seed 13).
- **The endurance guard judges per cycle (p24).** `HarnessEnduranceTests` takes 16 quiesced samples and fails on the
  growth across the late cycles with the single LARGEST step removed, and on growth after that step: a late-suite
  process paying once for something (a 70 MB step that then stays flat) passes, a 2 MB-per-cycle retention fails
  (both neuter-checked p24). Print-out: `ENDURANCE footprint MB per cycle`.
- **A red test that TRAPS prints no failure.** XCTest relaunches after the trap and goes on, and the
  summary counts the trapped case as neither run nor failed ("Executed 0 tests"). Count those cases from
  the `Fatal error` lines (`HarnessNewlineInOneLineFieldCrashTests`). **Traps also fill the disk:** each one
  makes the test simulator's `coresymbolicationd` symbolicate, and its cache
  (`<BAZEL_TEST_iPhone 17 udid>/data/Library/Caches/com.apple.coresymbolicationd/data`) had grown to 22 GB
  by p23. The volume filled mid-sweep, and the run died with "No space left on device" and no test failure
  named. Check `df -h` after trap runs. The file is a regenerable cache in a BAZEL_TEST simulator (never a
  K-sim) and can be deleted.
- **The InputDec host suite's one flake (p22).** `IDSelectionDisplayFlushParityTests` failed its "before
  typing" precondition 5 of 8 focused runs and 1 of 3 full `hostapp.sh test` runs, for the STOCK oracle as
  often as for the engine, in the first case of a fresh process: the cursor's first placement can take longer
  than the setup's 0.05 s. The setup now waits for it (bounded, before any edit); 10/10 after. CPU load did
  not change the rate. `IDSpellingReadinessProbeTests` did not fail in 11 runs.
- **Call the chat's shared code, never copy a chat closure.** The emoji keyboard and the avatar menu's
  Mention are `chatComposerInsertTextOnUsersBehalf` / `chatComposerInsertMention`
  (`ChatTextInputPanelNode/Sources/ChatComposerUserInserts.swift`), which the app's closures call too;
  `HarnessChatInserts` hands them the panel's node and interaction. A verbatim copy tests the copy: the
  p18 red tests could not have gone green from an app fix while they ran `HarnessChatTransforms`. When a
  chat path needs testing and lives in `TelegramUI`, move its decision into a module the harness links
  first. **UIKit's plain paste
  is asynchronous** (20-30 ms, a stock `UITextView` too, `HarnessPasteLatencyOracleTests`), so an op that
  follows a paste must wait for it: the fuzz spins `FuzzConfig.pasteSettle` after each paste op. The p17
  seed-28 flake was a push landing before the paste.
- **A timed window never spins the run loop.** `settle(0.0)` (`RunLoop.run(until: now)`) SOMETIMES
  performs UIKit's pending Core Animation commit — a redraw of every canvas the step touched — and
  sometimes does not, so samples come in two modes (Bold over 40 media: 0.050 or 0.125 s). The mode
  frequency depends on the size, so a min-of-N ratio can pair the fast mode at the small size with the
  slow one at the large: 9.4-11.2x for a command that is ~4x in each mode. Time the step plus a
  synchronous `root.view.layoutIfNeeded()`, and `CATransaction.flush()` OUTSIDE the window, before and
  after (`HarnessAtomFormatScalingTests.boldSeconds`). Every scaling test times this way since p16
  (`HarnessNestedQuoteKeystrokeScalingTests`, `HarnessLargeRichPasteScalingTests` converted).
- **Find the superlinear piece with probes, not a profile alone.** A `sample` of a quadratic that is
  spread over a whole pass shows every frame growing a little; `CACurrentMediaTime` accumulators around
  the command's phases and the canvas pass's per-block steps (remove them after) named each term here.
- **Timing and memory loops need an `autoreleasepool` per iteration.** `settle(0.0)` spins no run-loop
  iteration, so nothing autoreleased inside one test method is drained: 1000 undo/redo cycles looked like a
  1.9 GB leak and were flat once each cycle was wrapped. Take the MINIMUM of several timed samples after a
  warm-up (`HarnessNestedQuoteKeystrokeScalingTests`), and assert a SCALING ratio, not a budget.
- Engine block identities (`editor.engine.tgid_blockIdentifiers`, `@testable`) tell whether a replay or a
  set rebuilt a block (`HarnessAtomParagraphReplayIdentityTests`).

## The model readout — a test contract

`ComposerModelDump` renders the live state. It is on screen, and it is also the
`accessibilityValue` of the element `harness.modelDump`, which is how a Tier-2 test reads model
state out of process as a plain string.

```
dump v1 backend=engine hasText=true
height=62.0
selection=34..<34
blocks=2
block[0] paragraph style=body
  run 0..<16 [] "First paragraph."
block[1] paragraph style=body
  run 0..<17 [] "Second paragraph."
```

- The accessibility value is always the WHOLE dump; the label drawn on screen is capped at
  `HarnessReadoutView.drawnCharacterLimit` characters. Drawing a large document's whole dump was most
  of a Format command's settle and swamped the product's timing in the scaling tests (p15 fix wave).
- `backend=` is read **from the node**, never from what was asked for. `none` means no rich input
  node was built.
- The format is a contract. Changing it means bumping `ComposerModelDump.formatVersion` and fixing
  every test that matches on it.
- The block `switch` has **no `default`**, deliberately: exhaustiveness is what reports a new block
  kind, and a `default` would absorb one silently.

Accessibility identifiers: `harness.root`, `harness.modelDump`, `harness.backendControl`,
`harness.scenarioLabel`, `harness.history`, `harness.historyEntry.<index>`.

## Which tier a regression test belongs in

*Write the test at the lowest tier that still reproduces.*

| | Tier 1 — hosted in-process | Tier 2 — XCUITest |
|---|---|---|
| Target | `ComposerHarnessTests` (iPhone 17 / iOS 26.5) | `ComposerHarnessUITests` (iPhone 18 Pro / iOS 27.0, like K1) |
| Drives | the panel's API | real touches, real keyboard |
| Asserts | the model directly | `harness.modelDump` value, screenshots |
| Use when | the model is wrong after an edit | it only reproduces through real input delivery — caret placement, selection gestures, keyboard attach, autocorrect, IME |

If a Tier-2 reproduction reduces to Tier 1, reduce it and keep only Tier 1. Keep Tier 2 where the
touch path **is** the defect — which will not be rare.

Files: `Tests/` and `UITests/`, one file per behaviour family. Each regression test carries a header
saying what broke, how it was seen, and which tier it is at and why.

## Tier 2 cannot skip after launching

`throw XCTSkip(...)` in a UI test after `app.launch()` does not skip: XCTest terminates the app, then
snapshots it for failure triage, and the case FAILS with "Application … is not running". Decide
whether a case can run before launching, or don't write it. Bazel's runner simulator also does not
autocorrect (hardware keyboard), so keyboard-correction behaviour is observable on K1 only.

## A Tier 2 "crashed" with no crash report

XCTest reports any exit it did not ask for as "crashed", and a process that exits through
`exit_with_reason` leaves no `.ips`. Read the Tier 2 simulator's own log instead (read-only; never a K-sim):

```bash
UDID=$(xcrun simctl list devices | grep "BAZEL_TEST_iPhone 18 Pro" | grep -oE '[0-9A-F-]{36}')
xcrun simctl spawn "$UDID" log show --last 1d --style compact \
  --predicate 'process == "launchd_sim" AND eventMessage CONTAINS "ComposerHarness" AND eventMessage CONTAINS "exit reason"'
```

p19 (2026-09-25) traced the one-off 19:28 failure this way: launchd reported
`exit reason (namespace: 19 code: 0x1) - OS_REASON_FOUNDATION, ran for 5615ms` — an orderly exit (the
app cancelled its sockets first), no signal, no fault logged by the app, no termination request from
SpringBoard or the runner. Three cold full runs (simulator shut down before each) were 16/0. Unexplained;
if it recurs, capture the app's stdout (`log show --predicate 'processID == <pid>' --debug --info`).

**The harness is hermetic (p19 fix wave).** Until then it opened TCP connections to Telegram's data
centres (149.154.167.x, 95.161.76.100; ports 80 / 443 / 5222) within seconds of launch, despite
`shouldKeepAutoConnection: false`: that flag keeps the account from HOLDING a connection, not MTProto from
dialling one. `HarnessAccount.make` now writes a SOCKS5 proxy at `127.0.0.1:1` (nothing listens) into the
account manager before the first `accountWithId`, which builds its network's transport from it, so every
dial is a local refusal. Measured on the Tier 2 simulator: 34,152 log lines naming a data-centre address in
one pre-fix hour, 0 across the 20 launches of the next full UI run. Check it the same way:
`log show --info --debug --predicate 'process == "ComposerHarness" AND (eventMessage CONTAINS "149.154" OR eventMessage CONTAINS "95.161")'`.

## Never read the clipboard before writing it

A hosted test must not READ `UIPasteboard.general` (e.g. `let saved = UIPasteboard.general.items` to
restore it later) before it has written its own content. The test process is the app; when the
clipboard holds another process's content — the simulator syncs the Mac's clipboard — the read raises
the system "Allow Paste" prompt, which blocks the main thread, and the run hangs until Bazel's
timeout with no failure named. Eight tests did this; with the reused test simulator it hung 2 runs in 3
(`simctl pbcopy` of anything reproduced it every time). Write what the test needs and never restore.
As of 2026-09-24 the user has turned OFF the Simulator's shared clipboard (host ↔ simulator sync),
which removes the usual source of foreign content. The guards stay: another process on the
simulator can still write the clipboard, and the fuzz tracks `changeCount` for that reason.

## Discipline when something breaks

1. **The test goes red before the fix exists.** A test written after the fix, against the
   reproduction, fixes the reproduction and nothing else.
2. **Confirm the test RAN.** Grep for its name plus `started`, and read the `Executed N tests` line.
   A bundle that fails to compile still lets another target print `0 failures`, and a process that
   traps mid-run is relaunched and prints a green summary for the cases that did run.
3. **Count, do not wait.** `wait()` returns on the first callback, so a duplicate a turn later is
   invisible; drain setup, then count.
4. **Height and inset findings are provisional** until reproduced in the real app.
5. Append every finding to `docs/findings.md`.

## Driving the simulator: pre-baked hazards

Each of these has already cost a session.

- **`axe touch --down --up --delay 0.08`, never `axe tap`.** An instant down/up does not place a
  caret in this editor and reads as the app ignoring you. In XCUITest, use
  `coordinate.press(forDuration: 0.1)` rather than `tap()`.
- **One `axe key-sequence` burst, never a per-character loop.** Per-invocation overhead drops
  presses; a loop silently stops landing.
- **Screenshot after every typing step** and confirm the text changed before believing a result.
- **`axe type` injects HID and can kill the software keyboard for the rest of that process's life.**
  Restore with `GSEventSetHardwareKeyboardAttached(1, 0)` via lldb, and clear latched modifiers with
  `axe key-sequence --keycodes 224,225,226,227,228,229,230,231` before walking away.
- **A text view's frame extends under the send button.** A tap at the right edge of
  `app.textViews.firstMatch` (e.g. normalized dx 0.95) lands on Send, not in the text; a test
  written that way passes without ever exercising the text tap.
- **Watching a focus race perturbs it.** lldb breakpoints and even `NSLog` tracing changed the
  focusing-tap defect's rate from 4/10 to 0/8. Count reproductions on an uninstrumented build.
- **A wedged `axe hid-broker` makes typing silently stop landing while still exiting 0.**
  `pgrep -fl axe`, kill it, and the next call respawns one.

Because arrange is out of band, type only the characters actually under test; that keeps most of
this out of the loop.

## If you are a dispatched subagent

The controller runs the long Bazel builds — a subagent's backgrounded build is torn down when it
returns — and reads the build's own exit code. You drive the simulator and write the tests.

## Non-obvious things about the app context

- **`HarnessProcessRetainer` is not optional.** Releasing a live `Account`, its account manager, a
  replaced shared `Logger`, or a context owning an animation cache tears down `ManagedFile`s that
  assert they are freed on their own queue. The process dies with a bare "Assertion failed" naming
  nothing, and the runner relaunches and prints green. Register anything process-scoped there.
- **Unprovided members trap and name themselves.** If you hit
  `harness: SharedAccountContext.<name> is not provided`, that member now needs a real answer.
  Add it to the hand-written conformance and to the generator's `--exclude` list, then regenerate:

  ```bash
  python3 Tests/ComposerHarness/Tools/generate_harness_stubs.py \
    --source submodules/AccountContext/Sources/AccountContext.swift \
    --protocol SharedAccountContext --conformer HarnessSharedAccountContext \
    --exclude currentPresentationData,immediateExperimentalUISettings,currentChatSettings,energyUsageSettings,mainWindow,accountManager \
    > Tests/ComposerHarness/AppContext/HarnessSharedAccountContext+Generated.swift
  ```

  **Never give a member a plausible constant instead.** A stub returning `false` is
  indistinguishable from a correct answer at the call site and has already cost this project five
  debugging sessions.
- The app bundles `//Telegram:AppStringResources` and the generated `PresentationStrings.data`.
  Without either it traps at launch, because `defaultPresentationStrings` force-unwraps its lookup.
