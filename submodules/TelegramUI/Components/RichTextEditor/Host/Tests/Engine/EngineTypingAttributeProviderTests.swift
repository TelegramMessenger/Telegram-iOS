import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

@available(iOS 18.4, *)
final class EngineTypingAttributeProviderTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 320))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }

    func test_theProviderAnswersByRoleNotByAPushedMap() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 2, columns: 1))])
        XCTAssertNotNil(editor.engine.id_emptyLineAttributesProvider)
        XCTAssertNil(editor.engine.id_emptyLineAttributesByBlock, "nothing is pushed any more")
        let ids = editor.engine.tgid_blockIdentifiers
        let header = editor.engine.id_emptyLineAttributesProvider!(ids[0])
        let body = editor.engine.id_emptyLineAttributesProvider!(ids[1])
        XCTAssertTrue((header?[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        XCTAssertFalse((body?[.font] as? UIFont)?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true)
        XCTAssertEqual((body?[.font] as? UIFont)?.pointSize, StyleSheet.tableCells.metrics.body.size)
    }

    func test_anIdentityTheHostDoesNotKnowAnswersNil() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), style: .body))])
        XCTAssertNil(editor.engine.id_emptyLineAttributesProvider!(UUID()))
    }

    func test_anEmptyPullQuoteAuthorsCaretOffsetIsHalfThePromptWidth() {
        editor.document = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "quoted")], author: []))])
        let ids = editor.engine.tgid_blockIdentifiers
        XCTAssertEqual(ids.count, 2, "body + author line")
        let offset = editor.engine.id_emptyLineCaretOffsetProvider!(ids[1])?.doubleValue ?? 0
        XCTAssertLessThan(offset, -10, "a centred prompt: the caret starts at its left edge")
        XCTAssertNil(editor.engine.id_emptyLineCaretOffsetProvider!(ids[0]))
    }

    func test_typingIntoAnEmptyHeaderCellIsBoldThroughTheProvider() {
        editor.document = Document(blocks: [.table(TableBlock.empty(rows: 2, columns: 2))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.engine.insertText("F")
        let font = editor.engine.attributedBlocks[0].attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
    }

    // MARK: re-adoption after a set that moves no caret

    private func face(_ attributes: [NSAttributedString.Key: Any]) -> String {
        let font = attributes[.font] as? UIFont
        let alignment = (attributes[.paragraphStyle] as? NSParagraphStyle)?.alignment ?? .natural
        return "\(font?.familyName ?? "-")/\(font?.pointSize ?? 0)/\(alignment.rawValue)"
    }
    private func typedFace(_ index: Int) -> String {
        let block = editor.engine.attributedBlocks[index]
        guard block.length > 0 else { return "empty" }
        return face(block.attributes(at: 0, effectiveRange: nil))
    }

    func test_aPullQuoteMadeFromAnEmptyParagraphTypesInThePullQuotesFace() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("\n")
        editor.makePullQuote()
        let expected = face(editor.bridge.lineAttributes(for: editor.currentRoles[1]))
        editor.engine.insertText("q")
        XCTAssertEqual(typedFace(1), expected, "the command changed the role without moving the caret; typing must still take the new role's face")
    }

    func test_aDissolvedCodeBlockTurnedPullQuoteDoesNotTypeInTheCodesFace() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("\n")
        editor.makeCodeBlock()
        editor.engine.deleteBackward()   // dissolves the empty code block; same id, same (empty) text
        editor.makePullQuote()
        let expected = face(editor.bridge.lineAttributes(for: editor.currentRoles[1]))
        editor.engine.insertText("q")
        XCTAssertEqual(typedFace(1), expected, "measured on device: the code block's adopted face survived two role changes")
    }

    /// Reported from the device after the structure-only roles change: a fresh code block's FIRST
    /// line typed in the body face while the second (after a Return) took the code face.
    func test_aCodeBlockMadeFromAnEmptyParagraphTypesInTheCodesFaceOnItsFirstLine() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0"), runs: [TextRun(text: "before")]))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 6, length: 0)
        editor.engine.insertText("\n")
        editor.makeCodeBlock()
        XCTAssertEqual(editor.currentRoles.count, 3, "p0, the language line, the code body")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0), "the caret opens the code body")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 8, length: 0), "and stays there across a run-loop turn")
        let expected = face(editor.bridge.lineAttributes(for: editor.currentRoles[2]))
        editor.engine.insertText("x")
        XCTAssertEqual(typedFace(2), expected, "the first line of a fresh code block types in the code face")
        editor.engine.insertText("\n")
        editor.engine.insertText("y")
        let second = editor.engine.attributedBlocks[2]
        XCTAssertEqual(face(second.attributes(at: 2, effectiveRange: nil)), expected, "and so does the second")
    }

    func test_aCodeBlockMadeInAnEmptyFieldTypesInTheCodesFace() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0")))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.makeCodeBlock()
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "the caret opens the code body")
        let expected = face(editor.bridge.lineAttributes(for: editor.currentRoles[1]))
        // The chat composer writes the document and the selection back after every change, and the
        // next keystroke comes a run-loop turn later.
        editor.document = editor.document
        editor.composerSelectedRange = editor.composerSelectedRange
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "and stays there")
        editor.engine.insertText("x")
        XCTAssertEqual(typedFace(1), expected)
    }

    /// The chat composer's content round trip re-mints the code block's id, so its write-back is a
    /// real span replace through the storage, not a no-op set; the controller's own caret
    /// bookkeeping after such a replace runs on a later turn.
    func test_aCodeBlockReplacedWithANewIdByTheComposerKeepsTheCaretInItsBody() {
        editor.document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("p0")))])
        XCTAssertTrue(editor.engine.becomeFirstResponder())
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.makeCodeBlock()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        editor.document = Document(blocks: [.code(CodeBlock(id: BlockID(UUID().uuidString), language: nil, runs: []))])
        editor.composerSelectedRange = NSRange(location: 0, length: 0)
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "the caret opens the code body")
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 1, length: 0), "and stays there across a run-loop turn")
        let expected = face(editor.bridge.lineAttributes(for: editor.currentRoles[1]))
        editor.engine.insertText("x")
        XCTAssertEqual(editor.engine.attributedBlocks.map(\.string), ["", "x"])
        XCTAssertEqual(typedFace(1), expected)
    }
}
