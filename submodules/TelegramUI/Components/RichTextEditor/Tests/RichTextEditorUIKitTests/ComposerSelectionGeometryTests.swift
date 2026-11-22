#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

/// Geometry for the chat composer's flat-coordinate selection: `composerSelectionRects(forFlatRange:)`
/// anchors the emoji-suggestion popover; `composerCaretRectInCanvas()` anchors the emoji context panel.
/// These reuse the flat↔global mapping in `DocumentCanvasView+ComposerSelection`. All rects are in canvas
/// content space (the facade converts to view space).
final class ComposerSelectionGeometryTests: XCTestCase {
    private func makeCanvas(_ blocks: [Block]) -> DocumentCanvasView {
        let c = DocumentCanvasView()
        c.setBlocks(blocks, width: 320)
        c.frame = CGRect(x: 0, y: 0, width: 320, height: 400)
        c.layoutIfNeeded()
        return c
    }
    private func para(_ s: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(), runs: s.isEmpty ? [] : [TextRun(text: s)]))
    }
    private func emojiRun(_ alt: String, id: String = "5217587809472226220") -> TextRun {
        var a = CharacterAttributes.plain
        a.emoji = EmojiRef(id: id, instanceID: BlockID.generate().rawValue, altText: alt)
        return TextRun(text: "\u{FFFC}", attributes: a)
    }

    // MARK: composerSelectionRects(forFlatRange:)

    func test_selectionRects_singleParagraph_nonEmptyAndInBounds() {
        let c = makeCanvas([para("hello world")])
        let rects = c.composerSelectionRects(forFlatRange: NSRange(location: 0, length: 5))   // "hello"
        XCTAssertFalse(rects.isEmpty)
        for r in rects {
            XCTAssertGreaterThanOrEqual(r.minX, 0)
            XCTAssertGreaterThanOrEqual(r.minY, 0)
            XCTAssertLessThanOrEqual(r.maxY, c.bounds.height + 1)
        }
    }

    func test_selectionRects_matchEquivalentGlobalRects() {
        let c = makeCanvas([para("ab"), para("cd")])   // flat "ab\ncd"; "cd" = flat location 3, length 2
        let flat = c.composerSelectionRects(forFlatRange: NSRange(location: 3, length: 2))
        let p2 = c.boxes[1].textStart
        let global = c.selectionRects(globalFrom: p2, globalTo: p2 + 2)
        XCTAssertEqual(flat, global)
    }

    func test_selectionRects_afterCustomEmoji_advancesPastIt() {
        let c = makeCanvas([.paragraph(ParagraphBlock(id: BlockID.generate(),
            runs: [emojiRun("\u{1F600}"), TextRun(text: "x")]))])   // 😀x ; flat: emoji=[0,2), "x"=[2,3)
        let emojiRects = c.composerSelectionRects(forFlatRange: NSRange(location: 0, length: 2))
        let xRects = c.composerSelectionRects(forFlatRange: NSRange(location: 2, length: 1))
        XCTAssertFalse(emojiRects.isEmpty)
        XCTAssertFalse(xRects.isEmpty)
        XCTAssertGreaterThan(xRects[0].minX, emojiRects[0].minX, "the glyph after the emoji is further right")
    }

    func test_selectionRects_zeroLengthRange_returnsEmpty() {
        let c = makeCanvas([para("abc")])
        XCTAssertTrue(c.composerSelectionRects(forFlatRange: NSRange(location: 1, length: 0)).isEmpty)
    }

    // MARK: composerCaretRectInCanvas()

    func test_caretRect_placedCaret_isFiniteAndNonZero() {
        let c = makeCanvas([para("abc")])
        c.composerSelectedRange = NSRange(location: 2, length: 0)
        guard let r = c.composerCaretRectInCanvas() else { return XCTFail("expected a caret rect") }
        XCTAssertGreaterThan(r.height, 0)
        XCTAssertTrue(r.origin.x.isFinite && r.origin.y.isFinite)
        XCTAssertGreaterThan(r.minX, 0, "caret after 'ab' is indented from the leading edge")
    }

    // MARK: composerSelectionBoundingRectInCanvas()

    func test_boundingRect_withSelection_isFirstRect() {
        let c = makeCanvas([para("abcd")])
        c.composerSelectedRange = NSRange(location: 1, length: 2)   // "bc"
        let bounding = c.composerSelectionBoundingRectInCanvas()
        let rects = c.selectionRects(globalFrom: c.selFrom, globalTo: c.selTo)
        XCTAssertEqual(bounding, rects.first)
    }

    func test_boundingRect_noSpan_fallsBackToBounds() {
        let c = makeCanvas([para("abc")])
        c.composerSelectedRange = NSRange(location: 1, length: 0)   // collapsed → no covered glyphs
        XCTAssertEqual(c.composerSelectionBoundingRectInCanvas(), c.bounds)
    }

    // MARK: Facade (RichTextEditorView) — canvas→view conversion

    private func makeEditor(_ text: String) -> RichTextEditorView {
        let editor = RichTextEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: text)]))])
        _ = editor.update(size: CGSize(width: 320, height: 400), insets: .zero)
        return editor
    }

    func test_facade_firstSelectionRect_nonNilForSelection() {
        let editor = makeEditor("hello")
        XCTAssertNotNil(editor.composerFirstSelectionRect(forFlatRange: NSRange(location: 0, length: 3)))
    }

    func test_facade_firstSelectionRect_nilForEmptyRange() {
        let editor = makeEditor("hi")
        XCTAssertNil(editor.composerFirstSelectionRect(forFlatRange: NSRange(location: 0, length: 0)))
    }

    func test_facade_caretRect_mapsIntoViewBounds() {
        let editor = makeEditor("hello")
        editor.composerSelectedRange = NSRange(location: 3, length: 0)
        guard let r = editor.composerCaretRect() else { return XCTFail("expected caret") }
        XCTAssertTrue(r.origin.x.isFinite && r.origin.y.isFinite)
        XCTAssertTrue(editor.bounds.insetBy(dx: -1, dy: -1).contains(CGPoint(x: r.midX, y: r.midY)),
                      "caret rect maps into the editor view bounds")
    }

    func test_facade_boundingRect_isContentSpaceFromCanvas() {
        let editor = makeEditor("abcd")
        editor.composerSelectedRange = NSRange(location: 1, length: 2)
        // Facade bounding rect is NOT view-converted; it equals the canvas-space first rect.
        XCTAssertEqual(editor.composerSelectionBoundingRect, editor.canvas.composerSelectionBoundingRectInCanvas())
    }
}
#endif
