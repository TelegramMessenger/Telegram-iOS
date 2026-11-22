#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EmojiEditingTests: XCTestCase {
    private func makeCanvas(text: String) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: text)]))],
                    width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        c.layoutIfNeeded()
        return c
    }

    /// The first emoji run in document order, or nil.
    private func firstEmojiRun(_ c: DocumentCanvasView) -> TextRun? {
        c.currentBlocks().compactMap { block -> [TextRun]? in
            if case let .paragraph(p) = block { return p.runs }; return nil
        }.flatMap { $0 }.first { $0.attributes.emoji != nil }
    }

    private func installFormulaRenderer(_ c: DocumentCanvasView) {
        c.mapper.formulaRenderer = { context in
            let size = CGSize(width: max(12.0, CGFloat((context.latex as NSString).length) * 4.0), height: 14.0)
            let image = UIGraphicsImageRenderer(size: size).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: size, ascent: 10.0, descent: 4.0)
        }
    }

    private func firstFormulaRun(_ c: DocumentCanvasView) -> TextRun? {
        c.currentBlocks().compactMap { block -> [TextRun]? in
            if case let .paragraph(p) = block { return p.runs }; return nil
        }.flatMap { $0 }.first { $0.attributes.formula != nil }
    }

    private func firstParagraphRuns(_ c: DocumentCanvasView) -> [TextRun] {
        c.currentBlocks().compactMap { block -> [TextRun]? in
            if case let .paragraph(p) = block { return p.runs }; return nil
        }.first ?? []
    }

    private func firstFormulaRect(_ c: DocumentCanvasView) -> CGRect? {
        for region in c.allLeafRegions() {
            let attr = region.layout.attributedString
            var result: CGRect?
            attr.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attr.length), options: []) { value, range, stop in
                guard value is FormulaTextAttachment,
                      let box = region.layout.attachmentBox(at: range.location)
                else {
                    return
                }
                result = box.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
                stop.pointee = true
            }
            if let result {
                return result
            }
        }
        return nil
    }

    func test_insertEmoji_insertsOneCharRun_caretAfter() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)   // between a and b
        c.insertEmoji(id: "star", altText: ":star:")
        let run = firstEmojiRun(c)
        XCTAssertEqual(run?.text, "\u{FFFC}")
        XCTAssertEqual(run?.attributes.emoji?.id, "star")
        XCTAssertEqual(c.head, c.boxes[0].textStart + 2, "caret lands after the inserted emoji")
    }

    func test_insertEmoji_generatesUniqueInstanceIDs() {
        let c = makeCanvas(text: "")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart, head: c.boxes[0].textStart)
        c.insertEmoji(id: "star", altText: nil)
        c.insertEmoji(id: "star", altText: nil)
        let ids = c.currentBlocks().compactMap { b -> [TextRun]? in
            if case let .paragraph(p) = b { return p.runs }; return nil
        }.flatMap { $0 }.compactMap { $0.attributes.emoji?.instanceID }
        XCTAssertEqual(Set(ids).count, 2, "each occurrence has a distinct instanceID")
    }

    func test_insertEmoji_isOneUndoStep() {
        let c = makeCanvas(text: "ab")
        let um = UndoManager(); um.groupsByEvent = false; c.undoManagerOverride = um
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        um.beginUndoGrouping(); c.insertEmoji(id: "star", altText: nil); um.endUndoGrouping()
        XCTAssertNotNil(firstEmojiRun(c))
        um.undo()
        XCTAssertNil(firstEmojiRun(c), "one undo removes the emoji")
    }

    func test_deleteBackward_removesEmoji() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: nil)   // caret now after emoji
        c.deleteBackward()
        XCTAssertNil(firstEmojiRun(c))
    }

    func test_insertFormula_insertsOneCharAtom_caretAfter() {
        let c = makeCanvas(text: "ab")
        installFormulaRenderer(c)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertFormula(latex: "x^2")
        let run = firstFormulaRun(c)
        XCTAssertEqual(run?.text, "\u{FFFC}")
        XCTAssertEqual(run?.attributes.formula, "x^2")
        XCTAssertEqual(c.head, c.boxes[0].textStart + 2, "caret lands after the inserted formula atom")
    }

    func test_textIn_substitutesFormulaLatex() {
        let c = makeCanvas(text: "ab")
        installFormulaRenderer(c)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertFormula(latex: "x^2")
        let range = DocumentTextRange(DocumentTextPosition(0),
                                      DocumentTextPosition(c.documentSizeValue))
        XCTAssertEqual(c.text(in: range), "ax^2b")
    }

    func test_deleteBackward_removesFormulaAtom() {
        let c = makeCanvas(text: "ab")
        installFormulaRenderer(c)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertFormula(latex: "x^2")
        c.deleteBackward()
        XCTAssertNil(firstFormulaRun(c))
    }

    func test_typingAfterRenderedFormulaDoesNotInheritFormula() {
        let c = makeCanvas(text: "")
        installFormulaRenderer(c)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart, head: c.boxes[0].textStart)

        c.insertFormula(latex: "x^2")
        c.insertText(" after")

        let runs = firstParagraphRuns(c)
        XCTAssertEqual(runs.compactMap(\.attributes.formula), ["x^2"])
        XCTAssertEqual(runs.last?.text, " after")
        XCTAssertNil(runs.last?.attributes.formula, "plain text after a rendered formula must stay plain")
    }

    func test_typingAfterRawLatexFormulaDoesNotInheritFormula() {
        let c = makeCanvas(text: "")   // no renderer: the formula is visible as raw LaTeX
        c.setSelectionForTesting(anchor: c.boxes[0].textStart, head: c.boxes[0].textStart)

        c.insertFormula(latex: "x^2")
        c.insertText(" after")

        let runs = firstParagraphRuns(c)
        XCTAssertEqual(runs.compactMap(\.attributes.formula), ["x^2"])
        XCTAssertEqual(runs.last?.text, " after")
        XCTAssertNil(runs.last?.attributes.formula, "plain text after raw-LaTeX fallback must stay plain")
    }

    func test_typingBeforeFormulaAtLineStartDoesNotInheritFormula() {
        let c = makeCanvas(text: "")
        installFormulaRenderer(c)
        let lineStart = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: lineStart, head: lineStart)
        c.insertFormula(latex: "x^2")

        c.setSelectionForTesting(anchor: lineStart, head: lineStart)
        c.insertText("before ")

        let runs = firstParagraphRuns(c)
        XCTAssertEqual(runs.first?.text, "before ")
        XCTAssertNil(runs.first?.attributes.formula, "plain text before a leading formula must stay plain")
        XCTAssertEqual(runs.compactMap(\.attributes.formula), ["x^2"])
    }

    func test_tapFormula_requestsEditAndReplacesAtom() throws {
        let c = makeCanvas(text: "ab")
        installFormulaRenderer(c)
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertFormula(latex: "x^2")
        c.layoutIfNeeded()

        var requestedLatex: String?
        c.formulaEditRequested = { latex, completion in
            requestedLatex = latex
            completion("y^2")
        }

        let rect = try XCTUnwrap(firstFormulaRect(c))
        c.performSingleTapForTesting(at: CGPoint(x: rect.midX, y: rect.midY))

        XCTAssertEqual(requestedLatex, "x^2")
        let run = try XCTUnwrap(firstFormulaRun(c))
        XCTAssertEqual(run.text, "\u{FFFC}")
        XCTAssertEqual(run.attributes.formula, "y^2")
    }

    // MARK: - Backspace deletes a whole grapheme cluster (standard Unicode emoji)

    /// The text of the first paragraph block.
    private func firstParagraphText(_ c: DocumentCanvasView) -> String? {
        c.currentBlocks().compactMap { b -> ParagraphBlock? in
            if case let .paragraph(p) = b { return p }; return nil
        }.first?.text
    }

    private func caretToEnd(_ c: DocumentCanvasView) {
        let end = c.boxes[0].textStart + c.boxes[0].textLength
        c.setSelectionForTesting(anchor: end, head: end)
    }

    func test_deleteBackward_removesWholeSurrogatePairEmoji() {
        let c = makeCanvas(text: "a\u{1F600}")   // "a😀" — 😀 is 2 UTF-16 units
        caretToEnd(c)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a", "the whole emoji is removed, not one surrogate half")
    }

    func test_deleteBackward_removesWholeZWJSequence() {
        let c = makeCanvas(text: "a\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}")  // "a👨‍👩‍👧‍👦"
        caretToEnd(c)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a", "the whole ZWJ family emoji is removed as one unit")
    }

    func test_deleteBackward_removesWholeSkinToneEmoji() {
        let c = makeCanvas(text: "a\u{1F44D}\u{1F3FD}")   // "a👍🏽" — thumbs-up + skin-tone modifier
        caretToEnd(c)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a", "the base emoji and its skin-tone modifier are removed together")
    }

    func test_deleteBackward_removesWholeFlagEmoji() {
        let c = makeCanvas(text: "a\u{1F1FA}\u{1F1F8}")   // "a🇺🇸" — regional indicator pair
        caretToEnd(c)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a", "a regional-indicator flag is removed as one unit")
    }

    func test_deleteBackward_partialGraphemeSelection_removesWholeEmoji() {
        // The OS can request a backspace as a RANGE delete covering only one half of a surrogate pair
        // (observed: selFrom/selTo split the emoji). Deleting it verbatim leaves a stray code unit.
        let c = makeCanvas(text: "a\u{1F600}")   // "a😀" — a(0..1), 😀(1..3)
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 2, head: base + 3)   // selection of ONLY the low surrogate half
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "a", "a partial-grapheme selection delete removes the whole emoji, not half")
    }

    func test_insertText_overPartialGraphemeSelection_replacesWholeEmoji() {
        let c = makeCanvas(text: "a\u{1F600}b")   // "a😀b"
        let base = c.boxes[0].textStart
        c.setSelectionForTesting(anchor: base + 2, head: base + 3)   // partial emoji
        c.insertText("X")
        XCTAssertEqual(firstParagraphText(c), "aXb", "typing over a partial-grapheme selection replaces the whole emoji")
    }

    func test_deleteBackward_plainASCII_removesOneChar() {
        let c = makeCanvas(text: "abc")
        caretToEnd(c)
        c.deleteBackward()
        XCTAssertEqual(firstParagraphText(c), "ab", "a plain character still deletes one at a time")
    }

    func test_insertEmoji_atImageGap_isNoOp() {
        let c = DocumentCanvasView()
        c.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "ab")])),
            .media(MediaBlock(id: BlockID("i1"), mediaID: "a", naturalSize: Size2D(width: 10, height: 10))),
        ], width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        guard let gap = c.boxes.first(where: { $0 is MediaBlockBox })?.nodeStart else { return XCTFail("no image") }
        c.setSelectionForTesting(anchor: gap, head: gap)   // the image gap (region-less but renderable)
        let before = c.currentBlocks().count
        c.insertEmoji(id: "star", altText: nil)
        XCTAssertNil(firstEmojiRun(c), "an emoji at an image gap is a no-op (no inline place to land)")
        XCTAssertEqual(c.currentBlocks().count, before, "no spurious block inserted")
    }

    func test_insertEmoji_atDocumentStart_landsInFirstParagraph() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: 0, head: 0)   // document-start structural slot (before the first paragraph's text)
        c.insertEmoji(id: "star", altText: nil)
        XCTAssertEqual(firstEmojiRun(c)?.attributes.emoji?.id, "star")
        let para = c.currentBlocks().compactMap { b -> ParagraphBlock? in
            if case let .paragraph(p) = b { return p }; return nil
        }.first
        XCTAssertEqual(para?.text, "\u{FFFC}ab", "emoji lands at the start of the first paragraph")
    }

    func test_insertEmoji_replacesNonEmptySelection() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart, head: c.boxes[0].textStart + 2)   // select "ab"
        c.insertEmoji(id: "star", altText: nil)
        let runs = c.currentBlocks().compactMap { b -> [TextRun]? in
            if case let .paragraph(p) = b { return p.runs }; return nil
        }.flatMap { $0 }
        XCTAssertEqual(runs.map(\.text).joined(), "\u{FFFC}", "the selected text is replaced by the emoji")
        XCTAssertEqual(firstEmojiRun(c)?.attributes.emoji?.id, "star")
        XCTAssertEqual(c.head, c.boxes[0].textStart + 1, "caret lands after the emoji")
    }

    func test_textIn_substitutesAltText() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: ":star:")
        let range = DocumentTextRange(DocumentTextPosition(0),
                                      DocumentTextPosition(c.documentSizeValue))
        XCTAssertEqual(c.text(in: range), "a:star:b")
    }

    func test_textIn_skipsEmojiWithNoAltText() {
        let c = makeCanvas(text: "ab")
        c.setSelectionForTesting(anchor: c.boxes[0].textStart + 1, head: c.boxes[0].textStart + 1)
        c.insertEmoji(id: "star", altText: nil)
        let range = DocumentTextRange(DocumentTextPosition(0),
                                      DocumentTextPosition(c.documentSizeValue))
        XCTAssertEqual(c.text(in: range), "ab")
    }
}
#endif
