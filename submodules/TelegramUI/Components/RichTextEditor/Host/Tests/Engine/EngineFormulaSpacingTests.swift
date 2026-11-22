import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-formulas Task 2 — a standalone formula paragraph takes `.formula` rhythm, not `.paragraph`.
///
/// The membership test is legacy's, ported from `BlockBox.spacingKind`: body style, no list,
/// length 1, sole attachment a `FormulaTextAttachment`. Legacy tests its LAYOUT rather than the
/// model deliberately — "reaching the model would mean `currentParagraph()`, which re-derives every
/// run from the attributed string, and this is read on every layout pass for every block" — and the
/// engine reads its own storage for the same reason. No role carries content.
@available(iOS 18.4, *)
final class EngineFormulaSpacingTests: XCTestCase {
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

    private func formulaRun(_ latex: String) -> TextRun {
        var attributes = CharacterAttributes()
        attributes.formula = latex
        return TextRun(text: latex, attributes: attributes)
    }
    private func para(_ id: String, _ runs: [TextRun], style: ParagraphStyleName = .body,
                      list: ListMembership? = nil) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), style: style, list: list, runs: runs))
    }
    private func text(_ id: String, _ s: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: s)]))
    }

    func test_aStandaloneFormulaParagraphIsClassifiedAsOne() {
        editor.document = Document(blocks: [text("a", "before"), para("f", [formulaRun("x^2")])])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.standaloneFormulaRoleIndices(), [1])
    }

    func test_aFormulaAmongTextIsNotStandalone() {
        editor.document = Document(blocks: [para("f", [TextRun(text: "see "), formulaRun("x^2")])])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.standaloneFormulaRoleIndices(), [],
                       "two runs, so the paragraph is prose that happens to contain a formula")
    }

    func test_aListedOrHeadedFormulaIsNotStandalone() {
        editor.document = Document(blocks: [
            para("l", [formulaRun("x^2")], list: ListMembership(marker: .bullet, level: 1)),
            para("h", [formulaRun("y^2")], style: .heading1),
        ])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.standaloneFormulaRoleIndices(), [],
                       "mirrors InstantPageBuilder's dispatch: the formula test requires body + no list")
    }

    /// With no renderer the run is N characters of LaTeX, so it is literally a paragraph of text at
    /// that moment and must NOT take formula rhythm. It resolves itself when a renderer arrives.
    func test_anUnrenderedFormulaIsNotStandalone() {
        let plain = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(plain)
        plain.document = Document(blocks: [para("f", [formulaRun("x^2")])])
        plain.layoutIfNeeded()
        XCTAssertEqual(plain.standaloneFormulaRoleIndices(), [])
    }

    func test_theSpacingPassGivesAFormulaADifferentGapThanAParagraph() {
        editor.document = Document(blocks: [text("a", "before"), para("f", [formulaRun("x^2")])])
        editor.layoutIfNeeded()
        let asFormula = EngineBlockSpacing.blockLayout(
            for: editor.currentRoles, styleSheet: editor.bridge.styleSheet,
            quoteStyle: editor.quoteStyle, pullQuoteStyle: editor.pullQuoteStyle,
            standaloneFormulas: editor.standaloneFormulaRoleIndices(),
            lineAttributes: editor.spacingLineAttributes()).insets[1].top
        let asParagraph = EngineBlockSpacing.blockLayout(
            for: editor.currentRoles, styleSheet: editor.bridge.styleSheet,
            quoteStyle: editor.quoteStyle, pullQuoteStyle: editor.pullQuoteStyle,
            standaloneFormulas: [],
            lineAttributes: editor.spacingLineAttributes()).insets[1].top
        XCTAssertNotEqual(asFormula, asParagraph, accuracy: 0.001,
                          "if these agree the parameter is not reaching the rhythm table")
    }

    // MARK: - Alignment

    private func alignment(ofBlock index: Int) -> NSTextAlignment? {
        let block = editor.engine.attributedBlocks[index]
        guard block.length > 0,
              let style = block.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        else { return nil }
        return style.alignment
    }

    /// The V2 renderer centres a block formula (`InstantPageV2FormulaItem.centeringBounds`), and the
    /// editor lays out to match what will be sent.
    func test_aStandaloneFormulaIsCentred() {
        editor.document = Document(blocks: [text("a", "before"), para("f", [formulaRun("x^2")])])
        editor.layoutIfNeeded()
        XCTAssertEqual(alignment(ofBlock: 1), .center)
        XCTAssertEqual(alignment(ofBlock: 0), .natural, "an ordinary paragraph is untouched")
    }

    func test_aFormulaAmongTextIsNotCentred() {
        editor.document = Document(blocks: [para("f", [TextRun(text: "see "), formulaRun("x^2")])])
        editor.layoutIfNeeded()
        XCTAssertEqual(alignment(ofBlock: 0), .natural,
                       "prose containing a formula is prose")
    }

    /// The stored alignment is OVERRIDDEN, not consulted: the renderer ignores it too, since a block
    /// formula reaches the wire as `InstantPageBlock.formula`, which carries no alignment.
    func test_aStandaloneFormulaIsCentredEvenWhenTheParagraphSaysOtherwise() {
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("f"),
                                      paragraph: ParagraphAttributes(alignment: .right),
                                      runs: [formulaRun("x^2")])),
        ])
        editor.layoutIfNeeded()
        XCTAssertEqual(alignment(ofBlock: 0), .center)
    }

    /// Centring must survive the presentation guard: an inserted formula and a rendered one both go
    /// through the same `attributedString(for:)`, so `verifyPresentationIsDerived` sees no drift.
    func test_anInsertedFormulaIsCentredAndDoesNotDrift() {
        editor.document = Document(blocks: [text("p", "")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.insertFormula(latex: "x^2")
        editor.layoutIfNeeded()
        let index = editor.standaloneFormulaRoleIndices().first
        XCTAssertNotNil(index)
        XCTAssertEqual(alignment(ofBlock: index ?? 0), .center)
        XCTAssertEqual(editor.presentationDrift(atBlock: index ?? 0), [])
    }
}
