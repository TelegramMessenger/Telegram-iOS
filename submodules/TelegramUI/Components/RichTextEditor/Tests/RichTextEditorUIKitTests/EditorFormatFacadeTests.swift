#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class EditorFormatFacadeTests: XCTestCase {
    func editor() -> RichTextEditorView {
        let e = RichTextEditorView()
        e.frame = CGRect(x: 0, y: 0, width: 320, height: 480)
        e.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Hello")]))])
        e.layoutIfNeeded()
        return e
    }
    func runs(_ e: RichTextEditorView) -> [TextRun] {
        for b in e.document.blocks { if case .paragraph(let p) = b { return p.runs } }
        return []
    }

    func test_facade_toggleItalic_reflectsInDocument() {
        let e = editor()
        e.selectAll(); e.toggleItalic()
        XCTAssertEqual(runs(e).map { $0.text }.joined(), "Hello")
        XCTAssertTrue(runs(e).allSatisfy { $0.attributes.italic })
    }
    func test_facade_setParagraphStyle_reflectsInDocument() {
        let e = editor()
        e.selectAll(); e.setParagraphStyle(.heading1)
        guard case .paragraph(let p)? = e.document.blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(p.style, .heading1)
    }
    func test_facade_undo_revertsFormatting() {
        let e = editor()
        let um = UndoManager(); um.groupsByEvent = false; e.canvas.undoManagerOverride = um
        e.selectAll()
        um.beginUndoGrouping(); e.toggleBold(); um.endUndoGrouping()
        XCTAssertTrue(runs(e).allSatisfy { $0.attributes.bold })
        e.undo()
        XCTAssertTrue(runs(e).allSatisfy { !$0.attributes.bold }, "facade undo reverts bold")
    }

    func test_facade_selectedGlobalRange_nilWhenCollapsed() {
        let e = editor()
        e.canvas.setSelectionForTesting(anchor: 3, head: 3)
        XCTAssertNil(e.selectedGlobalRange(), "a collapsed selection has no range")
    }
    func test_facade_selectedGlobalRange_reportsOffsets() {
        let e = editor()
        e.canvas.setSelectionForTesting(anchor: 1, head: 4)
        let r = e.selectedGlobalRange()
        XCTAssertEqual(r?.from, 1); XCTAssertEqual(r?.to, 4)
    }
    func test_facade_selectedGlobalRange_ordersEndpoints() {
        let e = editor()
        e.canvas.setSelectionForTesting(anchor: 4, head: 1)   // dragged backwards
        let r = e.selectedGlobalRange()
        XCTAssertEqual(r?.from, 1); XCTAssertEqual(r?.to, 4)
    }
    func test_facade_replaceRange_replacesAndCollapses() {
        let e = editor()   // "Hello" → text global 1..6
        e.replaceRange(from: 1, to: 6, with: Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("n"), runs: [TextRun(text: "Bye")]))]))
        guard case .paragraph(let p)? = e.document.blocks.first else { return XCTFail("expected paragraph") }
        XCTAssertEqual(p.text, "Bye")
    }

    // MARK: convertToBodyText composition
    //
    // The `RichTextAttachmentScreen` "Text" menu item normalizes the caret's / selection's paragraph(s)
    // to a plain body paragraph, stripping whatever block container they sit in. The helper is app-side,
    // so these tests reproduce its exact façade composition and assert each container type collapses to
    // plain body — the load-bearing behavior the menu item relies on.
    private func convertToBodyText(_ e: RichTextEditorView) {
        let live = e.currentState()
        if live.isCodeBlock { e.makeCodeBlock(); return }
        if live.isPullQuote { e.makePullQuote(); return }
        // Unwrap quotes first so a quoted list item becomes a top-level paragraph `setList` can reach.
        var guardCount = 0
        while e.currentState().blockQuoteDepth > 0 && guardCount < 32 { e.unwrapBlockQuoteLevel(); guardCount += 1 }
        if e.currentState().listMarker != nil { e.setList(nil) }
        e.setParagraphStyle(.body)
    }
    private func firstParagraph(_ e: RichTextEditorView) -> ParagraphBlock? {
        for b in e.document.blocks { if case .paragraph(let p) = b { return p } }
        return nil
    }
    private func assertPlainBody(_ e: RichTextEditorView, _ message: String) {
        let paras = e.document.blocks.compactMap { block -> ParagraphBlock? in
            if case .paragraph(let p) = block { return p }; return nil
        }
        XCTAssertEqual(paras.count, e.document.blocks.count, "\(message): every block is a paragraph (no container survives)")
        XCTAssertTrue(paras.allSatisfy { $0.style == .body }, "\(message): every paragraph is body style")
        XCTAssertTrue(paras.allSatisfy { $0.list == nil }, "\(message): no list membership survives")
        XCTAssertEqual(paras.map { $0.text }.joined(), "Hello", "\(message): the text is preserved")
    }

    func test_convertToBodyText_stripsHeading() {
        let e = editor()
        e.selectAll(); e.setParagraphStyle(.heading1)
        XCTAssertEqual(firstParagraph(e)?.style, .heading1)
        e.selectAll(); convertToBodyText(e)
        assertPlainBody(e, "heading → body")
    }

    func test_convertToBodyText_stripsList() {
        let e = editor()
        e.selectAll(); e.setList(.bullet)
        XCTAssertNotNil(firstParagraph(e)?.list)
        e.selectAll(); convertToBodyText(e)
        assertPlainBody(e, "list → body")
    }

    func test_convertToBodyText_stripsBlockQuote() {
        let e = editor()
        e.selectAll(); e.wrapInBlockQuote()
        // The caret is left inside the quote (depth > 0), mirroring a menu tap with the selection/caret in
        // the container — `blockQuoteDepth` is head-based, exactly like the existing Quote toggle.
        XCTAssertGreaterThan(e.currentState().blockQuoteDepth, 0)
        convertToBodyText(e)
        assertPlainBody(e, "block quote → body")
    }

    func test_convertToBodyText_stripsQuotedList() {
        let e = editor()
        e.selectAll(); e.setList(.bullet); e.selectAll(); e.wrapInBlockQuote()
        XCTAssertGreaterThan(e.currentState().blockQuoteDepth, 0)
        XCTAssertEqual(e.currentState().listMarker, .bullet)
        convertToBodyText(e)
        assertPlainBody(e, "quoted list → body")
    }

    func test_convertToBodyText_stripsCodeBlock() {
        let e = editor()
        e.selectAll(); e.makeCodeBlock()
        XCTAssertTrue(e.currentState().isCodeBlock)
        convertToBodyText(e)
        assertPlainBody(e, "code block → body")
    }

    func test_convertToBodyText_stripsPullQuote() {
        let e = editor()
        e.selectAll(); e.makePullQuote()
        XCTAssertTrue(e.currentState().isPullQuote)
        convertToBodyText(e)
        assertPlainBody(e, "pull quote → body")
    }
}
#endif
