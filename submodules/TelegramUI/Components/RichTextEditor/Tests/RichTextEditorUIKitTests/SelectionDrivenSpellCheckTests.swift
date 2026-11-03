#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SelectionDrivenSpellCheckTests: XCTestCase {
    // "hello wrold today": hello=0..5, wrold=6..11, today=12..17 (region-local UTF-16).
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello wrold today")]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func g(_ v: DocumentCanvasView, _ local: Int) -> Int { v.boxes[0].textStart + local }   // local→global
    private func wrold(_ v: DocumentCanvasView) -> NSRange { NSRange(location: g(v, 6), length: 5) }
    private func today(_ v: DocumentCanvasView) -> NSRange { NSRange(location: g(v, 12), length: 5) }

    func test_targets_sameWord_returnsNil() {
        let v = makeCanvas()
        let t = v.spellCheckTargets(fromCaret: g(v, 7), toCaret: g(v, 9))   // both inside "wrold"
        XCTAssertNil(t.check); XCTAssertNil(t.clear)
    }

    func test_targets_leavingWord_checksLeftClearsEntered() {
        let v = makeCanvas()
        let t = v.spellCheckTargets(fromCaret: g(v, 8), toCaret: g(v, 14))   // "wrold" → "today"
        XCTAssertEqual(t.check, wrold(v))   // re-check the word just left
        XCTAssertEqual(t.clear, today(v))   // clear the word now under the caret
    }

    private func spin(_ s: TimeInterval) {
        let e = Date().addingTimeInterval(s)
        while Date() < e { RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02)) }
    }
    override func setUp() {   // warm UITextChecker to avoid the cold-start race (see SpellCheckTapTests)
        super.setUp()
        _ = UITextChecker().guesses(forWordRange: NSRange(location: 0, length: 4), in: "helo", language: "en_US")
    }

    func test_movingCaretOutOfMisspelledWord_flagsIt() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()
        XCTAssertNotNil(v.nativeChecker, "native controller unavailable")
        spin(2.5)                                   // async textChecker load
        v.setCaret(global: g(v, 8))                 // caret INTO "wrold"
        v.setCaret(global: g(v, 14))                // caret OUT to "today" → checks "wrold"
        spin(1.0)
        let ranges = Set((v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.range })
        XCTAssertTrue(ranges.contains(NSRange(location: 6, length: 5)), "leaving 'wrold' must flag it")
    }

    func test_noCaretTraversal_leavesDocumentUnflagged() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()
        spin(2.5)                                   // never move the caret through a word
        XCTAssertNil(v.spellResults[BlockID("p")], "untraversed text must not be flagged (draft/paste parity)")
    }

    func test_caretIntoFlaggedWord_clearsItsFlag() {
        let v = makeCanvas()
        // `becomeFirstResponder()` needs a window to actually succeed (see SelectionInteractionTests);
        // this canvas is never hosted in one, so install explicitly — same pattern as the two tests above.
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()
        v.applyNativeAnnotations(global: NSRange(location: g(v, 6), length: 5), style: .spelling)   // pre-flag "wrold"
        v.lastCheckedCaret = g(v, 14)               // pretend caret was in "today"
        v.setCaret(global: g(v, 8))                 // move INTO "wrold" → clears its flag
        let ranges = Set((v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.range })
        XCTAssertFalse(ranges.contains(NSRange(location: 6, length: 5)), "caret entering a word clears its flag")
    }

    func test_sentenceGlobalRange_enclosesPosition() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "One thing. Two things.")]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let start = v.boxes[0].textStart
        // "One thing. " is sentence 0 (local 0..11); a position inside it resolves to that sentence.
        let r = v.sentenceGlobalRange(atGlobal: start + 4)
        XCTAssertEqual(r?.location, start + 0)
        XCTAssertEqual(r?.length, 11)
    }

    func test_clearOnlyStyle_leavesOtherStyles() {
        let v = makeCanvas()
        let word = NSRange(location: g(v, 6), length: 5)
        v.applyNativeAnnotations(global: word, style: .spelling)
        v.applyNativeAnnotations(global: NSRange(location: g(v, 0), length: 5), style: .grammar)
        v.clearNativeAnnotations(global: NSRange(location: g(v, 0), length: 11), onlyStyle: .grammar)
        let styles = (v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.style }
        XCTAssertTrue(styles.contains(.spelling), "spelling flag must survive a grammar-only clear")
        XCTAssertFalse(styles.contains(.grammar), "grammar flag in range must be cleared")
    }

    func test_wordLevelClear_preservesGrammarFlag() {
        let v = makeCanvas()               // "hello wrold today" — one sentence
        // `becomeFirstResponder()` needs a window to actually succeed (see SelectionInteractionTests);
        // this canvas is never hosted in one, so install explicitly — same pattern as the tests above.
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()   // installs the native checker so the driver actually runs
        v.applyNativeAnnotations(global: NSRange(location: g(v, 0), length: 17), style: .grammar)   // grammar over the whole sentence
        v.lastCheckedCaret = g(v, 2)       // caret was in "hello"
        v.setCaret(global: g(v, 13))       // move to "today" — a word move WITHIN the sentence
        let styles = (v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.style }
        XCTAssertTrue(styles.contains(.grammar),
            "a word-level spelling clear must not wipe a grammar flag in the same sentence")
    }

    func test_crossingSentenceBoundary_clearsGrammarOnEnteredSentence() {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "One thing. Two things.")]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()
        let start = v.boxes[0].textStart
        v.applyNativeAnnotations(global: NSRange(location: start + 11, length: 11), style: .grammar)   // grammar on sentence 2 ("Two things.")
        v.lastCheckedCaret = start + 4          // caret in sentence 1 ("One thing.")
        v.setCaret(global: start + 15)          // cross into sentence 2
        let grammar = (v.spellResults[BlockID("p")]?.ranges ?? []).filter { $0.style == .grammar }
        XCTAssertTrue(grammar.isEmpty,
            "crossing into a new sentence clears its grammar markers before the re-check")
    }
}
#endif
