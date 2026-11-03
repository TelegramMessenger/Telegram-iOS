import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// **The drawn cursor must be on the caret when the layout pass ends — not a run-loop turn later.**
///
/// The user's report was "when typing the cursor sometimes lags behind the typed text": on K3 the
/// caret stayed at the line's start through the first five keystrokes while the glyphs advanced,
/// then jumped and thereafter trailed by about a character.
///
/// The cause is in UIKit, and it is structural rather than intermittent. Marking the selection
/// display dirty reaches `-[UITextSelectionDisplayInteraction setNeedsSelectionUpdate]`, which moves
/// nothing: it sets a pending flag and schedules the real work with `performSelector:afterDelay:0`
/// in `kCFRunLoopCommonModes`. A zero-delay timer cannot run in the iteration that scheduled it, so
/// the cursor is drawn from the PREVIOUS state in the CoreAnimation commit that draws the new
/// glyphs. A stock `UITextView` takes that same deferred path and never shows it, because UIKit's
/// own canvas posts a notification from its `-layoutSubviews` that the interaction answers by
/// flushing the update inside the commit — and a text input that draws its own canvas, as this
/// engine does, posts nothing.
///
/// The engine therefore flushes it itself, from `-[IDBlockTextView layoutSubviews]`
/// (`id_flushSelectionDisplayUpdate`, upstream). That is pinned upstream against a real
/// `UITextView`; this pins it through the Telegram host's own editor, which is the thing that
/// regressed, and would catch a port that dropped it.
///
/// **Nothing here may spin the run loop between the edit and the assertion.** One turn and the timer
/// fires, the cursor is right whatever the engine does, and the test passes over a live defect.
@available(iOS 18.4, *)
final class EngineCaretFollowsTypingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(
            id: BlockID("p0"), runs: [TextRun(text: "The quick brown fox")]))])
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        XCTAssertTrue(editor.becomeFirstResponder())
        // The ONE run loop in this test, and it is before any edit: UIKit installs the
        // selection-display interaction and builds its cursor view on its own schedule after the
        // engine takes the responder role.
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    override func tearDown() {
        _ = editor?.resignEditorFirstResponder()
        window?.isHidden = true
        window = nil
        editor = nil
        super.tearDown()
    }

    /// UIKit's cursor, via the interaction's PUBLIC `cursorView`. Matching on the concrete class
    /// name would be a silent no-op the day UIKit renames it — and a test that finds nothing
    /// reports no lag.
    private func drawnCursorRectInEngine() -> CGRect? {
        for interaction in editor.engine.interactions {
            guard let display = interaction as? UITextSelectionDisplayInteraction else { continue }
            let cursor = display.cursorView
            return cursor.superview?.convert(cursor.frame, to: editor.engine) ?? cursor.frame
        }
        return nil
    }

    private func assertCursorSitsOnTheCaret(_ label: String,
                                            file: StaticString = #filePath, line: UInt = #line) {
        guard let selection = editor.engine.selectedTextRange else {
            return XCTFail("\(label): no selection", file: file, line: line)
        }
        let caret = editor.engine.caretRect(for: selection.end)
        guard let drawn = drawnCursorRectInEngine() else {
            return XCTFail("\(label): no cursor view to measure", file: file, line: line)
        }
        XCTAssertEqual(drawn.minX, caret.minX, accuracy: 1.0,
                       "\(label): the cursor is drawn at \(drawn.minX) while the caret is at "
                       + "\(caret.minX) — the selection display was left to its run-loop timer",
                       file: file, line: line)
        // BOTH axes. Typing moves the caret along one line, so the x alone was enough for the
        // keystroke cases; a command that moves the caret to another BLOCK is a vertical move, and
        // an x-only assertion reads a caret one paragraph away as correct whenever the two lines
        // happen to start at the same indent — which two blocks of the same kind always do.
        XCTAssertEqual(drawn.minY, caret.minY, accuracy: 1.0,
                       "\(label): the cursor is drawn at y \(drawn.minY) while the caret is at "
                       + "y \(caret.minY) — the selection display was left to its run-loop timer",
                       file: file, line: line)
    }

    /// One keystroke and the layout pass the commit would run, and nothing else.
    private func typeOneCharacterAndLayOut() {
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)
        editor.engine.insertText("W")
        editor.engine.setNeedsLayout()
        editor.engine.layoutIfNeeded()
    }

    func test_theCursorIsOnTheCaretAfterTypingWithoutARunLoopTurn() {
        assertCursorSitsOnTheCaret("before typing")
        typeOneCharacterAndLayOut()
        assertCursorSitsOnTheCaret("after typing")
    }

    /// A RUN of keystrokes with no run loop between them is the reported shape — the device showed
    /// five characters of drift before the caret caught up, not one.
    func test_theCursorTracksARunOfKeystrokes() {
        for index in 1...5 {
            typeOneCharacterAndLayOut()
            assertCursorSitsOnTheCaret("keystroke \(index)")
        }
    }

    // MARK: - A host command's caret

    /// The HOST's layout pass, which is the one that draws a command's change — not the engine's
    /// alone, as the keystroke helper above uses.
    private func layOut() {
        editor.setNeedsLayout()
        editor.layoutIfNeeded()
    }

    /// A HOST COMMAND changes the document and then places the caret, and that is the same
    /// invariant with a different trigger — one the engine's own flush does not cover.
    ///
    /// The engine arms the flush when its document changes and the first layout pass SPENDS it. A
    /// host command's document set moves the caret twice: the setter's own bookkeeping clamps it to
    /// the replaced span's end, and the command then puts it where it belongs. The setter lays the
    /// engine out in between (it measures table frames and container insets before it clamps), so
    /// the flush is spent on the clamp and the command's real caret waits for UIKit's zero-delay
    /// timer — a painted frame with the cursor in the wrong place.
    ///
    /// Reported from K3 as "when adding a detail block, the cursor momentarily blinks in its body,
    /// and then jumps into the title" (2026-09-15). Those two positions are exactly the clamp's
    /// landing and the command's: the replaced span ends at the details' body, and
    /// `insertDetailsBlock` wants the title.
    func test_theCursorIsOnTheCaretAfterInsertingADetailsBlock() {
        // The end of "The quick brown fox", which is where a user types before reaching for the
        // menu — and the shape that reproduces: the details is APPENDED, so the replaced span ends
        // at its body.
        editor.engineSelectedRange = NSRange(location: 19, length: 0)
        layOut()
        editor.insertDetailsBlock()
        layOut()
        assertCursorSitsOnTheCaret("after inserting a details block")
    }

    /// The same defect through a different command, because a fix aimed at one host command would
    /// leave every sibling standing: `wrapInBlockQuote` rebuilds through the same document setter
    /// and lands its caret somewhere the clamp did not.
    func test_theCursorIsOnTheCaretAfterWrappingInABlockQuote() {
        editor.engineSelectedRange = NSRange(location: 19, length: 0)
        layOut()
        editor.wrapInBlockQuote()
        layOut()
        assertCursorSitsOnTheCaret("after wrapping in a block quote")
    }

    // MARK: - The host's own layout moves the caret

    /// **A host layout pass that changes the engine's GEOMETRY moves the caret, and must draw it.**
    ///
    /// The two cases above are document changes. This one is not: the document is settled and the
    /// caret has already been drawn correctly by the engine's own in-edit flush — then the host runs
    /// `update(size:insets:contentMargins:scrollIndicatorInsets:)`, which assigns the engine's frame
    /// and `textContainerInset`. That re-lays the text out and moves the caret with it, and nothing
    /// on the engine's side has a flush pending, so the cursor keeps the position the earlier flush
    /// gave it until UIKit's zero-delay timer fires a run-loop iteration later.
    ///
    /// Both hosts do exactly this on every `onChange`, which is every keystroke — the composer's
    /// field grows as the text wraps and the article editor re-runs its component update — so the
    /// user-visible shape is "typing does not move the caret", with the model perfectly correct
    /// underneath (a backspace still deletes the right character).
    ///
    /// **This was reported as a regression from the typing-coalescing fix, and it half was.** The
    /// per-keystroke presentation restyle that fix removed used to leave the engine's flush flag
    /// armed, so the host's next layout pass happened to spend it and redraw the caret. That was an
    /// accident of a restyle nobody wanted, not a mechanism — the FIRST keystroke was stale before
    /// the fix too, measured, because nothing had armed a second flush yet. So the rule is stated
    /// here on its own terms rather than by restoring the accident.
    ///
    /// The margins differ per pass on purpose: a host that re-runs `update` with identical geometry
    /// changes nothing and must NOT flush, which is the `Shift+Right` hazard the flush's own doc
    /// comment carries.
    func test_theCursorIsOnTheCaretAfterAHostLayoutThatMovesTheText() {
        let end = editor.engine.endOfDocument
        editor.engine.selectedTextRange = editor.engine.textRange(from: end, to: end)

        for keystroke in 1...4 {
            editor.engine.insertText("W")
            editor.engine.setNeedsLayout()
            editor.engine.layoutIfNeeded()
            assertCursorSitsOnTheCaret("keystroke \(keystroke), before the host lays out")

            // The host's own pass, with geometry that actually moves: the left margin alternates,
            // so every pass re-lays the text out at a different origin.
            _ = editor.update(size: CGSize(width: 320, height: 240),
                              insets: .zero,
                              contentMargins: UIEdgeInsets(top: 12, left: keystroke % 2 == 0 ? 0 : 4,
                                                           bottom: 12, right: 0),
                              scrollIndicatorInsets: nil)
            layOut()
            assertCursorSitsOnTheCaret("keystroke \(keystroke), after the host laid out")
        }
    }

    /// The other half of that rule, and the half no cursor position can show: a host pass that
    /// changes NOTHING must not flush. A needless flush leaves the caret in the right place, so it
    /// is invisible here and surfaces later as the Shift+Right anchor defect that
    /// `tgid_flushSelectionDisplayUpdate` carries the trace for — which is why this counts instead
    /// of measuring.
    func test_aHostLayoutThatMovesNothingDoesNotRedrawTheCaret() {
        let margins = UIEdgeInsets(top: 12, left: 4, bottom: 12, right: 0)
        _ = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                          contentMargins: margins, scrollIndicatorInsets: nil)
        layOut()

        let afterTheMove = editor.caretRedrawCount
        XCTAssertGreaterThan(afterTheMove, 0, "the geometry moved and nothing drew the caret")

        // Same numbers, twice more. Nothing is re-laid out, so nothing is owed a draw.
        for _ in 0..<2 {
            _ = editor.update(size: CGSize(width: 320, height: 240), insets: .zero,
                              contentMargins: margins, scrollIndicatorInsets: nil)
            layOut()
        }
        XCTAssertEqual(editor.caretRedrawCount, afterTheMove,
                       "an idle host pass flushed the selection display anyway")
    }
}
