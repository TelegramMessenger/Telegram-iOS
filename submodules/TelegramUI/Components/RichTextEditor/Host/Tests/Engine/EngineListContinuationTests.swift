import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// The gap Task 2's ruling F7 deferred to R6: `EngineDocumentBridge.document(fromAttributedBlocks:
/// reusingStructureOf:)` mints DEFAULT structure (no list) for any block beyond `previous.count` —
/// exactly what happens to the second half of a Return split. Left alone, pressing Return at the
/// end of a list item silently drops the new paragraph out of the list.
///
/// The fix is observe-and-reconcile, never veto: the engine performs its own split first, and only
/// AFTERWARDS does the host correct the resulting block's structure. `shouldChangeCharactersInRanges:`
/// / `shouldReplaceTextInRange:` are never touched (Global Constraint 4).
///
/// **Fix round 1: the reconciliation is DEFERRED to the next main-runloop turn**, not applied
/// synchronously from the engine's own observation callback (`RichTextEngineEditorView
/// .engineDidChangeDocument()`) — the original synchronous version re-entered
/// `tgid_setAttributedBlocks` from INSIDE the engine's own `-processEditing`, a real hazard on the
/// IME/marked-text path even though it happened to work under this harness. So the two positive
/// tests below CANNOT assert synchronously right after `insertText`: they must wait for the
/// deferred reconciliation to land. **That wait is the load-bearing part of these tests** — omitting
/// it would very likely still pass today (the deferred block typically runs well before an XCTest
/// method returns even with no explicit wait), which is exactly the kind of coincidental green this
/// codebase's own testing guidance warns about elsewhere. The synchronization signal is `onChange`:
/// the reconciliation design (`RichTextEngineEditorView+Paragraph.swift`'s list-continuation header
/// comment) fires it EXACTLY ONCE, after the corrected document has landed, for any edit that needed
/// reconciliation — waiting for that one call is therefore necessary AND sufficient, not a guess-a-
/// duration sleep.
///
/// **Fix round 2: multi-hop chaining.** The two positive tests above only ever created ONE new
/// block per edit (a single Return). `test_insertingMultipleNewlinesAtOnceContinuesTheListForEvery
/// NewParagraph` and `test_pastingMultiLineTextContinuesTheListForEveryNewParagraph` below cover a
/// single edit that creates SEVERAL new blocks at once — the case where the naive one-hop detection
/// silently stopped continuing the list after the first new paragraph (see
/// `RichTextEngineEditorView+Paragraph.swift`'s `blockIDsNeedingListContinuation` doc comment for
/// the mechanism).
final class EngineListContinuationTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        XCTAssertTrue(editor.becomeFirstResponder())
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func paragraph(at index: Int) -> ParagraphBlock {
        guard case let .paragraph(p) = editor.document.blocks[index] else {
            fatalError("expected a paragraph")
        }
        return p
    }

    /// Runs `perform`, waits for `editor.onChange` to fire exactly once, then runs `verify`. This is
    /// what correctly synchronizes a test with the DEFERRED reconciliation turn instead of racing
    /// it. `onChange` fires SYNCHRONOUSLY when no reconciliation is needed (so the wait resolves
    /// immediately) and ASYNCHRONOUSLY, after the deferred apply, when one is scheduled — this one
    /// helper covers both without the caller needing to know which case it is.
    private func afterNextOnChange(timeout: TimeInterval = 2.0, _ perform: () -> Void, then verify: () -> Void) {
        let onChangeFired = expectation(description: "onChange fired after the edit settled")
        editor.onChange = { onChangeFired.fulfill() }
        perform()
        wait(for: [onChangeFired], timeout: timeout)
        verify()
    }

    /// Return at the end of a bullet item must create a SECOND bullet item at the SAME level —
    /// not a plain paragraph, and not a level change.
    func test_returnAtEndOfABulletItemContinuesTheListAtTheSameLevel() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      list: ListMembership(marker: .bullet, level: 1),
                                      runs: [TextRun(text: "first")])),
        ])
        editor.composerSelectedRange = NSRange(location: 5, length: 0)   // end of "first"

        afterNextOnChange {
            editor.insertText("\n")
        } then: {
            XCTAssertEqual(editor.document.blocks.count, 2, "Return did not split the paragraph")
            XCTAssertEqual(paragraph(at: 0).list?.marker, .bullet,
                           "the ORIGINAL item lost its own list membership")
            XCTAssertEqual(paragraph(at: 1).list?.marker, .bullet,
                           "the new paragraph did not continue the list")
            XCTAssertEqual(paragraph(at: 1).list?.level, 1,
                           "the new paragraph continued the list at the wrong nesting level")
        }
    }

    /// The companion case this task must NOT regress: Return inside an ordinary paragraph must
    /// never invent list membership out of nothing. No reconciliation is scheduled for this edit
    /// (its predecessor has no list to continue), so `onChange` fires SYNCHRONOUSLY here — the
    /// shared wait helper still applies correctly, it just resolves immediately.
    func test_returnInsideAPlainParagraphDoesNotInventAList() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "plain")])),
        ])
        editor.composerSelectedRange = NSRange(location: 5, length: 0)   // end of "plain"

        afterNextOnChange {
            editor.insertText("\n")
        } then: {
            XCTAssertEqual(editor.document.blocks.count, 2, "Return did not split the paragraph")
            XCTAssertNil(paragraph(at: 0).list)
            XCTAssertNil(paragraph(at: 1).list, "a plain paragraph split acquired list membership")
        }
    }

    /// Negative control for the deferral itself (fix round 1): ordinary typing into a list item —
    /// no paragraph split, so nothing needs list-continuation reconciliation — must NOT pay a
    /// deferral. Proven by checking that `onChange` has ALREADY fired by the time `insertText`
    /// returns, synchronously, with no runloop turn in between. If the deferral ever crept onto
    /// every keystroke (e.g. a bug that schedules regardless of whether continuation is actually
    /// needed), this goes red: `onChangeFiredSynchronously` would still be `false` immediately after
    /// `insertText` returns, because a dispatched block cannot have run yet within this same call
    /// stack.
    func test_typingIntoAListItemWithoutReturnDoesNotDeferReconciliation() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      list: ListMembership(marker: .bullet, level: 0),
                                      runs: [TextRun(text: "first")])),
        ])
        editor.composerSelectedRange = NSRange(location: 5, length: 0)   // end of "first"

        var onChangeFiredSynchronously = false
        editor.onChange = { onChangeFiredSynchronously = true }

        editor.insertText("!")

        XCTAssertTrue(onChangeFiredSynchronously,
                      "ordinary typing must not defer its onChange notification")
    }

    /// R6/Task 8 fix round 2: a SINGLE edit can create more than one new block at once — typing (or
    /// programmatically inserting) a multi-line string splits one paragraph into several in ONE
    /// `insertText` call, not one Return at a time. The naive one-hop detection compared each new
    /// block only against its RAW predecessor, which is itself still list-less for every hop past
    /// the first at the moment of detection — so only the FIRST new paragraph continued the list and
    /// every later one silently fell back to plain. This is deterministic, not a race: it is what
    /// happens the first time a user pastes (or otherwise inserts) multi-line text into a list.
    func test_insertingMultipleNewlinesAtOnceContinuesTheListForEveryNewParagraph() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      list: ListMembership(marker: .bullet, level: 1),
                                      runs: [TextRun(text: "first")])),
        ])
        editor.composerSelectedRange = NSRange(location: 5, length: 0)   // end of "first"

        afterNextOnChange {
            editor.insertText("\nsecond\nthird")
        } then: {
            XCTAssertEqual(editor.document.blocks.count, 3,
                           "the multi-line insert did not split into three paragraphs")
            for index in 0..<3 {
                XCTAssertEqual(paragraph(at: index).list?.marker, .bullet,
                               "paragraph \(index) did not continue the list")
                XCTAssertEqual(paragraph(at: index).list?.level, 1,
                               "paragraph \(index) continued the list at the wrong nesting level")
            }
        }
    }

    /// The same scenario through the OTHER API path that can insert multi-line text in one call:
    /// `pasteFromPasteboard()` (`RichTextEngineEditorView+Responder.swift`), which forwards to the
    /// engine's `-paste:` — `[self.id_behaviorInput performPaste:sender]`
    /// (`IDBlockTextView+TextInput.m`), a genuinely different code path from `-insertText:` (paste
    /// does not gate on `canPerformAction:`, unlike cut/copy, so calling it directly always attempts
    /// the paste). Restores whatever the pasteboard held before the test, so this does not leak
    /// state into the simulator's shared pasteboard for later runs.
    func test_pastingMultiLineTextContinuesTheListForEveryNewParagraph() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"),
                                      list: ListMembership(marker: .bullet, level: 1),
                                      runs: [TextRun(text: "first")])),
        ])
        editor.composerSelectedRange = NSRange(location: 5, length: 0)   // end of "first"

        let pasteboard = UIPasteboard.general
        let priorPasteboardString = pasteboard.string
        defer { pasteboard.string = priorPasteboardString ?? "" }
        pasteboard.string = "\nsecond\nthird"

        afterNextOnChange {
            editor.pasteFromPasteboard()
        } then: {
            XCTAssertEqual(editor.document.blocks.count, 3,
                           "the paste did not split into three paragraphs")
            for index in 0..<3 {
                XCTAssertEqual(paragraph(at: index).list?.marker, .bullet,
                               "paragraph \(index) did not continue the list")
                XCTAssertEqual(paragraph(at: index).list?.level, 1,
                               "paragraph \(index) continued the list at the wrong nesting level")
            }
        }
    }
}
