import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-formulas Task 1 — the host's renderer reaches the bridge's mapper.
///
/// It never did: `registerFormulaRenderer` stored the provider in `deferredConfiguration` and
/// nothing handed it on, so a formula rendered as its raw LaTeX source. That is a graceful
/// degradation rather than a blank, which is why it went unnoticed.
@available(iOS 18.4, *)
final class EngineFormulaRenderingTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    /// A stand-in for the host's math renderer: a fixed-size box, so the test asserts on wiring
    /// rather than on any real typesetting.
    private func stubRenderer(_ context: RichTextFormulaRenderContext) -> RichTextFormulaRenderResult? {
        let size = CGSize(width: 40, height: 20)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
        }
        return RichTextFormulaRenderResult(image: image, size: size, ascent: 16, descent: 4)
    }

    private func formulaRun(_ latex: String) -> TextRun {
        var attributes = CharacterAttributes()
        attributes.formula = latex
        return TextRun(text: latex, attributes: attributes)
    }
    private func paragraph(_ id: String, _ runs: [TextRun]) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: runs))
    }
    private func firstBlock() -> NSAttributedString { editor.engine.attributedBlocks[0] }
    private func attachmentCount() -> Int {
        let block = firstBlock()
        return (0..<block.length).filter {
            block.attribute(.attachment, at: $0, effectiveRange: nil) is FormulaTextAttachment
        }.count
    }

    func test_withNoRendererAFormulaIsItsRawLatex() {
        editor.document = Document(blocks: [paragraph("p", [formulaRun("E=mc^2")])])
        XCTAssertEqual(firstBlock().string, "E=mc^2", "the documented degradation, not a blank")
        XCTAssertEqual(attachmentCount(), 0)
    }

    /// THE ORDERING THAT MATTERS. `RichTextAttachmentScreen` sets the document at line 1376 and
    /// registers the renderer at 1395, so a document holding formulas is always rendered once with
    /// no renderer. Registration then changes the run from N characters to ONE — a text LENGTH
    /// change no attribute merge can express — so it must re-derive from the model.
    func test_registeringARendererAfterTheDocumentReRendersIt() {
        editor.document = Document(blocks: [paragraph("p", [formulaRun("E=mc^2")])])
        XCTAssertEqual(attachmentCount(), 0)
        editor.registerFormulaRenderer { [weak self] in self?.stubRenderer($0) }
        XCTAssertEqual(firstBlock().length, 1, "one attachment character now, not six of LaTeX")
        XCTAssertEqual(attachmentCount(), 1)
    }

    func test_theModelIsUnchangedByRendering() {
        let document = Document(blocks: [paragraph("p", [formulaRun("E=mc^2")])])
        editor.document = document
        editor.registerFormulaRenderer { [weak self] in self?.stubRenderer($0) }
        guard case let .paragraph(back) = editor.document.blocks[0] else { return XCTFail("not a paragraph") }
        XCTAssertEqual(back.runs.count, 1)
        XCTAssertEqual(back.runs[0].attributes.formula, "E=mc^2",
                       "the model's run text IS the latex; rendering replaces it only on the engine's axis")
    }

    func test_aFormulaRenderedFromTheStartNeedsNoRebuild() {
        editor.registerFormulaRenderer { [weak self] in self?.stubRenderer($0) }
        editor.document = Document(blocks: [paragraph("p", [formulaRun("x^2")])])
        XCTAssertEqual(attachmentCount(), 1)
    }

    func test_aFormulaAmongTextRendersInline() {
        editor.registerFormulaRenderer { [weak self] in self?.stubRenderer($0) }
        editor.document = Document(blocks: [paragraph("p", [
            TextRun(text: "see "), formulaRun("x^2"), TextRun(text: " there"),
        ])])
        XCTAssertEqual(attachmentCount(), 1)
        XCTAssertEqual(firstBlock().string, "see \u{FFFC} there")
    }

    /// The last of three. `characterAttributes(from:)` returns early for each attachment kind, and
    /// each early return used to drop `.rtSpoiler`: fixed for emoji first, for buttons in
    /// R9-buttons, and here for formulas. The forward path is already right — `ca.formula` goes
    /// through the GENERAL branch, which carries the marker — so only the read-back is repaired.
    func test_aSpoileredFormulaKeepsItsSpoilerThroughTheRoundTrip() {
        editor.registerFormulaRenderer { [weak self] in self?.stubRenderer($0) }
        var attributes = CharacterAttributes()
        attributes.formula = "x^2"
        attributes.spoiler = true
        editor.document = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "x^2", attributes: attributes)])),
        ])
        guard case let .paragraph(back) = editor.document.blocks[0] else { return XCTFail("not a paragraph") }
        XCTAssertEqual(back.runs.first?.attributes.formula, "x^2")
        XCTAssertEqual(back.runs.first?.attributes.spoiler, true)
    }
}
