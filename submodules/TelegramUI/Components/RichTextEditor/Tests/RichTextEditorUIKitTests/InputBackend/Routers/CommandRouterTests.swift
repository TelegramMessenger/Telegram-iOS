#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// TASK 30 — Family 7 (responder commands and clipboard). SEVEN canvas witnesses onto THREE backend
/// members: `copy(_:)`/`cut(_:)`/`paste(_:)`/`select(_:)`/`selectAll(_:)` -> `performCommand(_:sender:)`,
/// `canPerformAction(_:withSender:)` -> `canPerformCommand(_:sender:)`, and the `undoManager` override
/// -> the backend's own `undoManager`.
///
/// **`performCommand` forwards the five witness-mapped commands to the RENAMED CANVAS BODIES**
/// (`legacyCopy`/`legacyCut`/`legacyPaste`/`legacySelect`/`legacySelectAll`), not through the command
/// client, and Section 2 is mostly the measurement that forced that choice. The task brief said this
/// family "needs no `legacyCanvas` hook because the client already owns the bodies"; it owns strictly
/// less than the witnesses do, in two places a test can see and two more that are cycles. The full
/// four-way account is in `LegacyRichTextInputBackend+Commands.swift`'s header; the two deletions the
/// client route would have caused are pinned below by
/// `test_paste_withAnEmptyPasteboard_stillDelegatesToTheHostsMediaHook` and
/// `test_select_stillPresentsTheEditMenu_whichTheCommandClientRouteWouldHaveDropped`.
///
/// **Which backend each test runs against, decided before any of them were written** (the handoff's
/// rule 3):
///
///   * **Spy** for the routing-shape tests (Section 1). The spy performs no work, so
///     `XCTAssertRoutesOnly`'s "and the canvas did nothing of its own" half is exactly right — and it
///     is genuinely non-inert here: under the real backend these same calls move `anchor`/`head`
///     (select/selectAll), `revision`/`layoutGeneration`/`undoRegistrationCount`/
///     `dismissEditMenuCountForTesting` (cut/paste) — five of the seven fields `RouterStateSnapshot`
///     watches. A router that kept a copy of the old body fails there.
///   * **Real legacy backend** for the behavioural tests (Section 2). A correctly-routed command
///     legitimately moves those same fields, so `XCTAssertRouterDidNoWork` would fail FOR CORRECT
///     CODE; they assert the expected effect instead.
///
/// The detached-drop characterizations live in `BackendAttachmentTests`, not here: rule R14 forbids
/// this directory from naming the canvas's backend property, and detaching requires exactly it.
///
/// Every test reads through a real `DocumentCanvasView` member, never the canvas's backend property.
@MainActor
@available(iOS 16.0, *)
final class CommandRouterTests: XCTestCase {

    // MARK: - Fixtures

    /// A pasteboard double, duplicated rather than shared — **on the package's established convention,
    /// not on an access-control obstacle.**
    ///
    /// **FIX ROUND 1 (Min-6): the first version of this comment said the sibling copy is `private` to
    /// its own file's test class and therefore unreachable. That is false.**
    /// `CanvasClipboardTests.FakePasteboard` is a non-private nested `final class` — internal, and
    /// reachable from any file in this target as `CanvasClipboardTests.FakePasteboard`. The reasoning
    /// was transplanted from `SpyNoOpTokenizer`, which genuinely IS `private`, without re-checking the
    /// subject. The real reason: this target already carried THREE independent, mutually reachable
    /// copies of this double before Task 30 (`CanvasClipboardTests`, `CanvasTableMenuActionsTests`,
    /// `TelegramCommandInputClientTests`), so per-file isolation is the standing convention here — a
    /// suite's fixtures do not become another suite's dependency, and a test double that half the target
    /// imports is a double nobody can change. Task 30 added two more (this one and
    /// `BackendAttachmentTests`' `DetachedFakePasteboard`), bringing the count to five. Consolidating
    /// them is a defensible follow-on; inventing an access-control excuse for not doing it is not.
    final class FakePasteboard: TextPasteboard {
        var items: [String: Any] = [:]
        var string: String? {
            get { items["public.utf8-plain-text"] as? String }
            set { if let v = newValue { items = ["public.utf8-plain-text": v] } else { items = [:] } }
        }
        var hasStrings: Bool { !((string ?? "").isEmpty) }
        func data(forPasteboardType type: String) -> Data? { items[type] as? Data }
        func setItems(_ newItems: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
            items = newItems.first ?? [:]
        }
        func contains(pasteboardTypes: [String]) -> Bool { pasteboardTypes.contains { items[$0] != nil } }
    }

    private func laidOut(_ v: DocumentCanvasView) -> DocumentCanvasView {
        v.setParagraphs([ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "Hello world")])], width: 300)
        v.frame = CGRect(x: 0, y: 0, width: 300, height: 300); v.layoutIfNeeded()
        return v
    }

    /// A spy-backed canvas with a NON-COLLAPSED selection over "Hello", so the pre-seam, non-routing
    /// answer for every one of copy/cut/select/selectAll is a real effect — the spy performing no work
    /// is signal, not a coincidence of an inert selection.
    private func spyCanvas() -> (DocumentCanvasView, SpyRichTextInputBackend, FakePasteboard) {
        let spy = SpyRichTextInputBackend()
        let v = laidOut(DocumentCanvasView(inputBackend: spy))
        let pb = FakePasteboard(); v.pasteboard = pb
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s, head: s + 5)
        spy.reset()
        return (v, spy, pb)
    }

    private func realCanvas() -> (DocumentCanvasView, FakePasteboard) {
        let v = laidOut(DocumentCanvasView())
        let pb = FakePasteboard(); v.pasteboard = pb
        return (v, pb)
    }

    private var copySelector: Selector { #selector(UIResponderStandardEditActions.copy(_:)) }
    private var cutSelector: Selector { #selector(UIResponderStandardEditActions.cut(_:)) }
    private var pasteSelector: Selector { #selector(UIResponderStandardEditActions.paste(_:)) }
    private var selectSelector: Selector { #selector(UIResponderStandardEditActions.select(_:)) }
    private var selectAllSelector: Selector { #selector(UIResponderStandardEditActions.selectAll(_:)) }
    private var deleteSelector: Selector { #selector(UIResponderStandardEditActions.delete(_:)) }

    // MARK: - Section 1: the spy backend — "one call, exact arguments, nothing else"

    /// RED IF: the witness kept its own body (the canvas would write the pasteboard and record no
    /// backend call at all).
    func test_copy_callsTheBackendExactlyOnce() {
        let (v, spy, pb) = spyCanvas()
        XCTAssertLessThan(v.selFrom, v.selTo,
                          "precondition: a non-collapsed selection, so a non-routing body would copy")
        XCTAssertRoutesOnly(v, spy, member: "performCommand(_:sender:)", arguments: ["copy", "nil"]) {
            v.copy(nil)
        }
        XCTAssertTrue(pb.items.isEmpty, "the spy performs no copy — the pasteboard is untouched")
    }

    /// `sender` is forwarded VERBATIM. The spy records it as a type-described string (an `Any?` has no
    /// meaningful equality), so "non-nil" is the whole observable — which is exactly the point: a router
    /// that dropped the sender and passed `nil` would read "nil" here.
    func test_cut_callsTheBackendExactlyOnce_forwardingItsSender() {
        let (v, spy, _) = spyCanvas()
        let sender = NSObject()
        XCTAssertRoutesOnly(v, spy, member: "performCommand(_:sender:)", arguments: ["cut", "non-nil"]) {
            v.cut(sender)
        }
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Hello world",
                       "the spy performs no cut — the document is untouched")
    }

    /// Note this is ONE call, not two: `legacyCut`'s inner `replace(_:withText:)` — itself a routed
    /// witness — never runs, because the spy's `performCommand` does nothing. The two-call shape is
    /// real only against the live backend, and is what `test_cut_removesTheSelection…` below observes.
    func test_paste_callsTheBackendExactlyOnce() {
        let (v, spy, pb) = spyCanvas()
        pb.string = "xyz"   // a real paste is available, so a non-routing body would splice text
        XCTAssertRoutesOnly(v, spy, member: "performCommand(_:sender:)", arguments: ["paste", "nil"]) {
            v.paste(nil)
        }
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "Hello world",
                       "the spy performs no paste — the document is untouched")
    }

    func test_select_callsTheBackendExactlyOnce() {
        let (v, spy, _) = spyCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s + 8, head: s + 8)   // a collapsed caret inside "world": a real word to select
        spy.reset()
        XCTAssertRoutesOnly(v, spy, member: "performCommand(_:sender:)", arguments: ["selectWord", "nil"]) {
            v.select(nil)
        }
    }

    func test_selectAll_callsTheBackendExactlyOnce() {
        let (v, spy, _) = spyCanvas()
        XCTAssertRoutesOnly(v, spy, member: "performCommand(_:sender:)", arguments: ["selectAll", "nil"]) {
            v.selectAll(nil)
        }
    }

    /// The `undoManager` override. `stubbedUndoManager` is a manager the SPY owns, so `===` against it
    /// is real signal: the non-routing answer (`effectiveUndoManager`) is a different, always-non-nil
    /// instance, which is why a `nil` stub would have proved nothing.
    ///
    /// RED IF: the override still returned `effectiveUndoManager` (identity fails, and no backend call
    /// is recorded).
    func test_undoManager_routesToTheBackend() {
        let (v, spy, _) = spyCanvas()
        let read = XCTAssertRoutesOnly(v, spy, member: "undoManager", arguments: []) {
            v.undoManager
        }
        XCTAssertTrue(read === spy.stubbedUndoManager, "the override must return the backend's manager")
        XCTAssertFalse(read === v.effectiveUndoManager,
                       "…and the spy's manager is NOT the canvas's own, so this identity is real signal")
    }

    /// `canPerformAction(_:withSender:)` is the one witness in Phase 4 that is not a bare
    /// `inputBackend.…` one-liner: it maps the `Selector` to a `RichTextInputCommand` first. Both halves
    /// are asserted — that the mapped command is the RIGHT one, and that the backend's answer is
    /// propagated unmodified.
    ///
    /// **PER-TEST POLARITY, as `SpyRichTextInputBackend.stubbedCanPerformCommand`'s own note requires:**
    /// `false` is the non-routing answer for `copy:` under this fixture's collapsed caret, so `copy:`
    /// is checked with the stub set to `true`; `select:`'s non-routing answer under a collapsed caret
    /// inside a word is `true`, so it is checked with the stub left `false`. Neither can pass by
    /// coincidence.
    func test_canPerformAction_mapsAKnownSelectorAndAsksTheBackend() {
        let (v, spy, _) = spyCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s + 8, head: s + 8)   // collapsed inside "world"

        spy.stubbedCanPerformCommand = true
        let copyAnswer = XCTAssertRoutesOnly(v, spy, member: "canPerformCommand(_:sender:)",
                                             arguments: ["copy", "nil"]) {
            v.canPerformAction(copySelector, withSender: nil)
        }
        XCTAssertTrue(copyAnswer, "the backend's `true` must propagate — the canvas would answer false " +
                                  "for a collapsed caret, so this cannot pass by coincidence")

        spy.stubbedCanPerformCommand = false
        let selectAnswer = XCTAssertRoutesOnly(v, spy, member: "canPerformCommand(_:sender:)",
                                               arguments: ["selectWord", "nil"]) {
            v.canPerformAction(selectSelector, withSender: nil)
        }
        XCTAssertFalse(selectAnswer, "the backend's `false` must propagate — the canvas would answer " +
                                     "true for a collapsed caret inside a word")
    }

    /// The other four mapped selectors, so the translation table is checked entry by entry rather than
    /// by two samples. `delete:` is included deliberately: it was never a `case` in the pre-seam
    /// witness (it fell to `super`, which consults the NEXT RESPONDER and answers `false` for every
    /// chain this package can produce — see `+EditMenu.swift`'s Min-8 note), and it IS mapped, so it is
    /// the family's one axis-4 divergence: the DECIDER moved, not the answer.
    func test_canPerformAction_mapsEveryOneOfTheSixEditActionSelectors() {
        let (v, spy, _) = spyCanvas()
        let expected: [(Selector, String)] = [
            (copySelector, "copy"), (cutSelector, "cut"), (pasteSelector, "paste"),
            (selectSelector, "selectWord"), (selectAllSelector, "selectAll"), (deleteSelector, "delete"),
        ]
        for (selector, command) in expected {
            spy.reset()
            _ = v.canPerformAction(selector, withSender: nil)
            XCTAssertEqual(spy.calls, [SpyRichTextInputBackend.Call(
                member: "canPerformCommand(_:sender:)", arguments: [command, "nil"])],
                "\(selector) must map to .\(command) and ask the backend exactly once")
        }
    }

    /// The legacy `UIMenuItem` actions of the iOS 13-15 `UIMenuController` fallback and the six
    /// spelling-menu actions keep their EXISTING handling: they are not `UIResponderStandardEditActions`
    /// selectors, `richTextInputCommand(for:)` maps none of them, and the backend must never be asked
    /// about them. (The task brief says "the 8 legacy `UIMenuItem` actions"; there are FIVE —
    /// `legacyBold`/`legacyItalic`/`legacyUnderline`/`legacyLookUp`/`legacyShare` — plus the six
    /// spelling ones, eleven in all. Counted from `+EditMenu.swift`, not from the brief.)
    ///
    /// Selectors are built with `NSSelectorFromString` because the five are `private` to the canvas's
    /// own extension; the strings are their Obj-C names, which `@objc private func` still exports.
    ///
    /// **BOTH POLARITIES for every selector, and the negative one is the load-bearing half.** A first
    /// version of this test asserted only the AVAILABLE side for the five custom items and was
    /// VACUOUS: `UIResponder.canPerformAction(_:withSender:)`'s own default answers `true` for any
    /// selector the responder implements, and the canvas implements all eleven — so deleting the five
    /// custom `case`s outright left this test GREEN (measured; RC9 in the task report). What those
    /// cases actually contribute is the NARROWING (`selFrom < selTo`), which only a collapsed-selection
    /// assertion can see. The same applies to the six spelling items, whose narrowing is
    /// `pendingSpellingMenu != nil`.
    ///
    /// RED IF: the mapping had been placed AFTER a `default:` that swallowed these, or either group's
    /// cases had been dropped when the witness was rewritten.
    func test_canPerformAction_passesTheLegacyMenuItemAndSpellingSelectorsToSuper() {
        let (v, spy, _) = spyCanvas()
        let custom = ["legacyBold", "legacyItalic", "legacyUnderline", "legacyLookUp", "legacyShare"]
        let spelling = ["spellGuess0", "spellGuess1", "spellGuess2", "spellGuess3",
                        "spellNoop", "spellRevert"]

        // The five custom items: available exactly for a non-collapsed selection (the fixture has one).
        for name in custom {
            spy.reset()
            XCTAssertTrue(v.canPerformAction(NSSelectorFromString(name), withSender: nil),
                          "\(name) must still be offered for a non-collapsed selection")
            XCTAssertEqual(spy.calls, [], "\(name) must never reach the backend")
        }
        // …and UNAVAILABLE for a collapsed caret. This is the half that is not `super`'s answer.
        let caret = v.boxes[0].textStart + 3
        v.setSelectionForTesting(anchor: caret, head: caret)
        for name in custom {
            spy.reset()
            XCTAssertFalse(v.canPerformAction(NSSelectorFromString(name), withSender: nil),
                           "\(name) must be unavailable for a collapsed caret — `super` would say true")
            XCTAssertEqual(spy.calls, [], "\(name) must never reach the backend")
        }
        // The six spelling items: available exactly while a spelling menu is pending.
        for name in spelling {
            spy.reset()
            XCTAssertFalse(v.canPerformAction(NSSelectorFromString(name), withSender: nil),
                           "\(name) must be unavailable with no pending spelling menu")
            XCTAssertEqual(spy.calls, [], "\(name) must never reach the backend")
        }
        v.pendingSpellingMenu = (range: NSRange(location: 0, length: 1), guesses: ["Hell"], revertTo: nil)
        for name in spelling {
            spy.reset()
            XCTAssertTrue(v.canPerformAction(NSSelectorFromString(name), withSender: nil),
                          "\(name) must be offered once a spelling menu is pending")
            XCTAssertEqual(spy.calls, [], "\(name) must never reach the backend")
        }
        // And an entirely unrelated responder selector still falls through to `super`.
        spy.reset()
        _ = v.canPerformAction(#selector(UIResponder.becomeFirstResponder), withSender: nil)
        XCTAssertEqual(spy.calls, [], "an unmapped selector must go to super, not to the backend")
    }

    // MARK: - Section 2: the real legacy backend — the canvas bodies the routing moved

    func test_copy_writesThePasteboardThroughTheBackend() {
        let (v, pb) = realCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s, head: s + 5)

        v.copy(nil)

        XCTAssertEqual(pb.string, "Hello", "the whole `legacyCopy` body ran through the backend")
        XCTAssertNotNil(pb.data(forPasteboardType: DocumentCanvasView.richTextFragmentUTI))
    }

    /// `legacyCut`'s body calls the ROUTED `replace(_:withText:)` witness, so one `cut(_:)` makes two
    /// backend calls. That is deliberate (Task 29's `legacySetMarkedText` precedent) and is observed
    /// here by its effect rather than by a call count: the text is gone, which only the inner
    /// `replace` can accomplish.
    func test_cut_removesTheSelection_soTheRoutedReplaceInsideItStillRuns() {
        let (v, pb) = realCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s, head: s + 6)   // "Hello "

        v.cut(nil)

        XCTAssertEqual(pb.string, "Hello ", "the pasteboard half ran")
        XCTAssertEqual((v.boxes[0] as! BlockBox).currentParagraph().text, "world",
                       "…and so did the inner routed `replace(_:withText:)`")
    }

    /// **THE FINDING THAT SET THIS FAMILY'S SHAPE.** `legacyPaste` ends in an unconditional
    /// `_ = onPasteMedia?()` — "no text representation, let the host route the media". The command
    /// client's `canPerform(.paste)` gate does NOT admit that case: with an empty pasteboard and no
    /// `canPasteMedia` hook it answers `false`, `prepare` returns terminal, and the body never runs.
    /// So routing `paste(_:)` through the client would silently stop delegating media pastes.
    ///
    /// This is the same behaviour `CanvasClipboardTests
    /// .test_paste_noTextRep_delegatesToOnPasteMedia_documentUnchanged` has always pinned from the
    /// canvas side — it is what MEASURED the client route as wrong. Re-asserted here, through the
    /// routed witness, in the file a future editor of this router reads.
    ///
    /// RED IF: `performCommand`'s `.paste` case were re-pointed at the command client (observed: the
    /// hook is never called).
    func test_paste_withAnEmptyPasteboard_stillDelegatesToTheHostsMediaHook() {
        let (v, pb) = realCanvas()
        pb.items = [:]                          // no fragment, no RTF, no plain text
        var mediaCalled = false
        v.onPasteMedia = { mediaCalled = true; return true }
        XCTAssertFalse(v.clipboardCanPerformAction(pasteSelector),
                       "precondition: the command client's own gate answers `false` for this state")

        v.paste(nil)

        XCTAssertTrue(mediaCalled, "the witness body's media fallback must still run")
    }

    /// **THE SECOND FINDING THAT SET THIS FAMILY'S SHAPE.** `legacySelect` is `selectWord(at: head)`
    /// PLUS `presentEditMenu()`; the command client's `.selectWord` commit case is the first line only.
    /// Routing through the client would have dropped the menu re-presentation with no compiler error —
    /// and, before `presentEditMenuCountForTesting` existed, nothing in the package could see it
    /// (`presentEditMenu()`'s two real effects both no-op in a unit test: `isFirstResponder` is false
    /// and `editMenuInteraction` is nil).
    ///
    /// RED IF: `performCommand`'s `.selectWord` case were re-pointed at the command client (observed:
    /// the selection still moves, and the count does not).
    func test_select_stillPresentsTheEditMenu_whichTheCommandClientRouteWouldHaveDropped() {
        let (v, _) = realCanvas()
        let s = v.boxes[0].textStart
        v.setCaret(global: s + 8)   // inside "world"
        let before = v.presentEditMenuCountForTesting

        v.select(nil)

        XCTAssertEqual(v.selFrom, s + 6, "the selectWord half ran")
        XCTAssertEqual(v.selTo, s + 11)
        XCTAssertEqual(v.presentEditMenuCountForTesting, before + 1, "…and so did the menu half")
    }

    /// The same for Select All, plus the gate divergence that is specific to it: the client's
    /// `canPerform(.selectAll)` is `hasText && !(selFrom <= begin && selTo >= end)`, i.e. it REJECTS
    /// when everything is already selected — where the witness re-selects and re-presents the menu. A
    /// programmatic `selectAll(nil)` (four in-tree tests make one) would have started no-op'ing.
    ///
    /// RED IF: `performCommand`'s `.selectAll` case were re-pointed at the command client (observed:
    /// the second call does nothing at all).
    func test_selectAll_presentsTheMenu_andStillRunsWhenEverythingIsAlreadySelected() {
        let (v, _) = realCanvas()
        v.selectAll(nil)
        let selectedFrom = v.selFrom, selectedTo = v.selTo
        XCTAssertLessThan(selectedFrom, selectedTo, "precondition: the first call selected everything")

        let before = v.presentEditMenuCountForTesting
        v.selectAll(nil)   // everything is already selected — the client's gate would reject this

        XCTAssertEqual(v.selFrom, selectedFrom, "the selection is unchanged…")
        XCTAssertEqual(v.selTo, selectedTo)
        XCTAssertEqual(v.presentEditMenuCountForTesting, before + 1,
                       "…but the body still ran and re-presented the menu, as it always did")
    }

    /// The availability QUERY does route through the command client, and this is the control proving
    /// that path answers identically to the predicate the witness used to evaluate inline. All three
    /// clipboard commands, both polarities, against the live pasteboard.
    func test_canPerformAction_clipboardAnswersMatchTheCanvasPredicate() {
        let (v, pb) = realCanvas()
        let s = v.boxes[0].textStart

        v.setSelectionForTesting(anchor: s, head: s + 5)   // a non-collapsed selection
        pb.string = "xyz"
        XCTAssertTrue(v.canPerformAction(copySelector, withSender: nil))
        XCTAssertTrue(v.canPerformAction(cutSelector, withSender: nil))
        XCTAssertTrue(v.canPerformAction(pasteSelector, withSender: nil))

        v.setSelectionForTesting(anchor: s, head: s)   // collapsed
        pb.items = [:]
        XCTAssertFalse(v.canPerformAction(copySelector, withSender: nil))
        XCTAssertFalse(v.canPerformAction(cutSelector, withSender: nil))
        XCTAssertFalse(v.canPerformAction(pasteSelector, withSender: nil))
    }

    /// `delete(_:)` still answers `false`, which is what `super` answered before — the axis-4
    /// divergence is the decider, not the answer, and this pins the answer so a future change to the
    /// client's `.delete` case cannot silently start offering a Delete item the canvas cannot perform.
    func test_canPerformAction_deleteIsStillFalse_thoughTheDeciderMoved() {
        let (v, _) = realCanvas()
        let s = v.boxes[0].textStart
        v.setSelectionForTesting(anchor: s, head: s + 5)   // even with a selection, which is when Delete would be offered
        XCTAssertFalse(v.canPerformAction(deleteSelector, withSender: nil))
    }

    /// The routed `undoManager` is value-identical to what the override returned: the canvas's own
    /// manager, and it still tracks `undoManagerOverride`. (`UndoBufferIsolationTests` pins the same
    /// two facts and was deliberately left untouched — this is the router-side restatement, in the
    /// file a future editor of the router reads.)
    func test_undoManager_isStillTheCanvasOwnManager_throughTheRealBackend() {
        let (v, _) = realCanvas()
        XCTAssertTrue(v.undoManager === v.effectiveUndoManager)
        let injected = UndoManager()
        v.undoManagerOverride = injected
        XCTAssertTrue(v.undoManager === injected, "…and still follows an injected override")
    }

    // MARK: - Section 3: the family's stubs are gone — TEST DELETED BY TASK 34, BOTH HALVES DEAD
    //
    // `test_noPendingRoutingStubsRemainForThisFamily` stood here, and its own doc comment argued that
    // the second half was the load-bearing one ("an entry can be deleted from the Set while the stub
    // body survives"). That argument was right, and by Task 34 BOTH halves were dead anyway:
    //
    //   * The `!pendingRoutingInventory.contains(…)` half died at TASK 33, which emptied the Set —
    //     `contains` on an empty Set is `false` for every argument, so the assertion could not fail.
    //     It was live when written and was killed by a correct change somewhere else; see the fuller
    //     write-up of that failure CLASS at the identical deletion in `FloatingCursorRouterTests`
    //     (Section 5), which is the other of the exactly two instances Task 34's sweep found.
    //   * The `pendingRoutingCalls == []` half died at TASK 34, which deleted the `pendingRouting(_:)`
    //     funnel outright — no production code can record a call to a function that no longer exists.
    //
    // Successor: rule R20 in the Core source-boundary suite
    // (`test_noPendingRoutingResidueRemains_R20`) — a source-level property covering
    // every file under `S/InputBackend/`, not a per-family runtime probe.
    //
    // This family's routing itself is unaffected: Sections 1-2 above pin it through
    // `SpyRichTextInputBackend`, per member and per `switch` arm.
}
#endif
