# InputDec backend — divergences from upstream InputDec

Running log of places where `IDTextEditorBackend`'s use of the vendored kernel deliberately
diverges from what InputDec's own reference host does with it, and why. Add one entry per
divergence as it is introduced; do not delete entries once true even if a later task narrows or
removes the gap — record the narrowing as a new entry instead.

1. **Autoscroll is never requested.** `IDTextEditorBackend.requestedCapabilities` never includes
   `.capabilityAutoscroll`, so the kernel's `autoscrollEntry` capability is never constructed and
   `IDUIKitBehaviorKernel.autoscrollEntry` stays nil for every attachment. InputDec's own
   autoscroll assumes the view that becomes first responder (`view:` passed to the kernel) IS the
   `UIScrollView` doing the scrolling — a valid assumption for InputDec's own host, where the text
   view and the scroll view are the same object. Telegram's canvas
   (`DocumentCanvasView`/`IDDocumentCanvasView`) is a plain `UIView` first responder living
   *inside* a separate `GripYieldingScrollView` (see the package `CLAUDE.md`'s "Gesture
   arbitration is gate-only" note), so adopting the kernel's autoscroll would hand it a `UIView`
   it can't actually scroll. Telegram's own drag-based auto-scroll
   (`DocumentCanvasView.swift`, the table-drag `CADisplayLink` driver and the floating-cursor
   auto-scroll driver — see `docs/superpowers/...` / the package `CLAUDE.md`'s floating-cursor
   section) keeps running unchanged and unaffected; there is no double auto-scroll to reconcile.

2. **Position identity is flat, not block-anchored.** `RichTextInputStateSnapshot.selection` and
   every other position this backend ever hands to Telegram (`RichTextCanonicalSelection`,
   `.caret(at: .downstream(utf16Offset))`) is a flat `(utf16Offset, affinity, revision)` triple —
   the seam's own position model (see `RichTextInputTypes.swift`). InputDec's own document model
   (`IDBlockDocument`/`IDRichTextLayoutController`, the class this package's
   `TGRichTextInputDecLayoutController` is a document-neutral rewrite of, per its own header
   comment) anchors positions to block identity, so a structural edit can rebase a position by
   asking "where did this block go" rather than "did anything before this offset change". This
   backend has no block-anchor model to ask that question of, so a position surviving a structural
   edit is entirely the seam's `RichTextInputDocumentClient.rebase(_:fromRevision:)` contract's
   job — offsets are only ever range-clamped/shifted by whatever `rebase` says moved, never
   reasoned about via a block graph. Task C0 does not implement any witness that calls `rebase`
   (no document family lands until a later task), so this divergence is recorded now, before it
   is exercised, precisely so the task that DOES wire `rebase` in can find this note and does not
   have to rediscover the reasoning.

3. **The starting line for stage 1's eight contract suites under `.inputDec` (Task C3, Decision
   10) — measured 2026-08-25, K3 simulator, all real `xcodebuild` runs, exit codes and per-test
   output quoted verbatim in `task-C3-report.md`.** All eight new `IDBackend*ContractTests`
   subclasses (`Tests/RichTextEditorUIKitTests/InputDec/IDBackendContractSubclasses.swift`) FAIL
   in full — 0 of 68 inherited tests pass:

   | Suite | Tests | Pass | Fail |
   | --- | --- | --- | --- |
   | `IDBackendMutationContractTests` | 9 | 0 | 9 |
   | `IDBackendRevisionContractTests` | 6 | 0 | 6 |
   | `IDBackendPublicationContractTests` | 8 | 0 | 8 |
   | `IDBackendSelectionContractTests` | 7 | 0 | 7 |
   | `IDBackendMarkedTextPolicyTests` | 11 | 0 | 11 |
   | `IDBackendReentrancyTests` | 15 | 0 | 15 |
   | `IDBackendAttachDetachTests` | 6 | 0 | 6 |
   | `IDBackendEditPolicyTests` | 6 | 0 | 6 |
   | **Total** | **68** | **0** | **68** |

   **Root cause is earlier than the `isSupported()`/mandatory-contract gate that skips every
   other `.inputDec` suite in Stage C.** `BackendContractCases.setUpWithError()` (stage 1, shared
   by all eight) calls `makeHost(log:)`, which — since none of these eight subclasses override
   it (correctly: Step 7 sanctions ONLY a `makeBackend()` override) — always constructs the
   default `FakeInputHost`, whose `hostInputView` is a plain `DocumentCanvasView` (the LEGACY
   canvas). `IDTextEditorBackend.attach(to:)`'s very FIRST guard rejects that:
   `guard let canvas = host.hostInputView as? IDDocumentCanvasView else { throw
   .incompatibleHost(...) }` — thrown before kernel construction, before `isSupported()`-style
   contract evaluation ever runs. So this is a HOST-FIXTURE mismatch, not (yet) a manifestation
   of the `incomingCallbacks` rejection that gates every other `.inputDec` suite in this stage.

   **These are genuine FAILURES, not skips, despite each per-suite `Executed N tests, with N
   tests skipped and N failures` summary line making it look ambiguous.** XCTest's own dual
   bookkeeping is the source of the ambiguity: when `setUpWithError()` throws a plain (non-
   `XCTSkip`) error, XCTest logs `Test skipped: threw error "..."` for internal aborted-test-run
   accounting AND still records the test as `failed`, appends it to `Failing tests:`, marks the
   containing `Test Suite` as `failed`, and returns a non-zero process exit (65, confirmed for
   all eight suites via `Scripts/iostest.sh`, one full raw un-filtered `xcodebuild` run kept for
   `IDBackendMutationContractTests`). This is UNRELATED to the deliberate `XCTSkip`/
   `XCTSkipUnless` used by `IsSupportedTests`, `IDBackendSemanticTests`, and every other
   `.inputDec` suite in this stage, which register as genuine, zero-failure skips. Do not
   conflate the two "skipped" wordings when reading a future `matrix.sh`/`iostest.sh` log.

   **Consequence for the package-wide baseline: `0 failures` is NOT the health signal from this
   commit forward, until a family task (C4 onward) routes `attach(to:)` to accept the ID canvas.**
   The full-suite run after this task lands 68 new UIKit failures (see `task-C3-report.md` for
   the exact `Executed …` line). This is the expected, designed-in red state (brief Step 8: "most
   fail... the correct red state") — do NOT "fix" it here by overriding `makeHost()` or a
   `test_` method in `IDBackendContractSubclasses.swift`; per that file's own doc comment, a
   subclass needing more than `makeBackend()` is a finding about the ID backend's host-attachment
   surface, to be closed by a later family task's real routing work, not by weakening the
   inherited stage-1 assertions.

   **FIX ROUND 1 (2026-08-25, controller review) — the host-fixture mismatch above was itself
   the WRONG reason to be red, and has been fixed; the count is unchanged but the failure reason
   is not.** Controller review pointed out that Step 8's "most fail... the correct red state"
   framing presumes attach gets far enough to reach the manifest/kernel gate — `.incompatibleHost`
   fires at the very first `guard`, before that gate, so implementing the 42 `incomingCallbacks`
   rows in Tasks C4-C14 would change nothing about which canvas the fake host vends, and these
   eight suites would have stayed red forever, making D5's "all eight fully green" exit gate
   unreachable. **Fix:** `IDBackendContractSubclasses.swift` now also overrides `makeHost(log:)`
   on all eight subclasses (a SECOND legitimate hook `BackendContractCases` exposes alongside
   `makeBackend()` — not a contract relaxation: requiring an ID canvas is deviation D23, a
   documented design fact, not an invention of this file). Each override builds an
   `IDDocumentCanvasView` paired with the suite's own already-constructed `backend` (mirroring
   `IDFakeClientHarness.swift`'s `makeIDFakeClientHarness` construction order exactly: construct
   the canvas around the backend, detach that construction's self-attach, hand the canvas to a
   `FakeInputHost` via its `init(hostInputView:log:text:)` overload from Task C2), and preserves
   `nextHostIsIncompatible` by delegating to `super.makeHost(log:)` on that branch (needed by
   `BackendAttachDetachTests`'s inherited incompatible-host test). No inherited assertion was
   relaxed and no `test_` method was overridden.

   **Re-measured after the fix: still 68 of 68 failing (0 material count change) — same 8
   suites, same per-suite counts (9/6/8/7/11/15/6/6) — but now for the failure Task C4 onward
   actually addresses.** All eight now fail with exactly one message,
   `privateRuntimeFailure("The mandatory input-controller capability was rejected.")`, thrown
   from `attach(to:)`'s kernel-construction `catch` — i.e. attach now clears the
   `.incompatibleHost` guard and reaches real `IDUIKitBehaviorKernel` construction, which rejects
   for a DIFFERENT, deeper reason than `isSupported()`'s own lightweight check reports. Traced
   into the vendored source (`Sources/RichTextInputDecObjC/Kernel/IDUIKitBehaviorKernel.m:120-146`):
   the kernel's initializer does not merely re-check `resolver.evaluateContract(inputContract)
   .isAccepted` (which is what `isSupported()`'s `mandatoryContractsAccepted` does, and which
   supplement §4 recorded as ACCEPTING for `inputController`) — it goes on to actually
   CONSTRUCT an `IDUIKitInputControllerCapability` instance from the real `layoutController`/
   `delegate`/`resolver`, and that construction is what fails here, before the kernel ever
   reaches its separate `incomingCallbacks` gate (a different, later check in the same
   initializer, with its own distinct message, `"The required incoming-callback capability was
   rejected."` — not the one hit today). This is a genuine, C4-onward-relevant finding, not
   something this fix-round investigated further or fixed: recorded here so whichever task
   implements `.inputController`'s real construction path does not have to rediscover it.

   **One caveat worth flagging for whoever routes `.inputController` next:** the canvas
   construction inside `makeIDContractHost` (`IDDocumentCanvasView(inputBackend: backend)`)
   ALSO self-attaches and ALSO hits this same kernel-construction rejection internally, before
   the test's own real `attach(to:)` call ever runs — `DocumentCanvasView.init` catches that and
   routes it through `RichTextInputContractViolation.report(...)`, which `assertionFailure`s (a
   hard process trap) with no reporter installed at that point in
   `BackendContractCases.setUpWithError()`'s sequence (it installs its own reporter only
   immediately before the real `attach(to:)` call, after `makeHost(log:)` already returned).
   `makeIDContractHost` installs a temporary no-op reporter around just that construction and
   restores the previous one immediately after, specifically to prevent this from crashing the
   whole xctest process instead of surfacing as the plain, observable test failure recorded
   above. If `.inputController` construction starts succeeding, this guard becomes a no-op
   (nothing to swallow) and can stay in place harmlessly, or be removed for clarity — it is not
   load-bearing once the real construction succeeds.

4. **Task C4's 21 Family-1 rows land, but they do NOT move the `.inputController`-construction
   rejection recorded above -- measured with a throwaway diagnostic, not shipped.** Entry 3 traced
   the rejection to the real private `UITextInputController`'s `initWithTextLayoutController:`
   throwing when it queries a selector `TGRichTextInputDecLayoutController` does not answer, but
   did not identify WHICH selector. It is **`-textContainers`** -- manifest row 2, owned by Task
   **C5** (Family 2), not this task:
   ```
   Error Domain=IDUIKitInputControllerCapabilityErrorDomain Code=3
   "-[TGRichTextInputDecLayoutController textContainers]: unrecognized selector sent to instance 0x..."
   ```
   Confirmed identical (same selector, same wrapping message) both BEFORE this task's commit
   (checked out via `git show 66e63b0864:...TGRichTextInputDecLayoutController.m`/`...Internal.h`
   over the working tree, then restored) and AFTER it -- because the real private controller's own
   init queries `-textContainers` before it ever asks for anything Family 1 answers
   (`-beginningOfDocument`, `-positionFromPosition:offset:`, etc.). So the task brief's own
   supplement Section 2 framing -- "your 21 rows feed exactly that [construction gate]" -- does not hold
   for THIS specific gate today: Family 1's rows are simply never reached by real construction
   yet. **What Task C4 does move, exactly as its own supplement Section 1 specifies as the success
   criterion, is the SEPARATE, purely static `incomingCallbacks` capability evaluation** (no
   construction involved -- `IDUIKitCapabilityResolver.evaluateContract(_:)` against the 47-row
   signature table): `mismatchCount` measured 42 before this task (`task-C0-report.md`) and
   **21 after** (measured here via the same `resolver.evaluateContract(manifest.capabilities[
   "incomingCallbacks"])` call `IsSupportedTests.test_mandatoryContractsAreEvaluated_notAssumed`
   already uses, in a throwaway, unshipped scratch test), and the 21 REMAINING mismatches are
   EXACTLY the 12 Family-2 (C5) + 1 Family-3 (C6, `invalidateDisplayForCharacterRange:`) + 1
   Family-5 (C12, `_visualSelectionRangeForExtent:...`) + 7 Family-6 (C14) rows -- none of Family
   1's 21 rows appear. So the observable `attach(to:)` failure TEXT (both the outer wrapper and
   the underlying `-textContainers` reason) is unchanged by this task, and will next move only
   once Task C5 answers `-textContainers` (whichever selector the private controller's init
   happens to query first among C5's rows) -- recorded here so C5 does not have to rediscover
   which specific selector unblocks real construction.

5. **Task C5 lands `-textContainers` (and the other 11 Family-2 rows) and BOTH of the supplement's
   falsifiable predictions hold EXACTLY, measured with the same throwaway scratch test and the
   same real, non-skipped `IDBackendMutationContractTests` suite entry 4 used.**

   **Mismatch count: 21 -> 9**, and the 9 remaining are precisely C6's 1 + C12's 1 + C14's 7 --
   none of Family 2's 12 rows appear:
   ```
   SCRATCH: incomingCallbacks isAccepted=false mismatchCount=9
   incoming.addAnnotation / addRendering / annotatedSubstring / annotationAtPosition /
   invalidateTemporary / removeAnnotation / removeRendering   (C14, 7)
   incoming.invalidateDisplay                                  (C6, 1)
   incoming.visualSelection                                    (C12, 1)
   ```

   **Attach failure text ADVANCES**, exactly as predicted -- construction now gets PAST
   `-textContainers` and fails at the SEPARATE, LATER `incomingCallbacks` gate instead:
   ```
   BEFORE: privateRuntimeFailure("The mandatory input-controller capability was rejected.")
   AFTER:  privateRuntimeFailure("The required incoming-callback capability was rejected.")
   ```
   Traced into `IDUIKitBehaviorKernel.m:120-181`: `-textContainers` (and everything else the real
   private `initWithTextLayoutController:` needs from Family 1/2) now resolves, so
   `IDUIKitInputControllerCapability` construction SUCCEEDS -- `input != nil` -- and the kernel
   proceeds to its separate `incomingCallbacks` contract evaluation (a different code path, a
   different message), which still rejects on the 9 remaining rows. Both counts (9/9 failing,
   same 9 test names) are unchanged from before this task; only the TEXT of the shared failure
   moved. Confirmed via a `git stash`/`git stash pop` round-trip re-run of both instruments
   (throwaway scratch mismatch test + `IDBackendMutationContractTests`) against base commit
   `7fff0bc521` for "before" and this task's full diff for "after" -- not inferred from either
   report alone.

   **Design decisions this task made where the brief's `Produces (bridge)` interface underspecified
   behavior** (none of these are covered by a brief snippet or the supplement):
   - **`id_selectionRectsForRange:fromView:forContainerPassingTest:` derives `visibleRect` from
     `fromView.bounds`**, not `CGRectNull` (unbounded). `fromView` is UIKit's own requesting
     view for this private callback -- the same canvas `IDUIKitBehaviorKernel` was constructed
     with as `view:` -- so its `bounds` is the honest "what's currently visible" answer the
     spec's bounded-Select-All requirement calls for (mirroring
     `BoundedSelectionGeometryTests`'s `visible: v.bounds` fixture at the client boundary).
     `CGRectNull` remains the fallback only when UIKit hands this callback no view.
   - **`closestOffsetToPoint:withinRange:revision:outOffset:`'s `range` sentinel is
     `NSNotFound`-location, mapped to `nil`** (no bound) on the Swift side. Neither
     `id_cursorPositionAtPoint:inContainer:` nor `id_nearestPositionAtPoint:inContainer:` --
     Family 2's only two callers -- receives a range from UIKit at all (their own `@encode`
     signatures carry only a point and a container), so both pass the sentinel.
   - **`id_baseWritingDirectionAtPosition:` and `id_requestTextGeometryAtPosition:...` both reuse
     the `caretGeometryAtOffset:...` bridge call**, discarding the fields they don't need
     (rect / typing-attributes respectively). The client bridge header declares exactly THREE
     Family-2 methods (per the brief's own `Produces` list) -- there is no fourth,
     narrower "writing direction only" or "geometry request only" method, and adding one would
     have been unscoped machinery the brief's interface list does not sanction.
   - **`id_boundingRectForCharacterRange:` computes the UNION of `selectionRectsForRange:
     visibleRect:revision:`'s rects** (unbounded `CGRectNull` visible rect, since this row's own
     `@encode` carries only a plain `NSRange`, no view). No dedicated bridge method exists for a
     single "bounding rect" query; the union of the range's selection rects is the one honest,
     non-fabricated answer available from the three declared bridge methods.
   - All FOUR of these rows share the same "no fabricated non-null/non-zero answer" discipline as
     `id_insertionRectForPosition:...typingAttributes:placeholderAttachment:textContainer:`
     (given verbatim in the brief): `CGRectNull` on a bridge NO, never `CGRectZero` -- the shared
     geometry client must never be told UIKit is intolerant of absence.

6. **Task C6 lands row 30 (`invalidateDisplayForCharacterRange:`) and the two falsifiable
   predictions hold EXACTLY: mismatch count 9 -> 8, attach failure text UNCHANGED (this task does
   not own the `incomingCallbacks` blocker; C12/C14 do).**

   Measured with the same scratch technique C4/C5 used
   (`IDUIKitCapabilityResolver.system().evaluateContract(manifest.capabilities["incomingCallbacks"])`,
   run via a raw `xcodebuild` invocation -- NOT `Scripts/iostest.sh`, whose `grep` filter strips
   `print()` output, which is how this task first (harmlessly) discovered the filter's scope):
   ```
   SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
   incoming.visualSelection (C12, 1) + 7 C14 annotation/rendering rows -- incoming.invalidateDisplay is GONE.
   ```
   Attach failure text, `IDBackendMutationContractTests` (unconditional real `attach(to:)`, same as
   C4/C5's own check): `privateRuntimeFailure("The required incoming-callback capability was
   rejected.")` -- byte-identical to before this task. Expected, per the supplement: this task does
   not own the all-or-nothing gate's clearing condition.

   **Design decisions this task made where the brief's interface underspecified behavior:**

   - **The four Step-3 canvas thunks' exact private-API argument shapes are a documented
     RECONSTRUCTION, not a certified contract.** None of `textInputDidChange:`,
     `textInputDidChangeSelection:`, `keyboardInputChangedSelection:`, `_deleteBackwardAndNotify:`
     appears anywhere in the vendored manifest's 47 `incomingCallbacks` rows or in any Kernel/
     source this snapshot carries -- `Vendor/VENDOR.md` records that `referenceOnly` (53 rows) was
     dropped from this export, and these four are plausibly among the rows that carried. Installed
     the same UNCONDITIONAL way `textStorage`/`textInputView` already are (`class_addMethod`, no
     ABI-witness borrow, no resolver validation) -- consistent with their absence from the manifest.
     ~~Each selector's one colon (arity 1) is honored with a generic trailing `id` parameter
     (`"v@:@"`), even where the body ignores it, so the runtime's own arity bookkeeping is not
     silently wrong~~ (**CORRECTED BY TASK F3 — see entry 21. Arity is not shape: three of the four
     really do take an object, but `_deleteBackwardAndNotify:` takes a BOOL, and declaring that `id`
     made ARC retain `YES` as a pointer and segfaulted the app on the first Backspace. The
     reconstruction was replaced by a runtime PROBE.**); three thunks forward to a matching
     `delegate*` bridge method by NAME resemblance (`textInputDidChange:` ->
     `delegateTextInputDidChange`, etc.).
     ~~`_deleteBackwardAndNotify:` -- the one that ADOPTS a new selection rather than merely relaying
     a notification -- reads the CANVAS's OWN already-routed `selectedTextRange` rather than trusting
     the untyped `arg`, since that is the one value guaranteed correct regardless of the real ABI's
     actual parameter shape.~~ (**ALSO CORRECTED BY TASK F3: the selector does not report a delete,
     it asks for one. There is no thunk any more.**) ~~**None of the four is reachable by any test in this stage** (kernel
     construction, and therefore `TGRichTextInputDecInstallCanvasCallbacks` itself, never runs while
     `incomingCallbacks` stays rejected)~~, which is what makes a documented best-effort
     reconstruction the responsible choice here rather than leaving the row unimplemented or blocking
     on unobtainable certainty. See `TGRichTextInputDecCanvasCallbacks.m`'s file-level comment.
     **CORRECTED BY TASK F2 (struck through above, kept verbatim so the mischaracterisation stays
     legible): that claim expired at Task C14 and was never revisited.** C14 landed the final 7
     `incomingCallbacks` rows, so real kernel construction succeeds and
     `TGRichTextInputDecInstallCanvasCallbacks` runs on every attach —
     `CanvasCallbackInstallationTests` (5+ direct call sites),
     `IDTextEditorBackendInteractionPreflightTests` and `IDBackendFamily9Tests` all exercise it, and
     `IDKeyboardActivationTests
     .test_theAppReachableInstallationStateHasEveryThunkLive` now pins the installed thunks in the
     exact state the app reaches (real `RichTextEditorView`, attached, first responder, every
     conditional thunk live). The same expired claim appears twice more in
     `TGRichTextInputDecCanvasCallbacks.m` (the C6 and C7 group comments) and is corrected there
     too. What is still true of the four C6 thunks is only the narrower half: their parameter SHAPES
     are an uncertified reconstruction. Reachability is not in doubt any more, and treating it as
     doubtful is what let Task F2's brief spend its first hypothesis on a path that was already
     covered.
   - **Hard invariant 10 required widening `InputBackendSourceBoundaryTests`' R16 rule (the
     "only the backend sends `UITextInputDelegate` notifications" mechanical gate) from ONE allowed
     file to a Set of TWO** -- `LegacyRichTextInputBackend+Notifications.swift` and, now,
     `IDTextEditorBackend.swift`. This is R16 applied to a second backend it predates, not a
     relaxation: each file is independently asserted non-vacuous (both must actually send at least
     one of the four notification selectors), and the Set is explicitly capped at exactly two with a
     comment that widening it further is a review event -- mirroring the existing
     `inputDecExemptPaths` convention in the same file. Verified real (both directions): the
     un-widened test failed the moment `IDTextEditorBackend.swift`'s sends existed, and passed clean
     after the edit (`swift test --filter InputBackendSourceBoundaryTests`, 35/35, then reconfirmed
     for real by running it against the finished diff).
   - **The same rule's "DOOR 1" (`test_theWriteDoorsIntoBackendOwnedInputStateAreEnumerated`,
     the exact per-file `setSelection(` call-site census) needed TWO new entries, not one.**
     `IDTextEditorBackend.swift:1` is `selectedTextRange`'s setter forwarding onto
     `setSelection(_:reason:.keyboard)` (mirrors Legacy's own setter). SEPARATELY,
     `IDTextEditorBackendClientBridge.swift:1` is `setCanonicalSelectionAnchor(_:head:reason:)`
     adopting the selection a kernel-driven backward-delete reports -- a real, DIFFERENT file, since
     the bridge is where the ObjC `_deleteBackwardAndNotify:` thunk lands in Swift. Measured, not
     assumed: `swift test --filter InputBackendSourceBoundaryTests` after the edit, 35/35 real (not
     skipped) passes on the K1/Core side.
   - **`DocumentCanvasView.textRange(from:to:)` NORMALIZES (orders) its result regardless of
     argument order -- measured, not assumed, and it is a DIFFERENT fact from
     `selectedTextRange`'s own unordered-getter guarantee.** The first-drafted
     `test_aReversedSelectionRoundTripsThroughSelectedTextRange` (shared `BackendSemanticContractCases`)
     built its reversed write via `canvas.selectedTextRange = canvas.textRange(from: hi, to: lo)`
     and went RED against the REAL `LegacyBackendSemanticTests` --
     `XCTAssertEqual failed: ("2") is not equal to ("5") - start must be the ANCHOR, not min()` --
     because `textRange(from:to:)` is a separate `UITextInput` witness ("give me a range spanning
     two positions") that orders its own result; only `selectedTextRange`'s GETTER (reading
     `canonicalSelectionStorage`/`state.selection` verbatim) is unordered. Fixed by seating the
     reversed pair through `setSelectionForTesting(anchor:head:)` (the harness's raw selection seam,
     `h.select(_:_:)`) instead, and asserting via `offset(from: range.start, to: range.end) == -3`
     (direction-only, no dependency on the fixture's raw axis start) rather than
     `beginningOfDocument`-relative offsets, which a first repair attempt also got wrong the same
     way C3's Family-1 tests originally did (the axis is sparse; `beginningOfDocument` is not raw
     offset 0). Re-run confirmed green: `LegacyBackendSemanticTests`, 11/11, 0 failures. Recorded
     here because the next task to build a reversed-selection fixture in this shared suite will hit
     the identical trap if it reaches for `textRange(from:to:)` again.
   - **The matrix suite baseline this task's own supplement quoted ("80") was already stale by 2
     before this task started.** Re-measured with a `git stash -u` round-trip against base commit
     `da1c736141` (the FIRST such measurement in this log to include `-u` -- prior entries' `git
     stash` round-trips left an untracked new test file in place for BOTH the "before" and "after"
     reads, which is why C5's own supplement-vs-measured discrepancy note undercounted too): true
     pre-C6 baseline is **82**, not 80; this task's `IDBackendFamily3Tests.swift` addition brings it
     to **83**. Not a finding about this task's own work -- flagged so the controller's running tally
     stays accurate, per the same convention entry 5 (via C5's report) already established.


7. **Task C7 lands Family 4 (insertion and replacement) but owns ZERO `incomingCallbacks` rows —
   both falsifiable predictions hold EXACTLY: mismatch count stays 8, attach failure text stays
   byte-identical.**

   Measured with the same scratch technique C4/C5/C6 used, via raw `xcodebuild`, added then fully
   removed before committing:
   ```
   SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
   incoming.visualSelection (C12, 1) + 7 C14 annotation/rendering/invalidateTemporary rows.
   ```
   Attach failure text, `IDBackendMutationContractTests` (9/9 real failures, unconditional real
   `attach(to:)`): `privateRuntimeFailure("The required incoming-callback capability was
   rejected.")` — byte-identical to C4/C5/C6's own measurement. Expected: Family 4's storage façade
   and intent latch are entirely canvas-hosted (the façade class + two pre-mutation thunks + one
   ABI-witness edit), not a `TGRichTextInputDecLayoutController` `incomingCallbacks` row.

   **Design decisions this task made where the brief's interface underspecified behavior:**

   - **`IDTextEditorBackend.emitWillChange(_:)`/`adoptAndEmitDidChange(_:)` gained TYPE-based
     overloads, rather than the brief's illustrative snippet's implied signature actually existing.**
     The brief's Step 4 calls `backend.emitWillChange(prepared)`/`backend.adoptAndEmitDidChange(result)`
     as if those already accepted a `RichTextInputPreparedMutation`/`RichTextInputMutationResult` —
     Task C6 built them `private` and `NotificationKind`-taking, and `private` alone makes them
     unreachable from the bridge (a different file) regardless of signature. Added two `internal`
     overloads (same base names, different parameter TYPE — Swift resolves this cleanly since
     neither original nor new method carries an external label) that route through the private
     originals, keeping hard invariant 10 (only this file sends `UITextInputDelegate`
     notifications) intact while making the brief's own call syntax literally correct.
   - **`keyboardInputShouldDelete:`'s latch lives inside `TGRichTextInputDecCanvasABIWitness.m`'s
     EXISTING method body, not a fourth unconditional canvas thunk.** That selector is one of the
     3 resolver-validated canvas rows (`inputController.keyboardDeletePreflight`) — its compiled
     IMP is borrowed verbatim by `TGRichTextInputDecInstallCanvasCallbacks`, so a competing
     `class_addMethod` under the same selector name would either lose to `class_addMethod`'s
     already-exists no-op or require reordering the installer. Editing the existing body preserves
     the exact IMP/type-encoding pair the resolver already validated (a body edit changes neither)
     while adding the `.deleteBackward` latch.
   - **`textInput:shouldChangeCharactersInRanges:replacementText:` latches `.programmatic`,
     explicitly.** The brief lists this as the third pre-mutation thunk but, unlike its two
     siblings, never says which of the six `TGRichTextInputDecIntent` cases it should set. Its own
     selector name carries no keyboard/deletion-specific qualifier — only that some external agent
     is about to replace text in (possibly several) ranges — so `.programmatic` (→ the mapper's
     general `RichTextInputMutation.replaceText` shape) is the only case its name supports without
     inventing information it doesn't carry. Latches unconditionally (not "leave whatever was
     there") so a genuine system-driven replace can never inherit a stale, coincidentally-preceding
     thunk's intent. Corroboration found AFTER choosing the spelling, not before: the pre-existing
     `CanvasCallbackInstallationTests.installedSelectors` inventory (predates this task, unrelated
     test) already names both this selector and `keyboardInput:shouldInsertText:isMarkedText:`
     verbatim.
   - **`IDFakeClientHarness.storageFacade` retypes to NON-optional** (force-unwrapping the
     backend's own Optional `storageFacadeForTesting`), while `RichTextInputBackendHarness
     .storageFacade` stays Optional. The supplement's site list shows both as `NSTextStorage?`
     without saying which stays Optional after the retype; the brief's own Step-1 test
     (`IDBackendIntentLatchTests`, quoted verbatim) writes `h.storageFacade.currentIntent = …`
     positionally, which only compiles non-optional, while `IDHarnessTests
     .test_storageFacadeIsVendedForInputDecAndNilForLegacy` asserts the OTHER harness's property is
     `nil` for `.legacy`, which only compiles Optional. Both compile checks are real, run
     constraints, not a style preference, so the two properties end up with different optionality
     by necessity.
   - **Closed most of the "every ID-backend test in this stage compiles but never runs" gap with
     two NEW, non-skip-gated suites** (`IDTextEditorBackendIntentTests`, 7 tests over the pure
     intent mapper; `IDTextStorageFacadeTests`, 6 tests over the façade class directly, against a
     hand-rolled fake bridge mirroring `CanvasCallbackInstallationTests.StubBridge`'s existing
     pattern) — neither needs kernel construction/`attach(to:)`/`isSupported()` at all, so both
     genuinely EXECUTE (not skip) on this runtime, real pass: 7/7 and 6/6. The façade suite caught
     a real bug in its own first draft (`NSRangeException` from replacing at a non-zero range on an
     empty mirror while the fake bridge answered `applies = true`) — fixed by making that
     particular test assert on FORWARDING only (`applies = false`), a genuine red-then-green cycle
     against the façade's own compiled behavior, not a hypothetical.
   - **The shared `BackendSemanticContractCases` Family-4 additions needed explicit
     `beginUndoGrouping()`/`endUndoGrouping()` brackets around every `canvas.insertText(...)` call**
     — the harness's undo manager is deliberately `groupsByEvent = false`
     (`RichTextInputBackendHarnessTests` pins this: "the factory must configure groupsByEvent =
     false so every mutation needs its own bracket"), and Family 4's shared cases are the FIRST in
     this parameterised suite to actually perform a real edit through the canvas rather than only
     reading state — the mismatch (`NSUndoManager … must begin a group before registering undo`)
     surfaced immediately on the first `LegacyBackendSemanticTests` run and was fixed by matching
     `RichTextInputBackendHarnessTests`'s own existing bracket convention.


8. **Task C8 lands Family 5 (backward deletion) but owns ZERO `incomingCallbacks` rows — both
   falsifiable predictions hold EXACTLY: mismatch count stays 8, attach failure text stays
   byte-identical.**

   Measured with the same scratch technique C4/C5/C6/C7 used, via raw `xcodebuild`, added then
   fully removed before committing:
   ```
   SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
   incoming.visualSelection (C12, 1) + 7 C14 annotation/rendering/invalidateTemporary rows.
   ```
   Attach failure text, `IDBackendMutationContractTests` (9/9 real failures, unconditional real
   `attach(to:)`): `privateRuntimeFailure("The required incoming-callback capability was
   rejected.")` — byte-identical to C4/C5/C6/C7's own measurement. Expected: Family 5's whole
   path — the controller's own delete-range resolution, the `.deleteBackward` intent latch, the
   intent-mapper case, and the post-delete selection adoption — was already fully wired by C6/C7
   before this task started (see decision 1 below); this task adds no `TGRichTextInputDecLayoutController`
   `incomingCallbacks` row of its own.

   **Design decisions this task made where the brief's interface underspecified — or was stale
   about — behavior:**

   1. **Step 4 ("implement `id_rangeOfCharacterClusterAtIndex:type:`") and "the bridge header
      (delete group)" file the brief lists both turned out to require NO new code.** Verified,
      not assumed: `TGRichTextInputDecLayoutController.m:480` already grapheme-walks
      `documentPlainTextInRange:` exactly as Step 4 describes (fetches the whole document string
      via the bridge, then `-rangeOfComposedCharacterSequenceAtIndex:` on the caller's clamped
      index) — Task C4 landed it under manifest row 31, which belongs to Family 1's own MARK
      group (`TGRichTextInputDecLayoutControllerInternal.h:97-98`), not Family 5's; the brief's
      Step 4 re-assigning it here is stale prose the supplement already flags. Separately,
      `TGRichTextInputDecClientBridge.h`'s per-task `@optional` group convention (C4 six methods,
      C5 three, C6 four, C7 one) has no C8 entry to add: the controller-side flow this task's
      `Consumes`/`Produces` list names —
      `IDUIKitInputControllerCapability.preflightBackwardDeleteRanges()`/`.backwardDeleteRange()`
      (private-controller-internal, no bridge crossing), the `.deleteBackward` case in
      `IDTextEditorBackendIntent.mutation(for:...)` (added by C7,
      `IDTextEditorBackendIntent.swift`), the `.deleteBackward` intent latch (added by C7 inside
      `TGRichTextInputDecCanvasABIWitness.keyboardInputShouldDelete:`), and the post-delete
      selection adoption (`setCanonicalSelectionAnchor:head:reason:`, C6's fourth bridge method,
      consumed by the `_deleteBackwardAndNotify:` canvas thunk C6 also installed) — were all
      fully wired before this task started. Added a doc-comment note to
      `TGRichTextInputDecClientBridge.h` recording this explicitly (so a future reader does not
      go looking for a missing C8 group), rather than inventing a group with nothing to declare.
   2. **`kernelInput` and `reportKernelFailure(_:witness:)` widened from `private` to `internal`**,
      mirroring `LegacyRichTextInputBackend`'s own documented "ACCESS LEVEL IS LOAD-BEARING"
      precedent for the identical situation (a class split across multiple files; Swift's
      `private` is file-scoped). This is the one genuinely new piece of machinery this task adds:
      `deleteBackward()` moved out of `IDTextEditorBackend.swift`'s class body into a new
      `+KeyInput.swift` extension file (per the brief's own file list), so the two members it
      touches need to be reachable from a second file in the same module. `kernelInteraction`
      stays `private` — nothing outside `IDTextEditorBackend.swift` reads it yet. No
      source-boundary rule restricts `internal` access inside `InputBackend/InputDec/` (that
      directory is the R1/R8 exemption path, confirmed by grep against
      `InputBackendSourceBoundaryTests.swift`); 35/35 boundary tests stayed green.
   3. **Both of `deleteBackward()`'s kernel-witness calls are guarded SEPARATELY, not combined
      into one `TGRichTextInputDecPerform` block**, and the second call is skipped entirely if
      the first raises. `preflightBackwardDeleteRanges()` failing to produce a `unionRange`-
      capable object is a genuine contract violation (the private controller's own
      `_rangesForBackwardsDelete` didn't answer what we asked); attempting the real delete anyway
      would be a "try anyway" the exception guard's whole point is to avoid. Verified this
      matters, not merely by inspection: temporarily force-unwrapping the first call's
      `kernelInput?` produced a REAL `Fatal error: Unexpectedly found nil while unwrapping an
      Optional value` process crash (K3, `IDTextEditorBackendDeleteBackwardRoutingTests`),
      confirming both the guard shape's necessity and the new zero-skip test's teeth; reverted
      and re-confirmed green before committing.
   4. **Step 6 ("run the shared deletion semantic suite for both backends... if it diverges, that
      is a stop") cannot be observed in this environment, and this is a structural fact about the
      `incomingCallbacks` gate, not a gap in this task's testing.** The stop condition presupposes
      BOTH backends can run the same scenario for real so their outcomes can be compared. The ID
      backend cannot: every `.inputDec`-gated suite (incl. this task's own
      `IDBackendFamily5Tests`) skips because `isSupported()` is false until C14 clears the
      remaining 8 rows (measured above) — there is no live ID-backend execution of
      `deleteBackward()` to diverge from Legacy's. This task's diff also touches zero legacy
      deletion code (`LegacyRichTextInputBackend+Deletion.swift`, `DocumentCanvasView+UITextInput.swift`,
      and every `Canvas*BackspaceTests`/`CanvasStructuralTests` file are untouched), so there is
      no plausible mechanism by which this diff regresses "backspace merges paragraphs" or
      "backspace at table cell start" on the Legacy side either — confirmed empirically, not just
      by inspection: the full UIKit run's 68 failures are byte-identical to the pre-task baseline
      (none newly appear or disappear), and none of the 68 names any deletion/backspace suite.
   5. **Two Family-5 test files, not one**, following C7's own split
      (`IDTextEditorBackendIntentTests`/`IDTextStorageFacadeTests` vs. the skip-gated
      `IDBackendFamily4Tests`): `IDBackendFamily5Tests.swift` is the brief's own 4 tests, gated
      like every other family suite (SKIP today — a SKIP is not a FAIL, disclosed, not claimed as
      a pass); `IDTextEditorBackendDeleteBackwardRoutingTests.swift` is NEW, zero-skip-gate, and
      genuinely RUNS (2/2) — it constructs a bare, unattached `IDTextEditorBackend()` (no canvas,
      no `attach(to:)` attempt, so none of `IDDocumentCanvasView(inputBackend:)`'s self-attach/
      `assertionFailure()` crash trap is anywhere near it) and calls `deleteBackward()` directly,
      proving the new routing's guarded-optional-chain shape is safe on a nil `kernelInput` — the
      one thing about this task's own new code that CAN be verified without a live kernel. The
      grapheme-cluster-walking logic itself (Step 4/Family 1, C4's code) could not get further
      zero-skip coverage from this task: `TGRichTextInputDecLayoutController`'s `id_`-prefixed
      methods live in `Host/TGRichTextInputDecLayoutControllerInternal.h`, outside the module's
      `publicHeadersPath: "include"` (confirmed in `Package.swift`/`BUILD`), so Swift test code
      cannot reach them at all — the same structural constraint that already kept EVERY Family
      1/2 test suite (not just this task's) skip-gated; it is not new to Family 5 and not a gap
      this task introduced or could close.

9. **Task C9 lands Family 6 (marked text and prediction) but owns ZERO `incomingCallbacks` rows —
   both falsifiable predictions hold EXACTLY: mismatch count stays 8, attach failure text stays
   byte-identical.**

   Measured with the same scratch technique C4-C8 used, via raw `xcodebuild`, added then fully
   removed before committing:
   ```
   SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
   incoming.visualSelection (C12, 1) + incoming.annotatedSubstring/addAnnotation/
   annotationAtPosition/removeAnnotation/addRendering/removeRendering/invalidateTemporary (C14, 7).
   ```
   Attach failure text, grepped across the WHOLE 68-failure UIKit run (`grep -o 'failed: caught
   error: .*' | sort -u` returns exactly ONE distinct string across all 68):
   `privateRuntimeFailure("The required incoming-callback capability was rejected.")` —
   byte-identical to C4-C8's own measurement. Expected: `.prediction` (this task's one
   `requestedCapabilities` addition) is one of `IDUIKitBehaviorKernel.m`'s
   `optionalDeclarativeCapabilityNames` (alongside `checking`/`typingAttributes`/`paste`/
   `dictation`), never `declarativeCapabilityNames = @[@"incomingCallbacks"]` — the single
   contract that `[input detach]`s and throws on rejection. Marked text is otherwise ENTIRELY
   `kernelInput` routing + this backend's own single-`state` bookkeeping, never a
   `TGRichTextInputDecLayoutController` row.

   **Design decisions this task made where the brief's interface underspecified — or was stale
   about — behavior:**

   1. **Step 3's `.capabilityPrediction` does not compile — confirmed, not merely trusted from the
      supplement.** `.prediction` is the correct spelling, matching the supplement's §1 and the
      established pattern from `.inputController`/`.typingAttributes`/`.incomingCallbacks`
      (Tasks C0/C4/C5/C6). Added to `requestedCapabilities` unconditionally: verified by reading
      `IDUIKitBehaviorKernel.m` that a rejected `.prediction` contract cannot fail attach (see
      above) — it only leaves `IDUIKitInputControllerCapability.hasValidatedCapability(.prediction)`
      false, which is exactly what `-setAttributedMarkedText:selectedRange:`'s own fallback to
      plain `-setMarkedText:selectedRange:` already handles (`IDUIKitInputControllerCapability.m:
      274-288`) — this backend never calls `-setAttributedMarkedText:selectedRange:` itself (it is
      not part of the standard `UITextInput`/`UIKeyInput` protocol pair `kernelInput` conforms to
      in the public header; it is UIKit's own private caller that would use it, if anything does).
   2. **`TGRichTextInputDecLayoutController.m` needed NO new code, and neither did the client
      bridge's marked-text group — verified, not assumed, mirroring C8's identical finding one
      family over.** `grep -n "arkedText\|redict"` across `TGRichTextInputDecLayoutController.m` /
      `TGRichTextInputDecLayoutControllerInternal.h` / `TGRichTextInputDecClientBridge.h` returns
      NOTHING. The whole marked-text/prediction surface routes through the standard `UITextInput`
      members `IDUIKitInputControllerCapability` already inherits from conforming to
      `<UITextInput, UIKeyInput>` — there is no `id_`-prefixed private-controller callback for
      marked text the way Family 1/2's caret/geometry/navigation queries need one, so no manifest
      row and no bridge crossing exist for this family at all. A doc-comment note was added to
      `TGRichTextInputDecClientBridge.h` recording this explicitly, mirroring C8's own.
   3. **A composing edit's `state.markedRange`/`.isComposing` adoption needed NO new code either —
      it already reaches `adoptAndEmitDidChange(_:RichTextInputMutationResult)` through the
      EXISTING Family-4 two-phase transaction, because `IDTextEditorBackendIntent.mutation(for:
      .markedText, …)` and the `keyboardInput:shouldInsertText:isMarkedText:YES` intent latch were
      both already landed by Task C7.** What this task DID have to add: the `markedRange` witness
      itself (`RichTextInputBackend.swift`'s state-snapshot getter, distinct from the UITextInput
      `markedTextRange` witness) was still the Task-C0 `{ nil }` stub, so `isComposing` — spelled
      from THAT member per the protocol's own documented rule — could never read `true` regardless
      of what `state.markedRange` held internally. Fixed by routing `markedRange` to
      `state.markedRange`; `test_setMarkedTextPublishesIsComposing` is the pin. This is the kind of
      gap the class's own header warns about ("a conformer stubbed to plausible values... makes an
      `.inputDec` test pass while testing nothing") — here inverted: the stub was ALREADY blocking
      a test from passing even after the real state existed underneath it.
   4. **`unmarkText()` needed an EXPLICIT state retirement this backend's existing machinery does
      not supply for free — the one genuinely new piece of Family-4-adjacent plumbing this task
      adds.** `IDUIKitInputControllerCapability.unmarkText` is a bare one-line forward to the real
      private controller's own `-unmarkText`, which (mirroring the standard `UITextInput` contract
      every text view honors, and `LegacyRichTextInputBackend+MarkedText.swift`'s own
      `legacyUnmarkText`/`commitMarkedText()` precedent: "Does NOT mutate text — provisional chars
      stay committed") commits without inserting or removing a character. So no
      `replaceCharactersInRange:withString:` call reaches the storage façade, no
      `prepareAndCommitReplacement` round-trip happens, and `adoptAndEmitDidChange` never runs —
      `state.markedRange` would go stale forever without an explicit clear. Added
      `commitMarkedTextStateIfComposing()` — a narrow, purpose-built `internal` crossing point
      (mirroring `kernelInput`'s own "ACCESS LEVEL IS LOAD-BEARING" precedent for the identical
      file-split reason), not a blanket widening of `state`/`publishState`. `test_unmarkTextCommitsTheComposition`
      is the pin.
   5. **`synchronizeAfterExternalChange(_:)`'s three `RichTextMarkedTextPolicy` branches were
      extracted as a `static`, self-contained pure function (`reconciledMarkedRange(currentMarkedRange:
      change:rebase:)`) rather than inlined into the instance method** — the strongest non-skip-gated
      coverage this task could give "the most intricate logic in the task" (task-C9 supplement §3):
      it takes the marked range and a `rebase` callback as plain values, so it needs NO attached
      kernel, NO host, and NO canvas at all. `IDTextEditorBackendMarkedTextPolicyTests` (9 tests,
      zero skip-gate) drives it directly and genuinely EXECUTES on this runtime — unlike every
      `IDBackendFamily6Tests` assertion, which needs a live kernel and stays skip-gated until C14.
      **Proven capable of failing, not merely capable of passing**: a real mutation-and-revert run
      (swapping `.discard`'s `return nil` to `return range`, and dropping the `min`/`max`
      normalization in the `.preserveIfRebasable` branch) produced 3 genuine `XCTAssertNil`/
      `XCTAssertEqual` failures with real quoted output (`("nil") is not equal to
      ("Optional({40, 10})")` among them — see this task's report), then reverted and reconfirmed
      green (9/9).
   6. **This backend's `synchronizeAfterExternalChange(_:)` carries NONE of `LegacyRichTextInputBackend`'s
      `transactionPhase`/deferred-external-change/reentrancy machinery — a deliberate omission, not
      an oversight.** Family 3-5 never built any such machinery for this backend (there is no
      `transactionPhase` field on `IDTextEditorBackend` at all), and inventing it here, unasked, for
      a brief whose hard invariant is narrowly "never synthesize a counterfeit keyboard mutation"
      would be exactly the "plausible fake" this file's own header warns against. The method is a
      plain guard-reconcile-adopt-publish bracket, matching the granularity `setSelection(_:reason:)`
      (Family 3) already established for this backend.
   7. **Step 6's cross-backend comparison (`LegacyBackendSemanticTests` on K1 vs. `IDBackendSemanticTests`
      on K3, both green) is STRUCTURALLY UNREACHABLE for the `.inputDec` half while `isSupported()`
      is false — exactly the same finding C8's own entry 8 §4 recorded for Family 5's Step 6, one
      family earlier.** `IDBackendSemanticTests` (the shared suite's `.inputDec` arm) is gated the
      identical way every other `.inputDec` suite in this stage is; there is no live ID-backend
      execution of `setMarkedText`/`unmarkText` to compare against Legacy's — measured, not
      assumed: `IDBackendSemanticTests` runs `18 tests, with 18 tests skipped and 0 failures`
      (all 15 pre-existing Family-1-4 cases PLUS this task's 3 new ones, all skipping together).
      This entry declares that half of the Step-6 stop condition unsatisfiable today rather than
      ticking it.

      **The other half IS reachable, and this task did it for real, not merely wrote it.** The
      three shared cases the brief's Step 6 names (`test_setMarkedTextPublishesAMarkedRange`,
      `test_unmarkTextClearsTheMarkedRange`, `test_markedTextIsReplacedNotAppendedOnASecondSetMarkedText`)
      were added to `BackendSemanticContractCases` (`// MARK: - Family 6: marked text`) and
      `LegacyBackendSemanticTests` runs ALL 18 (15 pre-existing + 3 new) for real against the REAL
      Telegram document/geometry clients on K1 — `Executed 18 tests, with 0 failures`. This is
      GENUINE new Legacy-side coverage today (the shared suite had never exercised marked text at
      all before this task), and it will extend to the ID side automatically the moment C14 clears
      `isSupported()` — no further edit needed there.

      **Caught real red on the first draft, not merely written to pass**: the first draft asserted
      raw `NSRange` literals (`NSRange(location: 5, length: 1)`) for the marked range after
      composing at `beginningOfDocument`-offset-5. `test_setMarkedTextPublishesAMarkedRange` failed
      with `XCTAssertEqual failed: ("Optional({6, 1})") is not equal to ("Optional({5, 1})")` —
      the position axis is SPARSE (this file's own Family-1 tests already document
      `beginningOfDocument` sitting at raw offset 1, not 0, on this fixture), so a caret 5 positions
      past it is raw 6, not 5. Fixed by switching to the file's own established relative-offset
      idiom (`h.canvas.offset(from:to:)` against `h.canvas.markedTextRange`, never a hardcoded
      absolute), matching `test_aReversedSelectionRoundTripsThroughSelectedTextRange`'s own
      precedent one Family up. Re-run confirmed green (18/18) after the fix.

10. **Task C10 lands Family 7 (responder commands and clipboard) but owns ZERO `incomingCallbacks`
    rows — both falsifiable predictions hold EXACTLY: mismatch count stays 8, attach failure text
    stays byte-identical.**

    Measured with the same scratch technique C4-C9 used, via raw `xcodebuild`, added then fully
    removed before committing:
    ```
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
    incoming.visualSelection (C12, 1) + incoming.annotatedSubstring/addAnnotation/
    annotationAtPosition/removeAnnotation/addRendering/removeRendering/invalidateTemporary (C14, 7).
    ```
    Attach failure text, grepped across the WHOLE failing-test run
    (`grep -oE "failed: caught error: .*" | sort -u` returns exactly ONE distinct string across all
    9 `IDBackendMutationContractTests` failures, and the full-suite re-run below confirms the same 8
    suites / same 68 total, byte-for-byte): `privateRuntimeFailure("The required incoming-callback
    capability was rejected.")` — byte-identical to C4-C9's own measurement. Expected: `.paste`
    (this task's one `requestedCapabilities` addition) is one of `IDUIKitBehaviorKernel.m`'s
    `optionalDeclarativeCapabilityNames` (alongside `checking`/`typingAttributes`/`prediction`/
    `dictation`), never `declarativeCapabilityNames = @[@"incomingCallbacks"]` — the single contract
    that `[input detach]`s and throws on rejection. Responder commands are otherwise entirely
    `RichTextInputCommandClient` routing + one `kernelInput` availability read, never a
    `TGRichTextInputDecLayoutController` row.

    **Full-suite re-run after this task: UIKit 2592 executed / 148 skipped / 68 failures (same 8
    suites, same per-suite counts 9/6/8/7/11/15/6/6 as every prior entry in this log); Core 408 / 0
    failures — unchanged.** +13 executed / +4 skipped over the pre-task baseline (2579/144) is
    exactly this task's own new test count: 9 non-skip-gated `IDTextEditorBackendCommandRoutingTests`
    (all pass) + 4 skip-gated `IDBackendFamily7Tests` (all skip) = 13 total, 4 of them skipped.

    **Design decisions this task made where the brief's interface underspecified — or disagreed
    with — behavior:**

    1. **`.performCut(_:)`/`.performCopy(_:)`/`.performPaste(_:)` are named in the brief's own
       `Consumes (kernel)` list but are NEVER CALLED — a deliberate divergence, recorded in
       `DIVERGENCES.md`'s own numbered entries (this one) per the brief's Step 4 instruction.**
       Reading `IDUIKitInputControllerCapability.m`'s implementation of all three
       (`performCut:`/`performCopy:`/`performPaste:`, lines 572-604) shows each forwards straight to
       `[self activeController]` — the real PRIVATE `UITextInputController` — which would let it
       mutate Telegram's document directly, bypassing `RichTextInputDocumentClient.prepareMutation`/
       `commitPreparedMutation` entirely. The spec forbids that (every mutation goes through the
       document client). So `performCommand(_:sender:)` routes every command through
       `RichTextInputCommandClient.prepare`/`.commit` instead, and the ONLY kernel witness this task
       calls is `shouldHandlePasteAction(_:sender:)` — read directly from
       `IDUIKitInputControllerCapability.m` (lines 552-570): when the `.paste` capability is
       validated it ALSO forwards to `activeController` for the *availability* question
       (`_canHandleResponderAction:`/`_shouldHandleResponderAction:withSender:`), but that method
       only ANSWERS a `BOOL`, mutating nothing — the one kernel consultation this file's own header
       says is genuinely UIKit's to make.
    2. **`.capabilityPaste` does not compile — `.paste` is correct, verified by reading
       `IDUIKitBehaviorKernel.m` rather than trusting the supplement alone.** `.paste` sits in the
       kernel's `optionalDeclarativeCapabilityNames` array (`IDUIKitBehaviorKernel.m:260-266`,
       alongside `checking`/`typingAttributes`/`prediction`/`dictation`), and that loop
       (`:267-299`) never `[input detach]`s or throws on rejection — only the SEPARATE
       `declarativeCapabilityNames = @[@"incomingCallbacks"]` entry earlier in the same initializer
       does. So adding `.paste` to `requestedCapabilities` unconditionally cannot move the
       `incomingCallbacks` mismatch count or the attach failure text, confirmed above by
       re-measurement, exactly as C9 found for `.prediction`.
    3. **`canPerformCommand(_:sender:)`'s three gates for `.paste` (edit policy, command client,
       kernel) were extracted as a `static`, self-contained pure function
       (`canPerformCommandDecision(_:editPolicyAllowsPaste:commandClientAllows:kernelPasteAvailability:)`)
       rather than inlined into the instance method** — mirroring `reconciledMarkedRange(...)`'s own
       shape (Task C9) for the identical reason: the strongest non-skip-gated coverage this task can
       give the family's substance. The kernel gate is a CLOSURE, not a plain `Bool?` parameter,
       specifically so a test can observe whether it fired — proving the "never asked once the
       client already said no" guarantee rather than merely asserting the boolean OUTCOME.
       `IDTextEditorBackendCommandRoutingTests` (9 tests, zero skip-gate) drives it directly and
       genuinely EXECUTES on this runtime. **Proven capable of failing, not merely capable of
       passing**: a real mutation-and-revert run (moving the kernel-closure call ahead of the
       command-client gate) produced 2 genuine `XCTAssertFalse` failures with real quoted output
       (`"the private controller must never be asked once the command client already said no"` and
       `"a policy that already says no must short-circuit before the kernel is asked"` — see this
       task's report), then reverted and reconfirmed green (9/9).
    4. **`performCommand(_:sender:)`'s prepare/commit transaction was likewise extracted as a
       `static` function (`performCommandViaClient(_:sender:client:)`) taking the command client
       DIRECTLY**, rather than through `host`/`self` — reachable and testable with a bare
       `FakeInputCommandClient(log:)`, no canvas, no host, no attach at all. Unlike
       `LegacyRichTextInputBackend.performCommand(_:sender:)`, which forwards five of the eight
       `RichTextInputCommand` cases straight to renamed canvas bodies (`legacyCut`/`legacyCopy`/…)
       because those bodies predate the command-client abstraction and are wider than its model of
       them (see that file's own header) — this backend has no such legacy bodies, so EVERY command
       routes through the client uniformly, which is also what keeps this witness's own mutation
       forbidden per this task's divergence (decision 1 above).
    5. **Neither `canPerformCommand(_:sender:)` nor `performCommand(_:sender:)` performs any state
       adoption from the command result** (`RichTextInputCommandResult.revision`/`.selection` are
       read by NOTHING in this task's diff). `.copy` in particular is read-only and must never
       reorder or collapse the backend's own `state.selection` — pinned by
       `test_copyOfAReversedSelection_copiesTheLogicalRange`, which drives a REVERSED selection
       through `.copy` and asserts it survives byte-identical. Adding a state-adoption bracket here
       (mirroring Family 4's `adoptAndEmitDidChange(_:RichTextInputMutationResult)`) was considered
       and REJECTED as unscoped: no test in this task's brief asks for it, and `RichTextInputCommand`
       carries no per-command "did this genuinely change the document" evidence beyond what the
       fake's `commitResult` happens to be configured with in a test — inventing the bracket now
       would be exactly the "plausible fake" this file's own header warns against. A future task
       wiring a REAL command client for this backend (mirroring `TelegramCommandInputClient`) owns
       deciding whether/how to adopt `RichTextInputCommandResult` into `state`.
    6. **`host` (`IDTextEditorBackend`'s stored `weak var`) widened from `private` to `internal`** —
       the identical file-scoping reason `kernelInput` was widened at Task C8: `+Responder.swift`
       needs `host.lifecycleClient`/`host.commandClient`, and Swift's `private` is file-scoped. No
       source-boundary rule restricts `internal` access inside `InputBackend/InputDec/` (the R1/R8
       exemption, per C8's own identical finding).

11. **Task C11 lands Family 8 (responder lifecycle) but owns ZERO `incomingCallbacks` rows — both
    falsifiable predictions hold EXACTLY: mismatch count stays 8, attach failure text stays
    byte-identical.**

    Measured with the same scratch technique C4-C10 used, via raw `xcodebuild`, added then fully
    removed before committing:
    ```
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=8
    incoming.visualSelection (C12, 1) + incoming.annotatedSubstring/addAnnotation/
    annotationAtPosition/removeAnnotation/addRendering/removeRendering/invalidateTemporary (C14, 7).
    ```
    Attach failure text, grepped across the WHOLE failing-test run (`grep -oE "failed: caught
    error: .*" | sort -u` returns exactly ONE distinct string across all 68 failures):
    `privateRuntimeFailure("The required incoming-callback capability was rejected.")` —
    byte-identical to C4-C10's own measurement. Expected: responder lifecycle is entirely
    `RichTextInputLifecycleClient` routing + one (currently inert) `kernelInteraction` witness call,
    never a `TGRichTextInputDecLayoutController` row.

    **Full-suite re-run after this task: UIKit 2603 executed / 155 skipped / 68 failures (same 8
    suites, same per-suite counts 9/6/8/7/11/15/6/6 as every prior entry in this log); Core 408 / 0
    failures — unchanged.** +11 executed / +7 skipped over C10's own post-task baseline (2592/148)
    is exactly this task's own new test count: 5 skip-gated `IDBackendFamily8Tests` + 2
    non-skip-gated `IDTextEditorBackendWindowRemovalTests` (both pass) + 2 new shared-suite cases ×
    2 subclasses (`LegacyBackendSemanticTests` — both genuinely pass; `IDBackendSemanticTests` —
    both skip) = 11 total, 7 of them skipped (5 + 2).

    **Design decisions this task made where the brief's interface underspecified — or disagreed
    with — behavior:**

    1. **`insertText(_:)`'s edit-policy gate is the ONE place `RichTextInputLifecycleClient.editPolicy`
       is consulted for this backend, and it is DISCLOSED as narrower than it looks.** This backend
       has no real insertion wiring at all yet (a later, unassigned family — no `kernelInput` call,
       no document-client mutation) — the guard added here (`guard isAttached, let host,
       host.lifecycleClient.editPolicy.isEditable else { return }`) still leaves the method doing
       nothing besides consulting and rejecting. What is genuinely NEW is that the consultation
       itself is real and re-read every call (`test_editPolicyIsReadAtOperationTime_notCachedAtAttach`),
       not that a working mutation is now gated.
    2. **`BackendSemanticContractCases.test_notEditableRejectsInsertText` — the brief's third
       Step-5 shared case — is DELIBERATELY NOT ADDED, after a real red run disproved the premise it
       was written on.** The brief's own supplement item 3 calls edit-policy consultation "pure
       Swift decision logic" and the shared-suite instruction assumes `canvas.editPolicy` gates
       `insertText` identically for both backends (plausible: `canvas.editPolicy` IS settable
       directly and BOTH backends' production `lifecycleClient` reads it — one
       `TelegramLifecycleInputClient(canvas: self)`, constructed once in `DocumentCanvasView.init`
       regardless of which backend attaches). **Measured, not assumed: adding the shared case and
       running it against the REAL `LegacyBackendSemanticTests` failed** —
       `XCTAssertEqual failed: ("Optional("Alpha!\nBeta")") is not equal to ("Optional("Alpha\nBeta")")`
       — because `LegacyRichTextInputBackend.insertText(_:)` is, since deviation D35, a plain
       forward to `legacyCanvas?.legacyInsertText(text)`
       (`LegacyRichTextInputBackend+Insertion.swift`) that consults `editPolicy`/`isEditable`
       NOWHERE in its reachable body (grepped: zero hits across
       `DocumentCanvasView+UITextInput.swift`). `TelegramDocumentInputClient.prepareMutation`'s own
       `guard canvas.editPolicy.isEditable` gate — where the instruction's author evidently expected
       the check to live — is reached only by the ID backend's two-phase mutation transactions
       (`deleteBackward`/`setMarkedText`), never by Legacy's structural `insertText`. The
       PRE-EXISTING `BackendEditPolicyTests.test_notEditable_rejectsInsertText_…` (Task 22i) passes
       only because it substitutes the TEST-ONLY `ReferenceMutationBackend` — its own doc comment:
       "stage 1's legacy conformer no longer owns that mutation" — not the real
       `LegacyRichTextInputBackend` this shared suite's `.legacy` arm actually attaches. Adding the
       case would therefore either fail honestly (unacceptable for a shared "both green" case) or
       require retrofitting an editPolicy gate onto Legacy's real `insertText`, which is unscoped,
       production-behavior-changing work well outside Family 8. The ID-side half of the identical
       assertion still exists, unweakened, in `IDBackendFamily8Tests
       .test_notEditablePolicy_rejectsInsertText_withNoDelegateNotifications`. The other two Step-5
       cases (`test_becomeFirstResponderSucceedsOnAnEditableCanvas`/`test_resignFirstResponderEndsEditing`)
       hold for real against Legacy (20/20, see the full-suite re-run above) because
       `becomeFirstResponder()`/`resignFirstResponder()` are canvas-level SHARED overrides
       (`DocumentCanvasView.swift`'s own "Responder lifecycle (TASK 31, Family 8)" section) that
       both backends' `canBecomeFirstResponder`/`canResignFirstResponder` gate identically in shape,
       even though only Legacy's answer is exercised for real today.
    3. **`hostWillMove(toWindow:)` closes a REAL, previously-live leak — not a documented no-op —
       and its fix is EXTRACTED as a static function
       (`stopDisplayLinksForWindowRemoval(_:newWindow:)`) taking the canvas directly, for testability
       without a live kernel.** Before this task the member was an empty stub, so removing an
       `IDDocumentCanvasView` from its window never invalidated the two canvas-level, backend-agnostic
       `CADisplayLink`s the SHARED drag/floating-cursor machinery can leave running
       (`dragAutoScrollLink`/`floatingScrollLink`, both retaining the canvas — the identical
       mechanism `legacyWillMove(toWindow:)` has torn down for Legacy since Task 31). Extracting the
       fix as a canvas-taking static function makes it reachable from a canvas built under the SAME
       reporter-guarded construction `IDBackendContractSubclasses.swift`'s `makeIDContractHost`
       already establishes (the self-attach inside `IDDocumentCanvasView(inputBackend:)`'s `init`
       fails harmlessly today, under a temporary no-op `RichTextInputContractViolation.reporter`) —
       `IDTextEditorBackendWindowRemovalTests` (2 tests, zero skip-gate) drives it directly and
       genuinely EXECUTES on this runtime, unlike every `IDBackendFamily8Tests` assertion including
       `test_removeFromWindowWhileDragging_stopsEveryDisplayLink` itself, which needs the full,
       successfully-attached fake-client harness and stays skip-gated until Task C14. **Proven
       capable of failing, not merely capable of passing**: a real mutation-and-revert run
       (restoring the pre-task empty-stub behavior inside `stopDisplayLinksForWindowRemoval`)
       produced 2 genuine `XCTAssertNil` failures quoting REAL, non-nil `CADisplayLink` instances
       (`"<CADisplayLink: 0x10533c360>" - a nil new window must stop the drag auto-scroll link` and
       the matching floating-cursor line — see this task's report), then reverted and reconfirmed
       green (2/2).
    4. **`kernelInteraction` widened from `private` to `internal` (mirroring `kernelInput`'s and
       `host`'s own identical file-scoping precedent), AND wired for the first time in `attach(to:)`
       (`self.kernelInteraction = kernel.interaction`) — a genuine gap this task closes, not new
       machinery invented for it.** `detach()` has called `kernelInteraction?.detach()` since Task
       C0's illustrative snippet, but nothing had ever ASSIGNED the property, so it was permanently
       nil and that call — and this task's own new `hostDidResignFirstResponder()` call to
       `.resignedFirstResponder()` — were both guaranteed no-ops. Confirmed still true after this
       task's own wiring: `.interaction` is NOT in `requestedCapabilities` (entry 1, autoscroll/
       interaction stay Telegram-owned), so `kernel.interaction` remains nil regardless — this
       assignment is inert today and becomes live only if a later task requests `.interaction`.
    5. **Step 5's cross-backend comparison (`LegacyBackendSemanticTests` on K1 vs. `IDBackendSemanticTests`
       on K3, both green) is STRUCTURALLY UNREACHABLE for the `.inputDec` half while `isSupported()`
       is false — the identical finding C8's entry 8 §4 and C9's entry 9 §7 already recorded for
       Families 5 and 6's own Step 6, one and two families earlier.** `IDBackendSemanticTests` runs
       `20 tests, with 20 tests skipped and 0 failures` (the 18 pre-existing Family-1-6 cases PLUS
       this task's 2 new ones, all skipping together) — there is no live ID-backend execution of
       `becomeFirstResponder`/`resignFirstResponder` to compare against Legacy's. This entry
       declares that half of the Step-5 stop condition unsatisfiable today rather than ticking it.
       **The other half IS reachable, and this task did it for real**: `LegacyBackendSemanticTests`
       runs all 20 (18 + 2 new) for real against the REAL Telegram clients on K1 —
       `Executed 20 tests, with 0 failures`.
    6. **A SECOND, separate "structurally unreachable" declaration, for `test_removeFromWindowWhileDragging_stopsEveryDisplayLink`
       specifically: it has no legacy counterpart at all (the brief's own words), so no cross-backend
       assertion is possible for it — none was invented.** Its ability to fail was verified instead
       by the mutation-and-revert on its zero-skip sibling (`IDTextEditorBackendWindowRemovalTests`,
       decision 3 above), which drives the SAME underlying `stopDisplayLinksForWindowRemoval(_:newWindow:)`
       function `hostWillMove(toWindow:)` calls — the strongest verification available for a test
       that cannot itself execute on this runtime.

12. **Task C12 lands Family 9 (touch interaction and selection) and owns ONE `incomingCallbacks`
    row — row 37, `_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:` — dropping
    the mismatch count 8 → 7; the attach failure text stays byte-identical.**

    Measured with the same scratch technique C4-C11 used, via raw `xcodebuild`, added then fully
    removed before committing:
    ```
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=7
    SCRATCH: mismatches=["incoming.annotatedSubstring: missing …", "incoming.addAnnotation: missing …",
    "incoming.annotationAtPosition: missing …", "incoming.removeAnnotation: missing …",
    "incoming.addRendering: missing …", "incoming.removeRendering: missing …",
    "incoming.invalidateTemporary: missing …"]
    ```
    `incoming.visualSelection` is GONE from the list — the remaining 7 are exactly C14's own
    annotation/rendering/invalidateTemporary rows. Attach failure text,
    `IDBackendMutationContractTests` (9/9 real failures, unconditional real `attach(to:)`, grepped
    with `grep -oE "failed: caught error: .*" | sort -u` returning exactly ONE distinct string):
    `privateRuntimeFailure("The required incoming-callback capability was rejected.")` —
    byte-identical to C4-C11's own measurement.

    **Full-suite re-run after this task: UIKit 2613 executed / 160 skipped / 68 failures (same 8
    suites, same per-suite counts 9/6/8/7/11/15/6/6 as every prior entry in this log — re-verified
    by suite name this time, not merely by count: `IDBackendReentrancyTests` 15,
    `IDBackendMarkedTextPolicyTests` 11, `IDBackendMutationContractTests` 9,
    `IDBackendPublicationContractTests` 8, `IDBackendSelectionContractTests` 7,
    `IDBackendRevisionContractTests`/`IDBackendEditPolicyTests`/`IDBackendAttachDetachTests` 6
    each); Core 408 / 0 failures — unchanged.** +10 executed / +5 skipped over C11's own post-task
    baseline (2603/155) is exactly this task's own new test count: 5 skip-gated
    `IDBackendFamily9Tests` + 3 non-skip-gated `IDTextEditorBackendInteractionPreflightTests` (all
    pass) + 2 non-skip-gated `IDTextEditorBackendInteractionContainerTests` (all pass) = 10 total,
    5 of them skipped. `LegacyBackendSemanticTests`/`IDBackendSemanticTests` stayed at 20/20 —
    this task adds NO shared `BackendSemanticContractCases` cases (see decision 6 below), unlike
    every one of C9-C11's own Families.

    **Design decisions this task made where the brief's interface underspecified — or was stale
    about — behavior:**

    1. **Row 37's real private ABI is unknown, so `id_visualSelectionRangeForExtent:forPoint:
       fromPosition:inDirection:` is a documented, best-effort reconstruction — not guessed at
       blindly.** Its selector is sent while a selection-handle drag is in flight, asking "if the
       dragged handle moved to `point`, what would the resulting selection range be, given the
       drag started from `position` in `direction`". `extent`'s enum meaning is unknown
       (`Vendor/VENDOR.md` records `referenceOnly` — 53 rows — was dropped from this export), so it
       is received and passed through untyped (`NSInteger`), mirroring `id_
       rangeOfCharacterClusterAtIndex:type:`'s own `type:` parameter (Family 1, Task C4). The body
       REUSES Family 1/2 machinery instead of inventing new geometry math: resolves `point` to the
       nearest offset via the SAME `TGClosestPosition` helper `id_cursorPositionAtPoint:
       inContainer:`/`id_nearestPositionAtPoint:inContainer:` already share, then builds the range
       from the caller's own `position` to that resolved endpoint via `id_textRangeFromPosition:
       toPosition:`. Measured as genuinely correct, not merely plausible: the SCRATCH mismatch
       count above confirms the resolver's own ABI validation for this row is satisfied for real.
    2. **`.capabilityInteraction` does not compile — `.interaction` is correct**, the same
       `IDUIKitBehaviorCapability` prefix-stripping shape as `.inputController`/`.typingAttributes`/
       `.incomingCallbacks`/`.prediction`/`.paste` before it. **Confirmed safe by READING the kernel
       source, not by inferring from `nullable` or by assuming it works the same way C9/C10's
       optional capabilities do** — it does not. `.interaction` is NOT one of
       `IDUIKitBehaviorKernel.m`'s `optionalDeclarativeCapabilityNames` (`checking`/
       `typingAttributes`/`prediction`/`paste`/`dictation` only); it is validated by its own
       dedicated `wantsInteraction` block, whose failure path reads as FATAL at first glance
       (`interactionContract == nil` or construction failing both `[input detach]` + throw, exactly
       like the single mandatory `incomingCallbacks` gate). It is safe anyway, for a genuinely
       DIFFERENT reason: `IDUIKitInteractionCapability.initWithContract:resolver:view:error:`
       (`IDUIKitInteractionCapability.m`) has NO code path that returns nil — every failure branch
       (contract rejected, the host-preflight ABI check throwing, the assistant class missing, or
       the assistant's own `initWithView:` raising) still runs `self = [super init]; …; return
       self`, populating only `report`/`floatingCursorReport` and leaving `privateAssistant` nil.
       So the kernel's own `if (interaction == nil) { … return nil; }` is DEAD CODE in practice — a
       rejected `.interaction` contract simply leaves `_interaction` unset on the kernel (gated on
       `interaction.privateAssistant != nil`), i.e. `kernel.interaction` stays nil, exactly the
       pre-C12 state. Full reasoning recorded in `IDTextEditorBackend.swift`'s
       `requestedCapabilities` doc comment.
    3. **Step 4 ("force the container view at attach") needed NO new code — verified, not
       reimplemented, exactly as C8's own Step 4 was.** `prepareInteractionContainer()`
       (`DocumentCanvasView.swift`) already exists and `TelegramPresentationInputClient.init`
       already calls it. The brief's own worry — "your identity test runs on the fake harness,
       whose presentation client may not be `TelegramPresentationInputClient`" — is TRUE (it is
       `FakeInputPresentationClient`, a plain non-`lazy` `UIView`), but irrelevant: `DocumentCanvasView
       .init` constructs `presentationInputClient = TelegramPresentationInputClient(canvas: self,
       facade: nil)` UNCONDITIONALLY, immediately BEFORE `self.inputBackend.attach(to: self)` runs
       — for EVERY canvas, `IDDocumentCanvasView` included, regardless of which backend attaches.
       So the forcing happens before ANY backend's `attach(to:)` can even begin, and
       `IDTextEditorBackend.attach(to:)` never needs to (and does not) touch
       `host.presentationClient` at all. New, genuinely additive, NON-skip-gated coverage of this
       exact fact was added anyway (`IDTextEditorBackendInteractionContainerTests`, decision 5
       below), since the fake-harness test alone cannot exercise it.
    4. **Step 6 ("check Telegram's own drag-autoscroll for conflict") is STRUCTURALLY UNREACHABLE
       today, for reasons DIFFERENT IN KIND from C8/C9/C11's own Step 6 — declared, not
       substituted.** C8/C9/C11's Step 6 was each a cross-backend PARAMETERIZED-SUITE comparison
       (`LegacyBackendSemanticTests` vs. `IDBackendSemanticTests`), unreachable because
       `isSupported()` is false. Family 9's Step 6 is categorically different: a MANUAL, on-device
       simulator interaction ("drag a selection handle to the screen edge") — not a suite at all,
       and doubly unreachable: (a) it needs a LIVE `kernelInteraction` to conflict with anything,
       which does not exist while `isSupported()` is false, exactly like C8/C9/C11's blocker; AND
       (b) manual simulator interaction is the user's to perform, never an agent's, regardless of
       (a). It already exists as Stage D checklist item 11, which is where it belongs — this task
       does NOT substitute a simulator run of its own, and does not tick the brief's own Step 6
       checkbox. **The eventual resolution the brief records is preserved here, unweakened**: if
       Telegram's own `DocumentCanvasView.swift:1392-1449` drag auto-scroll and
       `UITextInteractionAssistant`'s own selection-gesture ownership DO fight once both are live,
       the fix is to DISABLE Telegram's link while `kernelInteraction` is attached — NOT to request
       `autoscrollEntry` (`IDUIKitBehaviorKernel.autoscrollEntry`, DIVERGENCES.md entry 1's own
       autoscroll-stays-Telegram-owned decision, unchanged and unnarrowed by this entry).
    5. **Zero-skip coverage: 5 new tests, all proven capable of failing by real mutation-and-revert
       with quoted output** (matching C7-C11's own standard) — split across two angles the
       supplement named explicitly:
       - **The container-identity invariant** (`IDTextEditorBackendInteractionContainerTests`, 2
         tests). The stronger of the two: `test_constructingTheCanvasAlreadyForcesTheInteraction
         Container_beforeAnyExplicitRead` distinguishes "already forced by the canvas's own
         construction" from "forced only when THIS test reads it" via a subview-COUNT delta (reading
         `selectionChromeContainer` must add zero new subviews if it was already forced) — a
         materially STRONGER claim than a bare identity-equality check, which would hold even if
         BOTH reads happened to realize the `lazy var` for the first time together.
         Mutation-and-revert: commenting out `canvas.prepareInteractionContainer()` inside
         `TelegramPresentationInputClient.init` and re-running produced a real
         `XCTAssertEqual failed: ("13") is not equal to ("12")`, then reverted and reconfirmed
         green.
       - **The preflight-gating decision** (`IDTextEditorBackendInteractionPreflightTests`, 3
         tests) drives `TGRichTextInputDecHostPreflight.requireInteractionHost(_:stage:)` directly
         — no kernel, no host, no attach. Mutation-and-revert: commenting out the
         `selectionContainerView` thunk's `class_addMethod` call in `TGRichTextInputDecInstallCanvasCallbacks`
         and re-running produced two real failures (`XCTAssertTrue failed` + `XCTAssertNil failed`
         quoting the caught ABI-mismatch error), then reverted and reconfirmed green.
       - **A genuine, measured finding surfaced while writing the THIRD preflight test, caught red
         on the first draft**: it asserted all three selector names (`interactionAssistant`,
         `_textInputViewForAddingGestureRecognizers`, `selectionContainerView`) appear as "missing"
         in a LEGACY canvas's preflight-rejection reason, and failed —
         `XCTAssertTrue failed … got: "… ABI mismatch:\nselectionContainerView is missing"` (quoted
         verbatim from the real run). On this SDK, `UIView`/`UIResponder` (an ANCESTOR of
         `DocumentCanvasView`, nothing this task or the kernel installs) already answers
         `-interactionAssistant` and `-_textInputViewForAddingGestureRecognizers` with SOME private
         implementation of its own — the SAME class of OS-level pre-existing-selector fact
         `CanvasCallbackInstallationTests`'s own doc comment already records for the unrelated
         `textInputView`/`_deleteBackwardAndNotify:` pair. `IDDocumentCanvasView`'s own thunks still
         win for real (Objective-C method resolution always prefers a subclass's own
         `class_addMethod`-installed IMP over an inherited one), so this changes nothing about
         whether the preflight passes for `IDDocumentCanvasView` — only which selector(s) a LEGACY
         canvas is caught missing. Fixed by narrowing the test to `selectionContainerView` alone,
         renamed `test_requireInteractionHost_mismatchReasonNamesTheMissingSelector` (singular).
    6. **No new `BackendSemanticContractCases` shared cases — a deliberate scope decision, not an
       oversight.** Every one of C9's (marked text), C10's (responder commands), and C11's
       (responder lifecycle) own Families added shared cases because Legacy has a directly
       comparable behavior to pin against the ID side. Family 9's `IDUIKitInteractionCapability`
       witnesses (`setSelectionActive`/`selectionChanged`/`setNeedsSelectionDisplayUpdate`/
       `setGestureRecognizersEnabled`/`clearGestureRecognizersForced`/`selectWord`/`selectAll`) have
       NO Legacy-backend counterpart at all — Legacy drives touch/selection entirely through
       Telegram's own canvas-level gesture recognizers (`LegacyRichTextInputBackend+Interaction.swift`,
       Task 32), never through anything resembling a private interaction-assistant capability — so
       there is no shared behavior to assert equal. `LegacyBackendSemanticTests`/
       `IDBackendSemanticTests` both stayed at 20 tests (confirmed in the full-suite re-run above),
       neither gaining new cases from this task.
    7. **The seven `IDUIKitInteractionCapability` witnesses (`IDTextEditorBackend+Interaction.swift`)
       are PRODUCED surface, not yet CONSUMED from any canvas call site — disclosed, not glossed.**
       `RichTextInputInteractionBackend`'s existing protocol requirements
       (`installInteractions()`/`removeInteractions()`/…, no-op stubs since Task C0) have no member
       shaped like `selectWord()`/`selectAll(_:)`/`setSelectionActive(_:visible:)`; nothing in this
       task's Files list authorizes widening that protocol. So six of the seven have no call site
       today (white-box test-driven only, once C14 lands); the SEVENTH, `clearGestureRecognizersForced(_:)`,
       gets a genuine first caller from this task's own edit to `IDTextEditorBackend.detach()`
       (called before `kernelInteraction?.detach()`, both before `host.presentationClient
       .tearDownPresentation()`) — mirroring the exact shape C11 left `kernelInteraction`'s own
       wiring in for `hostDidResignFirstResponder()`.
    8. **A real, mechanically-caught bug this task introduced and fixed before committing:**
       `IDTextEditorBackendClientBridge.interactionAssistant()`'s first draft read
       `backend.kernelInteraction?.privateAssistant` bare — an unguarded kernel-witness property
       access. `IDBackendCallGuardTests.test_everyKernelCallIsInsideTheExceptionGuard` (a
       pre-existing, MECHANICAL scan for exactly this shape) caught it for real in this task's own
       full Core suite run: `XCTAssertEqual failed: ("["IDTextEditorBackendClientBridge.swift:286"]")
       is not equal to ("[]")`. Fixed by wrapping the read in `TGRichTextInputDecPerformReturningObject`
       + `reportKernelFailure(_:witness:)`, matching every other kernel-facing crossing point in
       this package; re-run confirmed clean (Core 408/0, this suite 3/3).

13. **Task C13 lands Family 10 (floating cursor; autoscroll deliberately deferred) and owns ZERO
    `incomingCallbacks` rows — the mismatch count stays at 7 (all C14's), and the attach failure
    text is byte-identical.**

    Measured with the same scratch technique C4-C12 used, via raw `xcodebuild`, added then fully
    removed before committing:
    ```
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=7
    SCRATCH: mismatches=["incoming.annotatedSubstring: missing …", "incoming.addAnnotation: missing …",
    "incoming.annotationAtPosition: missing …", "incoming.removeAnnotation: missing …",
    "incoming.addRendering: missing …", "incoming.removeRendering: missing …",
    "incoming.invalidateTemporary: missing …"]
    ```
    Identical set to C12's own measurement — this task adds no `incomingCallbacks` row. Attach
    failure text, grepped across the whole 68-failure run with `grep -oE "failed: caught error: .*"
    | sort -u`, returns exactly ONE distinct string:
    `privateRuntimeFailure("The required incoming-callback capability was rejected.")` —
    byte-identical to every prior entry in this log.

    **Full-suite re-run after this task: UIKit 2619 executed / 164 skipped / 68 failures (same 8
    known-red suites, same per-suite counts as every prior entry); Core 408 / 0 failures —
    unchanged.** +6 executed / +4 skipped over C12's own post-task baseline (2613/160) is exactly
    this task's own new test count: 4 skip-gated `IDBackendFamily10Tests` + 2 non-skip-gated
    `IDTextEditorBackendFloatingCursorSuppressionTests` (both pass) = 6 total, 4 of them skipped.
    `LegacyBackendSemanticTests`/`IDBackendSemanticTests` stayed at 20/20 — this task adds no shared
    `BackendSemanticContractCases` case, for the same reason entry 12 gave for Family 9: the
    floating-cursor kernel witnesses have no comparable Legacy-side "ask the private assistant"
    behavior to pin equal (Legacy drives its OWN floating-cursor presentation entirely through
    `DocumentCanvasView+FloatingCursor.swift`'s `legacyBegin`/`legacyUpdate`/`legacyEndFloatingCursor`
    bodies, never through anything resembling this capability).

    **Design decisions this task made where the brief's interface underspecified — or was stale
    about — behavior:**

    1. **`.capabilityFloatingCursor` does not compile — `.floatingCursor` is correct.** The
       ELEVENTH wrong Swift/ObjC name recorded across this plan's prose, the fifth of exactly this
       `.capabilityXxx` shape. Confirmed by a real simulator build, matching the established
       convention.

    2. **The kernel-witness method names in BOTH the brief AND this task's own supplement are ALSO
       wrong — a TWELFTH and THIRTEENTH instance, of a DIFFERENT shape than the `.capabilityXxx`
       ones.** `beginFloatingCursorAtPoint(_:)` and `updateFloatingCursorAtPoint(_:animated:)` (the
       brief's Interfaces block, repeated verbatim in the supplement's own prose) do not compile —
       real errors: `'beginFloatingCursorAtPoint' has been renamed to 'beginFloatingCursor(at:)'`
       and `'updateFloatingCursorAtPoint(_:animated:)' has been renamed to
       'updateFloatingCursor(at:animated:)'`. Swift's Cocoa-API importer applies its "Omit Needless
       Words" transform to these two ObjC selectors (`beginFloatingCursorAtPoint:` /
       `updateFloatingCursorAtPoint:animated:`), folding `AtPoint` into the `at:` argument label —
       the OBJECTIVE-C selector names in `IDUIKitInteractionCapability.h` are exactly as the brief
       spells them; only the SWIFT call syntax differs, and only a real iOS-simulator compile
       surfaces it (`swift build` never type-checks this file at all — see the package CLAUDE.md).
       Found and fixed before committing; no prior task's supplement flagged this shape of error,
       so it is recorded here as new evidence for the standing lesson rather than assumed away.

    3. **`.floatingCursor` is SAFE to request — established by reading `IDUIKitBehaviorKernel.m`,
       not by pattern-matching C9/C10/C12.** `IDUIKitBehaviorCapabilityFloatingCursor` is read in
       exactly two places: computing `wantsFloating`, and a single
       `if (wantsFloating) { [reports addObject: interaction.floatingCursorReport]; }` inside the
       `wantsInteraction` branch — appending an ALREADY-COMPUTED diagnostic report to the
       construction-time `IDUIKitBehaviorReport`. It is not one of `optionalDeclarativeCapabilityNames`
       (`checking`/`typingAttributes`/`prediction`/`paste`/`dictation`), has no dedicated gate of
       its own the way `.interaction` does, and can never throw or fail construction on its own
       account. Requesting it moves neither the `incomingCallbacks` mismatch count nor the attach
       failure text, for the same "not one of the two mismatch-tracked arrays" reason
       `.prediction`/`.interaction` established — re-measured above, not assumed to match by
       analogy.

    4. **A genuinely NEW finding this task's own reading turned up: requesting `.floatingCursor`
       changes NOTHING about whether the three floating-cursor kernel witnesses actually fire.**
       `IDUIKitInteractionCapability.initWithContract:resolver:view:error:` evaluates the
       `floatingCursor` runtime contract and sets `_floatingCursorAvailable =
       floatingResult.isAccepted` UNCONDITIONALLY — triggered purely by `.interaction` being
       requested (true since Task C12), never consulting the kernel's own `requested` bitmask at
       all. `beginFloatingCursorAtPoint:`/`updateFloatingCursorAtPoint:animated:`/`endFloatingCursor`
       (`IDUIKitInteractionCapability.m`) each independently check `self.floatingCursorAvailable`
       and no-op otherwise — so these three were already live-or-inert purely from `.interaction`,
       BEFORE this task's Step 3 edit ever ran. The ONLY observable effect of adding
       `.floatingCursor` to `requestedCapabilities` is whether `interaction.floatingCursorReport`
       is folded into the construction-time diagnostic report (`kernel.report`) — never a
       behavioral difference in the three witnesses this task's Step 4 routes into. Requested
       anyway, matching the brief's Step 3 and this list's own bookkeeping-parity convention, not
       because runtime behavior depends on it.

    5. **The reachable-throw hazard this task's supplement flagged is real but PRE-EXISTING, not
       newly introduced by this task.** `IDUIKitFloatingCursorRuntimeContract()`
       (`IDUIKitInteractionCapability.m:132`, one of the kernel's seven surviving `@throw` sites)
       raises `NSInternalInconsistencyException` when `manifest.capabilities["floatingCursor"]` is
       nil — and per decision 4 above, that call is reached on EVERY `IDUIKitInteractionCapability`
       construction, i.e. on every attach that requests `.interaction` (true since Task C12),
       independent of `.floatingCursor`. So the hazard has been live since C12's own commit, not
       introduced here. Live-verified NON-nil (3 members) on this runtime by the non-skip-gated
       `IDTextEditorBackendFloatingCursorSuppressionTests
       .test_floatingCursorCapabilityIsPresentInTheManifest` (needs only manifest loading — no
       attach, no view, no live kernel), so the throw's precondition does not hold today. **The
       whole call chain that could reach it sits entirely inside A8's exception guard**:
       `attach(to:)`'s `TGRichTextInputDecPerformReturningObject { try IDUIKitBehaviorKernel(...) }`
       block (Step 7 of `attach(to:)`) transitively contains `IDUIKitBehaviorKernel`'s init →
       `IDUIKitInteractionCapability`'s init → this throw site — all inside the same block — so IF
       it ever fired it would be caught there and surfaced as
       `RichTextInputBackendAttachmentError.privateRuntimeFailure(...)`, never crash. This task
       could not force the manifest to omit the key without editing vendored/generated data
       (off-limits per this task's own constraints), so — unlike C12's finding for row 37, which
       was a genuine positive ABI-acceptance measurement — this is static-proof-plus-one-live-
       non-firing-check, not a genuine exercise of the catch. Recorded honestly as a gap, matching
       the standing rule that A8's guard has been static-proof-only since Task C0.

    6. **Step 5's autoscroll-deferral record, narrowing entry 1 with the ABI-witness-specific facts
       entry 1 does not cover.** `IDUIKitBehaviorKernel.autoscrollEntry`
       (`IDUIKitAutoscrollEntryCapability`, entry 1's own subject) is a SEPARATE mechanism from the
       two `incomingCallbacks`-manifest-row ABI witnesses this note is about:
       `TGRichTextInputDecCanvasABIWitness.startAutoscroll:`/`.cancelAutoscroll`
       (`Sources/RichTextInputDecObjC/Host/TGRichTextInputDecCanvasABIWitness.m`, telegram-ios-authored,
       NOT vendored — installed onto the real canvas by `TGRichTextInputDecInstallCanvasCallbacks`).
       Both were implemented by Task B4 as empty `void` bodies, with the rationale already recorded
       in that file's own header comment: they exist only to give the manifest row a real ABI to
       validate against. **They are not called by anything today** — `IDUIKitBehaviorKernel.m`
       gates the `autoscrollEntry` contract's construction (and therefore ANY validation of these
       two methods' signatures) behind `(requested & IDUIKitBehaviorCapabilityAutoscroll) != 0`,
       which is false (`.autoscroll` is never in `requestedCapabilities` — entry 1, unchanged and
       unnarrowed by this task). Per this task's own brief: `startAutoscroll:` returns `void` in
       the manifest (`returnType: "v"`, not `"B"`/BOOL), so there is no `NO` to return — the
       witness bodies were already correct as B4 left them, and this task's Step 5 job was this
       DIVERGENCES.md record, not code; neither `TGRichTextInputDecCanvasABIWitness.m` nor any
       other file this task touches was edited for this step.

    7. **Zero-skip coverage: 2 new tests, both proven capable of failing by real mutation-and-revert
       with quoted output** (matching C7-C12's own standard), plus a third empirical check folded
       into the safety analysis above:
       - `test_selectedTextRangeWrite_isDroppedWhileFloatingCursorActive_beforeReachingSetSelection`
         drives the suppression guard on a bare, never-attached `IDTextEditorBackend()` via the
         unguarded `setFloatingCursorActive(_:)` door — no canvas, no host, no live kernel.
         Mutation-and-revert: commenting out `guard !floatingCursorActive else { return }` in
         `IDTextEditorBackend.selectedTextRange`'s setter and re-running produced a real
         `XCTAssertTrue failed - the floating-cursor guard must return BEFORE the write ever
         reaches setSelection's own isAttached check — a contract-violation report here means the
         guard did not intercept: ["operation on a detached backend: setSelection(_:reason:)"]`,
         then reverted and reconfirmed green.
       - `test_floatingCursorCapabilityIsPresentInTheManifest` — the live check decision 5 above
         depends on. Mutation-and-revert: substituting a non-existent dictionary key
         (`"floatingCursor-TEMP-MUTATION"`) for the real lookup and re-running produced a real
         `failed - manifest.capabilities["floatingCursor"] is nil on this runtime —
         IDUIKitFloatingCursorRuntimeContract() would raise NSInternalInconsistencyException on
         every IDUIKitInteractionCapability construction …`, then reverted and reconfirmed green.
       - The 4 skip-gated `IDBackendFamily10Tests` (all currently SKIP, expected until Task C14)
         are not zero-skip evidence and are not counted as such here — see the honest disclosure in
         that suite's own header and this task's report.

    8. **A finding worth recording rather than silently duplicating: the load-bearing suppression
       invariant this family exists for was ALREADY under test, skip-gated, since Task C6.**
       `IDBackendFamily3Tests.test_selectedTextRangeSetterIsIgnoredDuringFloatingCursor` pins the
       identical decision — driven through the same raw `setFloatingCursorActive(_:)` door this
       task's own non-skip-gated test uses — because that setter's guard has existed since Task C6,
       long before this task gave `beginFloatingCursor(at:)`/`endFloatingCursor()` a real body. What
       this task's `IDBackendFamily10Tests` suite adds beyond that is the other half: that the real
       OS gesture entry points (previously empty no-ops) are what actually DRIVE that same latch —
       not a re-test of the guard itself.

14. **Task C14 lands Family 11 (spellchecking and annotations) — the FINAL 7 `incomingCallbacks`
    rows (41-47) — and this IS the gate-opening task: mismatch count 7 → 0, `incomingCallbacks`
    accepted, and `IDTextEditorBackend.isSupported()` flips `false` → `true` for the first time in
    the whole programme.**

    Measured via the same throwaway-scratch technique C4-C13 used (a temporary `print` inserted
    into `IsSupportedTests.test_mandatoryContractsAreEvaluated_notAssumed`, run via raw
    `xcodebuild test` to bypass `Scripts/iostest.sh`'s grep filter, then fully removed before
    committing):
    ```
    BEFORE (this task's changes stashed, base commit c999f7e058):
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=7
    SCRATCH: mismatches=["incoming.annotatedSubstring: missing TGRichTextInputDecLayoutController
    -annotatedSubstringForRange:", "incoming.addAnnotation: missing … -addAnnotationAttribute:
    value:forRange:", "incoming.annotationAtPosition: missing … -annotationAttribute:atPosition:",
    "incoming.removeAnnotation: missing … -removeAnnotationAttribute:forRange:",
    "incoming.addRendering: missing … -addRenderingAttributes:forRange:",
    "incoming.removeRendering: missing … -removeRenderingAttributes:forRange:",
    "incoming.invalidateTemporary: missing … -_invalidateTemporaryAttributesInRange:"]
    SCRATCH: isSupported=false

    AFTER (this task's full diff):
    SCRATCH: inputController isAccepted=true mismatchCount=0
    SCRATCH: typingAttributes isAccepted=true mismatchCount=0
    SCRATCH: incomingCallbacks isAccepted=true mismatchCount=0
    SCRATCH: isSupported=true
    SCRATCH: running=26.5.0
    ```
    This confirms, for the first time with a live measurement rather than a manifest-provenance
    inference, that the JSON manifest's `"class": "IDRichTextLayoutController"` field genuinely IS
    rewritten to `TGRichTextInputDecLayoutController` inside the baked
    `Generated/TGRichTextInputDecContractData.m` byte array (per `Vendor/VENDOR.md`'s rename
    table) — `NSClassFromString(@"IDRichTextLayoutController")` at runtime resolves to OUR OWN
    class, and the resolver's per-member "missing" text names it by that real name.

    **A genuinely NEW, real, non-manufactured finding surfaced while diagnosing why
    `isSupported()` did NOT flip on the first pass despite mismatchCount reaching 0 for the
    ANNOTATION rows: TWO OTHER, PRE-EXISTING ABI mismatches — in Family 2's (Task C5) and Family
    9's (Task C12) OWN work, not this task's — were masked until this task completed the
    `missing` set, and had to be fixed here for the gate to open at all.**
    `IDUIKitCapabilityResolver.evaluateContract:` (`Kernel/IDUIKitCapabilityResolver.m`) computes
    TWO separate lists per contract — `missing` (a required member whose class or selector is
    absent) and `abiMismatches` (found, but with the wrong return/argument type encoding) — and
    `result.mismatches` is assigned `missing` **whenever `missing.count != 0`, unconditionally**;
    `abiMismatches` is only ever surfaced once `missing` is empty. With this task's 7 rows still
    missing (`missing.count == 7`), any PRE-EXISTING `abiMismatches` on other rows were computed
    every time C4-C13 measured `mismatchCount`, but silently DISCARDED — invisible in every prior
    task's own SCRATCH log. Landing this task's 7 rows was what FIRST let `abiMismatches` surface,
    on a re-measurement after the annotation callbacks alone:
    ```
    SCRATCH: incomingCallbacks isAccepted=false mismatchCount=3
    SCRATCH: mismatches=["incoming.visualSelection: argument 0 expected @, observed q; return @",
    "incoming.ensureLayout: argument 0 expected @, observed {_NSRange=QQ}; return v",
    "incoming.invalidateLayout: argument 0 expected @, observed {_NSRange=QQ}; return v"]
    ```
    Both are genuine, narrow ABI-shape bugs, not semantic bugs:
    - **Row 37 (`_visualSelectionRangeForExtent:forPoint:fromPosition:inDirection:`, Task C12's
      own row).** The manifest's argument-0 type is `@` (an object — most likely `extent` is a
      boxed `NSNumber`, matching an ordinary enum-boxing convention); C12's own implementation
      typed it `(NSInteger)extent`, a raw scalar (`q`). C12's own internal-header comment already
      flagged `extent`'s real meaning as unknown/undocumented ("received and passed through
      untyped … rather than guessed at") — it simply guessed the wrong WIRE SHAPE for "untyped,"
      not merely the wrong semantic meaning (the supplement's own framing — "C12's row 37 extent
      semantics: ABI-shape-correct, meaning unverified" — is itself corrected by this
      measurement: the row was NOT ABI-shape-correct).
    - **Rows 38/39 (`ensureLayoutForRange:`/`invalidateLayoutForRange:`, Task C5's own rows).**
      The manifest wants `@` (`UITextRange *`) for both; C5's implementation typed the parameter
      `(NSRange)range` (a raw struct, `{_NSRange=QQ}`) — the convention row 30's
      `invalidateDisplayForCharacterRange:` genuinely uses, but not what rows 38/39 want. The two
      private protocols evidently differ in this respect, and C5 matched the wrong one.

    **Decision: fixed both, in this task, even though neither row is one of this task's own 7.**
    Reasoning: (1) leaving them broken would leave `incomingCallbacks` permanently rejected and
    `isSupported()` permanently `false`, defeating this task's entire measurable deliverable — the
    "gate opens" claim the whole plan is built around; (2) both fixes are pure wire-type changes
    with ZERO behavior change — `id_ensureLayoutForRange:`/`id_invalidateLayoutForRange:`'s bodies
    are (and remain) empty no-ops, so converting the incoming `UITextRange *` to `NSRange` via the
    pre-existing `id_characterRangeForTextRange:` helper before calling them changes nothing
    observable; `extent` is (and remains) UNUSED by `id_visualSelectionRangeForExtent:...`'s body
    (`(void)extent;`), so widening its wire type from `NSInteger` to `id` and best-effort-unboxing
    (`[extent respondsToSelector:@selector(integerValue)] ? [(NSNumber *)extent integerValue] :
    0`) changes nothing observable either; (3) both are narrow, single-line-signature edits to
    telegram-ios-authored files this task is already touching, not vendored/generated data. Per
    this task's own dispatch — "If the brief and reality disagree in a way the supplement does not
    cover, decide it yourself, implement the better answer, and record the decision" — this is
    recorded as exactly that kind of decision, not a silent scope creep. **The 4 known-unverified
    areas the supplement flagged (C5's bridge behaviours, C6's thunk argument shapes, C12's row 37
    semantics, A8's guard) predicted findings would surface here; this is the concrete instance for
    two of the four, and it is real code, not merely a documentation gap.**

    **Full-suite re-run after this task (K3, iOS 26.5): Core 408 executed / 0 failures —
    byte-identical to every prior entry.** UIKit is dramatically different in kind, not merely in
    count, from every prior entry's "same 8 known-red suites, same per-suite counts" pattern —
    because THIS is the run where `isSupported()` first answers `true`, so `makeIDFakeClientHarness()`
    /`makeBackendHarness(backend: .inputDec)` first construct a REAL, LIVE kernel for the first
    time in ~160 previously-skip-gated tests plus the 68 known-red contract-suite cases (the
    `LegacyBackendSemanticTests`/`IDBackendSemanticTests` parameterised pair, `BackendMutationContractTests`
    /`IDBackendMutationContractTests`, and siblings — all of `Tests/RichTextEditorUIKitTests/InputBackend/`'s
    `Backend*ContractTests.swift` files, plus `Tests/.../InputDec/IDBackend*.swift`). Skips
    collapsed to **5** (exactly the pre-Stage-C baseline the supplement names — see report for the
    precise before/after skip count). Failures are real, numerous, and — per this task's own
    anti-vacuity mandate — NOT weakened, skip-gated, or deleted; they are reported and categorized
    in the task report, not fixed here (all are pre-existing gaps in OTHER families' work, first
    exercised for real by this task's gate-opening, and are out of this task's 7-row scope). The
    report has the full breakdown; the headline shape is: dozens of `IDBackend*Tests`/contract-suite
    failures across Families 1, 2, 4-9 (assertion-level mismatches — wrong text, wrong rect, wrong
    revision/affinity, a policy check returning the wrong value) plus several genuine PROCESS
    CRASHES surfaced for the first time (an unstubbed `fatalError` in `IDTextEditorBackend.swift`,
    a real vendored-kernel `NSMutableRLEArray`/text-storage exception during a marked-text/replace
    path, and a handful of test-fixture force-unwraps that assumed attach always fails). One test
    (`CanvasFactoryTests.test_idDocumentCanvasView_attachesTheGivenBackend_notTheLegacyDefault`) has
    a now-STALE hard-coded assertion that `attach(to:)` always throws "until Task C0" — a test-code
    bug in earlier scaffolding, not a runtime bug, needing an update by whoever owns that file next.

    **This task's own new coverage is clean: `IDBackendFamily11Tests`' 4 tests execute for real
    (not skipped) and all 4 pass; `IDTextEditorBackendClientBridgeCheckingAndAnnotationTests`' 11
    zero-skip tests all pass; `CanvasCallbackInstallationTests`' 6 tests (covering the two new
    canvas thunks via the census list) all pass.**

    **`RichTextInputCanvasFactory.make(.legacy)` is called unconditionally by
    `RichTextEditorView.swift:254` — the one production call site. No shipped, non-test code path
    reads `IDTextEditorBackend.isSupported()` to select a backend; `.inputDecIfSupported`/
    `.inputDecRequired` are used only by test harnesses. So this task's gate-opening changes
    `isSupported()`'s ANSWER but changes NOTHING about what backend the real app uses — every
    finding above is a TEST-ONLY discovery, confirmed by reading the one production call site
    rather than assumed safe.**

    **Design decisions this task made where the brief's interface underspecified — or was stale
    about — behavior:**

    1. **`.capabilityChecking` does not compile — `.checking` is correct**, confirmed against a
       real simulator build (the twelfth wrong `.capabilityXxx`-shaped name in this plan's prose,
       the sixth of exactly this shape). Confirmed SAFE to request unconditionally, by reading
       `IDUIKitBehaviorKernel.m:260-266` directly rather than by analogy: `.checking` IS one of
       `optionalDeclarativeCapabilityNames` (`checking`/`typingAttributes`/`prediction`/`paste`/
       `dictation`) — the SAME purely-declarative, never-construction-gating loop `.prediction`
       (C9) already established is safe. A rejected `.checking` contract only leaves
       `IDUIKitInputControllerCapability.hasValidatedCapability(.checking)` false, never `[input
       detach]` + throw.

    2. **"The two spellchecking thunks" are literal `class_addMethod`-installed canvas thunks
       (`setContinuousSpellCheckingEnabled:`/`isContinuousSpellCheckingEnabled`), not a looser
       reading of "thunk" as "any Swift forwarding method."** The brief's own prose is ambiguous
       here (Consumes lists the KERNEL'S outgoing `checking` capability by these exact two
       selector names; Produces separately lists "the two spellchecking thunks"). Resolved by
       precedent: (a) EVERY use of the word "thunk" anywhere else in this package (grepped
       exhaustively) refers to a `TGThunk_*` C function installed via `class_addMethod` in
       `TGRichTextInputDecCanvasCallbacks.m` — never a Swift method; (b) `CanvasCallbackInstallationTests`'
       22-name census — written at Task A/B, before ANY family's work began — already names both
       exact selectors among the 22, meaning the plan always intended them to be installed there;
       (c) the manifest's OWN `legacyCanvas` reference group documents the upstream REAL canvas
       class implementing a method with the SAME name (`setContinuousSpellCheckingEnabled:`, on
       `IDPrivateUIKit+TextLayoutCanvas.m`) — i.e. a genuine text-view-shaped class answers this
       selector on itself too, not only on its internal controller. Installed the SAME
       unconditional, best-effort-reconstruction way C6/C7/C12's own non-`incomingCallbacks`
       thunks are (neither selector is one of the 47 rows; the manifest's OWN two members with
       these names are on class `UITextInputController`, direction `outgoing` — a DIFFERENT
       mechanism, described in decision 3 below).

    3. **The setter thunk does BOTH things the brief's split implied were separate**: it reaches
       the kernel's own outgoing `.checking` capability (`kernelInput?.setContinuousSpellCheckingEnabled`,
       guarded through `TGRichTextInputDecPerform` like every other kernel call in this package) AND
       mirrors the value onto `(host?.hostInputView as? DocumentCanvasView)?.isSpellCheckingEnabled`
       — the SAME `host.hostInputView as? …` cast pattern already used in `IDTextEditorBackend.swift`'s
       `attach(to:)` and `+Responder.swift`. The getter reads ONLY the canvas-state half (Telegram's
       own model flag is the single source of truth; the kernel's own flag may be unvalidated on any
       given OS and is not authoritative). This reconciles the brief's "Consumes (kernel): …" line
       (satisfied by the guarded `kernelInput` call) with `test_spellCheckingToggleReachesTheCanvasState`'s
       literal name (satisfied by the canvas-state mirror) — both are real, in the SAME thunk.

    4. **The seven annotation callbacks are NOT run through `TGResolvePosition`** (Family 1's
       rebase helper, used by almost every other family in this file). A new helper,
       `TGRawCharacterRangeForRange`, extracts the incoming position/range's RAW, UNRESOLVED
       `documentRevision` and threads it straight through to the matching
       `TGRichTextInputDecClientBridging` method — because `TelegramAnnotationInputClient`'s
       `guard revision == canvas.documentRevision` (an EXACT-match staleness gate: reject, don't
       repair) is the real behavior D17 already documents ("ranges deliberately do not shift");
       resolving the incoming range first would always stamp the CURRENT revision, making that
       gate permanently pass and silently defeating it. None of the 7 ObjC selectors carries its
       own `revision` argument (confirmed against the manifest's `argumentTypes`), so the
       position/range object's own stamp is the only source.

    5. **Testing shape: `IDBackendFamily11Tests` drives a new `IDTextEditorBackend.bridgeForTesting`
       hook, not raw ObjC dynamic dispatch of the seven undeclared selectors.** All seven (and the
       two checking thunks) are UNDECLARED, kernel/OS-driven-only private selectors with no
       Swift-visible entry point — the real native-checking machinery that would drive
       `annotatedSubstringForRange:` etc. is async and OS-scheduled (this package's own CLAUDE.md
       admission: grammar checking "did NOT fire in the unit-test host"), and one selector
       (`addAnnotationAttribute:value:forRange:`, 3 explicit arguments) exceeds what
       `NSObject.perform(_:with:with:)` can even invoke from Swift. `IDBackendFamily4Tests` (Task
       C7) already set this precedent for a multi-arg undeclared thunk: it drives
       `storageFacadeForTesting` directly rather than the private selector that sets its latch.
       `bridgeForTesting` (mirroring `storageFacadeForTesting`'s own DEBUG-only, test-only shape)
       exposes `IDTextEditorBackendClientBridge` so the SEVEN callback methods and the TWO thunk
       methods can be driven directly and deterministically — the layer this task actually writes
       new behavior in; the layout controller's one-line casts above it add nothing beyond ABI
       matching, which the manifest resolver already certifies structurally (measured above).

    6. **Step 7 collision check: the five `DocumentCanvasView+NativeTextCheckingClient.swift`
       `@objc` selectors and this task's two installed canvas thunks share NO name.** Enumerated
       explicitly: `nativeTextRangeForGlobalLocation:length:`, `annotatedSubstringForRange:`,
       `replaceRange:withAnnotatedString:relativeReplacementRange:`, `removeAnnotation:forRange:`,
       `validAnnotations` (a property). This task installs exactly two selectors onto
       `IDDocumentCanvasView`: `setContinuousSpellCheckingEnabled:`, `isContinuousSpellCheckingEnabled`.
       Neither matches any of the five — **no collision, result: pass.** One adjacent, harmless
       coincidence worth recording so a future reader does not mistake it for a near-miss: this
       task's LAYOUT CONTROLLER (a completely different, unrelated Objective-C class,
       `TGRichTextInputDecLayoutController`) implements a method ALSO named
       `annotatedSubstringForRange:` (row 41) — but Objective-C method dispatch is per-class, and
       two unrelated classes answering the same selector name is ordinary, unremarkable Cocoa
       (every `NSObject` subclass answers `-description`); it is not the same hazard Step 7 is
       about (a SECOND `class_addMethod` onto the SAME canvas class), and this task confirmed that
       distinction rather than asserting it.

    7. **Zero-skip coverage: 11 tests, 2 of them proven capable of failing by real
       mutation-and-revert with quoted output** (matching C7-C13's own standard):
       - `test_annotatedSubstring_forwardsToTheAnnotationClient`. Mutation: changed
         `annotatedSubstring(forRange:revision:)`'s body from the real forward to `nil`.
         Re-run: `XCTAssertEqual failed: ("0") is not equal to ("1")`. Reverted, reconfirmed green.
       - `test_setNativeContinuousSpellCheckingEnabled_reachesCanvasState_withNoLiveKernel`.
         Mutation: commented out the `(host?.hostInputView as? DocumentCanvasView)?
         .isSpellCheckingEnabled = enabled` line. Re-run: TWO real `XCTAssertFalse failed`
         (the setter no longer moved the canvas state, so both post-toggle assertions failed).
         Reverted, reconfirmed green.
       - The remaining 9 (one per other annotation-forward method, plus the getter and the
         nil-host inertness pair) are not separately mutation-tested here for time, but follow the
         identical one-line-forward shape the two proven cases do — each asserts a client-side
         call-count/log entry that only the matching forward line produces.
       - The 4 skip-gated `IDBackendFamily11Tests` (all now EXECUTE — not skipped — and all 4
         pass, one only after a genuine test-authoring bug this task found and fixed in its own
         divergence test: an off-by-one between the annotation client's 1-based GLOBAL axis and
         `spellResults`' 0-based REGION-LOCAL axis, plus a missing `beginUndoGrouping`/
         `endUndoGrouping` bracket around the direct `canvas.insertText(...)` call — both fixed
         before this entry was written) are executing-and-passing evidence, not skip-evidence.

15. **Task R2 wires `insertText(_:)` — route (b), through the storage façade, not a direct
    `prepareAndCommitReplacement` call — with the evidence, and records two NEW, real kernel/
    harness-boundary limitations this wiring exposes for the first time.**

    **The route (a)/(b) decision, with evidence from the façade's own source
    (`TGRichTextInputDecTextStorageFacade.m`/`.h`).** `TGRichTextInputDecTextStorageFacade` is not
    a bare pass-through to the bridge: its own header doc comment states its purpose directly —
    "UIKit calls `string` and `attributesAtIndex:effectiveRange:` constantly during layout and
    selection, so `mirror` [a real, private `NSMutableAttributedString`] answers those reads;
    Telegram's document (behind `bridge`) remains the WRITE authority." Its
    `replaceCharactersInRange:withString:` override does FOUR things on a successful transaction,
    not one: (1) run the two-phase transaction through `bridge`; then, only if applied, (2)
    `beginEditing`/`[self.mirror replaceCharactersInRange:...]`/`endEditing`, (3) post `edited:`
    (which is what notifies whatever `NSLayoutManager`/text-storage observer the private kernel
    controller has attached), and (4) advance `self.revision` from the transaction's own outcome.
    Calling `bridge.prepareAndCommitReplacement` directly (route a) performs step (1) alone: the
    document client would be correct, but `mirror`/`revision` — which the private input
    controller's OWN read path depends on, and which `setMarkedText` (a DIFFERENT witness,
    `+TextBackend.swift`, driven through `kernelInput`, which reaches this SAME façade as a side
    effect of the private controller's own internal work) ALSO depends on — would silently go
    stale. Route (b) is what this task implemented; the mirror/revision divergence route (a) would
    have caused is real but is NOT visible to any of this task's target tests (none reads `mirror`
    back), which is exactly why the brief flagged it as evidence-worthy rather than test-provable.

    **Two genuine, NEW kernel/harness-boundary limitations surfaced by exercising this façade path
    for the first time from `insertText(_:)` — neither is a defect in this task's own wiring, and
    neither was fixable within this task's scope (kernel/vendored code and shared, widely-used
    test infrastructure are both off-limits per the task's own hard constraints):**

    - **A live, first-time-constructed kernel reacts to `edited:` on a FAKE-host canvas with zero
      real laid-out content, by calling BACK into `IDTextEditorBackendClientBridge
      .documentRebaseOffset(_:fromRevision:outOffset:)` (Family 1's own bridging method,
      `TGResolvePosition` in `TGRichTextInputDecLayoutController.m`) many times per mutation — a
      DETERMINISTIC, always-nil-rebase, always-harmless (the kernel keeps its own stale-but-valid
      offset on a `nil` rebase, per `TGResolvePosition`'s own documented fallback), but LOGGED
      side effect the fake `FakeInputDocumentClient.rebase` records as `.documentRebase` events —
      invisible to the real app (nothing there logs kernel-internal calls) and invisible to every
      OTHER target test in this task's cluster (none does an EXACT `log.kinds` array-equality
      check on a genuinely-committed mutation except one). This is the SAME class of kernel/façade
      instability entry 3's own root-cause discussion and the R1 clustering doc's "Cluster 5"
      (`NSMutableRLEArray … Out of bounds`, `IDBackendFamily4Tests
      .test_replaceOverASelection_carriesTheCanonicalSelection` and five siblings — still
      reproducing, unaffected, unrelated to this task) already document for `setMarkedText`/
      `replace` — this task's wiring is what first makes `insertText(_:)` a NEW member of that
      same family, via a DIFFERENT symptom (log pollution rather than a crash) once the mirror-range
      out-of-bounds crash below is fixed. Blocks exactly one target test:
      `IDBackendMutationContractTests.test_insertText_readyPreparation_commitsExactlyOnce_andPublishesApplied`
      (its 8-event prefix is byte-correct; 15 extra `documentRebase` entries are appended after it).
    - **`bridge.storage.mirror` starts and stays EMPTY in every test harness in this package**,
      because nothing before this task ever wrote through this witness — `[NSMutableAttributedString
      replaceCharactersInRange:withString:]` raises `NSRangeException` ("NSMutableRLEArray …
      Out of bounds") for a `range.location` past the mirror's actual (0) length, which
      `state.selection`'s LOGICAL offset (tracked against the document client's own, usually much
      larger, `utf16Length`) routinely is. `insertText(_:)` now clamps the range it hands the
      façade to `[0, bridge.storage.mirror.length]` — see that call site's own comment — which is
      what converts this from a process-crashing exception (measured directly:
      `IDBackendRevisionContractTests.test_stalePosition_isRebasedOnce_thenPreparesAtTheNewRevision`
      crashed with exactly this exception before the clamp) into the harmless log-pollution above.
      The DOCUMENT MUTATION sent to `host.documentClient.prepareMutation` is unaffected by this
      clamp — it is built from `backend.state.selection` (the real, logical position), never from
      the clamped range.

    **A third, unrelated limitation, in shared TEST INFRASTRUCTURE this task's hard constraints
    forbid touching (`RichTextInputBackendHarness`/`makeBackendHarness`, used by ~dozens of other
    suites beyond this task's cluster) — blocks the one REAL-host target test.**
    `IDBackendSemanticTests.test_insertTextIsOneUndoStepPerContiguousRun` drives
    `h.canvas.insertText(...)` against a REAL `TelegramDocumentInputClient`. `makeBackendHarness`
    seeds the canvas's content via `canvas.setParagraphs(...)` — the RAW `setBlocks` primitive,
    which bumps `canvas.documentRevision` directly and does NOT call
    `inputBackend.synchronizeAfterExternalChange(...)` (only `canvas.reload(...)`/the public
    `.document` setter does that, per `DocumentCanvasView.setBlocks`'s own doc comment: "for
    internal layout-only rebuilds"). This task's `attach(to:)` fix correctly seeds
    `state.documentRevision` from `host.documentClient.revision` AT ATTACH TIME (matching
    `LegacyRichTextInputBackend.installInitialState(from:)` exactly — see the `attach(to:)` call
    site's own comment) — but attach happens BEFORE `setParagraphs` runs, so the backend never
    learns about the harness's post-construction seeding, and is left exactly one revision stale.
    D32's real, correct behavior — "a stale object is explicitly rebased or rejected, never
    silently reinterpreted" — then legitimately rejects the mutation, because
    `TelegramDocumentInputClient.rebase(_:fromRevision:)` is identity-or-nil (`fromRevision ==
    revision ? position : nil`) and a genuine one-revision staleness can never satisfy that. This
    is a pre-existing GAP IN THE SHARED TEST HARNESS (real app usage always seeds content through
    `reload`, which correctly notifies every backend), not a defect in production `insertText(_:)`
    wiring, and was left unfixed: `RichTextInputBackendHarness.setParagraphs`/`setBlocks` back
    dozens of suites this task did not audit, and changing shared, widely-used test infrastructure
    to benefit one target test carries unbounded blast radius for a narrowly-scoped wiring task.
    `undoRegistrationCount` reads 0 (the mutation never reaches the document client at all — the
    same "an un-rebasable stale position must never reach `prepareMutation`" contract
    `IDBackendRevisionContractTests.test_rebaseReturningNil_rejectsWithRevisionMismatch_withoutPreparing`
    (a different, FAKE-host target test) pins as CORRECT behavior).

16. **Task R5 (Family 6, cluster 2) fixes three genuine bugs in `synchronizeAfterExternalChange`/
    `adoptAndEmitDidChange`, and records one remaining, disclosed capability gap it deliberately did
    NOT fix.**

    **Bug 1 — `synchronizeAfterExternalChange` had no transaction bracket of its own.** Unlike
    `insertText(_:)`'s `isMutating = true … isMutating = false; endTransaction()`, this method ran
    its whole body — including the `rebase` callout, a realistic re-entry point — with no latching in
    place, so a `detach()` fired reentrantly from inside `rebase` tore the backend down IMMEDIATELY,
    nil'ing `self.host` before this method's own trailing `publishState(reason:
    .externalSynchronization)` could reach it (`guard let host` there then silently drops the
    publish). Fixed by bracketing the method the same way `insertText(_:)` is bracketed; verified
    against `IDBackendReentrancyTests.test_detachFromInsideAPreserveIfRebasableRebaseCallout_stillLatchesToTheBoundary`.

    **Bug 2 — `.discard`/`.commitBeforeChange` retired `state.markedRange` but never told the
    KERNEL.** `markedTextRange`'s witness (`+TextBackend.swift`) reads `kernelInput` directly, not
    `state` (by design, matching every other `UITextPosition`/`UITextRange`-returning witness — it
    must answer for the REAL kernel UIKit itself is driving). `synchronizeAfterExternalChange` only
    ever wrote `state.markedRange`, so a `.discard`/`.commitBeforeChange` outcome was a dead write as
    far as anything UIKit could observe — the kernel's own tracked composition survived untouched.
    Fixed with a scoped `kernelInput?.unmarkText()` call (the SAME bookkeeping-only kernel primitive
    `unmarkText()`'s own witness uses for the identical reason) — but **scoped to exactly
    `.discard`/`.commitBeforeChange`**, not every nil-resolving outcome; see the standing gap below
    for why `.preserveIfRebasable`'s nil-resolving outcomes are excluded.

    **Bug 3 — `setMarkedText`'s composing edit always published with reason `.content`, never
    `.markedText`.** `RichTextInputTextBackend.setMarkedText(_:selectedRange:)`'s own doc comment
    (`RichTextInputBackend.swift`) requires a conformer to "publish... exactly once, with reason
    `.markedText`" — `adoptAndEmitDidChange(_:RichTextInputMutationResult)` always published
    `.content` regardless of what mutation it was adopting. Fixed by threading the `TGRichTextInputDecIntent`
    through from `prepareAndCommitReplacement` and gating the reason on
    `intent == .markedText || result.markedRange != nil` — the SECOND half of that OR is load-bearing,
    not redundant: `intent` is latched by `TGThunk_keyboardInputShouldInsertTextIsMarkedText`
    (`TGRichTextInputDecCanvasCallbacks.m`), itself a documented "best-effort reconstruction" of an
    uncertified private ABI callback that (measured, not assumed) only fires from a REAL keyboard
    input session — a fake-client test driving `kernelInput.setMarkedText(...)` directly never
    triggers it, so `intent` alone would leave every marked-text-policy test still red.
    `result.markedRange != nil` is a reliable, ABI-independent fallback (reusing the exact field this
    method already trusts for `isComposing`).

    **The standing gap this task leaves — `.preserveIfRebasable`'s nil-resolving outcomes (a failed
    rebase, or a rebased range that collapses to zero-length) do not retire the KERNEL's own live
    composition.** Calling `kernelInput?.unmarkText()` there was tried and measurably regresses two
    OTHER target tests: `TGRichTextInputDecLayoutController` reacts to the retirement by
    re-validating the marked range against current content, itself calling back into
    `documentClient.rebase` an UNCONTROLLED number of extra times (observed: 13 calls where the test
    expects 1) — the exact same reactive-storm shape entry 15 and Task R3's own report already
    document for this kernel, from different call sites. `performWhileSuppressingDelegateNotifications`
    was tried as a guard around the call and measurably does not gate this reaction. Two target tests
    (`IDBackendMarkedTextPolicyTests.test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil`,
    `…_collapsesAZeroLengthRebasedRangeToNil`) are left failing on exactly this: their `XCTAssertNil`
    against the KERNEL-facing `markedTextRange` witness stays red, while `backend.state.markedRange`
    (the canonical Swift-side value every OTHER assertion in this cluster now correctly reads) is
    genuinely nil. Not weakened, not skip-gated — left red, with this record, for a future task with
    either a real kernel-suppression primitive or a documented decision to accept the divergence.

    **CLOSED by Task R6D (diagnostic) + Task R6 (the one sanctioned attempt) — permanently red by
    design.** R6D captured `Thread.callStackSymbols` for all 13 calls and proved every one of the 12
    "extra" calls originates one level up, inside real `UIKitCore` frames
    (`-[UITextInputController unmarkText:]`'s own two internal `_selectedRange` reads,
    `-[UITextInputController setSelectedTextRange:]`'s `_selectedRanges` read, and
    `-[UITextInputController _ensureSelectionValid]` fired 3× from
    `-[UITextInputController _coordinateSelectionChange:]`) — not our code re-entering itself, and not
    something `Vendor/`/`Kernel/` (unedited throughout both tasks) could be patched to avoid. Root
    cause: the private controller holds its own internally-cached `selectedTextRange`/marked-range
    objects stamped with the OLD document revision, and because `TGResolvePosition` returns a *new*
    freshly-stamped position rather than mutating the one it was given, UIKit's own copy is never
    updated — so each of its 6 independent internal re-validation steps repeats the identical stale
    query and pays for another rebase.

    R6D proposed exactly one testable containment, left explicitly unverified: pre-warm the kernel's
    cached `selectedTextRange` — reassign it to a range reminted at the CURRENT revision
    (`state.documentRevision`/`state.selection`, both already adopted by this point in the method) —
    immediately before calling `unmarkText()`, on the theory that the private controller's own cached
    copy would then be current *before* its internal cascade starts querying it.

    Task R6 ran this as the sole, one-shot experiment the brief authorized. **Step 1 (reproduction):**
    re-widened the `.discard`/`.commitBeforeChange` guard to also cover `.preserveIfRebasable`'s
    nil-resolving outcome (R6D's own change, temporary) and confirmed `rebaseCallCount == 13` on
    `IDBackendMarkedTextPolicyTests.test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil`
    — byte-for-byte matching R6D and R5's own prior observation, establishing a working "before".
    **Step 2 (the pre-warm):** added, immediately before the `unmarkText()` call, a
    `kernelInput?.selectedTextRange = TGRichTextInputDecRange(from: <fresh TGRichTextInputDecPosition
    at state.documentRevision, canonicalSelectionAnchorOffset>, to: <same, headOffset>)` write — the
    exact mechanism this backend's own `selectedTextRange` getter already uses to mint a
    revision-stamped identity object (`IDTextEditorBackend.swift`, `selectedTextRange { get }`).
    Re-ran the same test: **`rebaseCallCount == 27`, deterministic across two runs — MORE than DOUBLE
    the un-contained storm, not a reduction to ~1.** Mechanically: the pre-warm write is itself a
    `setSelectedTextRange:` call, which per R6D's own captured stack (call #5/#6) triggers its OWN
    internal `_selectedRanges` re-derivation against the range that was cached *before* this write —
    so the containment attempt pays for a full extra storm on top of the one `unmarkText()` still
    causes, rather than avoiding it. (As a side effect, the pre-warmed write DID make
    `backend.markedTextRange` read nil correctly in both target tests — the `XCTAssertNil` assertions
    themselves would have passed — but `test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil`
    also pins the exact rebase count, and 27 fails that pin worse than the original 13 did. A future
    attempt that wanted only the nil-correctness half would still need to solve the count, which this
    experiment shows the obvious lever does not.)

    Per the task brief's stated stopping rule ("if it does not drop [to ~1]: STOP — do not try a
    second, third or fourth variation"), this result closes the investigation. Both the temporary
    guard-widening and the pre-warm write were fully reverted (`git checkout --` on
    `IDTextEditorBackend.swift`; verified byte-identical to the R5 commit, `git diff` empty) — the two
    target tests are back to their exact pre-R6 failure shape (`XCTAssertNil` against the
    kernel-facing `markedTextRange` witness, non-nil `TGRichTextInputDecRange` at the pre-external-change
    offsets). **`IDBackendMarkedTextPolicyTests.test_preserveIfRebasable_discardsMarkedRange_whenRebaseReturnsNil`
    and `…_collapsesAZeroLengthRebasedRangeToNil` are now PERMANENTLY RED BY DESIGN under this
    backend**, not a to-do: two tasks (R6D diagnosing, R6 the one sanctioned fix attempt) have shown
    the storm is genuine, un-suppressible private-UIKit fan-out reachable only through a vendored,
    unedited one-line forward (`IDUIKitInputControllerCapability.unmarkText`), that
    `performWhileSuppressingDelegateNotifications` cannot gate it (wrong channel — outbound delegate
    notifications, not these inbound state queries — confirmed twice), and that the one remaining
    lever the kernel exposes (pre-warming the cached selection before the call) makes the measured
    cost worse, not better. Reopening this requires either a new kernel primitive this package does
    not have today (a real suppression hook for inbound `characterRangeForTextRange:`-shaped queries,
    or a way to make `TGResolvePosition` update the CALLER's stale object in place rather than
    minting a new one) or a documented decision to accept the divergence permanently. Do not spend a
    third task re-diagnosing or re-attempting containment on this call shape.

17. **Task R10 (clusters 8 and 9) — Task C8's own claim that Family 5's whole path "was already
    fully wired by C6/C7 before this task started" (entry 8 above) is FALSIFIED for two of its
    three pieces, and both failures share one mechanism: `deleteBackward()` reads/writes state the
    kernel keeps SEPARATELY from `IDTextEditorBackend.state`, and nothing kept the two in step.**

    **Bug A (cluster 8) — the kernel's own cached `selectedTextRange` is never told about a
    selection this backend sets any way other than a live keyboard session.** `activeController`
    (behind `kernelInput`) holds its own selection object; `setSelection(_:reason:)` (Family 3,
    Task C6/R9) only ever writes `IDTextEditorBackend.state`, never `kernelInput`. Under a real
    keyboard the two stay in step because the KERNEL drives selection changes in the first place
    (`TGThunk_deleteBackwardAndNotify`/the selection-changed thunks relay ITS state UP into
    `setSelection`, never the reverse) — but `setSelection` called any other way (every fake-client
    contract test, and any future programmatic caller) leaves the kernel's copy stale.
    `preflightBackwardDeleteRanges()`/`deleteBackward()` then resolve the delete range against
    wherever the kernel last thought the caret was, not where `state.selection` says it is.
    Measured directly: with `state.selection` moved to offset 3 via `setSelection` and the kernel's
    own cached selection left at its attach-time 0, `deleteBackward()` decided there was nothing
    before its (stale) caret to delete — the fake document client's `receivedMutations` stayed
    completely EMPTY, not merely wrong. Fix: `deleteBackward()` (`+KeyInput.swift`) pre-warms
    `kernelInput?.selectedTextRange` from a freshly-minted, revision-stamped
    `TGRichTextInputDecRange` (`IDTextEditorBackend.mintKernelSelectedTextRange()`, factored out of
    the `selectedTextRange` getter, which already built the identical object) before consulting the
    kernel about anything. This is the SAME lever R6D/R6 already tried for a DIFFERENT call
    (`unmarkText`, entry 16) and found made THAT call's cost worse, not better — but `deleteBackward`
    is not `unmarkText`: re-run after this fix, `IDBackendMarkedTextPolicyTests`' full 11-test suite
    (unrelated to this task's own two target clusters, but the nearest reactive-storm-prone
    neighbor) shows no new failures and the two entry-16 tests fail with byte-identical text/values
    to their pre-R10 baseline — this lever's cost is call-shape-specific, not universal.

    **Bug B (cluster 9) — the `.deleteBackward` intent is NOT latched by the ABI-witnessed
    `keyboardInputShouldDelete:` preflight the way Task C7 built it and Task C8's own entry 8 above
    claimed.** Instrumented directly (temporary `NSLog`s in `keyboardInputShouldDelete:`, the other
    two intent-latching thunks, and the façade's `replaceCharactersInRange:withString:`, all
    reverted before commit): driving `deleteBackward()` end to end through EITHER call path
    (through a canvas, or directly on the backend, as `IDBackendMutationContractTests`/
    `IDBackendSelectionContractTests` do) produces exactly ONE log line — the façade's replace, with
    `currentIntent == 0` (`.programmatic`, the value every transaction unconditionally resets to on
    exit) — and NONE of the three intent-latching thunks ever fires. Consistent with the manifest's
    own `"direction": "incoming"` on the `inputController.keyboardDeletePreflight` row: the kernel
    RECEIVES this call from a genuine system software-keyboard dispatch layer sitting ABOVE
    `UIKeyInput.deleteBackward()` — and `+KeyInput.swift`'s `deleteBackward()` (which calls straight
    into `kernelInput?.deleteBackward()`) IS that top-level entry point, both in every test harness
    in this stage and in production; nothing in this seam sits above it to have made that preflight
    call first. So Task C7's mechanism is real and correctly built for the case it was built for (a
    genuine software-keyboard-driven delete reaching the REAL system dispatch layer this test stage
    cannot construct) — it simply cannot fire from a call shape where THIS backend is the one
    invoking `[[self activeController] deleteBackward]` directly, which is every call shape this
    package's own test stage (and, per the reasoning above, production) actually exercises. Fix:
    `deleteBackward()` latches `.deleteBackward` itself, directly, immediately before the guarded
    kernel call whose internal machinery drives the façade's replace — mirroring `insertText(_:)`'s
    own direct `bridge.storage.currentIntent = .insertText` write (Task R2, entry 15) — via a new
    narrow crossing point, `IDTextEditorBackend.latchDeleteBackwardIntent()`.

    **The two bugs share one root and were re-measured independently to confirm it.** Fixing Bug A
    alone turns cluster 8's three tests from "no mutation reaches the document client at all" into
    cluster 9's own exact symptom (a mutation arrives with the CORRECT range but the WRONG case —
    `.replaceText`/`.programmatic` instead of `.deleteBackward`) — i.e. cluster 8's symptom was
    Bug A masking Bug B underneath it. Fixing Bug B alone (Bug A's pre-warm write temporarily
    disabled) leaves ALL FIVE target tests failing with their EXACT pre-fix text (cluster 8's three
    back to "got nil"; cluster 9's two back to "expected the last received mutation to be
    .deleteBackward") — proving Bug A is independently necessary too, not merely cluster 8's own
    concern. Both fixes are required together; neither cluster is fixable by patching only its own
    symptom. Full accounting, evidence, and the raw before/after `Test Case` counts:
    `task-R10-report.md`.

18. **Task D3d gets call-stack proof of entry 15's `insertText` reactive-rebase noise, and closes
    the three `IDBackendRevisionContractTests` cases it blocks as permanently red by the same
    mechanism entry 16 already established for `unmarkText`.** Entry 15 recorded, by COUNT only,
    that a live kernel reacts to `insertText(_:)`'s `edited:` post with extra
    `documentRebaseOffset` calls. This task captured `Thread.callStackSymbols` for those extra
    calls (temporary instrumentation in `FakeInputDocumentClient.rebase`, reverted before commit,
    byte-identical diff to before) and found every one rooted in REAL `UIKitCore` private frames —
    `-[UITextInputController _textStorageDidProcessEditing:]`, reached via
    `-[NSTextStorage endEditing]` → `processEditing` → `NSNotificationCenter`, calling
    `-[UITextInputController _selectedRange]` (and, on a later call, `_ensureSelectionValid`) —
    which lands on `-[TGRichTextInputDecLayoutController id_characterRangeForTextRange:]` →
    `TGResolvePosition` → `documentRebaseOffset`. This is architecturally IDENTICAL to entry 16's
    `unmarkText` finding (a private `UITextInputController` re-validating its own internally-cached,
    stale-revision-stamped position object on every reactive query, which `TGResolvePosition`
    cannot heal because it mints a fresh position rather than mutating the caller's own copy in
    place) — just triggered by the `edited:` bracket every committed `insertText` legitimately posts
    (required for `mirror`/UIKit's own read path to stay correct, per R7/R2's own findings), rather
    than by `unmarkText()`. Given R6/R6D already showed the one lever this kernel exposes
    (pre-warming the cached position before the reactive call) makes an architecturally-identical
    storm WORSE (13 → 27), and the brief's own stopping rule against re-running a shown-worse
    experiment, no new containment was attempted here.

    Confirmed the storm is pure noise, not a masked logic bug: in every failing assertion, the
    backend's OWN intentional rebase mechanism (`ensureCanonicalSelectionIsCurrent`) behaves exactly
    as specified — `test_stalePosition_isRebasedOnce_thenPreparesAtTheNewRevision`'s
    `receivedExpectedRevisions == [5]` assertion (line 70) passes even though its sibling
    `rebaseCallCount == 1` assertion (line 69, measured 17) fails; and
    `test_nonCollapsedSelection_rebasesBothEndpoints_andRefusesIfEitherFails`'s own captured
    `rebaseOffsets` are `[2, 5, 0, 0, …]` — the two REAL, correctly-ordered endpoint rebases land
    first, with every noise call afterward at offset 0 (the private controller's stale attach-time
    cached `{0,0}` selection object, re-queried and never healed). `IDBackendRevisionContractTests
    .{test_stalePosition_isRebasedOnce_thenPreparesAtTheNewRevision,
    test_rebaseIsAttemptedAtMostOncePerOperation_andCannotLoop,
    test_nonCollapsedSelection_rebasesBothEndpoints_andRefusesIfEitherFails}` are now, like entry
    16's two tests and `IDBackendMutationContractTests.test_insertText_readyPreparation_commitsExactlyOnce_andPublishesApplied`
    (entry 15's own casualty), permanently red by design under this backend. Full evidence
    (call-stack excerpts, raw counts): `task-D3d-report.md`.

19. **Task F1 — the "geometry bypass" was TWO defects, not one, and the second one crashed the app
    on the first tap. Family 2 is now routed at the host geometry client, and the geometry cluster
    is REACHABLE. Entries and documents that call it unreachable-by-design are corrected below.**

    **What was believed.** From Task C5 onward this repo recorded Family 2 as a known-unreachable
    kernel limit: the vendored kernel lays caret and selection geometry out through its OWN
    synthetic, unstyled `NSTextContainer`, R8 instrumented the `id_` geometry bridge and measured
    ZERO calls through it for point hit-testing, and the differential corpus attributed 108
    `caretRect` and 108 `selectionRects` divergences from stock to exactly that
    (`docs/input-backend-differential-baseline.md` §8.3(a); the two expectation entries were named
    `kernel-geometry-bypass-caretRect` / `kernel-geometry-bypass-selectionRects-empty`). Five tests
    were left red on that basis and treated as not-our-bug for the whole programme.

    **The half that was true.** The kernel really is not the geometry authority and really was
    being asked. That half is not in dispute — it is why the fix is a REROUTE.

    **The half nobody traced, and its consequence.** "The kernel answers geometry from its own
    container" also means the kernel is the one being handed the POSITION. Every canvas-level
    geometry call site mints a canvas-side identity object regardless of which backend is installed:
    `DocumentCanvasView+UITextInput.swift`'s `caretRect(atGlobal:)` (`caretRect(for:
    LegacyTextIdentity.position(atGlobal: offset))`) is what five canvas sites, `+EditMenu.swift`
    and `RichTextEditorView.scrollCaretIntoView(animated:)` all call.
    `TGRichTextInputDecLayoutController` casts every incoming position to
    `TGRichTextInputDecPosition` UNCHECKED and sends it `-utf16Offset`, so the pre-F1 witness
    produced `-[RichTextEditorUIKit.LegacyTextPosition utf16Offset]: unrecognized selector sent to
    instance` — an `NSException`, converted to an `NSError` by the exception guard, recorded by
    `reportKernelFailure(_:witness:)`, and (defect 2 below) TRAPPED. That is the user's crash,
    `Telegram-2026-08-26-171558.ips`: tap → `setCaret(global:)` → `scrollCaretIntoView` →
    `caretRect(atGlobal:)` → `IDTextEditorBackend.caretRect(for:)` → `assertionFailure`.

    **Why the suite never saw it.** Every pre-existing `IDBackendFamily2Tests` /
    `BackendSemanticContractCases` geometry case passes a KERNEL-minted position
    (`h.canvas.beginningOfDocument`, `textRange(from:to:)`). Not one of them went through
    `caretRect(atGlobal:)`, which is the only spelling production uses.
    `IDBackendCaretPlacementGeometryTests` (new, this task) is the reproduction and the guard.

    **The fix.** All eight Family-2 witnesses moved to `IDTextEditorBackend+Geometry.swift` and now
    answer from `RichTextInputHost.geometryClient` — the same client
    `LegacyRichTextInputBackend+Geometry.swift` has always used, and the one the spec names as the
    sole authority for caret, point, range, line and navigation geometry. Positions are resolved to
    a canvas-global UTF-16 offset from EITHER identity type (`TGRichTextInputDecPosition` or
    `LegacyTextIdentity`), because both carry the same number on the same axis; anything else still
    degrades to `.zero`/`[]`/`nil` (deviation D9 unchanged, still translated only at the UIKit edge).
    Positions handed BACK are always `TGRichTextInputDecPosition`, because this backend's Family-1
    witnesses still route into the kernel and the kernel accepts only its own type.

    **THE CLUSTER IS NOW REACHABLE — measured, not asserted.** All five previously-red geometry
    tests pass (`IDBackendFamily2Tests` 5/5, `IDBackendSemanticTests` 20/20), and the differential
    corpus stays 4/4 green with the SAME counts (410 differences, 0 unexplained). The strongest
    evidence is a narrowing that was impossible before: the `caretRect` expectation was tightened
    from "any dict-vs-dict difference on this field" to LEGACY's own predicate — the caret's SIZE
    must agree and only its origin may move — and it still matches 108/108 with 0 unexplained. The
    pre-F1 baseline explicitly recorded divergence in BOTH size and origin and declined to narrow
    for that reason. Both expectations were therefore renamed and reclassified from category (a)
    ("known-unreachable kernel limit") to the shared-with-legacy class:
    `kernel-geometry-bypass-caretRect` →
    `caret-origin-differs-because-the-arms-use-different-text-metrics-inputdec`;
    `kernel-geometry-bypass-selectionRects-empty` →
    `editor-returns-no-selection-rects-for-a-collapsed-range-inputdec`.
    `docs/input-backend-differential-baseline.md` §8.3(a) is corrected in the same commit.

    **One deliberate divergence FROM legacy, and it is specified rather than chosen.**
    `selectionRects(for:)` sends a request BOUNDED by `host.hostInputView.bounds`, where legacy
    passes `visibleRect: nil`. Legacy's deviation D26 records that the bounded request is built and
    proven at the client boundary but deliberately unsent by the legacy witness, because adopting
    it would change what the legacy canvas draws during a large Select All. That constraint does not
    apply to new code, and `IDBackendFamily2Tests.test_selectionRectsAreBoundedByTheVisibleRect`
    pins the bounded shape for this backend explicitly.

    **DEFECT 2, independent of all the above: `reportKernelFailure(_:witness:)` was fatal.** Its
    body ended in `#if DEBUG RichTextInputContractViolation.report(…) #endif`, which with no
    reporter installed is `assertionFailure()`. In a test host a reporter is always installed, so
    this was invisible to the whole suite; in the app it made EVERY kernel witness failure kill the
    process. That contradicted the method's own doc comment, which already said both of its causes
    are "DOCUMENTED, correct outcomes for a witness to answer its 'absent' value for — never a
    crash". It now records into `witnessFailures` (unchanged — the tests read it) and reports
    through the `reporter` hook when one is installed, `NSLog` otherwise. Nothing is silenced and
    nothing traps. This matters beyond F1: the kernel is certified against exactly ONE OS build and
    raises `NSException` on any contract mismatch, so the next unimplemented or OS-drifted witness
    would otherwise have crashed the same way instead of degrading.

    **NOT fixed here, and still true after F1 — the canvas mints legacy-shaped identity under every
    backend.** `LegacyTextIdentity`'s own doc comment anticipates a stage-2 backend having a
    different identity surface, but seven canvas sites mint or unwrap the legacy shape today.
    Geometry is now immune (it accepts both), but the Family-1 witnesses are not: they still forward
    the caller's position into the kernel, so a canvas-minted position reaching `compare(_:to:)`,
    `offset(from:to:)`, `textRange(from:to:)` or `position(from:offset:)` still fails that witness
    (recorded, no longer fatal). Two READ sites also degrade silently rather than fail:
    `DocumentCanvasView+UITextInput.swift`'s `documentEndOffset` and
    `+SelectionActions.swift`'s `selectAll` both do `LegacyTextIdentity.globalOffset(of:
    endOfDocument)`, whose cast fails against a `TGRichTextInputDecPosition` and falls back to
    `nil`/`0`/`documentSize`. The durable fix is a backend-neutral identity seam on the canvas, not
    more per-witness tolerance; it is real follow-on work with its own test surface, out of scope
    for a hotfix.


20. **Task F2 — the flag took first responder, drew a caret, and never raised a keyboard. One word:
    `isEditableForWritingTools` answered `false`.**

    **The defect, with a file:line.**
    `IDTextEditorBackend.swift`'s `var isEditableForWritingTools: Bool { false }`. The canvas routes
    that member to the UIKit witness `DocumentCanvasView.isEditable`
    (`Canvas/DocumentCanvasView+UITextInput.swift:394`, the D3 rename), and `-isEditable` is what
    UIKit asks a `UITextInput`-conforming first responder in order to decide whether that responder
    needs a keyboard **at all**. `LegacyRichTextInputBackend.isEditableForWritingTools`
    (`+Responder.swift:236`) is the literal `true` — itself a byte-for-byte port of the pre-seam
    canvas witness — so under Legacy the editor asks for a keyboard and under `.inputDec` it did not.

    **Measured, not inferred.** `IDKeyboardActivationTests` reads UIKit's own private
    `-_requiresKeyboardWhenFirstResponder` and calibrates that reading against two real `UITextView`s
    in the same process:

    | responder                         | `-isEditable` | `-_requiresKeyboardWhenFirstResponder` |
    | ---                               | ---           | ---                                    |
    | `UITextView`, `isEditable = true` | `true`        | `true`                                 |
    | `UITextView`, `isEditable = false`| `false`       | `false`                                |
    | Legacy canvas                     | `true`        | `true`                                 |
    | InputDec canvas (before F2)       | `false`       | `false`                                |

    A read-only `UITextView` is *precisely* the reported symptom — it takes first responder, it shows
    a caret and a selection, and no keyboard is raised. The ID canvas reproduced that state exactly.

    **The fix is Legacy parity, not a judgement call.** `true`, unconditionally: no `isAttached`
    guard (a detached Legacy backend still answers `true`, and `false` is the value that removes the
    keyboard), and no `RichTextInputEditPolicy` gate (Legacy's own doc comment records that gate as
    an open decision belonging to whoever makes the policy live). `InputBackendSourceBoundaryTests`
    already pins the Legacy shape as `.literal("true")`.

    **Why the whole suite could be green while this shipped — two independent blind spots, both
    measured.**
    1. *Keyboard appearance is unobservable in this test host.* An ordinary, plainly editable
       `UITextView`, first responder in a key window, posts **no** `keyboardWillShowNotification` in
       the xctest process. A test watching for it would have been vacuous for BOTH backends, which is
       presumably why none was ever written.
    2. *Nothing anywhere read the member that decides it.* `isEditableForWritingTools` had exactly
       one pin in the package (`InputBackendSourceBoundaryTests`, `.literal("true")`), and that rule
       is scoped to `LegacyRichTextInputBackend`'s **source text** — it never evaluates the ID
       backend. The differential corpus was blind too: `IDTextInputStateRecorder` records
       `firstResponder` and has no `isEditable` field at all, so none of the 410 recorded
       `.inputDec` differences could see it. See §6.6 of
       `docs/input-backend-differential-baseline.md`.

    **The brief's leading hypothesis was wrong, and is recorded as wrong rather than deleted.** It
    suspected `TGThunk_textInputView`/`TGThunk_textStorage` returning nil for want of an attached
    bridge. They do not: the bridge is published at the end of `attach(to:)`, a failed attach would
    have tripped `RichTextInputContractViolation.report`'s DEBUG `assertionFailure` inside
    `DocumentCanvasView.init` long before any tap, and the user reported no crash.
    `test_theAppReachableInstallationStateHasEveryThunkLive` measures all of it in the app-reachable
    state (bridge set, `textInputView === canvas`, `textStorage` is the façade, `interactionAssistant`
    and `selectionContainerView` non-nil) and passes both before and after this fix — deliberately, so
    the next reader does not re-derive the disproof.

    **A second silent stub, found in the same sweep and fixed with it: `hasText` answered `false`
    unconditionally.** Legacy's reads the document (`+Insertion.swift:174-177`). Besides UIKit's own
    per-keystroke polling, `TelegramCommandInputClient` gates BOTH `.selectWord` and `.selectAll` on
    `canvas.hasText` (`Clients/TelegramCommandInputClient.swift:201,206`) — so under `.inputDec`,
    **Select and Select All were permanently unavailable in the edit menu**, with nothing failing
    anywhere. Now mirrors Legacy, including its two disclosed decisions (detached answers `false`;
    no contract-violation report, because UIKit polls this on the keyboard's per-keystroke path).

    **Regression evidence.** `IDDifferentialTests` 4/4 (unchanged), `IDBackendFamily2Tests` 5/5,
    `IDBackendSemanticTests` 20/20, `InputBackendSourceBoundaryTests` 35/35,
    `VendorSnapshotIntegrityTests` 6/6, `IDBackendCallGuardTests` 3/3, `BackendEditPolicyTests` 6/6,
    `IDTextEditorBackendCommandRoutingTests` 9/9, `IDBackendFamily8Tests`/`Family9Tests` 5/5 each,
    `CanvasCallbackInstallationTests` 6/6, `IDHarnessTests` 5/5, `IDFakeClientHarnessTests` 6/6,
    `EditorViewPreferenceTests` 3/3. `IDBackendDifferentialTraceTests` remains at its pre-existing
    4-failing-case baseline — re-measured with the fix reverted and with it applied, byte-identical
    (9 tests, 15 assertion failures both ways), so this change moves nothing there.

    **What this does NOT prove.** A headless test cannot make a keyboard appear in this process. What
    is proven is that the editor now answers UIKit's keyboard question the same way an editable
    `UITextView` and the Legacy canvas do, and that it previously answered it the way a read-only
    `UITextView` does. If a keyboard still fails to appear by hand, the next thing to look at is
    something *after* that question, not this member — and entry 19's residual (the canvas mints
    legacy-shaped identity under every backend) is where the remaining silent degradations live.

21. **Task F3 — a guessed private ABI segfaulted the app on the first Backspace, and the guess was
    replaced by a runtime probe for all sixteen installed rows.**

    **The crash.** `Telegram-2026-08-26-182712.ips`: `objc_retain` <- `objc_storeStrong` <-
    `TGThunk_deleteBackwardAndNotify` <- `-[UIKBInputDelegateManager
    _deleteBackwardAndNotify:reinsertText:overrideOriginalContextBefore:...]`, `EXC_BAD_ACCESS ...
    KERN_INVALID_ADDRESS at 0x0000000000000001`. Task C6 installed `_deleteBackwardAndNotify:` with
    encoding `"v@:@"` and an IMP declared `(id self, SEL _cmd, id arg)`. The real argument is a
    `BOOL`; UIKit passed `YES`; ARC retained address `0x1`. **The body did `(void)arg;` and never
    read it — the retain alone was fatal**, so "we ignore the argument" is not protection. An `id`
    parameter is the ONLY shape that turns a wrong guess into a crash.

    **Step 2 — the probe, and what it found.** For each selector, every class in the process that
    implements it directly was enumerated (`objc_copyClassList` + `class_copyMethodList`, ~34,000
    classes) and its `method_getTypeEncoding` read; most rows are corroborated by a private-protocol
    declaration. Measured on iOS 26.5 / 23F73 (the kernel's certified build) and on iOS 27.0 — the
    two agree exactly. Every selector has exactly ONE distinct encoding across the whole runtime.
    **Five of C6/C7's six guesses were right; the sixth was the crash:**

    | selector | installed (before F3) | probed | verdict |
    | --- | --- | --- | --- |
    | `textInputDidChange:` | `v@:@` | `v@:@` (`UITextInputControllerDelegate`) | correct |
    | `textInputDidChangeSelection:` | `v@:@` | `v@:@` (`UITextInputControllerDelegate`) | correct |
    | `keyboardInputChangedSelection:` | `v@:@` | `v@:@` (`UIKeyboardInput`) | correct |
    | `keyboardInput:shouldInsertText:isMarkedText:` | `B@:@@B` | `B@:@@B` (`UIKeyboardInput`) | correct |
    | `textInput:shouldChangeCharactersInRanges:replacementText:` | `B@:@@@` | `B@:@@@` (`UITextInputControllerDelegate`) | correct |
    | `_deleteBackwardAndNotify:` | `v@:@` | **`v@:B`** (`UITextInput_Internal`, required) | **WRONG — the crash** |

    The nine rows C6 did not add (`textStorage`, `textInputView`, the three Family-9 interaction
    thunks, the two Family-11 spellchecking thunks, and the three ABI-witnessed rows) were probed in
    the same pass and all match.

    **Step 3 — the fix is NOT a corrected encoding.** `_deleteBackwardAndNotify:` is not installed at
    all any more, because the SEMANTICS were wrong too, and correcting only the ABI would have
    shipped a silently broken Backspace. Measured on iOS 26.5: `-[UIResponder
    _deleteBackwardAndNotify:]` calls `-deleteBackward` on self for BOTH flag values, and `-[UITextView
    _deleteBackwardAndNotify:]` really removes a character ("abc" -> "ab"). The selector ASKS the
    responder to perform the delete; the flag governs notification. So nothing had deleted anything
    when C6's thunk ran: it seated the PRE-delete selection (a no-op) and SWALLOWED the delete. Not
    installing leaves the canvas on `UIResponder`'s own implementation -> `-deleteBackward` ->
    `inputBackend.deleteBackward()` — which is exactly the route the LEGACY canvas takes today (it
    never installed this selector, and its Backspace works), with no guessed private ABI in it.

    **Step 4 — two standing guards, because a test alone cannot protect a shipped build.**
    - RUNTIME: every `class_addMethod` in `TGRichTextInputDecCanvasCallbacks.m` now goes through
      `TGAddThunk`, which REFUSES to install an encoding that contradicts an implementation already
      on the superclass chain (the canvas then keeps the inherited system implementation — by
      definition safer than a wrong one) and records the row in
      `TGRichTextInputDecCanvasCallbackABIRejections()`. This would have caught THIS bug: `UIResponder`
      carries `v@:B`, our `v@:@` contradicts it.
    - TEST: `IDCanvasCallbackABITests` re-runs the whole census in process and compares it against
      the installer's LIVE output (`class_copyMethodList` on `IDDocumentCanvasView`), so a NEW thunk
      is covered the day it is added rather than when someone remembers to update a list. It fails
      loudly if a row becomes unprobeable (the instrument going blind is itself a finding) or if the
      runtime carries more than one encoding for a row.

    **Regression evidence.** The reproduction (`test_deleteBackwardAndNotify_calledTheWayUIKitCallsIt_
    deletesInsteadOfCrashing`) was verified RED by re-introducing a `(id)`-parameter thunk installed
    with a raw `class_addMethod`: the xctest process dies ("Restarting after unexpected exit, crash,
    or test timeout", 0 executed) — the same signature as the app crash — and passes with the fix.
    `IDCanvasCallbackABITests` 6/6, `CanvasCallbackInstallationTests` 6/6, `IDKeyboardActivationTests`
    5/5, `IDDifferentialTests` 4/4, `IDBackendFamily2Tests` 5/5, `IDBackendFamily5Tests` 4/4,
    `IDBackendBackwardDeleteMirrorTests` 4/4, `IDTextEditorBackendDeleteBackwardRoutingTests`,
    `VendorSnapshotIntegrityTests` and `InputBackendSourceBoundaryTests` all green.

    **Residual.** `IDTextEditorBackendClientBridge.setCanonicalSelectionAnchor(_:head:reason:)` now
    has NO production caller — the deleted thunk was its only one. It is kept (the bridging protocol
    declares it, and a genuinely-reporting callback is its natural future consumer) with a doc
    comment saying so, but it is dead code that reads live, which is this backend's recurring failure
    shape. `InputBackendSourceBoundaryTests`' DOOR-1 count still pins it at 1 because that rule scans
    source text, not reachability.

22. **TASK F4 — the flag had no autocorrect and no spelling underlines. FIVE silently-inert sites,
    and one of them is a WHOLE MECHANISM the carve dropped rather than a bug in one.**

    Reported by the user on a real debug build after F1-F3: typing and Backspace worked, but no
    autocorrect candidates, no corrections applied, and no red spelling underlines — all fine with
    the flag off. Nothing errored: `reportKernelFailure` never fired and the log carried no contract
    violation, so every one of these was inert, not throwing.

    **The instrument that broke it open was the UPSTREAM SOURCE, not another reconstruction.**
    `~/Documents/InputDec` holds the host the kernel was developed against (`IDBlockTextView`), and
    the vendored carve kept the kernel while dropping that host. Reading it answered in minutes what
    four rounds of inference had not.

    **(a) THE MISSING MECHANISM — the private input controller's traits were never synchronised.**
    Upstream's host pushes its whole `UITextInputTraits` onto the private controller's own traits
    object — `IDBlockTextView.id_syncTextInputTraits` -> `IDPrivateSynchronizeTextInputTraits(
    inputController, self)` (`TextView/IDBlockTextView.m`, `PrivateUIKit/IDPrivateUIKit.m`) — once at
    construction and again from EVERY trait setter. This port did it nowhere:
    `IDTextEditorBackend.textInputTraitsDidChange()` was an empty body, and `_textInputTraits` /
    `textInputTraits` / `_inputController` sit in `CanvasCallbackInstallationTests`' census as
    "reserved, nothing installs".

    MEASURED on an attached `.inputDec` canvas in this package's own test host: the canvas answers
    `autocorrectionType = .yes` / `spellCheckingType = .yes`, while `kernelInput.textInputTraits`
    (`-[UITextInputController _textInputTraits]`, the manifest's own `typingAttributes.controllerTraits`
    row) answered `0 / 0 / 0` — byte-identical to `+[UITextInputTraits defaultTextInputTraits]`.
    Under `.legacy` there is no second traits object at all, which is exactly why only this arm loses
    autocorrection. Fixed by `TGRichTextInputDecSynchronizeTextInputTraits`
    (`TGRichTextInputDecCanvasCallbacks.m`, ours, not vendored) called from `attach(to:)` and from
    `textInputTraitsDidChange()`. Two deliberate differences from upstream, both toward safety:
    upstream `@throw`s on an ABI mismatch, we SKIP the row (Swift cannot catch an NSException); and
    upstream asserts the traits object exists, we no-op on nil (the kernel returns nil when
    `typingAttributes` was not validated, and today's behaviour is the correct fallback).

    **(b) The native checking driver was never installed.** `installCheckingIfNeeded()` and
    `checkOnSelectionChange()` were `{}`. The canvas's `NativeTextChecker` — the private checking
    controller that delivers every `.spelling`/`.grammar`/`.correction` flag `spellResults` renders —
    is constructed ONLY through `installCheckingIfNeeded()`, so under the flag it never existed.
    Measured: `.legacy` leaves `canvas.nativeChecker` non-nil after `becomeFirstResponder()`,
    `.inputDec` left it nil. Both members now forward to the canvas exactly as Legacy's do.

    **(c) The post-become segment was missing from `hostDidBecomeFirstResponder()`.** Legacy's runs
    three canvas segments; the third is the native-checking install + preheat + `lastCheckedCaret`
    seed. This backend fired only `backendDidBeginEditing()`. Focusing the field is the PRIMARY
    install site (the `isSpellCheckingEnabled` `didSet` only fires on a real toggle, which the chat
    composer never does), so without it (b) would still have been dead in practice. Legacy's ORDER is
    preserved (host callback first, checking segment after) — Legacy documents that order as
    observable. Legacy's FIRST segment (`legacyDidBecomeFirstResponder()`, caret/handles/writing
    directions) is deliberately still NOT mirrored: separate question, no evidence either way.

    **(d) The checking controller's range converter was unreadable under the flag — F1's deferred
    identity-seam residual, with a live consumer.** `DocumentCanvasView.nativeTextRange(
    forGlobalLocation:length:)` mints `LegacyTextIdentity` under EVERY backend, and the controller
    reads those ranges back through `text(in:)`, which forwarded them to the kernel, which casts every
    incoming range to its own type unchecked. Measured: `.legacy` read back `" wrol"`, `.inputDec`
    read back **nil** (`witnessFailures`: `-[LegacyTextPosition documentRevision]: unrecognized
    selector`), and `annotatedSubstring(for:)` degraded to `""` — so even with (b) and (c) fixed the
    controller would have been handed empty text and flagged nothing. Fixed the same way F1 fixed the
    eight geometry witnesses: `text(in:)` now normalises a canvas-minted range into the kernel's own
    type via `resolvedGlobalRange(of:)`. A genuinely foreign `UITextRange` still resolves to nil and
    degrades exactly as before.

    **(e) The word-boundary tokenizer cast was concrete, and went nil under the flag.** Three canvas
    sites reached past `UITextInputTokenizer` with `tokenizer as? DocumentTokenizer`. Under
    `.inputDec` the tokenizer is an `IDDocumentTokenizer`, so all three went nil and all three
    behaviours silently no-oped: double-tap word select, triple-tap paragraph select, and — the one
    this task was chasing — `spellCheckTargets`, which returned `(nil, nil)` for every caret move, so
    `nativeCheckOnSelectionChange()` drove a check on nothing no matter how often it ran. Fixed with
    a `DocumentBoundaryTokenizer` protocol both tokenizers conform to. Note `LegacyDocumentTokenizer.swift`'s
    own Task-43 comment predicted this exact failure mode ("three user-visible regressions, no
    compile error") for a different cause; it happened for this one.

    **(f) PRE-EXISTING, found on the way: a detached `tokenizer` read TRAPPED the process.**
    `IDTextEditorBackend.tokenizer`'s detached fallback called `RichTextInputContractViolation.report`,
    whose no-reporter DEBUG branch is an `assertionFailure`. It is reachable: a
    `Thread.callStackSymbols` probe named the caller as
    `-[TIDocumentState(UITextInputAdditions) initWithDocument:contextBoundary:]` ->
    `_contextBeforePosition:inDocument:toBoundary:` — UIKit's own KEYBOARD document-state snapshot,
    scheduled asynchronously, landing whenever it lands, including after detach while the canvas is
    still alive. Confirmed pre-existing by a `git stash` control run: on the untouched tree
    `IDBackendFamily8Tests` printed `Executed 5 tests, 0 failures` and then killed the xctest process,
    which is why it had never been counted as a failure. Degraded exactly the way F1 degraded
    `reportKernelFailure`: reporter when installed, `NSLog` otherwise, never a trap.

    **(g) F3's five unverified-semantics rows — THREE ARE NOW RESOLVED FROM UPSTREAM, and this port
    diverges on all three. NOT changed by this task.** `~/Documents/InputDec/PrivateUIKit/
    IDBlockTextView+PrivateInputDelegate.m` is authoritative:

    | selector | upstream does | this port does |
    | --- | --- | --- |
    | `textInputDidChange:` | `[self id_reconcileDerivedState]; [self id_scrollCaretToVisibleIfNeeded];` | sends `inputDelegate.textDidChange` |
    | `textInputDidChangeSelection:` | `[self id_selectionStateDidChange];` | sends `inputDelegate.selectionDidChange` |
    | `keyboardInputChangedSelection:` | forwards to the host's own `delegate` (the APP-level delegate), only when `delegate != self` | sends `inputDelegate.selectionDidChange` |
    | `keyboardInput:shouldInsertText:isMarkedText:` | returns `self.isEditable` | returns `YES` |
    | `textInput:shouldChangeCharactersInRanges:replacementText:` | returns `self.isEditable` | returns `YES` |

    These are INCOMING notifications: the private controller telling the host "I changed something,
    update your derived state". This port echoes them back to UIKit's own `UITextInputDelegate`,
    which is the "an external agent changed the document" signal — the thing that makes a keyboard
    discard its typing/autocorrection session. That is the same DIRECTION error F3 found in
    `_deleteBackwardAndNotify:`, in three more rows, and it remains a live suspect for any residual
    autocorrect misbehaviour after (a). It is left in place deliberately: the correct upstream
    behaviour has no ready equivalent on this side (there is no `id_reconcileDerivedState`, no
    `id_selectionStateDidChange`, and no app-level `delegate`), nothing headless can measure either
    version, and inventing one blind is the exact failure mode this programme keeps paying for.
    Upstream also implements `keyboardInput:shouldReplaceTextInRange:replacementText:`, which this
    port does not install at all — one of the eight census rows nothing installs.

    **A second, larger gap this task did not close, stated so it is not mistaken for done: upstream
    gets spelling FROM THE KERNEL, not from a `NativeTextChecker`.** `IDBlockTextView.setSpellCheckingType:`
    calls `[self.id_behaviorInput setContinuousSpellCheckingEnabled:]`, and the underlines arrive as
    TEMPORARY RENDERING ATTRIBUTES through the layout controller's annotation callbacks (manifest rows
    41-47) — `Tests/IDBlockSpellingIntegrationTests.m`'s `testMisspellingUsesNativeTemporaryPixels…`
    measures real red pixels and asserts the canonical storage carries no underline attribute. This
    port instead drives its own `NativeTextChecker` and renders from `spellResults`, which is what
    Legacy does and what (b)-(e) restore. Measured aside: `kernelInput.isContinuousSpellCheckingEnabled()`
    already answers `true` on an attached canvas, so the kernel-side path is switched on and its
    delivery half is simply not wired to anything that paints. Reconciling the two is real work with
    its own test surface, not a hotfix.

23. **TASK H1 — entry 22's three "direction error" rows were not merely wrong-direction. THEY WERE
    NEVER DELIVERED, and nothing in the tree could tell.** Entry 22 (above) records
    `textInputDidChange:`, `textInputDidChangeSelection:` and
    `textInput:shouldChangeCharactersInRanges:replacementText:` as INCOMING notifications this port
    echoes back out to `UITextInputDelegate`, and leaves them in place on the grounds that "nothing
    headless can measure either version." Something can, and it did.

    **The measurement.** All three are declared in the private `UITextInputControllerDelegate`, so
    UIKit sends them to the private controller's `delegate`. `IDTextEditorBackend.attach(to:)` passed
    the kernel `delegate: bridge`; the bridge spells its own members `delegateTextInputDidChange` &c.
    and answers `respondsToSelector:` NO for every real selector. Taken on an attached backend in this
    package's own test host:

    | reading | result |
    | --- | --- |
    | `kernelInput.privateController` | a real `UITextInputController` |
    | its `delegate` | `IDTextEditorBackendClientBridge` — **not** the canvas |
    | the three selectors, on the canvas / on the bridge | YES,YES,YES / **NO,NO,NO** |
    | selectors the controller asks its delegate about, and when | **17, once, inside `-setDelegate:`** |
    | selectors it asks about afterwards, across a full kernel `deleteBackward()` | **one** (`_textSelectingContainer`) |
    | sends the delegate actually received | **none** |
    | sends a delegate that answers YES receives, for one `deleteBackward()` | `textInputDidChangeSelection:` ×2, `textInputDidChange:` ×1 |

    **The cached bitmask is the whole reason this hid for a whole stage.** `-setDelegate:` asks once
    and remembers. There is no failed dispatch, no exception, no repeated `respondsToSelector:`
    traffic — no later moment at which a wrong delegate looks wrong. Reading the source can only ever
    show you a thunk that is installed and a bridge method that exists.

    **What changed.** `delegate: canvas`, matching upstream, whose host is its own view and therefore
    its own delegate (which is why `IDBlockTextView+PrivateInputDelegate.m` is a category ON THE
    VIEW). Of the 17 cached selectors the canvas answers exactly the three installed thunks and none
    of the other fourteen, so the re-point enables what was intended and nothing incidental; the
    property is `W` (weak — measured, not just declared), so the canvas→…→controller→canvas edge is
    not a cycle.

    **The bodies had to change in the same commit, and that is the point.** Entry 22's direction
    error was dormant only because of the mis-wiring. Fixing the wiring alone would have ACTIVATED
    it: relaying `inputDelegate.textDidChange` from inside the controller's own change notification
    tells the keyboard "an external agent changed this behind your back", i.e. discard the session
    that just produced the change. So `relayTextDidChangeFromKernel()` is deleted and the two
    notifications route to `reconcileAfterControllerTextChange()` /
    `reconcileAfterControllerSelectionChange()`, which notify UIKit of nothing — as upstream does.
    The selection one additionally forwards to `notifySelectionChangedToKernel()`, upstream's
    `[id_interactionCapability selectionChanged]`, which had **no caller anywhere in this port**;
    fixing the delegate supplied the caller upstream has for it.

    `keyboardInputChangedSelection:` (a `UIKeyboardInput` member, view-targeted, so NOT one of the
    17) came along unplanned: a receipt showed it firing once per kernel-driven selection change *as
    a consequence of the re-point* — it had not been delivered before either. Its own entry-22
    direction error would therefore have gone live in the same commit, so it too now notifies UIKit
    of nothing.

    **Still divergent, deliberately, and named so nobody reads this entry as "the group is done":**
    * `textInput:shouldChangeCharactersInRanges:replacementText:` returns unconditional `YES` where
      upstream returns `self.isEditable`. Making a never-delivered callback both start arriving AND
      start refusing edits in one change is two changes. Measured mitigation: it fired on none of
      `deleteBackward` / a `selectedTextRange` write / `insertText`, so its `.programmatic` latch does
      not race the Swift-side `.deleteBackward`/`.insertText` latches on those paths.
    * `keyboardInputChangedSelection:` no longer misinforms UIKit, but upstream additionally forwards
      to the host's APP-LEVEL delegate, and this port has no such object at that seam.
    * `id_updateInteractionContainerGeometry` — sizing the `syntheticContainer` to the document — is
      the one part of upstream's `textInputDidChange:` body this port still does not perform. It is a
      new mechanism rather than a wiring correction, so the callback is live with one step missing.
    * `keyboardInput:shouldReplaceTextInRange:replacementText:` is still not installed at all.

    **One hypothesis killed, worth the ink.** The missing `+load` →
    `class_addProtocol(<canvas>, @protocol(UIKeyboardInput))` does **not** gate any of this: a plain
    `NSObject` subclass declaring no private protocol whatsoever, installed as the delegate, received
    every send normally. The controller gates purely on the cached `respondsToSelector:` bitmask.
    That row is real on its own terms (the keyboard stack is a different consumer) but it is not part
    of this mechanism and must not be bundled with it.

    **A receipts counter now exists on the backend** (`ControllerNotificationReceipts`), deliberately:
    the defect being fixed was precisely "a mechanism that does not run, and nothing can tell". Same
    spirit as `witnessFailures`. `IDControllerDelegateWiringTests` pins the delegate identity, the
    cached-bitmask instrument, delivery, and the no-outward-notification rule.

24. **TASK H2 — the spelling underline. The signal arrived and we dropped it TWICE, both times on a
    UIKit identity object, both times silently. The instrument that found it was the certification
    harness plus one throwaway swizzle, not reading.**

    Task P2 had already narrowed the user's fifth defect ("corrected/misspelled words are never
    underlined with the flag on") from a theme to a step: `checkSpellingForWordInRange:` fires
    **once on every arm, InputDec included**, and the two host arms are indistinguishable at every
    step the lifecycle trace can see — yet only Legacy ends up with a flag in `spellResults`. So the
    defect was in DELIVERY, not driving.

    It was in delivery twice.

    **Drop 1 — the canvas's checking-client surface resolved the WRONG backend's identity.** The
    three `@objc` selectors the private controller messages
    (`DocumentCanvasView+NativeTextCheckingClient.swift`: `annotatedSubstringForRange:`,
    `replaceRange:withAnnotatedString:relativeReplacementRange:`, `removeAnnotation:forRange:`) each
    spelled `LegacyTextIdentity.globalRange(of:)` inline. That downcast succeeds only for a range
    the LEGACY backend minted, and under `.inputDec` the controller builds its ranges through the
    canvas's own `UITextInput` witnesses — which route to `IDTextEditorBackend` and answer
    `TGRichTextInputDecRange`. Measured (a swizzle over the three selectors, typing `"mispelled "`,
    both arms):

    ```
    INPUTDEC  annotatedSubstring range<TGRichTextInputDecRange> legacy=nil kernel(1,11) -> nil
              FLAGGED=false
    LEGACY    annotatedSubstring range<LegacyTextRange>         legacy(1,11) -> "mispelled "
              replaceRange legacy(1,10) attrs=[{0,9} NSTextAlternativesDisplayStyle=2]
              FLAGGED=true
    ```

    Resolution now goes through the ACTIVE backend, via one new
    `RichTextInputCheckingBackend.globalRange(ofCheckingRange:)` requirement — D37's rule verbatim
    (anything canvas-side code reaches through `inputBackend` must be on the contract, or it is
    unreachable). Legacy implements it as the identical expression the canvas used to spell, so that
    arm is a pure move.

    **Drop 2 — a canvas-minted position reaching the kernel produced a CONFIDENTLY WRONG answer, not
    an absent one.** With drop 1 fixed the controller read the word back correctly and *still*
    stopped. Instrumenting the position algebra showed why (`L` = canvas identity, `k` = kernel):

    ```
    compare(k1,k11) = -1     both kernel-minted: correct
    compare(L1,k11) =  0     the range the CHECKER handed in: reads as an EMPTY word
    ```

    `NativeTextChecker` converts its ranges through
    `DocumentCanvasView.nativeTextRange(forGlobalLocation:length:)`, which mints the canvas shape
    under EVERY backend (entry 22 / F4's finding, unchanged); the kernel casts incoming positions
    unchecked and raises `unrecognized selector`; the exception guard turns that into the witness's
    "no reply" fallback, which is `.orderedSame` for `compare(_:to:)` and `0` for
    `offset(from:to:)` — **both of which read as "these two positions are the same place."** The
    five position-taking Family-1 witnesses now normalise through `normalizedKernelPosition(for:)`,
    the position twin of entry 22's `normalizedKernelRange(for:)`. This is the THIRD instalment of
    the same asymmetry (F1: eight geometry witnesses; F4: `text(in:)`; H2: the position algebra) and
    the residual F1 explicitly deferred.

    **What this says about the fallback discipline.** `reportKernelFailure` being non-fatal (F1) is
    what let both drops be silent, and the per-witness fallbacks are chosen to be *sanctioned*
    answers — but `.orderedSame` and `0` are not "no reply", they are a specific, plausible, wrong
    reply. A fallback that is indistinguishable from a real answer is the same defect family as an
    empty body and a constant `false`; it is now the fourth shape this port has produced.

    **The three drops G1/G2 ranked are ALSO fixed, and none of them was the cause.** All three sit
    on the kernel's layout-controller path (`addAnnotationAttribute:value:forRange:`,
    `addRenderingAttributes:forRange:`), and the same probe recorded **zero** calls to that path on
    either arm while a misspelling was successfully flagged — the private *checking* controller
    talks to its client (the canvas) directly. Fixed anyway, each with a direct unit test:
    `addAnnotation` was a constant `false` (it demanded a Swift `SpellStyle`; the controller sends a
    boxed integer) and now reuses the canvas's own classifier through a new strict sibling
    `markerStyle(fromAttributes:)`; `addRenderingAttributes` whitelisted two keys that are not the
    underline and now recognises the `NSUnderlineStyle`/`NSUnderlineColor` marker upstream's own
    end-to-end test names, translating it into `spellResults` (this renderer has no general
    temporary-attribute channel, so translation — not storage of arbitrary attributes — is the
    honest port); and the revision gate is gone from all seven members, because it compared a
    deliberately un-rebased raw revision for hard equality and a correction annotation is by nature
    delivered after the replacement that bumped it. Upstream has no staleness gate; the clamps that
    must be there anyway (`clampedSpellRegionLocal`, `leafRegion(containingGlobal:)`, the
    `documentSizeValue` bounds checks) are what actually keep a late range in bounds.

    **Still divergent, deliberately:**
    * **G2 row F6 — `annotatedSubstringForRange:` still returns UNATTRIBUTED text.** Upstream returns
      the annotation store's annotated substring, so its controller can read back what is already
      flagged. G1 called this "a correct repaint of nothing" and suspected a store was the real shape
      of the fix. **Measured: it is not load-bearing.** With bare text, the full delivery completes
      on both arms and BOTH spelling claims — "a misspelling is flagged" and "correcting it clears
      the flag" — match the stock oracle. Building a store now would be a speculative change to a
      path that measurably works, and could change the controller's own decisions. Left as a
      divergence, named, rather than repaired blind.
    * **`nativeTextRange(forGlobalLocation:length:)` still mints the canvas's legacy identity under
      every backend.** The kernel now normalises it at every entry point it can reach, so nothing is
      broken by it — but the honest shape is for the canvas to mint the ACTIVE backend's identity
      (identity is backend-owned; `LegacyTextPosition.swift`'s own header says so). That is the
      resolver's missing twin and is real follow-on work.
    * **`style(from:)` is unchanged** and still answers `.grammar` for any attributed run it does not
      recognise. It is inside a delivery, where every attributed run IS a marker, so that is correct
      there — but it means the delivery path and the annotation-client path now classify by two
      functions, and only the second can say "not a marker".
