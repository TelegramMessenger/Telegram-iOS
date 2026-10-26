import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-formulas Task 3 — `insertFormula` makes a BLOCK, diverging from legacy's inline insert.
@available(iOS 18.4, *)
final class EngineFormulaCommandTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    private static func stub(_ context: RichTextFormulaRenderContext) -> RichTextFormulaRenderResult? {
        let size = CGSize(width: 40, height: 20)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return RichTextFormulaRenderResult(image: image, size: size, ascent: 16, descent: 4)
    }

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        editor.registerFormulaRenderer { Self.stub($0) }
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func latexes() -> [String] {
        editor.document.blocks.compactMap { block in
            guard case let .paragraph(p) = block else { return nil }
            return p.runs.compactMap(\.attributes.formula).first
        }
    }
    private func shape() -> [String] {
        editor.document.blocks.map { block in
            switch block {
            case let .paragraph(p):
                return p.standaloneFormulaLatex != nil ? "formula" : "p"
            case .buttonRow: return "row"
            case .blockQuote: return "quote"
            case .details: return "details"
            case .table: return "table"
            case .media: return "media"
            case .code: return "code"
            case .pullQuote: return "pull"
            }
        }
    }

    func test_anEmptyParagraphBecomesTheFormulaBlock() {
        editor.document = Document(blocks: [para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertFormula(latex: "E=mc^2")
        XCTAssertEqual(shape(), ["formula"])
        XCTAssertEqual(latexes(), ["E=mc^2"])
    }

    func test_aCaretMidParagraphSplitsIt() {
        editor.document = Document(blocks: [para("p", "abcd")])
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.insertFormula(latex: "x^2")
        XCTAssertEqual(shape(), ["p", "formula", "p"])
        XCTAssertEqual(editor.document.blocks[0].flatText, "ab")
        XCTAssertEqual(editor.document.blocks[2].flatText, "cd")
    }

    func test_noTrailingParagraphIsMinted() {
        editor.document = Document(blocks: [para("p", "text")])
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.insertFormula(latex: "x^2")
        XCTAssertEqual(shape(), ["p", "formula"],
                       "a formula paragraph IS a paragraph — there is somewhere to type already")
    }

    func test_aSelectionIsReplaced() {
        editor.document = Document(blocks: [para("p", "abcd")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 1, length: 2)
        editor.insertFormula(latex: "x^2")
        XCTAssertFalse(editor.document.blocks.map(\.flatText).joined().contains("bc"))
    }

    func test_aCaretInsideAQuoteMakesTheFormulaAChildOfIt() {
        editor.document = Document(blocks: [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [para("c", "in")], author: [])),
        ])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertFormula(latex: "x^2")
        guard case let .blockQuote(quote) = editor.document.blocks[0] else { return XCTFail("\(shape())") }
        XCTAssertTrue(quote.children.contains {
            if case let .paragraph(p) = $0 { return p.standaloneFormulaLatex != nil }
            return false
        })
    }

    func test_anEmptyLatexDoesNothing() {
        editor.document = Document(blocks: [para("p", "text")])
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.insertFormula(latex: "")
        XCTAssertEqual(shape(), ["p"])
    }

    // MARK: - Inline authoring

    private func runsOfFirstBlock() -> [TextRun] {
        guard case let .paragraph(p) = editor.document.blocks[0] else { return [] }
        return p.runs
    }

    func test_theSelectionBecomesAnInlineFormulaCarryingItsText() {
        editor.document = Document(blocks: [para("p", "let x^2 stand")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 3)   // "x^2"
        editor.makeSelectionInlineFormula()
        XCTAssertEqual(runsOfFirstBlock().compactMap(\.attributes.formula), ["x^2"])
        // The MODEL keeps the latex as the run's text — that is the documented round trip, "a
        // formula run's text its source, which the renderer replaced with one attachment
        // character". The U+FFFC lives on the ENGINE's axis, which is asserted below.
        XCTAssertEqual(runsOfFirstBlock().map(\.text).joined(), "let x^2 stand")
        XCTAssertEqual(runsOfFirstBlock().count, 3)
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand",
                       "one attachment character where the formula is")
        XCTAssertNil(editor.document.blocks[0].asParagraph?.standaloneFormulaLatex,
                     "three runs, so it is prose containing a formula — NOT the block form")
    }

    func test_anEmptySelectionMakesNoInlineFormula() {
        editor.document = Document(blocks: [para("p", "text")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.makeSelectionInlineFormula()
        XCTAssertTrue(runsOfFirstBlock().allSatisfy { $0.attributes.formula == nil })
    }

    /// A selection covering a WHOLE paragraph produces the block form, because one run alone in a
    /// body paragraph IS the block form. The two verbs meet here rather than conflicting.
    func test_selectingAWholeParagraphYieldsTheBlockForm() {
        editor.document = Document(blocks: [para("p", "x^2")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 0, length: 3)
        editor.makeSelectionInlineFormula()
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.standaloneFormulaLatex, "x^2")
    }

    // MARK: - Tap to edit

    private func insertOneFormula(_ latex: String = "x^2") {
        editor.document = Document(blocks: [para("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertFormula(latex: latex)
        editor.layoutIfNeeded()
    }

    func test_everyRenderedFormulaGetsATapTarget() {
        insertOneFormula()
        XCTAssertEqual(editor.formulaTapTargets.count, 1)
    }

    func test_theTargetCoversTheAttachmentsFrame() {
        insertOneFormula()
        guard let (offset, view) = editor.formulaTapTargets.first else { return XCTFail("no target") }
        XCTAssertEqual(view.frame, editor.engine.id_attachmentFrame(forCanonicalOffset: UInt(offset)))
    }

    /// A view that draws NOTHING receives no real touches, although `hitTest:` still returns it
    /// (project CLAUDE.md, "iOS 26/27 windows and touch delivery"). The target must therefore carry
    /// transparent `contents`; this pins that it does, though only a device tap proves delivery.
    func test_theTargetIsInteractiveAndRenders() {
        insertOneFormula()
        guard let view = editor.formulaTapTargets.values.first else { return XCTFail("no target") }
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.count, 1)
        XCTAssertNotNil(view.layer.contents, "a layer that renders nothing receives no real touches")
    }

    func test_aTapAsksTheHostToEditTheFormula() {
        insertOneFormula()
        var asked: String?
        editor.onEditFormulaRequested = { latex, _ in asked = latex }
        guard let view = editor.formulaTapTargets.values.first else { return XCTFail("no target") }
        XCTAssertTrue(editor.handleFormulaTapIfNeeded(
            atPointInEngine: CGPoint(x: view.frame.midX, y: view.frame.midY)))
        XCTAssertEqual(asked, "x^2")
    }

    func test_theCompletionReplacesThatFormula() {
        insertOneFormula()
        editor.onEditFormulaRequested = { _, completion in completion("y^3") }
        guard let view = editor.formulaTapTargets.values.first else { return XCTFail("no target") }
        _ = editor.handleFormulaTapIfNeeded(
            atPointInEngine: CGPoint(x: view.frame.midX, y: view.frame.midY))
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.standaloneFormulaLatex, "y^3")
    }

    func test_anEmptyReplacementIsRefused() {
        insertOneFormula()
        editor.onEditFormulaRequested = { _, completion in completion("") }
        guard let view = editor.formulaTapTargets.values.first else { return XCTFail("no target") }
        _ = editor.handleFormulaTapIfNeeded(
            atPointInEngine: CGPoint(x: view.frame.midX, y: view.frame.midY))
        XCTAssertEqual(editor.document.blocks[0].asParagraph?.standaloneFormulaLatex, "x^2",
                       "legacy's replaceFormula refuses an empty latex too; deletion is the host's")
    }

    func test_theTargetIsCulledWhenTheFormulaGoes() {
        insertOneFormula()
        XCTAssertFalse(editor.formulaTapTargets.isEmpty)
        editor.document = Document(blocks: [para("p", "plain")])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.formulaTapTargets.isEmpty)
    }

    func test_aTapAwayFromEveryFormulaIsNotOurs() {
        insertOneFormula()
        editor.onEditFormulaRequested = { _, _ in XCTFail("not a formula") }
        XCTAssertFalse(editor.handleFormulaTapIfNeeded(atPointInEngine: CGPoint(x: 10, y: 400)))
    }

    // MARK: - Inline insertion with an authored latex

    func test_anInlineFormulaLandsAtTheCaret() {
        editor.document = Document(blocks: [para("p", "let  stand")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.insertInlineFormula(latex: "x^2")
        XCTAssertEqual(runsOfFirstBlock().compactMap(\.attributes.formula), ["x^2"])
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand")
        XCTAssertNil(editor.document.blocks[0].asParagraph?.standaloneFormulaLatex,
                     "inline, so NOT the block form")
    }

    func test_anInlineFormulaReplacesASelection() {
        editor.document = Document(blocks: [para("p", "let junk stand")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 4)   // "junk"
        editor.insertInlineFormula(latex: "x^2")
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand")
        XCTAssertEqual(runsOfFirstBlock().compactMap(\.attributes.formula), ["x^2"])
    }

    func test_anEmptyLatexInsertsNoInlineFormula() {
        editor.document = Document(blocks: [para("p", "text")])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.insertInlineFormula(latex: "")
        XCTAssertTrue(runsOfFirstBlock().allSatisfy { $0.attributes.formula == nil })
        XCTAssertEqual(runsOfFirstBlock().map(\.text).joined(), "text")
    }

    /// Legacy's rule, kept: a formula asked for inside a CODE block is just its source text — code is
    /// plain by definition and a rendered atom there would be a lie about what will be sent.
    func test_insideACodeBlockAnInlineFormulaIsPlainText() {
        editor.document = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: nil,
                                                            runs: [TextRun(text: "let a = ")]))])
        _ = editor.engine.becomeFirstResponder()
        let body = editor.currentRoles.firstIndex { $0.containerID == BlockID("c") && $0.secondaryKind == nil }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: body)
                                             + editor.flatLength(ofRoleAt: body), length: 0)
        editor.insertInlineFormula(latex: "x^2")
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("not a code block") }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let a = x^2")
        XCTAssertTrue(code.runs.allSatisfy { $0.attributes.formula == nil })
    }

    /// An atom owns no text region, so there is nowhere for an inline run to go.
    func test_anAtomRefusesAnInlineFormula() {
        editor.document = Document(blocks: [
            .buttonRow(ButtonRowBlock(id: BlockID("r"), buttons: [ButtonRef(label: [], action: .url(""))])),
            para("p", "after"),
        ])
        _ = editor.engine.becomeFirstResponder()
        let row = editor.currentRoles.indices.first { editor.buttonRowShape(atRole: $0) != nil }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: row), length: 0)
        editor.insertInlineFormula(latex: "x^2")
        XCTAssertEqual(shape(), ["row", "p"], "unchanged")
    }

    /// Enabled in tables: a cell is a paragraph like any other for an inline atom.
    func test_anInlineFormulaLandsInATableCell() {
        var table = TableBlock.empty(rows: 1, columns: 2)
        table.id = BlockID("t")
        table.rows[0].cells[0].blocks = [para("c0", "let  stand")]
        editor.document = Document(blocks: [.table(table)])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0) + 4, length: 0)
        editor.insertInlineFormula(latex: "x^2")
        // The ENGINE holds the atom; the model's run keeps the latex as its text, as it does for
        // every formula run.
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand")
        guard case let .table(updated) = editor.document.blocks[0],
              let runs = updated.rows[0].cells[0].blocks.first?.asParagraph?.runs else { return XCTFail("no cell paragraph") }
        XCTAssertEqual(runs.compactMap(\.attributes.formula), ["x^2"])
    }
}
