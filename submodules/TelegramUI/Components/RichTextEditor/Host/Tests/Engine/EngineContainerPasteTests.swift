import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// What a MULTI-LINE paste does inside each container, and the two whole-document operations a
/// container has to survive: a theme push over mixed content, and a selection spanning a formula
/// run. A paste is one insert carrying "\n"s, which is the same surface the gate decides a Return
/// at — with a different rule per container, since a Return in a cell moves the caret while a
/// pasted newline may not move anything.
@available(iOS 18.4, *)
final class EngineContainerPasteTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func strings() -> [String] { editor.engine.attributedBlocks.map { $0.string.replacingOccurrences(of: "\u{2028}", with: "⏎") } }
    private func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            if role.innermostAncestor != nil { return "child" }
            switch role.shape { case .media: return "media"; case .buttonRow: return "buttonRow"; case .code: return "code"; case .pullQuote: return "pullQuote"; case .collapsedQuote: return "collapsedQuote"; case .paragraph: return "std" }
        }
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func para(_ id: String, _ text: String) -> Block { .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)])) }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    // MARK: - A paste keeps its lines inside the container it lands in

    /// A leaf body is ONE engine block: the pasted newlines are line separators, not new blocks.
    func test_aMultiLinePasteIntoACodeBodyStaysOneCodeBlock() {
        load([.code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "xz")]))])
        editor.engineSelectedRange = NSRange(location: 7, length: 0)   // "swift\nx|z"
        editor.engine.insertText("a\nb")
        turn()
        XCTAssertEqual(strings(), ["swift", "xa⏎bz"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 10, length: 0))
    }

    func test_aMultiLinePasteIntoAPullQuoteStaysOnePullQuote() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "xz")], author: [TextRun(text: "Me")]))])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)   // "x|z"
        editor.engine.insertText("a\nb")
        turn()
        XCTAssertEqual(strings(), ["xa⏎bz", "Me"])
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor"])
    }

    /// A block quote's children ARE separate blocks, so a pasted newline makes another child —
    /// settle declares it one, rather than letting it split the quote in three.
    func test_aMultiLinePasteIntoAQuoteChildMakesAnotherChild() {
        load([.blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "xz")], author: [TextRun(text: "Ada")]))])
        editor.engineSelectedRange = NSRange(location: 1, length: 0)   // "x|z"
        editor.engine.insertText("a\nb")
        turn()
        XCTAssertEqual(strings(), ["xa", "bz", "Ada"])
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor"])
        XCTAssertEqual(editor.document.blocks.count, 1, "still one quote, not three blocks")
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(quote.children.map { $0.flatText }, ["xa", "bz"])
    }

    /// A language line is one line, always: the text's newline becomes a space, as a `UITextField`
    /// does with one, so its words stay apart (composer harness, p12, `HarnessSingleLineFieldNewlineTests`
    /// — this used to pin the newline being DELETED, which glued "123 Main St⏎City" into one word).
    func test_aMultiLineInsertIntoALanguageLineKeepsItsWordsApart() {
        load([.code(CodeBlock(id: BlockID("c"), language: "sw", runs: [TextRun(text: "x")]))])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)   // "sw|"
        editor.engine.insertText("i\nft")
        turn()
        XCTAssertEqual(strings(), ["swi ft", "x"])
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "code"])
    }

    /// An author line is one line too.
    func test_aMultiLineInsertIntoAnAuthorLineKeepsItsWordsApart() {
        load([.pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "A")]))])
        editor.engineSelectedRange = NSRange(location: 8, length: 0)   // "quoted\nA|"
        editor.engine.insertText("d\na")
        turn()
        XCTAssertEqual(strings(), ["quoted", "Ad a"])
        XCTAssertEqual(kinds(), ["pullQuote", "secondary.pullQuoteAuthor"])
    }

    // MARK: - Whole-document operations over mixed content

    /// A theme push rebuilds the mapper and re-applies the document. The colours must change and
    /// the STRUCTURE must not: the rebuild reads `document` before swapping the bridge, and a
    /// container that came back as loose paragraphs would be invisible until the next edit.
    func test_aThemePushOverMixedContentKeepsEveryContainer() {
        load([para("p0", "before"),
              .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "x")])),
              .blockQuote(BlockQuote(id: BlockID("b"), children: [para("b0", "one")], author: [TextRun(text: "Ada")])),
              .pullQuote(PullQuote(id: BlockID("q"), runs: [TextRun(text: "quoted")], author: [TextRun(text: "Me")])),
              .table(TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                                rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("a"), blocks: [para("ap", "aa")])])])),
              para("p1", "after")])
        let before = kinds()
        XCTAssertEqual(before, ["std", "secondary.codeLanguage", "code", "child", "secondary.blockQuoteAuthor",
                                "pullQuote", "secondary.pullQuoteAuthor", "cell", "std"])
        let text = strings()

        var tinted = RichTextEditorTheme.default
        tinted.primaryText = .magenta
        editor.theme = tinted
        turn()

        XCTAssertEqual(kinds(), before, "the structure survives the rebuild")
        XCTAssertEqual(strings(), text)
        XCTAssertEqual(editor.document.blocks.map(\.id),
                       [BlockID("p0"), BlockID("c"), BlockID("b"), BlockID("q"), BlockID("t"), BlockID("p1")],
                       "and every block is the same one")
        XCTAssertEqual(editor.engine.attributedBlocks[0].attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor,
                       .magenta, "the theme reached the text")
    }

    /// A formula run is ONE character on the engine's axis and its LaTeX source in the model, so a
    /// range that spans it is measured in engine characters. A selection over a paragraph holding
    /// one and the code block after it drops both, like any other pair.
    func test_aSelectionAcrossAFormulaRunAndAContainerDropsBoth() {
        let renderer: (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult? = { _ in
            let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: CGSize(width: 10, height: 10), ascent: 8, descent: 2)
        }
        editor.removeFromSuperview()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                          mapper: AttributedStringMapper(formulaRenderer: renderer))
        window.addSubview(editor)
        var formula = CharacterAttributes.plain
        formula.formula = "x+y"
        load([.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x+y", attributes: formula)])),
              .code(CodeBlock(id: BlockID("c"), language: "swift", runs: [TextRun(text: "z")]))])
        XCTAssertEqual(strings(), ["\u{FFFC}", "swift", "z"], "one attachment character, not three")

        editor.engineSelectedRange = NSRange(location: 0, length: 9)   // the attachment + "\nswift\nz"
        editor.engine.deleteBackward()
        turn()
        XCTAssertEqual(strings(), [""])
        XCTAssertEqual(kinds(), ["std"])
        XCTAssertEqual(editor.document.blocks.map(\.id), [BlockID("p0")], "the start paragraph's identity survives")
    }
}
