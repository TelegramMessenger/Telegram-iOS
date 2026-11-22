import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R9-buttons Task 6 — the three atom Backspace rules, RECORDED before they are generalised over
/// atom kind. Behaviour that already ships; a change here means the generalisation is wrong.
///
/// R7-collapse generalised them over a THIRD kind (a folded block quote) and added the rows at the
/// bottom, which is what this file is for: the same three rules, asked of the new kind, answering
/// the same way. `EngineAtomPlacementGoldenTests` deliberately gained NO row — every case there
/// drives an INSERT verb, and a folded quote is produced by folding an existing quote rather than by
/// any insertion command, so there is nothing of that shape to record.
@available(iOS 18.4, *)
final class EngineAtomBackspaceGoldenTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!

    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
        _ = editor.engine.becomeFirstResponder()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    /// AUDIO is caption-less, so its unit is a single role — the shape a button row has.
    private func audio(_ id: String) -> Block {
        .media(MediaBlock(id: BlockID(id), items: [MediaItem(mediaID: "m-\(id)", kind: .audio,
                                                             naturalSize: Size2D(width: 0, height: 0))]))
    }
    private func atomIndex() -> Int {
        editor.currentRoles.firstIndex { if case .standalone(.media) = $0.position { return true }; return false }!
    }
    private func mediaCount() -> Int {
        editor.document.blocks.reduce(0) { if case .media = $1 { return $0 + 1 }; return $0 }
    }

    func test_aCaretInsideACaptionlessAtomSelectsIt() {
        editor.document = Document(blocks: [audio("a"), para("p", "after")])
        let atom = atomIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: atom) + 1, length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: atom),
                       "press 1 SELECTS rather than deleting")
        XCTAssertEqual(mediaCount(), 1, "nothing is gone yet")
    }

    func test_aSecondPressDeletesTheSelectedAtom() {
        editor.document = Document(blocks: [audio("a"), para("p", "after")])
        let atom = atomIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: atom) + 1, length: 0)
        editor.deleteBackward()
        editor.deleteBackward()
        XCTAssertEqual(mediaCount(), 0, "press 2 deletes it")
    }

    func test_aCaretAtTheStartOfTheBlockAfterAnAtomParksAtTheUnitsEnd() {
        editor.document = Document(blocks: [audio("a"), para("p", "after")])
        let after = editor.currentRoles.firstIndex { $0.containerID == BlockID("p") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.deleteBackward()
        let atom = atomIndex()
        XCTAssertEqual(editor.engineSelectedRange.location,
                       editor.flatOffset(ofRoleAt: atom) + editor.flatLength(ofRoleAt: atom),
                       "press 1 walks INTO the unit; it does not delete")
        XCTAssertEqual(mediaCount(), 1)
    }

    func test_anEmptyParagraphAfterAnAtomIsRemovedByThatSameWalk() {
        editor.document = Document(blocks: [audio("a"), para("p", "")])
        let after = editor.currentRoles.firstIndex { $0.containerID == BlockID("p") }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.document.blocks.count, 1, "the empty paragraph it came from goes with the walk")
    }

    func test_aCaretAtAnAtomsStartTakesAGraphemeFromThePreviousSiblingParagraph() {
        editor.document = Document(blocks: [para("p", "ab"), audio("a")])
        let atom = atomIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: atom), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.document.blocks[0].flatText, "a")
    }

    // MARK: - The same three rules, asked of a FOLDED QUOTE (R7-collapse)

    private func folded(_ id: String) -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: [para("\(id)-body", "hidden")],
                               collapsed: true, author: []))
    }
    private func foldedIndex() -> Int {
        editor.currentRoles.firstIndex { $0.shape.collapsedQuote != nil }!
    }
    private func quoteCount() -> Int {
        editor.document.blocks.reduce(0) { if case .blockQuote = $1 { return $0 + 1 }; return $0 }
    }

    func test_aCaretInsideAFoldedQuoteSelectsIt() {
        editor.document = Document(blocks: [folded("q"), para("p", "after")])
        let atom = foldedIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: atom) + 1, length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: atom),
                       "press 1 SELECTS rather than deleting")
        XCTAssertEqual(quoteCount(), 1, "nothing is gone yet")
    }

    func test_aSecondPressDeletesTheSelectedFoldedQuote() {
        editor.document = Document(blocks: [folded("q"), para("p", "after")])
        let atom = foldedIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: atom) + 1, length: 0)
        editor.deleteBackward()
        editor.deleteBackward()
        XCTAssertEqual(quoteCount(), 0, "press 2 deletes it, hidden body and all")
    }

    func test_aCaretAtTheStartOfTheBlockAfterAFoldedQuoteParksAtTheUnitsEnd() {
        editor.document = Document(blocks: [folded("q"), para("p", "after")])
        let after = editor.currentRoles.firstIndex { $0.containerID == BlockID("p") }!
        let atom = foldedIndex()
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: after), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange,
                       NSRange(location: editor.flatOffset(ofRoleAt: atom)
                               + editor.flatLength(ofRoleAt: atom), length: 0),
                       "parks at the unit's end, exactly as a captionless medium does")
        XCTAssertEqual(quoteCount(), 1)
    }

    func test_aCaretAtAnAtomsStartSelectsAPrecedingAtomInstead() {
        editor.document = Document(blocks: [audio("a"), audio("b")])
        let first = editor.currentRoles.firstIndex { if case .standalone(.media) = $0.position { return true }; return false }!
        let second = editor.currentRoles.lastIndex { if case .standalone(.media) = $0.position { return true }; return false }!
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: second), length: 0)
        editor.deleteBackward()
        XCTAssertEqual(editor.engineSelectedRange, editor.flatRange(ofRoleAt: first))
    }
}
