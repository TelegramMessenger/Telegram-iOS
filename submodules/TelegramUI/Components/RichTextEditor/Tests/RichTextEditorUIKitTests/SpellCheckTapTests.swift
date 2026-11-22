#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class SpellCheckTapTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // `UITextChecker`'s linguistic data loads lazily; the very FIRST call in a fresh test process can race
        // with other main-thread work (e.g. building a `DocumentCanvasView`'s TextKit layout) and return nil
        // guesses even for a real misspelling — a test-host cold-start quirk (real device usage stays warm via
        // the system keyboard's own continuous autocorrect / the native checking pass this feature already
        // drives). One throwaway call here, before any canvas exists, reliably avoids the race.
        _ = UITextChecker().guesses(forWordRange: NSRange(location: 0, length: 4), in: "helo", language: "en_US")
    }
    private func makeCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "hello wrold today")]))],
                    width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        v.applyNativeAnnotations(global: wordRange(v), style: .spelling)   // "wrold"
        return v
    }
    // "wrold" is at region-local UTF-16 offset 6..11; the paragraph's text starts at global `textStart`
    // (position 1 on the document's ProseMirror-style axis, not 0), so its GLOBAL range is textStart+6..+11.
    private func wordStart(_ v: DocumentCanvasView) -> Int { v.boxes[0].textStart + 6 }
    private func wordEnd(_ v: DocumentCanvasView) -> Int { v.boxes[0].textStart + 11 }
    private func wordRange(_ v: DocumentCanvasView) -> NSRange { NSRange(location: wordStart(v), length: 5) }
    /// A canvas point centered on the flagged word "wrold".
    private func pointOnFlaggedWord(_ v: DocumentCanvasView) -> CGPoint {
        let rects = v.selectionRects(globalFrom: wordStart(v), globalTo: wordEnd(v))
        return CGPoint(x: rects[0].midX, y: rects[0].midY)
    }

    func test_hitTest_returnsWord() {
        let v = makeCanvas()
        let hit = v.misspelledWord(atCanvasPoint: pointOnFlaggedWord(v))
        XCTAssertEqual(hit?.range, wordRange(v))
        // A `.spelling` flag carries no delivered alternatives — guesses come from the public UITextChecker
        // (guesses-only lookup; the checking pass itself stays native). Assert non-empty rather than a specific
        // word: UITextChecker's exact suggestion list/order is environment-dependent (see the N4 brief).
        XCTAssertFalse(hit?.guesses.isEmpty ?? true, "expected UITextChecker guesses for the misspelling \"wrold\"")
    }

    func test_hitTest_correctionWord_returnsStashedAlternativesCandidates() {
        let v = makeCanvas()
        // Re-flag the same word as `.correction` (overwrites the `.spelling` flag from `makeCanvas`) and stash
        // an alternatives entry for it — simulating what `nativeReplace` would have stored from a delivered
        // `NSTextAlternatives` (see `NativeTextCheckingClientTests` for the KVC-read path itself).
        v.applyNativeAnnotations(global: wordRange(v), style: .correction)
        let local = NSRange(location: wordRange(v).location - v.boxes[0].textStart, length: wordRange(v).length)
        v.spellingAlternatives[BlockID("p")] = [(range: local, candidates: ["world", "word"], primary: "world")]
        let hit = v.misspelledWord(atCanvasPoint: pointOnFlaggedWord(v))
        XCTAssertEqual(hit?.range, wordRange(v))
        XCTAssertEqual(hit?.guesses, ["world", "word"])
    }

    func test_hitTest_nilOffFlaggedWord() {
        let v = makeCanvas()
        let hit = v.misspelledWord(atCanvasPoint: CGPoint(x: 2, y: 8))   // on "hello", not flagged
        XCTAssertNil(hit)
    }

    func test_beginCorrection_selectsWordAndSetsPending() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))
        XCTAssertEqual(v.selFrom, wordStart(v)); XCTAssertEqual(v.selTo, wordEnd(v))   // word selected
        XCTAssertEqual(v.pendingSpellingMenu?.range, wordRange(v))
    }

    /// A tap directly on a red word shows the correction menu on the FIRST tap — even when the field wasn't
    /// first responder at entry (a draft loaded with the keyboard down). Previously the call site gated this
    /// behind `wasFirstResponder`, so the first (focusing) tap only placed the caret and the guesses never
    /// appeared ("highlight works, no suggestions on tap"). Driven through the real single-tap handler.
    func test_performSingleTap_onFlaggedWord_presentsOnFirstTapWithoutPriorFocus() {
        let v = makeCanvas()
        // Deliberately do NOT becomeFirstResponder first — this is the first, focusing tap.
        v.performSingleTapForTesting(at: pointOnFlaggedWord(v))
        XCTAssertEqual(v.pendingSpellingMenu?.range, wordRange(v),
                       "the first tap on a red word must show the correction menu, not just place the caret")
    }

    /// Tapping the SAME flagged word again while its menu is on-screen toggles the menu OFF (dismiss, no
    /// re-present) instead of the close-then-reopen flicker. Mirrors the caret-tap toggle semantics.
    func test_beginCorrection_sameWordWhileMenuShown_togglesOff() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))   // open
        XCTAssertNotNil(v.pendingSpellingMenu)
        v.editMenuVisible = true                                             // simulate the menu now on-screen
        let dismissesBefore = v.dismissEditMenuCountForTesting
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))   // tap the SAME word again
        XCTAssertNil(v.pendingSpellingMenu, "a same-word re-tap toggles the correction menu OFF")
        XCTAssertEqual(v.dismissEditMenuCountForTesting, dismissesBefore + 1,
                       "it dismisses without re-presenting (no flicker)")
    }

    /// After a toggle-OFF, a later tap on the same word REOPENS the menu (a clean present/dismiss cycle),
    /// provided it's outside the just-auto-dismissed suppression window.
    func test_beginCorrection_reopensAfterToggleOff() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))              // open
        v.editMenuVisible = true
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))              // toggle off
        XCTAssertNil(v.pendingSpellingMenu)
        v.editMenuVisible = false; v.lastMenuDismissTime = 0                  // menu closed, past the suppress window
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))   // tap again → reopen
        XCTAssertEqual(v.pendingSpellingMenu?.range, wordRange(v), "a later tap reopens the menu")
    }

    func test_applyReplacement_isOneUndoStep() {
        let v = makeCanvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        _ = v.becomeFirstResponder()
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))
        um.beginUndoGrouping(); v.applySpellingReplacement("world"); um.endUndoGrouping()
        XCTAssertEqual(currentText(v), "hello world today")
        XCTAssertNil(v.pendingSpellingMenu)                               // menu context cleared
        XCTAssertTrue(um.canUndo)
        um.undo()
        XCTAssertEqual(currentText(v), "hello wrold today")               // exactly one step reverts
    }

    private func currentText(_ v: DocumentCanvasView) -> String {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID("p") { return p.text } }
        return ""
    }

    /// Task 2 removed the post-edit `scheduleNativeChecking()` re-scan, and the corrected word's caret often
    /// lands back inside it (a same-length correction like "wrold"→"world" leaves the caret at the same global
    /// offset), so the selection-driven driver's `prev != now` guard no-ops and the stale flag lingers. A
    /// correction must explicitly drop it.
    func test_applyReplacement_clearsStaleFlag() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))
        v.applySpellingReplacement("world")   // same-length correction — caret lands back in the word
        let localRanges = Set((v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.range })
        XCTAssertFalse(localRanges.contains(NSRange(location: 6, length: 5)),
            "correcting a word must drop its stale spelling flag")
    }

    /// M9: the earlier style-agnostic clears in `applySpellingReplacement` wiped a `.grammar` flag overlapping
    /// the corrected word's range — the same bug class already fixed on the selection-driven path
    /// (`nativeCheckOnSelectionChange`). A tap-to-fix must clear only the `.spelling` flag it's correcting.
    func test_applyReplacement_preservesGrammarFlag() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        v.applyNativeAnnotations(global: NSRange(location: v.boxes[0].textStart, length: 17), style: .grammar)   // grammar over the whole sentence
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))   // select "wrold"
        v.applySpellingReplacement("world")                        // same-length correction
        let styles = (v.spellResults[BlockID("p")]?.ranges ?? []).map { $0.style }
        XCTAssertTrue(styles.contains(.grammar), "tap-to-fix must not wipe an overlapping grammar flag")
        XCTAssertFalse(styles.contains(.spelling), "the corrected word's spelling flag is cleared")
    }

    // MARK: - N5: autocorrect-revert

    /// Stands in for the private, non-publicly-constructible `NSTextAlternatives` — mirrors
    /// `NativeTextCheckingClientTests.FakeTextAlternatives`.
    private final class FakeTextAlternatives: NSObject {
        @objc let alternativeStrings: [String]
        @objc let primaryString: String
        init(alternativeStrings: [String], primaryString: String) {
            self.alternativeStrings = alternativeStrings
            self.primaryString = primaryString
        }
    }

    /// Flags "wrold" as a `.correction` with a stashed original, via the REAL controller-facing path
    /// (`nativeReplace`) — exactly like `NativeTextCheckingClientTests.test_nativeReplace_correctionStashesAlternativesViaKVC`.
    /// A `.correction` flag was never observed firing live in the test host (see the N4/N5 briefs), so this is
    /// the synthetic path N5 tests against rather than driving a real autocorrection.
    private func stashCorrection(_ v: DocumentCanvasView, primary: String, candidates: [String]) {
        let range = v.nativeTextRange(forGlobalLocation: wordStart(v), length: 5)!
        let alt = FakeTextAlternatives(alternativeStrings: candidates, primaryString: primary)
        let s = NSAttributedString(string: "wrold", attributes: [
            DocumentCanvasView.displayStyleKey: 0,
            DocumentCanvasView.alternativesKey: alt,
        ])
        v.nativeReplace(range, withAnnotatedString: s, relativeReplacementRange: NSRange(location: 0, length: 5))
    }

    func test_beginCorrection_correctionFlag_setsRevertToFromStashedPrimary() {
        let v = makeCanvas()   // starts with a plain `.spelling` flag on "wrold"
        stashCorrection(v, primary: "world", candidates: ["world", "word"])
        _ = v.becomeFirstResponder()
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))
        XCTAssertEqual(v.pendingSpellingMenu?.revertTo, "world")
    }

    func test_beginCorrection_spellingFlag_hasNoRevertTo() {
        let v = makeCanvas()   // `.spelling`, not `.correction` — no stashed original
        _ = v.becomeFirstResponder()
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedWord(v)))
        XCTAssertNil(v.pendingSpellingMenu?.revertTo)
    }

    func test_spellingGuessMenuElements_correctionWithRevert_prependsRevertAction() {
        let v = makeCanvas()
        stashCorrection(v, primary: "world", candidates: ["world", "word"])
        _ = v.becomeFirstResponder()
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))
        let elements = v.spellingGuessMenuElements()
        XCTAssertEqual(elements.count, 3, "revert action + 2 stashed candidates")
        guard let first = elements.first as? UIAction else { return XCTFail("expected a UIAction") }
        XCTAssertEqual(first.title, "Revert to \u{201C}world\u{201D}")
        XCTAssertEqual(elements.dropFirst().compactMap { ($0 as? UIAction)?.title }, ["world", "word"])
    }

    func test_applyRevert_replacesWithOriginalAsOneUndoStep() {
        let v = makeCanvas()
        stashCorrection(v, primary: "world", candidates: ["world", "word"])
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        _ = v.becomeFirstResponder()
        _ = v.beginSpellingCorrection(at: pointOnFlaggedWord(v))
        guard let revertTo = v.pendingSpellingMenu?.revertTo else { return XCTFail("expected a revert target") }
        um.beginUndoGrouping(); v.applySpellingReplacement(revertTo); um.endUndoGrouping()
        XCTAssertEqual(currentText(v), "hello world today")
        XCTAssertNil(v.pendingSpellingMenu)                               // menu context cleared
        XCTAssertTrue(um.canUndo)
        um.undo()
        XCTAssertEqual(currentText(v), "hello wrold today")               // exactly one step reverts
    }

    // MARK: - I2: a table structural (row/column) selection must not survive a spell-tap

    private func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    private func row(_ id: String, _ texts: [String], header: Bool = false) -> Row {
        Row(id: BlockID(id), isHeader: header, cells: texts.enumerated().map { cell(id + "\($0.offset)", $0.element) })
    }
    /// A 3-row × 2-col table (r0 header) whose row-1/col-0 cell contains the misspelled word "wrold".
    private func makeTableCanvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([
            .table(TableBlock(id: BlockID("t"),
                columns: [ColumnSpec(width: 140), ColumnSpec(width: 140)],
                rows: [row("r0", ["A", "B"], header: true),
                       row("r1", ["wrold", "fine"]),
                       row("r2", ["g", "h"])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let box = v.boxes.first { $0 is TableBlockBox } as! TableBlockBox
        let start = box.cellTextStart(row: 1, column: 0)!
        v.applyNativeAnnotations(global: NSRange(location: start, length: 5), style: .spelling)   // "wrold"
        return v
    }
    private func tableBox(_ v: DocumentCanvasView) -> TableBlockBox? { v.boxes.first { $0 is TableBlockBox } as? TableBlockBox }
    /// A canvas point centered on the flagged word "wrold" in cell (row 1, col 0).
    private func pointOnFlaggedTableWord(_ v: DocumentCanvasView) -> CGPoint {
        let hit = v.spellingWordRanges().first { v.spellCheckableRef($0.region.ref) == BlockID("r10p") }!
        let rects = v.selectionRects(globalFrom: hit.global.location, globalTo: hit.global.location + hit.global.length)
        return CGPoint(x: rects[0].midX, y: rects[0].midY)
    }

    func test_beginCorrection_onFlaggedTableCell_clearsActiveStructuralSelection() {
        let v = makeTableCanvas()
        _ = v.becomeFirstResponder()
        // Put the caret in the table so `activeTable()` resolves, then structurally select a row — the same
        // way a real row-handle tap would (see `CanvasTableBackspaceDeleteTests.putCaretInTable`).
        v.setSelectionForTesting(anchor: tableBox(v)!.cellTextStart(row: 1, column: 0)!, head: tableBox(v)!.cellTextStart(row: 1, column: 0)!)
        v.selectTableRows(1...1)
        XCTAssertNotNil(v.tableSelection, "sanity: the structural selection is active before the tap")
        XCTAssertTrue(v.beginSpellingCorrection(at: pointOnFlaggedTableWord(v)))
        XCTAssertNil(v.tableSelection, "the stale structural selection must not survive a spell-tap")
        XCTAssertNotNil(v.pendingSpellingMenu, "the flagged word was selected for correction")
    }
}
#endif
