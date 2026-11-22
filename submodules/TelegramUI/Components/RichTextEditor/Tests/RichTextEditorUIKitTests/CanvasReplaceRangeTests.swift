#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class CanvasReplaceRangeTests: XCTestCase {
    private func para(_ id: String, _ t: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: t)]))
    }
    private func table1(_ id: String, _ cellText: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 90)],
            rows: [Row(id: BlockID(id + "r"), cells: [Cell(id: BlockID(id + "c"),
                blocks: [para(id + "cp", cellText)])])]))
    }
    private func canvas(_ blocks: [Block]) -> DocumentCanvasView {
        let v = DocumentCanvasView()
        v.setBlocks(blocks, width: 320)
        v.frame = CGRect(x: 0, y: 0, width: 320, height: 600); v.layoutIfNeeded()
        return v
    }
    private func paraTexts(_ v: DocumentCanvasView) -> [String] {
        v.currentBlocks().compactMap { if case .paragraph(let p) = $0 { return p.text } else { return nil } }
    }

    func test_replaceRange_textToText() {
        let v = canvas([para("h", "Hello world")])
        // "world" is local 6..11 of the single paragraph whose text starts at global 1 → global 7..12.
        v.replaceRange(globalFrom: 7, globalTo: 12, with: Document(blocks: [para("x", "there")]))
        XCTAssertEqual(paraTexts(v), ["Hello there"])
        XCTAssertEqual(v.anchor, v.head, "collapsed caret after replace")
        XCTAssertEqual(v.head, 12)
    }

    func test_replaceRange_emptyFragment_deletesRange() {
        let v = canvas([para("h", "Hello world")])
        v.replaceRange(globalFrom: 6, globalTo: 12, with: Document(blocks: []))   // delete " world"
        XCTAssertEqual(paraTexts(v), ["Hello"])
    }

    func test_replaceRange_wholeTableToText() {
        let v = canvas([para("a", "A"), table1("t", "xyz"), para("b", "B")])
        let aSize = DocumentTree.documentSize(Document(blocks: [para("a", "A")]))
        let tSize = DocumentTree.documentSize(Document(blocks: [table1("t", "xyz")]))
        v.replaceRange(globalFrom: aSize, globalTo: aSize + tSize, with: Document(blocks: [para("n", "N")]))
        // Pure-Core replacingRange makes the partition deterministic: the table drops and "N" replaces it as its
        // own block; the surrounding paragraphs stay separate (they were not adjacent across a mere break).
        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } },
                       "the whole table was replaced")
        XCTAssertEqual(paraTexts(v), ["A", "N", "B"])
    }

    func test_replaceRange_wholeTableThenText_dropsTableKeepsText() {
        // MIRROR of textThenWholeTable: the table sits at the LEADING end of a mixed range (a drag starting
        // inside the table and ending in the trailing paragraph). Previously the canvas delete kept the table
        // (resolveBox degenerate-container tech debt); the pure-Core replacingRange drops it in both orientations.
        let v = canvas([para("a", "A"), table1("t", "xyz"), para("b", "CCDD")])
        let aSize = DocumentTree.documentSize(Document(blocks: [para("a", "A")]))
        let tSize = DocumentTree.documentSize(Document(blocks: [table1("t", "xyz")]))
        let cTextStart = aSize + tSize + 1   // "CCDD" text start; +2 is after "CC"
        v.replaceRange(globalFrom: aSize, globalTo: cTextStart + 2, with: Document(blocks: [para("n", "N")]))
        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } },
                       "the leading-edge table was dropped")
        let joined = paraTexts(v).joined(separator: "|")
        XCTAssertTrue(joined.contains("A"), "leading paragraph preserved: \(joined)")
        XCTAssertTrue(joined.contains("N"), "replacement present: \(joined)")
        XCTAssertTrue(joined.contains("DD"), "post-range text preserved: \(joined)")
        XCTAssertFalse(joined.contains("CC"), "the covered head of the trailing paragraph is gone: \(joined)")
    }

    func test_replaceRange_isOneUndoStep() {
        let v = canvas([para("h", "Hello world")])
        // groupsByEvent = true matches production (`ownUndoManager`): registerUndo lazily opens a group and
        // undo() closes+undoes it, so no manual grouping is needed; undoRegistrationCount pins the step count.
        let um = UndoManager(); um.groupsByEvent = true; v.undoManagerOverride = um
        let before = v.undoRegistrationCount
        v.replaceRange(globalFrom: 7, globalTo: 12, with: Document(blocks: [para("x", "there")]))
        XCTAssertEqual(v.undoRegistrationCount, before + 1, "delete + splice register exactly one undo step")
        XCTAssertEqual(paraTexts(v), ["Hello there"])
        um.undo()
        XCTAssertEqual(paraTexts(v), ["Hello world"], "a single undo reverts the whole replace")
    }

    func test_replaceRange_textThenWholeTable_dropsTableKeepsText() {
        // Range: from mid-way through the first paragraph THROUGH the end of the table (what expansion yields
        // for a drag starting in text and ending inside the table). The table must drop; the pre-caret text
        // ("AA") and the trailing paragraph ("C") survive; the replacement "N" is present.
        let v = canvas([para("a", "AABB"), table1("t", "xyz"), para("b", "C")])
        let aSize = DocumentTree.documentSize(Document(blocks: [para("a", "AABB")]))
        let tSize = DocumentTree.documentSize(Document(blocks: [table1("t", "xyz")]))
        // "AABB" text starts at global 1; global 3 is after "AA". Table span end = aSize + tSize.
        v.replaceRange(globalFrom: 3, globalTo: aSize + tSize, with: Document(blocks: [para("n", "N")]))
        XCTAssertFalse(v.currentBlocks().contains { if case .table = $0 { return true } else { return false } },
                       "the whole table was dropped")
        let joined = paraTexts(v).joined(separator: "|")
        XCTAssertTrue(joined.contains("AA"), "pre-range text preserved: \(joined)")
        XCTAssertTrue(joined.contains("N"), "replacement present: \(joined)")
        XCTAssertTrue(joined.contains("C"), "trailing paragraph preserved: \(joined)")
        XCTAssertFalse(joined.contains("BB"), "the covered tail of the first paragraph is gone: \(joined)")
    }
}
#endif
