import XCTest
@testable import RichTextEditorCore

final class CodeBlockPositionTests: XCTestCase {
    // A code block is a CONTAINER of two paragraph children — the language line and the code text —
    // so it contributes container(2) + (lang + 2) + (code + 2) tokens. Interior "\n"s count, as before.
    func test_codeBlock_sizeIncludesLanguageAndInteriorNewlines() {
        let text = "a\nbb"                          // 4 UTF-16 units incl. the "\n"
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: text)]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 4 + 5 + 6)
    }

    // The language region is NEVER content-gated (unlike a quote author): a language-less block still
    // carries a zero-length language region, so the code text's offset does not move when a language is
    // added or cleared.
    func test_codeBlock_languageRegionIsPresentEvenWhenAbsent() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: nil, runs: [TextRun(text: "ab")]))])
        XCTAssertEqual(DocumentTree.documentSize(doc), 2 + 0 + 6)
    }

    func test_codeBlock_languagePositionMapsToCodeLanguageRef() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        // Container open (0) → language paragraph open (1) → language text starts at 2.
        XCTAssertEqual(PositionResolver.textPosition(at: 2, in: root)?.ref, .codeLanguage(BlockID("c1")))
        XCTAssertEqual(PositionResolver.textPosition(at: 2, in: root)?.offset, 0)
        let tp = PositionResolver.textPosition(at: 3, in: root)
        XCTAssertEqual(tp?.ref, .codeLanguage(BlockID("c1")))
        XCTAssertEqual(tp?.offset, 1)
    }

    func test_codeBlock_textPositionMapsToCodeRef() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c1"), language: "swift", runs: [TextRun(text: "ab")]))])
        let root = DocumentTree.build(from: doc)
        // Code text starts at container(1) + languageParagraph(1 + 5 + 1) + codeParagraph open(1) = 9.
        let tp = PositionResolver.textPosition(at: 9 + 1, in: root)
        XCTAssertEqual(tp?.ref, .code(BlockID("c1")))
        XCTAssertEqual(tp?.offset, 1)
    }

    // The fragment/paste axis must agree with the position axis: a code block's text locus is now three
    // tokens deeper than a paragraph's. Getting this wrong slices the wrong UTF-16 range on copy and
    // inserts at the wrong offset on paste — silently.
    func test_topLevelTextLocus_findsTheCodeTextPastTheLanguage() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "abc")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        XCTAssertEqual(codeStart, 9)                                     // 0 + 4 + 5
        XCTAssertEqual(doc.topLevelTextLocus(globalCaret: codeStart + 1)?.local, 1)
        XCTAssertEqual(doc.topLevelTextLocus(globalCaret: codeStart + 1)?.index, 0)
    }

    func test_extractFragment_slicesCodeTextFromTheRightBase() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "abc")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        let frag = doc.extractFragment(globalFrom: codeStart, globalTo: codeStart + 2)
        guard case let .code(c) = frag.blocks[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(c.text, "ab")
        XCTAssertEqual(c.language, "swift")
    }

    func test_insertingFragment_pastesIntoTheCodeTextNotTheLanguage() {
        let doc = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "ac")]))])
        let codeStart = doc.globalTextStart(ofBlockAt: 0)
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p"), style: .body, runs: [TextRun(text: "b")]))])
        let result = doc.insertingFragment(frag, atGlobal: codeStart + 1)
        guard case let .code(c) = result!.document.blocks[0] else { return XCTFail("expected a code block") }
        XCTAssertEqual(c.text, "abc")
        XCTAssertEqual(c.language, "swift")
    }
}
