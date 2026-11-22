// Tests/RichTextEditorCoreTests/DocumentFragmentTrailingEmptyLineTests.swift
import XCTest
@testable import RichTextEditorCore

/// Core half of the composer harness's p17 fix (2026-09-25, `HarnessDetailsTrailingEmptyLineCopyTests`):
/// an empty paragraph ending an expanded details that ends the document is where Select All ends, so
/// `extractFragment` covers it, like an empty code block at the document end. Before, Select All → Copy
/// of `[p "a"] [details "Title" [p "body"] [p ""]]` gave a details with one body paragraph.
///
/// "The document end" is the COPIED document's, not a container's children's: a range ending at the
/// start of the empty last line of a details (or a quote) that more text follows does not cover it —
/// which also stops an empty code block ending a details body from being admitted there.
final class DocumentFragmentTrailingEmptyLineTests: XCTestCase {
    private func paragraph(_ text: String) -> Block {
        .paragraph(ParagraphBlock(id: .generate(), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }

    private func details(_ children: [Block]) -> Block {
        .details(DetailsBlock(id: .generate(), title: [TextRun(text: "Title")], children: children, expanded: true))
    }

    /// The global text start of the LAST child of the details at `index` (its body laid out after the
    /// container open, the title's open, its text and its close).
    private func lastChildTextStart(of document: Document, detailsAt index: Int) -> Int {
        guard case .details(let d) = document.blocks[index] else { XCTFail("not a details"); return 0 }
        var cursor = 0
        for block in document.blocks.prefix(index) { cursor += DocumentTree.documentSize(Document(blocks: [block])) }
        let childrenStart = cursor + 2 + d.titleUTF16Count + 1
        let before = DocumentTree.documentSize(Document(blocks: Array(d.children.dropLast())))
        return childrenStart + before + 1
    }

    private func bodyTexts(_ fragment: Document) -> [String]? {
        for block in fragment.blocks {
            if case .details(let d) = block {
                return d.children.map { block -> String in
                    if case .paragraph(let p) = block { return p.text }
                    if case .code(let c) = block { return "code:" + c.text }
                    return "?"
                }
            }
        }
        return nil
    }

    func test_selectAll_ofADetailsEndingTheDocument_keepsItsEmptyLastLine() {
        let document = Document(blocks: [paragraph("a"), details([paragraph("body"), paragraph("")])])
        let end = lastChildTextStart(of: document, detailsAt: 1)
        let fragment = document.extractFragment(globalFrom: 1, globalTo: end)
        XCTAssertEqual(bodyTexts(fragment), ["body", ""])
    }

    /// Control: a details that a paragraph follows — a range ending at its empty last line's start holds
    /// no character of that line and does not cover it (the range's end is exclusive).
    func test_rangeEndingAtTheEmptyLastLine_ofADetailsFollowedByText_doesNotCoverIt() {
        let document = Document(blocks: [paragraph("a"), details([paragraph("body"), paragraph("")]), paragraph("z")])
        let end = lastChildTextStart(of: document, detailsAt: 1)
        let fragment = document.extractFragment(globalFrom: 1, globalTo: end)
        XCTAssertEqual(bodyTexts(fragment), ["body"])
    }

    /// Control: past the details, the empty line is covered as before.
    func test_rangePastTheDetails_coversTheEmptyLastLine() {
        let document = Document(blocks: [paragraph("a"), details([paragraph("body"), paragraph("")]), paragraph("z")])
        let fragment = document.extractFragment(globalFrom: 1, globalTo: DocumentTree.documentSize(document) - 1)
        XCTAssertEqual(bodyTexts(fragment), ["body", ""])
    }

    /// The same rule for an empty CODE block ending a details body: admitted only when the details ends
    /// the document (it used to be admitted at the end of the children wherever the details stood).
    func test_emptyCodeEndingADetailsBody_isCoveredOnlyAtTheDocumentEnd() {
        let code = Block.code(CodeBlock(id: .generate(), language: "", runs: []))
        let atEnd = Document(blocks: [paragraph("a"), details([paragraph("body"), code])])
        let docSize = DocumentTree.documentSize(atEnd)
        // The empty code's text position: two tokens before the details' close (code close, details close).
        let codeText = docSize - 3
        XCTAssertEqual(bodyTexts(atEnd.extractFragment(globalFrom: 1, globalTo: codeText)), ["body", "code:"])
        let followed = Document(blocks: atEnd.blocks + [paragraph("z")])
        XCTAssertEqual(bodyTexts(followed.extractFragment(globalFrom: 1, globalTo: codeText)), ["body"])
    }

    /// Control: a top-level empty last paragraph keeps the bare rule — it is the document's trailing
    /// line, which a paste supplies itself.
    func test_topLevelEmptyLastParagraph_isNotCoveredAtItsStart() {
        let document = Document(blocks: [paragraph("a"), paragraph("")])
        let fragment = document.extractFragment(globalFrom: 1, globalTo: document.globalTextStart(ofBlockAt: 1))
        XCTAssertEqual(fragment.blocks.count, 1)
    }
}
