#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasClipboardTests: XCTestCase {
    final class FakePasteboard: TextPasteboard {
        var items: [String: Any] = [:]
        var string: String? {
            get { items["public.utf8-plain-text"] as? String }
            set {
                if let v = newValue { items = ["public.utf8-plain-text": v] } else { items = [:] }
            }
        }
        var hasStrings: Bool { !((string ?? "").isEmpty) }
        func data(forPasteboardType type: String) -> Data? { items[type] as? Data }
        func setItems(_ newItems: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {
            items = newItems.first ?? [:]
        }
        func contains(pasteboardTypes: [String]) -> Bool { pasteboardTypes.contains { items[$0] != nil } }
    }
    func cell(_ id: String, _ t: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"), runs: [TextRun(text: t)]))])
    }
    func canvas() -> (DocumentCanvasView, FakePasteboard) {
        let v = DocumentCanvasView()
        v.setBlocks([
            .paragraph(ParagraphBlock(id: BlockID("h"), runs: [TextRun(text: "Hello world")])),
            .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 120), ColumnSpec(width: 120)],
                rows: [Row(id: BlockID("r0"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])),
        ], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        let pb = FakePasteboard(); v.pasteboard = pb
        return (v, pb)
    }
    func region(_ v: DocumentCanvasView, _ id: String) -> LeafTextRegion {
        v.allLeafRegions().first { $0.ref == .paragraph(BlockID(id)) }!
    }
    func text(_ v: DocumentCanvasView, _ id: String) -> String {
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID(id) { return p.text } }
        return ""
    }

    func test_copy_writesFragmentRTFAndPlain() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // "Hello"
        v.copy(nil)
        XCTAssertEqual(pb.string, "Hello")                                  // plain
        XCTAssertNotNil(pb.data(forPasteboardType: DocumentCanvasView.richTextFragmentUTI))   // fragment
        XCTAssertNotNil(pb.data(forPasteboardType: "public.rtf"))           // rtf
        let frag = try! DocumentCodec.decode(pb.data(forPasteboardType: DocumentCanvasView.richTextFragmentUTI)!)
        guard case .paragraph(let p) = frag.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "Hello")
    }
    func test_cut_copiesAndDeletes_andUndoes() {
        let (v, pb) = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 6)   // "Hello "
        um.beginUndoGrouping(); v.cut(nil); um.endUndoGrouping()
        XCTAssertEqual(pb.string, "Hello ")
        XCTAssertEqual(text(v, "h"), "world")
        um.undo()
        XCTAssertEqual(text(v, "h"), "Hello world")
    }
    func test_paste_insertsStringAtSelection_andUndoes() {
        let (v, pb) = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // replace "Hello"
        pb.string = "Howdy"
        um.beginUndoGrouping(); v.paste(nil); um.endUndoGrouping()
        XCTAssertEqual(text(v, "h"), "Howdy world")
        um.undo()
        XCTAssertEqual(text(v, "h"), "Hello world")
    }
    func test_paste_multiline_splitsIntoParagraphs() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)   // caret after "Hello"
        pb.string = "a\nb"
        v.paste(nil)
        let paraTexts = v.currentBlocks().compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }
        XCTAssertEqual(paraTexts, ["Helloa", "b world"])   // newline → paragraph split (was flattened)
    }

    func test_paste_CRLF_splitsIntoParagraphs() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)
        pb.string = "a\r\nb"
        v.paste(nil)
        let paraTexts = v.currentBlocks().compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }
        XCTAssertEqual(paraTexts, ["Helloa", "b world"])   // CRLF → ONE split, no blank paragraph
    }

    func test_paste_prefersFragmentOverPlain() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("f"),
            runs: [TextRun(text: "Z", attributes: CharacterAttributes(bold: true))]))])
        pb.items = [DocumentCanvasView.richTextFragmentUTI: try! DocumentCodec.encode(frag),
                    "public.utf8-plain-text": "PLAIN"]
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "HelloZ world")       // fragment won, not "PLAIN"
        var bold = false
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID("h") {
            bold = p.runs.contains { $0.text.contains("Z") && $0.attributes.bold } } }
        XCTAssertTrue(bold)
    }

    func test_paste_rtfWhenNoFragment_preservesBold() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)
        let rtf = RTFConversion.rtfData(from: Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("f"),
            runs: [TextRun(text: "Q", attributes: CharacterAttributes(bold: true))]))]))!
        pb.items = ["public.rtf": rtf, "public.utf8-plain-text": "Q"]
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "HelloQ world")
        var bold = false
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID("h") {
            bold = p.runs.contains { $0.text.contains("Q") && $0.attributes.bold } } }
        XCTAssertTrue(bold)
    }

    func test_copy_acrossCells_concatenatesCellText() {
        let (v, pb) = canvas()
        let a = region(v, "ap"); let b = region(v, "bp")
        v.setSelectionForTesting(anchor: a.globalStart, head: b.globalStart + b.length)   // "Alpha" … "Beta"
        v.copy(nil)
        XCTAssertEqual(pb.string, "AlphaBeta")
    }
    func test_paste_emptyClipboard_isNoOp() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)
        pb.string = nil
        v.paste(nil)
        XCTAssertEqual(text(v, "h"), "Hello world")   // nothing on the clipboard → no change
    }
    func test_copyCut_collapsedSelection_isNoOp() {
        let (v, pb) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 3, head: r.globalStart + 3)   // collapsed
        pb.string = "orig"
        v.copy(nil)
        XCTAssertEqual(pb.string, "orig")             // copy no-ops on a collapsed selection
        v.cut(nil)
        XCTAssertEqual(pb.string, "orig")             // cut no-ops too
        XCTAssertEqual(text(v, "h"), "Hello world")   // and the text is unchanged
    }
    func test_canPerformAction_copyCutPaste() {
        let (v, pb) = canvas()
        let r = region(v, "h")
        v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.cut(_:)), withSender: nil))
        v.setSelectionForTesting(anchor: r.globalStart + 2, head: r.globalStart + 2)   // collapsed → no copy/cut
        XCTAssertFalse(v.canPerformAction(#selector(UIResponderStandardEditActions.copy(_:)), withSender: nil))
        pb.string = "x"
        XCTAssertTrue(v.canPerformAction(#selector(UIResponderStandardEditActions.paste(_:)), withSender: nil))
    }

    func test_pasteFragment_preservesBoldAcrossInsert() {
        let (v, _) = canvas()
        let um = UndoManager(); um.groupsByEvent = false; v.undoManagerOverride = um
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)   // caret after "Hello"
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("f"),
            runs: [TextRun(text: "X", attributes: CharacterAttributes(bold: true))]))])
        um.beginUndoGrouping(); v.pasteFragment(frag); um.endUndoGrouping()
        // model now "HelloX world"; the inserted "X" run is bold
        var boldFound = false
        for b in v.currentBlocks() { if case .paragraph(let p) = b, p.id == BlockID("h") {
            boldFound = p.runs.contains { $0.text.contains("X") && $0.attributes.bold }
        } }
        XCTAssertTrue(boldFound)
        XCTAssertEqual(text(v, "h"), "HelloX world")
        um.undo()
        XCTAssertEqual(text(v, "h"), "Hello world")   // single undo step restores
    }

    func test_pasteFragment_multiBlock_splitsIntoParagraphs() {
        let (v, _) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("x"), runs: [TextRun(text: "AA")])),
            .paragraph(ParagraphBlock(id: BlockID("y"), runs: [TextRun(text: "BB")])),
        ])
        v.pasteFragment(frag)
        let paraTexts = v.currentBlocks().compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }
        XCTAssertEqual(paraTexts, ["HelloAA", "BB world"])
    }

    func test_pasteFragment_replacesSelection() {
        let (v, _) = canvas()
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart, head: r.globalStart + 5)   // select "Hello"
        v.pasteFragment(Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("f"), runs: [TextRun(text: "Hi")]))]))
        XCTAssertEqual(text(v, "h"), "Hi world")
    }

    func allRunTexts(_ blocks: [Block]) -> [String] {
        var out: [String] = []
        for b in blocks {
            switch b {
            case .paragraph(let p): out += p.runs.map(\.text)
            case .code(let c): out += c.runs.map(\.text)
            case .media(let m): out += m.caption.map(\.text)
            case .table(let t): for row in t.rows { for cell in row.cells { out += allRunTexts(cell.blocks) } }
            case .pullQuote(let pq): out += pq.runs.map(\.text)
            case .blockQuote(let bq): out += allRunTexts(bq.children)
            case .details(let d): out += d.title.map(\.text); out += allRunTexts(d.children)
            case .buttonRow: break   // a pill label is not a document run
            }
        }
        return out
    }

    func test_pasteFragment_codeBlockIntoTableCell_noNewlineLeaksIntoRun() {
        let (v, _) = canvas()
        let r = region(v, "ap")                       // paragraph inside table cell "a"
        v.setSelectionForTesting(anchor: r.globalStart + r.length, head: r.globalStart + r.length)   // caret at end of "Alpha", in the cell
        // Fragment containing a code block with interior newlines → forces the cell fallback path.
        let frag = Document(blocks: [.code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "x\ny")]))])
        v.pasteFragment(frag)
        // No paragraph/code run anywhere may contain a literal newline (the doc has no legit code block).
        XCTAssertFalse(allRunTexts(v.currentBlocks()).contains { $0.contains("\n") })
    }

    // MARK: paste-media-to-send hooks (the editor delegates media; text wins)

    private var pasteSelector: Selector { #selector(UIResponderStandardEditActions.paste(_:)) }

    func test_canPerformAction_paste_trueWhenMediaAvailable_noText() {
        let (v, pb) = canvas()
        pb.items = [:]                                  // no text reps on the pasteboard
        v.canPasteMedia = { true }
        XCTAssertTrue(v.clipboardCanPerformAction(pasteSelector))
    }

    func test_canPerformAction_paste_falseWhenNoTextNoMedia() {
        let (v, pb) = canvas()
        pb.items = [:]
        v.canPasteMedia = { false }
        XCTAssertFalse(v.clipboardCanPerformAction(pasteSelector))
    }

    func test_paste_noTextRep_delegatesToOnPasteMedia_documentUnchanged() {
        let (v, pb) = canvas()
        pb.items = [:]                                  // no fragment / rtf / plain
        var mediaCalled = false
        v.onPasteMedia = { mediaCalled = true; return true }
        let beforeCount = v.currentBlocks().count
        v.paste(nil)
        XCTAssertTrue(mediaCalled)                      // media delegated
        XCTAssertEqual(v.currentBlocks().count, beforeCount)   // document untouched (no inline embed)
    }

    func test_paste_withTextRep_pastesText_doesNotDelegateMedia() {
        let (v, pb) = canvas()
        pb.string = "hello"                             // a plain-text rep present
        let r = region(v, "h"); v.setSelectionForTesting(anchor: r.globalStart + 5, head: r.globalStart + 5)   // after "Hello"
        var mediaCalled = false
        v.onPasteMedia = { mediaCalled = true; return true }
        v.paste(nil)
        XCTAssertFalse(mediaCalled)                     // text wins — media NOT consulted
        XCTAssertTrue(text(v, "h").contains("hello"))   // the text was pasted
    }

    // MARK: RichTextEditorClipboard public façade (host writes a whole Document to the pasteboard)

    func test_pasteboardItem_forDocument_hasFragmentRTFAndDerivedPlain() throws {
        let doc = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), style: .heading1, runs: [TextRun(text: "Title")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "body", attributes: CharacterAttributes(bold: true))])),
        ])
        let item = RichTextEditorClipboard.pasteboardItem(for: doc)
        let fragData = try XCTUnwrap(item[RichTextEditorClipboard.fragmentUTI] as? Data)
        XCTAssertEqual(try DocumentCodec.decode(fragData).blocks.count, 2)        // fragment round-trips
        XCTAssertNotNil(item["public.rtf"] as? Data)                              // RTF present
        XCTAssertEqual(item["public.utf8-plain-text"] as? String, "Title\nbody")  // plain derived, "\n"-joined
    }

    func test_pasteboardItem_explicitPlain_overridesDerived() {
        let doc = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "x")]))])
        let item = RichTextEditorClipboard.pasteboardItem(for: doc, plain: "custom")
        XCTAssertEqual(item["public.utf8-plain-text"] as? String, "custom")
    }

    func test_pasteFragment_caretBeforeFirstTextPosition_stillSplicesTable() {
        // Reproduces the freshly-latched chat composer: its selection was set before layout, so head == 0
        // (below the first paragraph's text start of 1). insertingFragment can't resolve that caret, and the
        // plain-text fallback drops a table to "". The retry via nearestTopLevelTextPosition must rescue it.
        let v = DocumentCanvasView()
        v.setBlocks([.paragraph(ParagraphBlock(id: BlockID("p"), runs: []))], width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 200); v.layoutIfNeeded()
        v.setSelectionForTesting(anchor: 0, head: 0)
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r"), cells: [cell("a", "Alpha"), cell("b", "Beta")])])
        v.pasteFragment(Document(blocks: [.table(table)]))
        XCTAssertTrue(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } },
            "a table pasted with caret reported before the first text position must survive")
    }

    func test_flatRtfd_isReadAsFragmentWithList() throws {
        // A flat-rtfd-only clipboard (some iOS Notes) whose RTF stream carries a bullet list must import
        // as a list fragment, not fall through to plain text.
        let rtf = "{\\rtf1\\ansi\\ansicpg1252{\\fonttbl\\f0\\fswiss Helvetica;}"
            + "\\pard\\li720\\fi-360 \\ls1\\ilvl0 {\\listtext\t\\uc0\\u8226 \t}Alpha\\\n"
            + "{\\listtext\t\\uc0\\u8226 \t}Beta}"
        let (v, pb) = canvas()
        pb.items = ["com.apple.flat-rtfd": Data(rtf.utf8)]
        let frag = try XCTUnwrap(v.fragment(fromPasteboard: pb))
        let listParas = frag.blocks.compactMap { b -> ParagraphBlock? in
            if case .paragraph(let p) = b, p.list != nil { return p } else { return nil }
        }
        XCTAssertEqual(listParas.count, 2)
        XCTAssertTrue(listParas.allSatisfy { $0.list?.marker == .bullet })
    }

    func test_facadeWrittenFragment_isReadByEditorPaste() throws {
        // A host-written fragment must be recognized by the editor's own paste reader (same UTI + codec).
        let doc = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"),
            runs: [TextRun(text: "Hello", attributes: CharacterAttributes(bold: true))]))])
        let (v, pb) = canvas()
        pb.items = RichTextEditorClipboard.pasteboardItem(for: doc)
        let frag = try XCTUnwrap(v.fragment(fromPasteboard: pb))
        guard case .paragraph(let p) = frag.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "Hello")
        XCTAssertTrue(p.runs.first?.attributes.bold == true)
    }
}
#endif
