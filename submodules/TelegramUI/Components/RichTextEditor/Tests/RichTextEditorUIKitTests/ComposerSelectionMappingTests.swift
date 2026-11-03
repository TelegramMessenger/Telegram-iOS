#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// The chat composer addresses text by a flat UTF-16 offset over its paragraphs joined by "\n" (the
/// `ComposerDocumentBridge` representation). `DocumentCanvasView.composerSelectedRange` maps that flat
/// offset to/from the editor's global selection. Without it the host's `selectedRange` is a stub (caret
/// never tracked) — the visible cause of the chat-composer emoji bugs (caret doesn't advance; a re-insert
/// after a delete leaves a stray code unit / "service character").
final class ComposerSelectionMappingTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        return c
    }
    private func makeFormulaCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.mapper.formulaRenderer = { context in
            let size = CGSize(width: max(12.0, CGFloat((context.latex as NSString).length) * 4.0), height: 14.0)
            let image = UIGraphicsImageRenderer(size: size).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: size, ascent: 10.0, descent: 4.0)
        }
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        return c
    }
    private func para(_ s: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(), runs: s.isEmpty ? [] : [TextRun(text: s)]))
    }

    func test_get_singleParagraph_collapsedCaret() {
        let c = makeCanvas([para("abc")])
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 2, head: base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 2, length: 0))
    }

    func test_get_multiParagraph_secondParagraphOffsetsAcrossNewline() {
        let c = makeCanvas([para("ab"), para("cd")])   // flat "ab\ncd"
        let p2 = c.boxes[1].textStart
        c.setSelectionForTesting(anchor: p2, head: p2)
        XCTAssertEqual(c.composerSelectedRange.location, 3, "start of paragraph 2 is flat offset 3 (after the \\n)")
        c.setSelectionForTesting(anchor: p2 + 2, head: p2 + 2)
        XCTAssertEqual(c.composerSelectedRange.location, 5, "end of paragraph 2 is flat offset 5")
    }

    func test_get_surrogatePairEmoji_offsetCountsUTF16Units() {
        let c = makeCanvas([para("a\u{1F600}")])   // "a😀" — emoji is 2 UTF-16 units, flat length 3
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 3, head: base + 3)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 3, length: 0), "caret after the emoji is flat offset 3")
    }

    func test_set_movesCaret_intoSecondParagraph_roundTrips() {
        let c = makeCanvas([para("ab"), para("cd")])
        c.composerSelectedRange = NSRange(location: 4, length: 0)   // 2nd char of paragraph 2
        XCTAssertEqual(c.head, c.boxes[1].textStart + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 4, length: 0))
    }

    func test_set_selectionSpan() {
        let c = makeCanvas([para("abcd")])
        c.composerSelectedRange = NSRange(location: 1, length: 2)
        XCTAssertEqual(c.selFrom, c.boxes[0].textStart + 1)
        XCTAssertEqual(c.selTo, c.boxes[0].textStart + 3)
    }

    func test_set_paragraphBoundary_endVsStart() {
        let c = makeCanvas([para("ab"), para("cd")])   // flat "ab\ncd"
        c.composerSelectedRange = NSRange(location: 2, length: 0)   // end of paragraph 1 (before the \n)
        XCTAssertEqual(c.head, c.boxes[0].textStart + 2)
        c.composerSelectedRange = NSRange(location: 3, length: 0)   // start of paragraph 2 (after the \n)
        XCTAssertEqual(c.head, c.boxes[1].textStart)
    }

    func test_set_caretAfterEmoji_landsPastBothUnits() {
        let c = makeCanvas([para("a\u{1F600}")])
        c.composerSelectedRange = NSRange(location: 3, length: 0)
        XCTAssertEqual(c.head, c.boxes[0].textStart + 3, "flat offset 3 maps past the whole 2-unit emoji")
    }

    /// A one-`U+FFFC` custom-emoji run carrying `alt` on its `EmojiRef.altText` (the chat alt-string).
    private func emojiRun(_ alt: String, id: String = "5217587809472226220") -> TextRun {
        var a = CharacterAttributes.plain
        a.emoji = EmojiRef(id: id, instanceID: BlockID.generate().rawValue, altText: alt)
        return TextRun(text: "\u{FFFC}", attributes: a)
    }
    /// A paragraph `pre` + <custom emoji(alt)> + `post`.
    private func emojiPara(_ pre: String, _ alt: String, _ post: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(),
                                  runs: [TextRun(text: pre), emojiRun(alt), TextRun(text: post)]))
    }
    private func formulaRun(_ latex: String) -> TextRun {
        var a = CharacterAttributes.plain
        a.formula = latex
        return TextRun(text: "\u{FFFC}", attributes: a)
    }
    private func formulaPara(_ pre: String, _ latex: String, _ post: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(),
                                  runs: [TextRun(text: pre), formulaRun(latex), TextRun(text: post)]))
    }

    func test_get_customEmoji_countsAltStringLength() {
        let c = makeCanvas([emojiPara("a", "\u{1F600}", "b")])   // "a" + emoji(alt "😀", 2 UTF-16) + "b"
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 1, head: base + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 1, length: 0), "before emoji = flat 1")
        c.setSelectionForTesting(anchor: base + 2, head: base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 3, length: 0), "after emoji = flat 3, not 2")
        c.setSelectionForTesting(anchor: base + 3, head: base + 3)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 4, length: 0), "end = flat 4")
    }

    func test_set_customEmoji_roundTrips() {
        let c = makeCanvas([emojiPara("a", "\u{1F600}", "b")])
        let base = c.boxes[0].textStart
        c.composerSelectedRange = NSRange(location: 3, length: 0)   // after the emoji
        XCTAssertEqual(c.head, base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 3, length: 0))
        c.composerSelectedRange = NSRange(location: 1, length: 0)   // before the emoji
        XCTAssertEqual(c.head, base + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 1, length: 0))
    }

    func test_customEmoji_multipleInParagraph_cumulativeExpansion() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID.generate(),
            runs: [emojiRun("\u{1F600}"), TextRun(text: "x"), emojiRun("\u{1F601}")]))])   // 😀 x 😁
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 3, head: base + 3)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 5, length: 0))
        c.composerSelectedRange = NSRange(location: 5, length: 0)
        XCTAssertEqual(c.head, base + 3)
    }

    func test_customEmoji_nilAltText_staysLengthOne() {
        var a = CharacterAttributes.plain
        a.emoji = EmojiRef(id: "777", instanceID: BlockID.generate().rawValue, altText: nil)
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID.generate(),
            runs: [TextRun(text: "a"), TextRun(text: "\u{FFFC}", attributes: a), TextRun(text: "b")]))])
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 2, head: base + 2)   // after the emoji
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 2, length: 0), "no altText -> emoji counts as 1")
    }

    func test_customEmoji_adjacent_roundTrips() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID.generate(),
            runs: [emojiRun("\u{1F600}"), emojiRun("\u{1F601}")]))])   // 😀😁 — two adjacent custom emoji, no text between
        let base = c.boxes[0].textStart
        // global: emoji1(base+0) emoji2(base+1); between = base+1, after both = base+2
        // flat: emoji1(2) emoji2(2); between = 2, after both = 4
        c.setSelectionForTesting(anchor: base + 1, head: base + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 2, length: 0))
        c.setSelectionForTesting(anchor: base + 2, head: base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 4, length: 0))
        c.composerSelectedRange = NSRange(location: 2, length: 0)
        XCTAssertEqual(c.head, base + 1)
        c.composerSelectedRange = NSRange(location: 4, length: 0)
        XCTAssertEqual(c.head, base + 2)
    }

    func test_customEmoji_selectionSpan_lengthInAltUnits() {
        let c = makeCanvas([emojiPara("a", "\u{1F600}", "b")])   // "a😀b"
        let base = c.boxes[0].textStart
        // whole "a😀b": global base+0..base+3 -> flat 0..4 -> length 4
        c.setSelectionForTesting(anchor: base + 0, head: base + 3)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 0, length: 4))
        // just the emoji: global base+1..base+2 -> flat 1..3 -> length 2
        c.setSelectionForTesting(anchor: base + 1, head: base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 1, length: 2))
    }

    func test_customEmoji_inSecondParagraph_offsetsAcrossNewlineAndExpands() {
        let c = makeCanvas([para("ab"), emojiPara("c", "\u{1F600}", "d")])   // "ab\n" + "c😀d"
        let p2 = c.boxes[1].textStart
        // p2 flat start = 3 (a,b,\n). caret after the emoji in p2: global p2+2 (c + U+FFFC), flat = 3 + 1(c) + 2(emoji) = 6
        c.setSelectionForTesting(anchor: p2 + 2, head: p2 + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 6, length: 0))
        c.composerSelectedRange = NSRange(location: 6, length: 0)
        XCTAssertEqual(c.head, p2 + 2)
    }

    func test_customEmoji_setMidAltString_snapsToEmojiBoundary() {
        let c = makeCanvas([emojiPara("a", "\u{1F600}", "b")])   // "a😀b": emoji global at base+1, flat span [1,3)
        let base = c.boxes[0].textStart
        // flat 2 is mid-emoji (between the surrogate halves of "😀"); the setter must snap to a U+FFFC boundary
        // (before/after the emoji), never mid-atom. The global axis has no position inside the 1-unit U+FFFC.
        c.composerSelectedRange = NSRange(location: 2, length: 0)
        XCTAssertTrue(c.head == base + 1 || c.head == base + 2,
                      "mid-alt-string flat offset must snap to before/after the emoji, got offset \(c.head - base)")
    }

    func test_get_formula_countsLatexLength() {
        let c = makeFormulaCanvas([formulaPara("a", "x^2", "b")])
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 1, head: base + 1)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 1, length: 0), "before formula = flat 1")
        c.setSelectionForTesting(anchor: base + 2, head: base + 2)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 4, length: 0), "after formula = flat 4")
        c.setSelectionForTesting(anchor: base + 3, head: base + 3)
        XCTAssertEqual(c.composerSelectedRange, NSRange(location: 5, length: 0), "end = flat 5")
    }

    func test_formula_setMidLatexString_snapsToFormulaBoundary() {
        let c = makeFormulaCanvas([formulaPara("a", "x^2", "b")])
        let base = c.boxes[0].textStart
        c.composerSelectedRange = NSRange(location: 2, length: 0)
        XCTAssertTrue(c.head == base + 1 || c.head == base + 2,
                      "mid-LaTeX flat offset must snap to before/after the formula atom, got offset \(c.head - base)")
    }
}
#endif
