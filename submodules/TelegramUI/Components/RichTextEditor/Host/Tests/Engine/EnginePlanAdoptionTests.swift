import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Structure-only roles design §3: a structural edit carries its plan, adopted in that edit's own
/// change notification — never a by-identity guess in between, never a plan built from post-edit
/// roles. And §2: a role is structure only; what the engine holds is read at the moment of use.
@available(iOS 18.4, *)
final class EnginePlanAdoptionTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }
    private func kinds() -> [String] {
        editor.currentRoles.map { role in
            if role.owningTable != nil { return "cell" }
            if let kind = role.secondaryKind { return "secondary.\(kind)" }
            if role.innermostAncestor != nil { return "child" }
            return "std"
        }
    }
    private func cell(_ id: String, _ text: String) -> Cell {
        Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID("\(id)p"), runs: [TextRun(text: text)]))])
    }

    /// A replacement across cells keeps the structure: no paragraph in between, the head and tail
    /// kept. Since the p16 fix wave it is one edit INSIDE each cell (`replaceAcrossCells`), so no
    /// identity is minted and there is no plan to adopt at all — every cell keeps its identity. (It
    /// was one span edit that minted the later cells and carried a plan; that edit re-inserted the
    /// kept text as a plain string and dropped a custom emoji's attachment, composer harness
    /// `HarnessAtomFlatteningTests`.)
    func test_aReplacementAcrossCellsLandsItsPlanInTheEditsOwnNotification() {
        editor.document = Document(blocks: [.table(TableBlock(
            id: BlockID("t0"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r0"), cells: [cell("a", "aa"), cell("b", "bb")])]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        let identitiesBefore = editor.engine.tgid_blockIdentifiers
        editor.engineSelectedRange = NSRange(location: 1, length: 3)   // a|a … b|b
        editor.engine.insertText("X")
        XCTAssertEqual(kinds(), ["cell", "cell"], "adopted with the edit: no paragraph in between")
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers, identitiesBefore, "every cell keeps its identity")
        guard case let .table(table) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(table.rows[0].cells.map { $0.blocks.first?.asParagraph?.runs.map(\.text).joined() ?? "" }, ["aX", "b"])
    }

    /// A plain edit leaves structure to identity: the code body keeps its role through a text change,
    /// and the text is the engine's, not a copy.
    func test_aPlainEditKeepsStructureByIdentityAndReadsTheEnginesText() {
        editor.document = Document(blocks: [
            .code(CodeBlock(id: BlockID("c0"), language: "swift", runs: [TextRun(text: "let x")])),
        ])
        editor.replaceFlat(NSRange(location: 6, length: 5), with: "var y")
        XCTAssertEqual(kinds(), ["secondary.codeLanguage", "std"])
        XCTAssertEqual(editor.currentBlocks.map { $0.flatText }, ["swift", "var y"])
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(code.text, "var y")
        XCTAssertEqual(code.language, "swift")
    }

    /// A no-op edit still adopts its plan — and settles: the quote it declared has content, so its
    /// author line appears.
    func test_aNoOpEditStillAdoptsItsPlanAndSettles() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p1"), runs: [TextRun(text: "two")])),
        ])
        let quote = QuoteShape(id: BlockID("q"))
        let plan = editor.currentRoles.map { EngineBlockRole.standalone($0.shape, within: [.blockQuote(quote)]) }
        editor.replaceFlat(NSRange(location: 0, length: 0), with: "", adopting: plan)
        XCTAssertEqual(kinds(), ["child", "child", "secondary.blockQuoteAuthor"])
        XCTAssertEqual(editor.document.blocks.count, 1)
        guard case let .blockQuote(back) = editor.document.blocks[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(back.children.map { $0.flatText }, ["one", "two"])
    }

    /// Geometry is the engine's: a formula run is one attachment character on the engine's axis and
    /// its source in the model, and the offsets after it are the engine's.
    func test_flatGeometryIsTheEnginesAxis() {
        let renderer: (RichTextFormulaRenderContext) -> RichTextFormulaRenderResult? = { _ in
            let image = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10)).image { _ in }
            return RichTextFormulaRenderResult(image: image, size: CGSize(width: 10, height: 10), ascent: 8, descent: 2)
        }
        let editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 240),
                                              mapper: AttributedStringMapper(formulaRenderer: renderer))
        window.addSubview(editor)
        var formula = CharacterAttributes.plain
        formula.formula = "x+y"
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "x+y", attributes: formula)])),
            .code(CodeBlock(id: BlockID("c0"), language: "", runs: [TextRun(text: "z")])),
        ])
        XCTAssertEqual(editor.engine.attributedBlocks[0].length, 1, "the formula rendered as one attachment")
        XCTAssertEqual(editor.flatOffset(ofRoleAt: 2), 3, "1 + newline + empty language line + newline")
        XCTAssertEqual(editor.roleIndex(atFlatOffset: 3), 2)
        XCTAssertEqual(editor.document.blocks[0].flatText, "x+y", "the model keeps the source")
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engine.insertText("\n"); turn()
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["\u{FFFC}", "", "z\u{2028}"], "a Return inside the code body")
        editor.removeFromSuperview()
    }
}
