#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// A composing IME (Tamil **Anjal**, and other Indic / Thai scripts) recomposes a syllable by issuing a
/// RANGED backspace / replace that targets a lone COMBINING MARK. To turn "க்" (consonant + virama) into
/// "க" the keyboard selects ONLY the virama (`setSelectedTextRange` over its one unit) and calls
/// `deleteBackward` — verified against the real iOS Tamil (Anjal) keyboard driving `DocumentCanvasView`.
///
/// The surrogate-pair guard in `applySelectionReplaceOutcome` must therefore snap only across UTF-16 surrogate
/// pairs (a single astral scalar), NOT across whole GRAPHEME CLUSTERS: a Tamil consonant+combining-mark
/// cluster is two independent scalars the IME edits individually, so expanding the selection to the whole
/// cluster erases the base consonant and the syllable can never be formed (the reported "can't type
/// Tamil" bug).
final class IndicCombiningMarkEditTests: XCTestCase {
    private func makeCanvas(text: String) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: text)]))], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        c.layoutIfNeeded()
        return c
    }
    private func firstParagraphText(_ c: DocumentCanvasView) -> String? {
        c.currentBlocks().compactMap { b -> ParagraphBlock? in
            if case let .paragraph(p) = b { return p }; return nil
        }.first?.text
    }

    // "க்" = க U+0B95 + virama U+0BCD — one grapheme cluster, but two independent Unicode scalars.

    func test_rangedDelete_ofLoneVirama_keepsBaseConsonant() {
        let c = makeCanvas(text: "\u{0B95}\u{0BCD}")     // க்
        let ts = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: ts + 1, head: ts + 2)   // select ONLY the virama (the Anjal recompose step)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "\u{0B95}",
                       "deleting the virama must leave க, not empty the paragraph")
    }

    func test_rangedReplace_viramaWithVowelSign_formsSyllable() {
        let c = makeCanvas(text: "\u{0B95}\u{0BCD}")     // க்
        let ts = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: ts + 1, head: ts + 2)   // select the virama
        c.insertText("\u{0BBF}")                         // replace it with the i-vowel sign ி → கி
        XCTAssertEqual(firstParagraphText(c), "\u{0B95}\u{0BBF}",
                       "க் with its virama replaced by the i-sign becomes கி")
    }

    // Regression guard: a genuine surrogate pair (one astral scalar in two UTF-16 units) must STILL be
    // protected — a ranged delete of one half removes the whole scalar (mirrors EmojiEditingTests).
    func test_rangedDelete_ofSurrogateHalf_stillRemovesWholeScalar() {
        let c = makeCanvas(text: "a\u{1F600}")           // "a😀" — a(0..1), 😀(1..3)
        let ts = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: ts + 2, head: ts + 3)   // select ONLY the low surrogate half
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a",
                       "a surrogate-pair half selection still deletes the whole emoji")
    }
}
#endif
