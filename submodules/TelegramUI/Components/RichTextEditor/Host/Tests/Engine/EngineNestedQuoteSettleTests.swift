import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Nesting design §7: a fresh block inherits its predecessor's ancestry (an author line's tail takes
/// the quote's parent), and author-line presence is decided per quote, over what is within it.
@available(iOS 18.4, *)
final class EngineNestedQuoteSettleTests: XCTestCase {
    private var window: UIWindow!
    private var editor: RichTextEngineEditorView!
    override func setUp() {
        super.setUp()
        editor = RichTextEngineEditorView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.addSubview(editor); window.makeKeyAndVisible()
    }
    override func tearDown() { window.isHidden = true; window = nil; editor = nil; super.tearDown() }
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func quote(_ id: String, _ children: [Block], author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind = role.secondaryKind.map { "\($0)" } ?? "p"
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }

    func test_returnAtTheEndOfAnInnerAuthorLineOpensAParagraphInTheOuterQuote() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two")], author: "In"), para("c", "three")])])
        // one 0..3 | two 4..7 | In 8..10 | three 11..16 | q author 17
        caret(10)
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@2", "p@1", "p@1", "blockQuoteAuthor@1"], "the tail is a paragraph in the quote's PARENT (§7.1)")
        XCTAssertEqual(strings(), ["one", "two", "In", "", "three", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 11, length: 0))
    }

    func test_returnMidAnInnerAuthorLineCarriesTheRestIntoTheOuterQuote() {
        load([quote("q", [quote("q2", [para("b", "two")], author: "Inner")])])
        // two 0..3 | Inner 4..9 | q author 10
        caret(6)   // In|ner
        editor.engine.insertText("\n")
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["two", "In", "ner", ""])
        guard case let .blockQuote(outer)? = editor.document.blocks.first, outer.children.count == 2,
              case let .blockQuote(inner) = outer.children[0] else { return XCTFail("\(editor.document.blocks)") }
        XCTAssertEqual(inner.author.map(\.text).joined(), "In")
        XCTAssertEqual(outer.children[1].flatText, "ner")
    }

    func test_emptyingTheInnerQuotesTextRemovesOnlyItsAuthorLine() {
        load([quote("q", [para("a", "one"), quote("q2", [para("b", "two")])])])
        // one 0..3 | two 4..7 | q2 author 8 | q author 9
        editor.engineSelectedRange = NSRange(location: 4, length: 3)
        editor.engine.deleteBackward()
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@1"], "q2 has nothing quoted; q still has 'one'")
        XCTAssertEqual(strings(), ["one", "", ""])
    }

    /// The OUTER quote's line is there from the start and stays: it holds a nested quote, and a
    /// child is content whatever its text (2026-09-11). Only the inner's line is typed into being.
    func test_typingIntoAnEmptyInnerQuoteGivesItAnAuthorLine() {
        load([quote("q", [quote("q2", [para("b", "")])])])
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@1"],
                       "the inner holds one empty paragraph; the outer holds the inner")
        caret(0)
        editor.engine.insertText("x")
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"],
                       "the inner now holds text too, so its own line joins below it")
        XCTAssertEqual(strings(), ["x", "", ""])
    }

    func test_aBypassSplitInsideANestedChildIsDeclaredAtTheSameDepth() {
        load([quote("q", [quote("q2", [para("b", "two")])])])
        // two 0..3 | q2 author 4 | q author 5
        caret(1)
        // The controller's own insert bypasses the gate — a dictation commit's shape.
        let controller = editor.engine.value(forKey: "id_behaviorInput") as AnyObject
        _ = controller.perform(#selector(UIKeyInput.insertText(_:)), with: "\n")
        XCTAssertEqual(roles(), ["p@2", "p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["t", "wo", "", ""])
    }
}
