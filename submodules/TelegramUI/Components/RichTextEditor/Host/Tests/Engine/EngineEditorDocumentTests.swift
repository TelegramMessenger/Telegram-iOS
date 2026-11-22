import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

final class EngineEditorDocumentTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    private func paragraphs(_ texts: [String]) -> Document {
        Document(blocks: texts.enumerated().map { index, text in
            .paragraph(ParagraphBlock(id: BlockID("p\(index)"),
                                      runs: text.isEmpty ? [] : [TextRun(text: text)]))
        })
    }

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
    }

    override func tearDown() {
        window.isHidden = true; window = nil; editor = nil
        super.tearDown()
    }

    func test_settingTheDocumentIsReadableBack() {
        let document = paragraphs(["alpha", "beta"])
        editor.document = document
        XCTAssertEqual(editor.document, document)
    }

    /// Drives the ENGINE directly — the keyboard's own path, where this class has no call of its
    /// own to flush after — so the notification arrives on the coalesced main-queue turn rather
    /// than synchronously. It is waited for, not raced: `onChange` is consumer code and is
    /// deliberately never fired from inside `-[IDCanonicalTextStorageAdapter processEditing]` (see
    /// `RichTextEngineEditorView.isChangeNotificationPending`). Asserting it synchronously here
    /// would be asserting the hazard.
    ///
    /// The synchronous half of the same guarantee — a mutation the EDITOR initiates delivers within
    /// the caller's own turn — is `EngineListContinuationTests
    /// .test_typingIntoAListItemWithoutReturnDoesNotDeferReconciliation`.
    func test_typingFiresOnChange() {
        editor.document = paragraphs(["alpha"])
        let fired = expectation(description: "typing reached onChange")
        editor.onChange = { fired.fulfill() }
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("!")
        wait(for: [fired], timeout: 2.0)
    }

    /// `onChange` must not run inside the engine's own text-storage edit processing. The consumer
    /// (`RichTextEditorChatInputNode`) runs a full layout pass from it, and
    /// `IDCanonicalTextStorageAdapter.m:156-166` invokes `documentChangeHandler` synchronously from
    /// `-processEditing`, itself reached from the original edit's `endEditing`. Proven by the one
    /// observable consequence available from outside: a keyboard-path edit's notification cannot
    /// have been delivered by the time `insertText` returns.
    ///
    /// The negative control is `test_typingFiresOnChange` above — the same edit, waited for, DOES
    /// deliver. Without it this assertion would also pass if `onChange` were simply never called.
    func test_aKeyboardPathEditDoesNotFireOnChangeFromInsideEditProcessing() {
        editor.document = paragraphs(["alpha"])
        var firedSynchronously = false
        let fired = expectation(description: "the deferred notification still lands")
        editor.onChange = { firedSynchronously = true; fired.fulfill() }
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("!")
        XCTAssertFalse(firedSynchronously,
                       "onChange fired from inside the engine's -processEditing stack")
        wait(for: [fired], timeout: 2.0)
        XCTAssertTrue(firedSynchronously)
    }

    /// **The interleaving the two delivery paths make reachable, and the regression the first
    /// version of that mechanism shipped.**
    ///
    /// A keyboard-direct edit — UIKit calls `insertText:` straight on `engine`, never through the
    /// wrapper — marks `isChangeNotificationPending` and enqueues a coalesced main-queue flush. A
    /// structural mutator running before that turn has NO engine change funnel call of its own to
    /// piggy-back on: its `document =` set is swallowed by `isApplyingHostDocument`, so
    /// `engineDidChangeDocument()` returns at its first line and the flag survives. When the mutator
    /// called `onChange?()` directly, it delivered once and the stale flush delivered a SECOND time,
    /// for state already reported.
    ///
    /// Not data-corrupting — the document is settled before either call — which is exactly why it
    /// needs a test: it costs a redundant full layout pass in the real consumer and shows up as
    /// nothing but two harmless-looking callbacks. Reachable through IME-batched input, any
    /// programmatic path that pairs a raw engine mutation with an immediate structural mutator, and
    /// test code that does not pump the runloop between the two. The reverse ordering does not
    /// double-fire; only this one does.
    ///
    /// Every step is asserted, so the test cannot pass by failing to reach the window it targets:
    /// the keyboard edit must NOT have been delivered yet (the pending flush is what makes the
    /// interleaving possible at all), the mutator must deliver, and the runloop turn must add
    /// nothing.
    /// A SELECTION-ONLY change must reach the host through `onChange`.
    ///
    /// REGRESSION TEST FOR DATA LOSS. The chat composer learns the caret moved only via `onChange` —
    /// the legacy backend fires it for selection as well as content, and the composer is written
    /// against that. This editor split the two and nothing bridged the gap, so the panel kept whatever
    /// selection it last saw. Select all, apply a spoiler, then insert a custom emoji, and it REPLACED
    /// THE WHOLE TEXT, because the panel still held the select-all range. Moving the caret did not
    /// help — the selection only looked gone.
    ///
    /// Coalesced, so this waits a runloop turn rather than asserting synchronously.
    func test_aSelectionOnlyChangeReachesTheHostThroughOnChange() {
        editor.document = paragraphs(["alpha beta"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())

        // Settle any notification owed by the document set before arming.
        let settled = expectation(description: "setup settled")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 2.0)

        var changeCount = 0
        editor.onChange = { changeCount += 1 }

        let start = editor.engine.beginningOfDocument
        let target = editor.engine.position(from: start, offset: 4)!
        editor.engine.selectedTextRange = editor.engine.textRange(from: target, to: target)

        let turned = expectation(description: "the coalesced selection flush")
        DispatchQueue.main.async { turned.fulfill() }
        wait(for: [turned], timeout: 2.0)

        XCTAssertEqual(changeCount, 1,
                       "a caret move did not reach the host, so a composer built against the legacy "
                       + "contract keeps a stale selection and inserts over it")
    }

    func test_aStructuralMutatorDuringAPendingCoalescedFlushFiresOnChangeExactlyOnce() {
        editor.document = paragraphs(["alpha"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        var changeCount = 0
        editor.onChange = { changeCount += 1 }

        // Keyboard-direct, so nothing flushes synchronously and a coalesced flush is left owed.
        editor.engine.insertText("!")
        XCTAssertEqual(changeCount, 0,
                       "the keyboard-path edit was delivered synchronously, so no coalesced flush "
                       + "is owed and this test does not reach the interleaving it targets")

        // No runloop turn in between: the mutator delivers while that flush is still owed.
        editor.setParagraphStyle(.heading1)
        XCTAssertEqual(changeCount, 1,
                       "the structural mutator did not deliver its own notification")

        // Enqueued AFTER the coalesced flush, so FIFO ordering on the serial main queue — not
        // wall-clock timing — guarantees the flush has already had its turn by the time this
        // fulfills.
        let turned = expectation(description: "the coalesced flush's runloop turn")
        DispatchQueue.main.async { turned.fulfill() }
        wait(for: [turned], timeout: 2.0)

        XCTAssertEqual(changeCount, 1,
                       "the stale coalesced flush fired a SECOND time for state the structural "
                       + "mutator had already delivered — onChange is no longer exactly-once")
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(paragraph.style, .heading1, "the structural mutation did not land")
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "alpha!",
                       "the keyboard edit did not survive the structural mutation")
    }

    func test_typingIsReflectedInTheDocument() {
        editor.document = paragraphs(["alpha"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("!")
        XCTAssertEqual(editor.document.blocks.count, 1)
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(paragraph.runs.map(\.text).joined(), "alpha!")
    }

    func test_pressingReturnCreatesASecondBlock() {
        editor.document = paragraphs(["alpha"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("\n")
        XCTAssertEqual(editor.document.blocks.count, 2,
                       "the engine's own newline split did not reach the Document")
    }

    func test_heightGrowsWithContent() {
        editor.document = paragraphs(["one"])
        let short = editor.height(forWidth: 320)
        editor.document = paragraphs(["one", "two", "three", "four"])
        XCTAssertGreaterThan(editor.height(forWidth: 320), short)
    }

    /// A host-driven document set is NOT a user edit and must not masquerade as one.
    func test_settingTheDocumentDoesNotFireOnChange() {
        editor.document = paragraphs(["alpha"])
        var changes = 0
        editor.onChange = { changes += 1 }
        editor.document = paragraphs(["beta"])
        XCTAssertEqual(changes, 0, "a host document set fired onChange")
    }

    /// R2 correction 2's gate. `EngineDocumentBridge.document(fromAttributedBlocks:
    /// engineIdentifiers:reusingStructureOf:)` mints a FRESH `BlockID` for any engine block whose
    /// identifier the identity table has never seen. If the `document` getter re-derived from the
    /// bridge on every call against a stale identity table, the block created by the Return split
    /// below would mint a new
    /// `BlockID` on every read — two consecutive reads of the very same on-screen paragraph would
    /// disagree, and no test asserting only block counts (the other tests here) would ever catch
    /// it. The getter must instead be a pure read of a cache refreshed exactly once per engine
    /// change.
    func test_twoConsecutiveDocumentReadsAreIdentical() {
        editor.document = paragraphs(["alpha"])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("\n")          // split — the new block gets a minted BlockID
        XCTAssertEqual(editor.document, editor.document,
                       "consecutive reads minted different BlockIDs for the same paragraph")
    }

    /// Fix round 1, Important finding 1. The mirror of `test_settingTheDocumentDoesNotFireOnChange`
    /// for the sibling callback: `document`'s setter moves the caret to end-of-document, which
    /// reaches `engineDidChangeSelection` synchronously, and that must not masquerade as a real
    /// user caret move either.
    func test_settingTheDocumentDoesNotFireOnSelectionChange() {
        editor.document = paragraphs(["alpha"])
        // Force the caret away from wherever the FIRST host set left it (end-of-document), so the
        // SECOND set's own end-of-document reposition below is guaranteed to be a REAL selection
        // change and not a coincidental no-op (position 0 stays valid across the content replace,
        // so nothing else would move it there first).
        let start = editor.engine.beginningOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: start, to: start)
        var selectionChanges = 0
        editor.onSelectionChange = { selectionChanges += 1 }
        editor.document = paragraphs(["beta"])
        XCTAssertEqual(selectionChanges, 0, "a host document set fired onSelectionChange")
    }

    /// **C1's gate, end to end: an edit in the MIDDLE of a multi-block document.**
    ///
    /// Nothing on this branch edited anywhere but the last block, which is why re-deriving block
    /// identity from array POSITION passed everything. `-[IDBlockDocument
    /// replaceCanonicalRange:withAttributedString:]` keeps the identifiers of blocks before AND
    /// after the affected range and mints fresh ones only inside it, so a Return at the end of "A"
    /// in `[A body][B heading1]` yields `["A"→u0, ""→new, "B"→u1]`. Positional reuse hands index 1
    /// (the new blank line) p1's heading structure and index 2 ("B", the real heading) a default
    /// body: the heading migrates onto the blank line and the real one silently demotes, with the
    /// original `BlockID` landing on the wrong paragraph.
    ///
    /// Every assertion below distinguishes identity reuse from positional reuse; none of them can
    /// be satisfied by both.
    func test_returnInTheMiddleOfADocumentKeepsTheFollowingBlocksOwnIdentityAndStructure() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("pA"), runs: [TextRun(text: "A")])),
            .paragraph(ParagraphBlock(id: BlockID("pB"), style: .heading1, runs: [TextRun(text: "B")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // Caret at the END of "A" — i.e. in the middle of the document, not at its end.
        editor.composerSelectedRange = NSRange(location: 1, length: 0)
        editor.insertText("\n")

        XCTAssertEqual(editor.document.blocks.count, 3, "Return did not split the first paragraph")
        guard case let .paragraph(first) = editor.document.blocks[0],
              case let .paragraph(middle) = editor.document.blocks[1],
              case let .paragraph(last) = editor.document.blocks[2] else {
            return XCTFail("expected three paragraphs")
        }
        XCTAssertEqual(first.id, BlockID("pA"), "the edited block lost its own identity")
        XCTAssertEqual(first.style, .body)
        XCTAssertEqual(first.runs.map(\.text).joined(), "A")

        XCTAssertEqual(middle.style, .body,
                       "the heading migrated onto the newly created blank line")
        XCTAssertNotEqual(middle.id, BlockID("pB"),
                          "the newly created blank line took the heading's BlockID")
        XCTAssertNotEqual(middle.id, BlockID("pA"))
        XCTAssertEqual(middle.runs.map(\.text).joined(), "")

        XCTAssertEqual(last.id, BlockID("pB"),
                       "the block AFTER the edit lost its own identity — structure is being reused "
                       + "by array position rather than by the engine's own block identity")
        XCTAssertEqual(last.style, .heading1,
                       "the real heading was silently demoted to body")
        XCTAssertEqual(last.runs.map(\.text).joined(), "B")
    }

    /// The merge direction of the same rule. Backspacing at the start of B in `[A][B][C]` merges A
    /// and B into one block that keeps A's identifier, and C keeps its own — so C must still be C.
    /// Positional reuse gives the surviving second block (C) block B's identity and structure.
    func test_mergingTwoBlocksLeavesTheFollowingBlockWithItsOwnIdentityAndStructure() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("pA"), runs: [TextRun(text: "A")])),
            .paragraph(ParagraphBlock(id: BlockID("pB"), style: .heading2, runs: [TextRun(text: "B")])),
            .paragraph(ParagraphBlock(id: BlockID("pC"), style: .heading3, runs: [TextRun(text: "C")])),
        ])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        // Caret at the START of "B" — flat axis: "A" (1) + "\n" (1) = 2.
        editor.composerSelectedRange = NSRange(location: 2, length: 0)
        editor.deleteBackward()

        XCTAssertEqual(editor.document.blocks.count, 2, "the backspace did not merge two paragraphs")
        guard case let .paragraph(merged) = editor.document.blocks[0],
              case let .paragraph(tail) = editor.document.blocks[1] else {
            return XCTFail("expected two paragraphs")
        }
        XCTAssertEqual(merged.id, BlockID("pA"), "the merged block did not keep the survivor's identity")
        XCTAssertEqual(merged.runs.map(\.text).joined(), "AB")
        XCTAssertEqual(tail.id, BlockID("pC"),
                       "the block after the merge inherited its former neighbour's identity")
        XCTAssertEqual(tail.style, .heading3,
                       "the block after the merge inherited its former neighbour's structure")
        XCTAssertEqual(tail.runs.map(\.text).joined(), "C")
    }

    /// I2's gate. `tgid_setAttributedBlocks` replaces the WHOLE canonical string, and UIKit keeps a
    /// shadow copy of the document for autocorrection, inline prediction and the candidate bar that
    /// it only re-reads when a client announces a change. Upstream's `-setText:` omits the bracket,
    /// but that is a load-time API; this one fires on every toolbar tap (`mutateTouchedParagraphs`)
    /// and every list continuation, while the user is focused. There is no way to observe UIKit's
    /// shadow copy directly, so the observable is the announcement itself.
    ///
    /// The two counts are asserted separately and both must be exactly one: a `textWillChange`
    /// without its matching `textDidChange` leaves UIKit mid-update, which is worse than neither.
    func test_aWholeDocumentWriteIsBracketedWithTheInputDelegateNotifications() {
        let delegate = RecordingInputDelegate()
        editor.engine.inputDelegate = delegate
        editor.document = paragraphs(["alpha", "beta"])
        XCTAssertEqual(delegate.textWillChangeCount, 1,
                       "the whole-document write did not announce textWillChange, so UIKit's text "
                       + "shadow document goes stale and autocorrect reasons about text that is gone")
        XCTAssertEqual(delegate.textDidChangeCount, 1,
                       "the whole-document write did not announce textDidChange")
    }

    /// I3's gate, re-pinned 2026-09-24 (composer harness p13, `HarnessAtomComposerAxisTests`).
    /// `composerSelectedRange` is the chat composer's flat axis, which counts a formula by its MODEL
    /// length — the LaTeX source, as `ChatInputContent` does (`docs/richtext-composer.md` §2) — while
    /// the engine renders it as ONE `U+FFFC`. It used to be pinned to the ENGINE's lengths (flat 2 =
    /// block 1's start), and that axis disagreed with the model the chat indexes: every offset after
    /// a formula or custom emoji was short, so the chat's own replace at the reported selection
    /// landed early. What this still proves is that the two measures are MAPPED, not confused: block
    /// 0 measures 3 in the model and 1 in the engine, and flat 4 (3 + the "\n") must reach block 1 —
    /// a walk on either measure alone retypes the WRONG paragraph.
    ///
    /// Driven entirely through the public composer surface (`composerSelectedRange` +
    /// `setParagraphStyle`), which is how a real toolbar reaches it.
    func test_aFlatOffsetResolvesAgainstTheEnginesBlockLengthsNotTheModels() {
        let renderer: (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult? = { _ in
            let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: CGSize(width: 10, height: 10),
                                               ascent: 8, descent: 2)
        }
        let editor = RichTextEngineEditorView(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240),
            mapper: AttributedStringMapper(formulaRenderer: renderer))
        window.addSubview(editor)

        var formula = CharacterAttributes.plain
        formula.formula = "x+y"
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x+y", attributes: formula)])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "B")])),
        ])
        // Anti-vacuity: the whole point is that the two measures DISAGREE for this document. If the
        // renderer ever stopped producing an attachment, block 0 would render as its raw LaTeX,
        // both measures would read 3, and this test would pass whichever one the walk used.
        XCTAssertEqual(editor.engine.attributedBlocks[0].length, 1,
                       "the formula run did not render as a single attachment character, so the "
                       + "model and engine measures agree and this test proves nothing")
        guard case let .paragraph(modelBlock) = editor.document.blocks[0] else {
            return XCTFail("expected a paragraph")
        }
        XCTAssertEqual(modelBlock.utf16Count, 3,
                       "the model no longer measures the formula run by its LaTeX source")

        // Flat offset 4 is the FIRST character of block 1 on the composer's axis (3 + the "\n");
        // the engine puts it at 2.
        editor.composerSelectedRange = NSRange(location: 4, length: 1)
        XCTAssertEqual(editor.selectedText(), "B", "the flat range did not select block 1's text")
        editor.setParagraphStyle(.heading1)

        guard case let .paragraph(first) = editor.document.blocks[0],
              case let .paragraph(second) = editor.document.blocks[1] else {
            return XCTFail("expected two paragraphs")
        }
        XCTAssertEqual(second.style, .heading1,
                       "the style landed on the wrong paragraph — block extents were taken from the "
                       + "model's run text rather than the engine's rendered lengths")
        XCTAssertEqual(first.style, .body, "the formula paragraph was restyled instead")

        editor.removeFromSuperview()
    }

    /// Fix round 1, Important finding 2. `height(forWidth:)` is a pure measurement: probing a
    /// width the caller has not committed to (a candidate width, before choosing one) must not
    /// leave the live engine frame at that queried width.
    func test_heightForWidthDoesNotDisturbTheEngineFrame() {
        editor.document = paragraphs(["alpha", "beta"])
        let before = editor.engine.frame
        _ = editor.height(forWidth: 200)          // deliberately NOT the 320pt bounds width
        XCTAssertEqual(editor.engine.frame, before, "the probe left the engine at the queried width")
    }
}

/// Counts the two whole-document announcements a `UITextInput` client owes UIKit. Only what
/// `EngineEditorDocumentTests.test_aWholeDocumentWriteIsBracketedWithTheInputDelegateNotifications`
/// reads is recorded; the selection pair is answered so the protocol is satisfied, not measured.
private final class RecordingInputDelegate: NSObject, UITextInputDelegate {
    var textWillChangeCount = 0
    var textDidChangeCount = 0
    func selectionWillChange(_ textInput: UITextInput?) {}
    func selectionDidChange(_ textInput: UITextInput?) {}
    func textWillChange(_ textInput: UITextInput?) { textWillChangeCount += 1 }
    func textDidChange(_ textInput: UITextInput?) { textDidChangeCount += 1 }
    /// iOS 18.4+ requirement, availability-gated so the file still compiles at the package's floor.
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {}
}
