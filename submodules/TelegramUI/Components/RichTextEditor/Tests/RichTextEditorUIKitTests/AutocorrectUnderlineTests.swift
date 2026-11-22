#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class AutocorrectUnderlineTests: XCTestCase {
    // "Wrl today": Wrl=0..3, today=4..9 (region-local UTF-16).
    private func makeCanvas(_ s: String = "Wrl today") -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: s)]))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func g(_ v: DocumentCanvasView, _ local: Int) -> Int { v.boxes[0].textStart + local }
    private func corrections(_ v: DocumentCanvasView) -> [NSRange] {
        (v.spellResults[BlockID("p")]?.ranges ?? []).filter { $0.style == .correction }.map { $0.range }
    }

    func test_detectAutocorrection_singleTokenDiffer_returnsOriginal() {
        let v = makeCanvas()
        XCTAssertEqual(v.detectAutocorrection(oldText: "Wrl", newText: "Well"), "Wrl")
    }
    func test_detectAutocorrection_identical_isNil() {
        let v = makeCanvas()
        XCTAssertNil(v.detectAutocorrection(oldText: "Well", newText: "Well"))
    }
    func test_detectAutocorrection_multiWord_isNil() {
        let v = makeCanvas()
        XCTAssertNil(v.detectAutocorrection(oldText: "two words", newText: "Well"))   // dictation-style, not autocorrect
        XCTAssertNil(v.detectAutocorrection(oldText: "Wrl", newText: "two words"))
    }
    func test_applyCorrectionFlag_flagsAndStashesOriginal_bypassingCaretWord() {
        let v = makeCanvas()
        v.setSelectionForTesting(anchor: g(v, 4), head: g(v, 4))   // caret at the END of "Well"-to-be — the caret-word case
        v.applyCorrectionFlag(global: NSRange(location: g(v, 0), length: 4), original: "Wrl")   // "Well" spans local 0..4
        XCTAssertEqual(corrections(v), [NSRange(location: 0, length: 4)], "correction flag present despite caret at word end")
        let alt = v.spellingAlternatives[BlockID("p")]?.first { $0.range == NSRange(location: 0, length: 4) }
        XCTAssertEqual(alt?.primary, "Wrl")
    }
    func test_applyCorrectionFlag_onlyOneActive() {
        let v = makeCanvas("Wrl teh")
        // "Wrl teh": Wrl=0..3, teh=4..7 (region-local UTF-16; verified char-by-char — "teh" starts at 4, not 5).
        v.applyCorrectionFlag(global: NSRange(location: g(v, 0), length: 4), original: "Wrl")   // corrects word 1
        v.applyCorrectionFlag(global: NSRange(location: g(v, 4), length: 3), original: "teh")   // corrects word 2 → supersedes
        XCTAssertEqual(corrections(v).count, 1, "at most one active correction")
        XCTAssertEqual(corrections(v).first, NSRange(location: 4, length: 3))
    }
    func test_replace_autocorrect_flagsCorrection_endToEnd() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        let range = DocumentTextRange(DocumentTextPosition(g(v, 0)), DocumentTextPosition(g(v, 3)))   // "Wrl"
        v.replace(range, withText: "Well")
        XCTAssertEqual(corrections(v), [NSRange(location: 0, length: 4)])
        XCTAssertEqual(v.spellingAlternatives[BlockID("p")]?.first?.primary, "Wrl")
    }
    func test_underlineDash_correctionIsSolid_othersDotted() {
        let v = makeCanvas()
        XCTAssertEqual(v.underlineDash(for: .correction), [], "correction is a solid stroke (no dash)")
        XCTAssertEqual(v.underlineDash(for: .spelling), [1.5, 2.5])
        XCTAssertEqual(v.underlineDash(for: .grammar), [1.5, 2.5])
    }
    func test_underlineWidth_correctionThicker() {
        let v = makeCanvas()
        XCTAssertEqual(v.underlineWidth(for: .correction), 2)
        XCTAssertEqual(v.underlineWidth(for: .spelling), 1)
    }
    func test_revertOnlyMenu_hasNoNoReplacementsRow() {
        let v = makeCanvas()
        _ = v.becomeFirstResponder()
        v.applyCorrectionFlag(global: NSRange(location: g(v, 0), length: 3), original: "Wrl")   // "Wrl" shown corrected (use short text)
        // Simulate a tap landing the pending menu on the correction: revert present, no guesses.
        v.pendingSpellingMenu = (range: NSRange(location: g(v, 0), length: 3), guesses: [], revertTo: "Wrl")
        let titles = v.spellingGuessMenuElements().compactMap { ($0 as? UIAction)?.title }
        XCTAssertEqual(titles, ["Revert to \u{201C}Wrl\u{201D}"], "a revert-only correction shows only the revert action")
        XCTAssertFalse(titles.contains("No Replacements Found"))
    }
    func test_caretLeavingRegion_clearsCorrection() {
        let v = makeCanvas("Wrl today")
        // `becomeFirstResponder()` needs a window to actually succeed (see SelectionDrivenSpellCheckTests);
        // this canvas is never hosted in one, so install native checking explicitly — same pattern used there.
        _ = v.becomeFirstResponder(); v.installNativeCheckingIfNeeded()
        v.applyCorrectionFlag(global: NSRange(location: g(v, 0), length: 4), original: "Wrl")
        v.setSelectionForTesting(anchor: g(v, 6), head: g(v, 6))   // caret still in the SAME region ("today")
        v.nativeCheckOnSelectionChange()
        XCTAssertEqual(corrections(v).count, 1, "same-region caret move keeps the correction")
        // Now a genuinely different region: add a second paragraph and move the caret into it.
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Wrl today")])),
                     .paragraph(ParagraphBlock(id: BlockID("q"), runs: [TextRun(text: "next line")]))], width: 320)
        v.layoutIfNeeded()
        v.applyCorrectionFlag(global: NSRange(location: v.boxes[0].textStart, length: 4), original: "Wrl")
        let q = v.boxes[1].textStart + 2
        v.setSelectionForTesting(anchor: q, head: q)
        v.nativeCheckOnSelectionChange()
        XCTAssertTrue(corrections(v).isEmpty, "moving the caret to a different region clears the correction")
    }
}
#endif
