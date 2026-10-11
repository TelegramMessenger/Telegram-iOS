import XCTest
import UIKit
import RichTextEditorCore
@testable import RichTextEngineEditor

/// A composition over a selection from a quoted list item into the quote's empty author line
/// (composer harness p17, fuzz seed 77, `HarnessCompositionAcrossQuoteEndTests`).
///
/// The composition's selection is decided first as a cross-block deletion, and that deletion minted
/// the quote's author line afresh. The list-continuation sweep took the fresh author line for a
/// paragraph following a list item and scheduled it to inherit the item's membership; the
/// reconciliation's document set then landed between the first two candidates and ended the
/// composition with the first candidate committed (`twمرk漢字` where typing gives `twمر漢字`). Whether
/// the set disturbed the marked text depended on the text (it did for an Arabic item, not a Latin
/// one), so the Latin case is a control for the outcome and the sweep is asserted directly.
@available(iOS 18.4, *)
final class EngineCompositionAcrossQuoteEndTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 360, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 360, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func turn() { RunLoop.main.run(until: Date().addingTimeInterval(0.02)) }

    private func quotedItem(_ text: String) -> Document {
        Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("i"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: text)]))
        ]))])
    }

    private func texts() -> [String] { editor.engine.attributedBlocks.map(\.string) }

    /// Composes `steps` over `range`, one candidate per run-loop turn as a keyboard delivers them.
    private func compose(_ document: Document, select range: NSRange, steps: [String]) -> (texts: [String], markedAfterEachStep: [Bool]) {
        editor.document = document
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        turn()
        editor.engineSelectedRange = range
        turn()
        let input = editor.engine
        var marked: [Bool] = []
        for step in steps {
            input.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
            turn()
            marked.append(input.markedTextRange != nil)
        }
        input.unmarkText()
        turn()
        return (texts(), marked)
    }

    private let japanese = ["k", "か", "かn", "かん", "かんj", "かんじ", "漢字"]

    func test_aCompositionFromAQuotedArabicItemIntoTheAuthorLineStaysMarkedAndLeavesNoCandidate() {
        let result = compose(quotedItem("tw\u{645}\u{631}\u{62D}\u{628}\u{627} "), select: NSRange(location: 4, length: 5), steps: japanese)
        XCTAssertEqual(result.markedAfterEachStep, Array(repeating: true, count: japanese.count), "the composition ended between candidates")
        XCTAssertEqual(result.texts.first, "tw\u{645}\u{631}漢字")
    }

    /// The sweep itself: a fresh author line is a container's own line and continues no list.
    func test_aFreshAuthorLineAfterAQuotedItemIsNotAListContinuation() {
        editor.document = quotedItem("one")
        turn()
        let roles = editor.currentRoles
        XCTAssertEqual(roles.count, 2, "precondition: the item and the author line")
        let author = roles[1].blockID
        let ids = editor.blockIDsNeedingListContinuation(previousIDs: [roles[0].blockID], in: roles)
        XCTAssertFalse(ids.contains(author), "the author line was scheduled to inherit the item's list")
    }

    /// Control: a fresh paragraph after an item in the SAME quote still continues the list.
    func test_controlAFreshSiblingAfterAQuotedItemContinuesTheList() {
        editor.document = Document(blocks: [.blockQuote(BlockQuote(id: BlockID("q"), children: [
            .paragraph(ParagraphBlock(id: BlockID("i"), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "two")])),
        ]))])
        turn()
        let roles = editor.currentRoles
        let fresh = roles[1].blockID
        let ids = editor.blockIDsNeedingListContinuation(previousIDs: [roles[0].blockID], in: roles)
        XCTAssertTrue(ids.contains(fresh))
    }

    func test_controlLatin() {
        let result = compose(quotedItem("hello world"), select: NSRange(location: 6, length: 6), steps: japanese)
        XCTAssertEqual(result.texts.first, "hello 漢字")
    }
}
