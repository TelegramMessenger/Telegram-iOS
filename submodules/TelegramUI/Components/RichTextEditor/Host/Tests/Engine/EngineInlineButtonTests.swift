import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 9 — an inline `textButton` renders a hosted pill.
///
/// Before this task the shared mapper emitted a `ButtonTextAttachment` carrying a 1×1 spacer image
/// and nothing hosted a view over it, so an inline button was a blank gap of exactly the right
/// size. That is the defect the first test here pins.
@available(iOS 18.4, *)
final class EngineInlineButtonTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func inlineButton(_ label: String, spoiler: Bool = false) -> TextRun {
        var attributes = CharacterAttributes()
        attributes.button = ButtonRef(label: [TextRun(text: label)], action: .url("https://example.com"))
        attributes.spoiler = spoiler
        return TextRun(text: "\u{FFFC}", attributes: attributes)
    }
    private func paragraph(_ id: String, _ runs: [TextRun]) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: runs))
    }

    func test_anInlineButtonGetsAHostedPill() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "go "), inlineButton("Tap")])])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.inlineButtonPillViews.count, 1,
                       "before this rung the attachment drew a 1x1 spacer and nothing hosted a view")
    }

    func test_thePillIsPlacedOverTheAttachmentsOwnFrame() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "go "), inlineButton("Tap")])])
        editor.layoutIfNeeded()
        guard let (offset, view) = editor.inlineButtonPillViews.first else { return XCTFail("no pill") }
        let frame = editor.engine.id_attachmentFrame(forCanonicalOffset: UInt(offset))
        XCTAssertEqual(view.frame, frame)
    }

    func test_thePillIsCulledWhenTheButtonGoes() {
        editor.document = Document(blocks: [paragraph("p", [inlineButton("Tap")])])
        editor.layoutIfNeeded()
        XCTAssertFalse(editor.inlineButtonPillViews.isEmpty)
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "plain")])])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.inlineButtonPillViews.isEmpty)
    }

    func test_anInlineButtonRoundTrips() {
        let document = Document(blocks: [paragraph("p", [TextRun(text: "go "), inlineButton("Tap")])])
        editor.document = document
        XCTAssertEqual(editor.document.blocks, document.blocks)
    }

    func test_aPillInsideAHiddenSpoilerIsHidden() {
        editor.document = Document(blocks: [paragraph("p", [inlineButton("Secret", spoiler: true)])])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.inlineButtonPillViews.values.filter(\.isHidden).count, 1,
                       "a hosted view is not hidden by a foreground colour — legacy leaks this today")
    }

    func test_aBlockRowsPillsAreNotHostedAsInlineOnes() {
        editor.document = Document(blocks: [
            .buttonRow(ButtonRowBlock(id: BlockID("r"),
                                      buttons: [ButtonRef(label: [TextRun(text: "A")], action: .url("https://a"))])),
            paragraph("p", []),
        ])
        editor.layoutIfNeeded()
        XCTAssertTrue(editor.inlineButtonPillViews.isEmpty,
                      "a block row's pills are the row view's subviews; only isBlockPill == false is inline")
    }

    /// The spoiler was lost in BOTH directions before this rung: the mapper's button branch dropped
    /// `ca.spoiler`, so no marker reached the attributed string (nothing could hide the pill) and the
    /// flag was gone from the model on the next round trip. The emoji branch beside it had the same
    /// defect, with the same self-justifying comment, and had already been fixed.
    func test_aSpoileredInlineButtonKeepsItsSpoilerThroughTheRoundTrip() {
        let document = Document(blocks: [paragraph("p", [inlineButton("Secret", spoiler: true)])])
        editor.document = document
        guard case let .paragraph(back) = editor.document.blocks[0] else { return XCTFail("not a paragraph") }
        XCTAssertEqual(back.runs.first?.attributes.spoiler, true)
        XCTAssertNotNil(back.runs.first?.attributes.button)
    }

    // MARK: - Authoring

    private func runs() -> [TextRun] {
        guard case let .paragraph(paragraph) = editor.document.blocks[0] else { return [] }
        return paragraph.runs
    }

    func test_theSelectionBecomesAPillCarryingItsText() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "tap here now")])])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 4)   // "here"
        editor.makeSelectionInlineButton()
        let buttons = runs().compactMap { $0.attributes.button }
        XCTAssertEqual(buttons.count, 1)
        XCTAssertEqual(buttons.first?.labelText, "here")
        XCTAssertEqual(runs().map(\.text).joined(), "tap \u{FFFC} now",
                       "the label lives INSIDE the button — a caret must never land in a pill")
    }

    func test_anEmptySelectionDoesNothing() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "text")])])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 2, length: 0)
        editor.makeSelectionInlineButton()
        XCTAssertTrue(runs().allSatisfy { $0.attributes.button == nil })
        XCTAssertEqual(runs().map(\.text).joined(), "text")
    }

    func test_theNewPillIsHostedWithoutAnotherDocumentSet() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "tap here now")])])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 4)
        editor.makeSelectionInlineButton()
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.inlineButtonPillViews.count, 1)
    }

    func test_aTapOnAnInlinePillAsksTheHostToEditIt() {
        editor.document = Document(blocks: [paragraph("p", [inlineButton("Tap")])])
        editor.layoutIfNeeded()
        var asked: (ButtonRef, Bool)?
        editor.onEditButtonRequested = { button, isBlockPill, _ in asked = (button, isBlockPill) }
        guard let view = editor.inlineButtonPillViews.values.first else { return XCTFail("no pill") }
        let point = CGPoint(x: view.frame.midX, y: view.frame.midY)
        XCTAssertTrue(editor.handleInlineButtonTapIfNeeded(atPointInEngine: point))
        XCTAssertEqual(asked?.0.labelText, "Tap")
        XCTAssertEqual(asked?.1, false, "an inline pill, not a block one")
    }

    func test_removingAnInlinePillLeavesItsLabelAsPlainText() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "a "), inlineButton("Tap")])])
        editor.layoutIfNeeded()
        guard let offset = editor.inlineButtonPillViews.keys.first else { return XCTFail("no pill") }
        editor.replaceInlineButton(atCanonicalOffset: offset, with: nil)
        XCTAssertTrue(runs().allSatisfy { $0.attributes.button == nil })
        XCTAssertEqual(runs().map(\.text).joined(), "a Tap", "the honest inverse of making one")
    }

    /// The rule having a CALLER, pinned separately from the rule working — and pinned to a TAP
    /// rather than to the touch-down hook, which would have opened the host's sheet on a drag that
    /// merely began on a pill.
    func test_theInlinePillCarriesATapRecogniser() {
        editor.document = Document(blocks: [paragraph("p", [inlineButton("Tap")])])
        editor.layoutIfNeeded()
        guard let view = editor.inlineButtonPillViews.values.first else { return XCTFail("no pill") }
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.count, 1)
    }

    // MARK: - Inserting a pill the host authored

    private func button(_ label: String) -> ButtonRef {
        ButtonRef(label: [TextRun(text: label)], action: .url("https://example.com"))
    }
    private func runsOfFirstBlock() -> [TextRun] { editor.document.blocks[0].asParagraph?.runs ?? [] }

    /// The Add menu's "Button ▸ Inline": the host authors the pill in its sheet first, then this puts
    /// it at the caret — the mirror of `insertInlineFormula`, and of `makeSelectionInlineButton`,
    /// which takes the selection's own text as the label instead.
    func test_anInlineButtonLandsAtTheCaret() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "let  stand")])])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.insertInlineButton(button("Go"))
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand")
        XCTAssertEqual(runsOfFirstBlock().compactMap(\.attributes.button), [button("Go")])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 5, length: 0), "the caret lands after the pill")
    }

    func test_anInlineButtonReplacesASelection() {
        editor.document = Document(blocks: [paragraph("p", [TextRun(text: "let junk stand")])])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: 4, length: 4)   // "junk"
        editor.insertInlineButton(button("Go"))
        XCTAssertEqual(editor.engine.attributedBlocks[0].string, "let \u{FFFC} stand")
        XCTAssertEqual(runsOfFirstBlock().compactMap(\.attributes.button), [button("Go")])
    }

    /// Enabled in tables: a cell is a paragraph like any other for an inline atom.
    func test_anInlineButtonLandsInATableCell() {
        var table = TableBlock.empty(rows: 1, columns: 2)
        table.id = BlockID("t")
        table.rows[0].cells[0].blocks = [paragraph("c0", [TextRun(text: "let  stand")])]
        editor.document = Document(blocks: [.table(table)])
        _ = editor.engine.becomeFirstResponder()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: 0) + 4, length: 0)
        editor.insertInlineButton(button("Go"))
        guard case let .table(updated) = editor.document.blocks[0],
              let runs = updated.rows[0].cells[0].blocks.first?.asParagraph?.runs else { return XCTFail("no cell paragraph") }
        XCTAssertEqual(runs.map(\.text).joined(), "let \u{FFFC} stand")
        XCTAssertEqual(runs.compactMap(\.attributes.button), [button("Go")])
        editor.layoutIfNeeded()
        XCTAssertEqual(editor.inlineButtonPillViews.count, 1, "and it is hosted, inside the cell's run")
    }

    /// Legacy's rule for formulas, applied to the sibling atom: code is plain by definition.
    func test_insideACodeBlockAnInlineButtonIsItsLabelAsPlainText() {
        editor.document = Document(blocks: [.code(CodeBlock(id: BlockID("c"), language: nil,
                                                            runs: [TextRun(text: "let a = ")]))])
        _ = editor.engine.becomeFirstResponder()
        let body = editor.currentRoles.firstIndex { $0.containerID == BlockID("c") && $0.secondaryKind == nil }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: body)
                                             + editor.flatLength(ofRoleAt: body), length: 0)
        editor.insertInlineButton(button("Go"))
        guard case let .code(code) = editor.document.blocks[0] else { return XCTFail("not a code block") }
        XCTAssertEqual(code.runs.map(\.text).joined(), "let a = Go")
        XCTAssertTrue(code.runs.allSatisfy { $0.attributes.button == nil })
    }

    func test_anAtomRefusesAnInlineButton() {
        editor.document = Document(blocks: [
            .buttonRow(ButtonRowBlock(id: BlockID("r"), buttons: [ButtonRef(label: [], action: .url(""))])),
            paragraph("p", [TextRun(text: "after")]),
        ])
        _ = editor.engine.becomeFirstResponder()
        let row = editor.currentRoles.indices.first { editor.buttonRowShape(atRole: $0) != nil }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: row), length: 0)
        editor.insertInlineButton(button("Go"))
        XCTAssertEqual(editor.document.blocks.count, 2)
        XCTAssertNil(editor.document.blocks[1].asParagraph?.runs.first?.attributes.button, "unchanged")
    }
}
