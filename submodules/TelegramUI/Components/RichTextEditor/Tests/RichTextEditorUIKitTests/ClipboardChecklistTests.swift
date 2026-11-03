#if canImport(UIKit)
import XCTest
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class ClipboardChecklistTests: XCTestCase {
    private func canvas() -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        return v
    }

    func test_plainTextFragment_parsesEmojiCheckboxLines() {
        let v = canvas()
        let doc = v.plainTextFragment("⬜ a\n✅ b\nplain")
        XCTAssertEqual(doc.blocks.count, 3)
        guard case .paragraph(let p0) = doc.blocks[0], case .paragraph(let p1) = doc.blocks[1],
              case .paragraph(let p2) = doc.blocks[2] else { return XCTFail() }
        XCTAssertEqual(p0.list?.marker, .checklist); XCTAssertEqual(p0.list?.checked, false); XCTAssertEqual(p0.text, "a")
        XCTAssertEqual(p1.list?.marker, .checklist); XCTAssertEqual(p1.list?.checked, true);  XCTAssertEqual(p1.text, "b")
        XCTAssertNil(p2.list); XCTAssertEqual(p2.text, "plain")
    }

    func test_externalPlainText_isUnchangedForNonChecklist() {
        // Guards that the plain rep of ordinary paragraphs is identical to before (no stray prefixes).
        let blocks: [Block] = [
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "two")])),
        ]
        XCTAssertEqual(externalChecklistPlainText(blocks), "one\ntwo")
    }

    // MARK: pasteFragment chokepoint — trailing-empty-paragraph stripping

    /// Sets up an empty canvas and positions the caret at the document end.
    private func emptyCanvas() -> DocumentCanvasView {
        let v = canvas()
        v.setBlocks([.paragraph(ParagraphBlock(id: .generate(), runs: []))], width: 300)
        // Caret at global position 1 (end of the sole empty paragraph's content slot).
        // allLeafRegions().first gives us the one region; globalStart+length is the end.
        if let r = v.allLeafRegions().first { v.setSelectionForTesting(anchor: r.globalStart + r.length, head: r.globalStart + r.length) }
        return v
    }

    func test_pasteFragment_dropsTrailingEmptyParagraph() {
        // A fragment ending with an empty paragraph (what RTF/internal/plain all produce for a
        // trailing terminator newline / blank line) must not paste a spurious trailing empty block.
        let v = emptyCanvas()
        v.pasteFragment(Document(blocks: [
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "hello")])),
            .paragraph(ParagraphBlock(id: .generate(), runs: [])),
        ]))
        let blocks = v.currentBlocks()
        XCTAssertEqual(blocks.count, 1, "trailing empty paragraph must not be pasted")
        guard case .paragraph(let p) = blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "hello")
    }

    func test_pasteFragment_preservesInteriorEmptyParagraph() {
        // An interior blank line must be preserved; only a TRAILING empty is dropped.
        let v = emptyCanvas()
        v.pasteFragment(Document(blocks: [
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "a")])),
            .paragraph(ParagraphBlock(id: .generate(), runs: [])),      // interior blank — keep
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "b")])),
        ]))
        XCTAssertEqual(v.currentBlocks().count, 3,
            "interior blank line must be preserved; only a TRAILING empty is dropped")
    }

    func test_pasteFragment_plainTextWithTrailingNewline_noSpuriousEmpty() {
        // Plain text "hello\n" → plainTextFragment produces [hello, ""] → pasteFragment chops trailing ""
        // (since the narrower plainTextFragment fix was reverted, the chokepoint must handle it).
        let v = emptyCanvas()
        v.pasteFragment(v.plainTextFragment("hello\n"))
        XCTAssertEqual(v.currentBlocks().count, 1, "trailing newline plain paste must not yield a trailing empty paragraph")
        guard case .paragraph(let p) = v.currentBlocks()[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "hello")
    }

    func test_rtfRoundTrip_blockCount() {
        // RTF round-trip datapoint: export a single-paragraph doc and re-import it.
        // Count must be 1 (clean) — if it's 2 the RTF import itself adds a trailing empty (separate issue).
        let doc = Document(blocks: [.paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "hello")]))])
        guard let rtfData = RTFConversion.rtfData(from: doc),
              let imported = RTFConversion.fragment(fromRTF: rtfData) else {
            XCTFail("RTF round-trip failed to produce data / import")
            return
        }
        XCTAssertEqual(imported.blocks.count, 1,
            "RTF round-trip of a single paragraph must yield exactly 1 block (block count was \(imported.blocks.count))")
    }
}
#endif
