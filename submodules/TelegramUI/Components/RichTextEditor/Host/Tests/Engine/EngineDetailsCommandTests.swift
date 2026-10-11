import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-details §8: the Detail Block menu item performs, landing a details wherever the caret is, and
/// every container rule counts it as one.
@available(iOS 18.4, *)
final class EngineDetailsCommandTests: XCTestCase {
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
    private func details(_ id: String, title: String, _ children: [Block]) -> Block {
        .details(DetailsBlock(id: BlockID(id), title: [TextRun(text: title)], children: children, expanded: true))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind = role.secondaryKind.map { "\($0)" } ?? (role.owningTable != nil ? "cell" : "p")
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func caret(_ at: Int) { editor.engineSelectedRange = NSRange(location: at, length: 0) }
    private func titleDepth() -> Int? {
        editor.currentRoles.first { $0.secondaryKind == .detailsTitle }?.containerDepth
    }

    func test_insertingADetailsAtAnEmptyParagraphReplacesIt() {
        load([para("p", "")])
        caret(0)
        editor.insertDetailsBlock()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"], "a title and one empty body child")
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0), "caret in the title")
    }

    func test_insertingADetailsAfterANonEmptyParagraphFollowsIt() {
        load([para("p", "text")])
        caret(4)
        editor.insertDetailsBlock()
        XCTAssertEqual(roles(), ["p@0", "detailsTitle@1", "p@1"])
        XCTAssertEqual(strings(), ["text", "", ""])
    }

    func test_insertingADetailsMidParagraphSplitsIt() {
        load([para("p", "abcd")])
        caret(2)
        editor.insertDetailsBlock()
        XCTAssertEqual(strings(), ["ab", "", "", "cd"], "head, title, empty body, tail")
        XCTAssertEqual(roles(), ["p@0", "detailsTitle@1", "p@1", "p@0"])
    }

    func test_insertingADetailsAtTheStartOfAParagraphPutsItBefore() {
        load([para("p", "text")])
        caret(0)
        editor.insertDetailsBlock()
        XCTAssertEqual(strings(), ["", "", "text"])
    }

    /// Decision 3: anywhere a table may go — including inside a quote, which legacy refuses.
    func test_insertingADetailsInsideAQuoteNestsIt() {
        load([.blockQuote(BlockQuote(id: BlockID("q"), children: [para("a", "one")]))])
        caret(3)
        editor.insertDetailsBlock()
        XCTAssertEqual(titleDepth(), 2, "the quote plus the details")
    }

    func test_insertingADetailsInsideADetailsNestsIt() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(5)                                   // end of "one", inside the body
        editor.insertDetailsBlock()
        let depths = editor.currentRoles.filter { $0.secondaryKind == .detailsTitle }.map(\.containerDepth)
        XCTAssertEqual(depths.sorted(), [1, 2], "the outer title at 1, the new one at 2")
    }

    /// §8.3: Quote over a details wraps the whole thing, title included.
    func test_quoteOverADetailsWrapsItWhole() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.engineSelectedRange = NSRange(location: 0, length: 5)
        editor.wrapInBlockQuote()
        XCTAssertEqual(titleDepth(), 2, "the details is inside the new quote, not beside it")
    }

    /// §8.2 reaches the same toggle the chevron does.
    func test_theToggleFoldsAndUnfolds() {
        load([details("d", title: "T", [para("a", "one")])])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1"])
        editor.toggleDetailsExpanded(id: BlockID("d"))
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"])
    }

    // MARK: the review wave — `containerDepth` is a COUNT OF CONTAINERS, and three sites still read it
    // as a count of quotes.

    /// `wrapInBlockQuote`'s toggle asked `common.last?.quote` — the exact `ancestry.last?.quote`
    /// shape §3.3 exists to eliminate, surviving at one site. Inside a quoted details the innermost
    /// ancestor is the details, so it read nil, fell into the WRAP branch and nested the quote in a
    /// new one. There was no way to un-quote from inside a details at all.
    func test_quoteToggleInsideAQuotedDetailsUnquotesRatherThanNesting() {
        load([.blockQuote(BlockQuote(id: BlockID("q"),
                                     children: [details("d", title: "T", [para("a", "one")])]))])
        caret(3)                                   // inside "one", at quote > details > paragraph
        editor.wrapInBlockQuote()
        XCTAssertEqual(titleDepth(), 1, "the quote is gone; only the details encloses the title")
    }

    /// The host reads `EditorState.blockQuoteDepth` to drive the quote-level control. Fed
    /// `containerDepth`, it reported 1 for a caret inside a top-level details enclosed by no quote.
    func test_blockQuoteDepthCountsQuotesAndNotContainers() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(3)
        XCTAssertEqual(editor.currentState().blockQuoteDepth, 0, "a details is not a quote")
    }

    /// …and the "None" quote-level verb dissolved whatever container was innermost, so choosing it
    /// with the caret in a details' body un-detailed the block.
    func test_unwrapBlockQuoteLevelLeavesADetailsAlone() {
        load([details("d", title: "T", [para("a", "one")])])
        caret(3)
        editor.unwrapBlockQuoteLevel()
        XCTAssertEqual(roles(), ["detailsTitle@1", "p@1"], "the details is untouched")
    }

    /// Counts over a WINDOW, not a wait: a duplicate landing a run-loop turn later is invisible to a
    /// wait, and the setup's own delivery has to be drained first or every case reads as one more
    /// than it should.
    func test_insertingADetailsDeliversExactlyOneChange() {
        load([para("p", "text")])
        caret(4)
        turn()
        var calls = 0
        editor.onChange = { calls += 1 }
        editor.insertDetailsBlock()
        turn()
        editor.onChange = nil
        XCTAssertEqual(calls, 1)
    }

    private func turn() {
        let expectation = expectation(description: "run loop")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }
}
