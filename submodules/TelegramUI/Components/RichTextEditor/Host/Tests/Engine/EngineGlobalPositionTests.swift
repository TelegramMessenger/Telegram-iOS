import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// **The global position axis is Core's, not legacy's** — and the engine can therefore answer it.
///
/// `selectedGlobalRange()` / `replaceRange(from:to:with:)` used to TRAP on the engine
/// (`richTextEngineUnimplemented(…, rung: "R7-paste")`), on the stated premise that they speak
/// "offsets into legacy's global position model, which the engine does not have". That premise was
/// wrong twice over:
///
/// 1. The axis is defined in **`RichTextEditorCore`** — `DocumentTree.documentSize` /
///    `Document.globalTextStart(ofBlockAt:)` / `PositionMapping` — as a pure function of a
///    `Document`. It is the axis `Document.extractFragment` and `Document.replacingRange` already
///    speak. Legacy merely happens to store its caret on it.
/// 2. The engine owns a `Document`, and each of its roles carries the very key a `TextNodeRef` is
///    keyed on: a `BlockID` plus which region of that block it is (`secondaryKind`). So a role maps
///    onto a text node one-to-one, and `PositionMapping` walks the rest of the tree — at any depth,
///    through cells, quotes and details alike.
///
/// The user-visible consequence of the trap: **tapping the AI button in the article editor killed
/// the app** (`EXC_BREAKPOINT`, K3 2026-09-17). `RichTextAttachmentScreen` opens that flow with
/// `if let sel = self.editor.selectedGlobalRange()`, so it trapped on the CALL — the selection being
/// empty never got a chance to matter — and `replaceRange` would have trapped again on the way back.
///
/// The one genuine asymmetry between the two axes is inside a run, and it is the reason this cannot
/// be `offset - roleStart`: a **formula** renders as a single `U+FFFC` in the engine while its
/// `TextRun.text` holds the whole LaTeX source (`EngineDocumentBridge.modelRuns(readingBack:)`).
/// Custom emoji and inline buttons are one `U+FFFC` on BOTH sides, so they need no conversion —
/// only a formula does, and one of them shifts every later offset in its block.
@available(iOS 18.4, *)
final class EngineGlobalPositionTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 900))
        window.addSubview(editor); window.makeKeyAndVisible()
        // Without a renderer the engine holds a formula's LaTeX VERBATIM
        // (`attributedFormulaString`'s documented degradation), so the two axes coincide and the
        // formula case below would assert nothing. Registering one is what creates the asymmetry.
        editor.registerFormulaRenderer { _ in
            let size = CGSize(width: 40, height: 20)
            let image = UIGraphicsImageRenderer(size: size).image { ctx in
                UIColor.red.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            }
            return RichTextFormulaRenderResult(image: image, size: size, ascent: 16, descent: 4)
        }
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block], author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: author.isEmpty ? [] : [TextRun(text: author)]))
    }

    /// The document's text, paragraph by paragraph — enough for the flat fixtures here.
    private func text(of document: Document) -> String {
        document.blocks.compactMap { block -> String? in
            guard case let .paragraph(p) = block else { return nil }
            return p.runs.map(\.text).joined()
        }.joined(separator: "\n")
    }

    /// Selects `text` inside the role at `index`, by its offset within that role.
    private func select(roleAt index: Int, from: Int, to: Int) {
        let base = editor.flatOffset(ofRoleAt: index)
        editor.engineSelectedRange = NSRange(location: base + from, length: to - from)
    }

    // MARK: - The axis itself

    /// The reference answer, computed straight off Core: a top-level paragraph's text starts at
    /// `globalTextStart(ofBlockAt:)`, so selecting `[from, to)` of its text is that plus the offsets.
    func test_aSelectionInTheFirstParagraphIsTheCoreAxisAnswer() {
        editor.document = Document(blocks: [para("p0", "Hello world")])
        select(roleAt: 0, from: 6, to: 11)   // "world"

        let doc = editor.document
        let textStart = doc.globalTextStart(ofBlockAt: 0)
        XCTAssertEqual(editor.selectedGlobalRange().map { [$0.from, $0.to] },
                       [textStart + 6, textStart + 11],
                       "the engine must answer the same axis Core's own globalTextStart does")
    }

    /// The second paragraph's text start is past the first block's open + content + close tokens, so
    /// this fails for any implementation that returns the engine's own flat offset unchanged.
    func test_aSelectionInTheSecondParagraphCountsTheFirstBlocksTokens() {
        editor.document = Document(blocks: [para("p0", "Hello"), para("p1", "world")])
        select(roleAt: 1, from: 0, to: 5)

        let doc = editor.document
        let textStart = doc.globalTextStart(ofBlockAt: 1)
        XCTAssertEqual(editor.selectedGlobalRange().map { [$0.from, $0.to] },
                       [textStart, textStart + 5])
        XCTAssertNotEqual(textStart, editor.flatOffset(ofRoleAt: 1),
                          "negative control: the two axes must genuinely differ here, or this test proves nothing")
    }

    /// `nil` means "nothing is selected" — the ONE answer the trap existed to avoid giving wrongly.
    func test_aCollapsedCaretHasNoRange() {
        editor.document = Document(blocks: [para("p0", "Hello")])
        select(roleAt: 0, from: 2, to: 2)
        XCTAssertNil(editor.selectedGlobalRange(), "a collapsed caret selects nothing")
    }

    /// The whole point of routing through `PositionMapping` rather than a top-level block scan: a
    /// paragraph nested inside a quote is found by the same tree walk, at depth.
    func test_aSelectionInsideAQuoteIsFoundAtDepth() {
        editor.document = Document(blocks: [para("p0", "before"),
                                            quote("q0", [para("q0p", "inside")])])
        let role = editor.currentRoles.firstIndex { $0.blockID == BlockID("q0p") }
        XCTAssertNotNil(role, "the quote's child must have a role of its own")
        select(roleAt: role!, from: 0, to: 6)

        let tree = DocumentTree.build(from: editor.document)
        let expected = PositionResolver.globalPosition(of: .paragraph(BlockID("q0p")), offset: 0, in: tree)
        XCTAssertNotNil(expected)
        XCTAssertEqual(editor.selectedGlobalRange()?.from, expected)
    }

    // MARK: - What the AI flow actually does with it

    /// The exact sequence in `RichTextAttachmentScreen`'s AI button: read the selection, expand it
    /// over non-text blocks, extract the fragment. The fragment must be the selected text.
    func test_theAIFlowExtractsTheSelectedText() {
        editor.document = Document(blocks: [para("p0", "keep this drop")])
        select(roleAt: 0, from: 5, to: 9)   // "this"

        guard let sel = editor.selectedGlobalRange() else { return XCTFail("expected a selection") }
        let doc = editor.document
        let (lo, hi) = doc.expandingRangeOverNonTextBlocks(globalFrom: sel.from, globalTo: sel.to)
        let fragment = doc.extractFragment(globalFrom: lo, globalTo: hi, carryingNonTextBlocks: true)
        XCTAssertEqual(text(of: fragment), "this")
    }

    /// The completion half. Replacing the selected range with a fragment must land exactly where the
    /// selection was — this is the call that trapped on the way BACK from the AI screen.
    func test_replacingTheSelectedRangeRewritesJustThatSpan() {
        editor.document = Document(blocks: [para("p0", "keep this drop")])
        select(roleAt: 0, from: 5, to: 9)

        guard let sel = editor.selectedGlobalRange() else { return XCTFail("expected a selection") }
        editor.replaceRange(from: sel.from, to: sel.to,
                            with: Document(blocks: [para("new", "THAT")]))
        XCTAssertEqual(text(of: editor.document), "keep THAT drop")
    }

    /// The `.empty` arm of the AI completion: an empty document deletes the range.
    func test_replacingWithAnEmptyDocumentDeletesTheRange() {
        editor.document = Document(blocks: [para("p0", "keep this drop")])
        select(roleAt: 0, from: 5, to: 10)   // "this "

        guard let sel = editor.selectedGlobalRange() else { return XCTFail("expected a selection") }
        editor.replaceRange(from: sel.from, to: sel.to, with: Document(blocks: []))
        XCTAssertEqual(text(of: editor.document), "keep drop")
    }

    /// Deleting a WHOLE block leaves `Document.replacingRange`'s caret in the gap between two
    /// blocks, and a gap is inside no text node — so without an outward scan the caret is never
    /// placed at all and stays wherever the document setter's clamp left it.
    func test_deletingAWholeBlockStillLandsTheCaret() {
        editor.document = Document(blocks: [para("p0", "abc"), para("p1", "def"), para("p2", "ghi")])

        // The whole of p1's node, boundaries included: neither endpoint is mid-paragraph, which is
        // the branch that parks the caret in a bare gap.
        let tree = DocumentTree.build(from: editor.document)
        guard let span = PositionResolver.blockSpan(ofBlockWithID: BlockID("p1"), in: tree) else {
            return XCTFail("expected p1 to have a span")
        }
        editor.replaceRange(from: span.start, to: span.end, with: Document(blocks: []))

        XCTAssertEqual(text(of: editor.document), "abc\nghi")
        // Forward first, so the caret means "after what I removed": the start of the survivor.
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: 1), length: 0),
                       "the caret must land in a real text region, not stay where the clamp left it")
    }

    // MARK: - The formula asymmetry

    /// A formula is ONE `U+FFFC` in the engine and its LaTeX source in the model, so a selection
    /// after one sits at a different offset on each axis. An implementation that subtracts the
    /// role's start and stops gets this wrong by `latex.count - 1`.
    func test_anOffsetAfterAFormulaIsConvertedToTheModelsExtent() {
        let latex = "x^2 + y^2"
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [
            TextRun(text: "a"),
            // A formula run's MODEL text is its LaTeX source; the engine renders it as one atom.
            TextRun(text: latex, attributes: CharacterAttributes(formula: latex)),
            TextRun(text: "bc"),
        ]))])
        // "bc" is at engine offset 2 (a + one atom) but model offset 1 + latex.count.
        select(roleAt: 0, from: 2, to: 4)

        let textStart = editor.document.globalTextStart(ofBlockAt: 0)
        XCTAssertEqual(editor.selectedGlobalRange().map { [$0.from, $0.to] },
                       [textStart + 1 + latex.utf16.count, textStart + 1 + latex.utf16.count + 2],
                       "the formula's LaTeX source occupies its full length on the model axis")
    }
}
