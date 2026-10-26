import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// R7-collapse §3.2 and §7. A folded quote's body lives on the SHAPE, and an expanded one's does
/// not — the "no two sources of truth hold the same text" rule, which is `DetailsShape`'s and is
/// what makes the round trip lossless in both states.
@available(iOS 18.4, *)
final class EngineQuoteCollapseRoundTripTests: XCTestCase {
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
    private func quote(_ id: String, _ children: [Block],
                       collapsed: Bool = false, author: String = "") -> Block {
        .blockQuote(BlockQuote(id: BlockID(id), children: children, collapsed: collapsed,
                               author: author.isEmpty ? [] : [TextRun(text: author)]))
    }
    private func load(_ blocks: [Block]) {
        editor.document = Document(blocks: blocks)
        XCTAssertTrue(editor.engine.becomeFirstResponder())
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }

    func test_aCollapsedQuotePutsItsBodyAndAuthorOnTheShape() {
        let quote = BlockQuote(id: BlockID("q"), children: [para("a", "one")],
                               collapsed: true, author: [TextRun(text: "Ada")])
        let shape = QuoteShape(quote)
        XCTAssertTrue(shape.collapsed)
        XCTAssertEqual(shape.foldedChildren.count, 1)
        XCTAssertEqual(shape.foldedChildren.first?.asParagraph?.runs.first?.text, "one")
        XCTAssertEqual(shape.author.first?.text, "Ada")
    }

    func test_anExpandedQuotePutsNeitherOnTheShape() {
        let quote = BlockQuote(id: BlockID("q"), children: [para("a", "one")],
                               collapsed: false, author: [TextRun(text: "Ada")])
        let shape = QuoteShape(quote)
        XCTAssertFalse(shape.collapsed)
        XCTAssertTrue(shape.foldedChildren.isEmpty,
                      "an expanded quote's children are on the ENGINE's axis; a copy here would drift")
        XCTAssertTrue(shape.author.isEmpty,
                      "an expanded quote's author is its #author secondary line, not the shape")
    }

    func test_aCollapsedQuoteIsOneEngineBlockAndIsNotAnAncestor() {
        load([quote("q", [para("a", "one"), para("b", "two")], collapsed: true, author: "Ada")])
        XCTAssertEqual(editor.currentRoles.count, 1, "one atom, no children, no author line")
        guard case let .standalone(.collapsedQuote(shape)) = editor.currentRoles[0].position else {
            return XCTFail("not a collapsed-quote atom: \(editor.currentRoles[0].position)")
        }
        XCTAssertEqual(shape.id, BlockID("q"))
        XCTAssertTrue(editor.currentRoles[0].ancestry.isEmpty,
                      "a folded quote LEAVES the ancestry — it is a leaf, not a container")
        XCTAssertEqual(strings(), ["\u{FFFC}"], "the atom is one attachment character")
    }

    func test_aCollapsedQuoteReadsBackWithItsBodyAndAuthorIntact() {
        load([quote("q", [para("a", "one"), para("b", "two")], collapsed: true, author: "Ada")])
        guard case let .blockQuote(read) = editor.document.blocks[0] else { return XCTFail("not a quote") }
        XCTAssertTrue(read.collapsed)
        XCTAssertEqual(read.children.count, 2)
        XCTAssertEqual(read.children.first?.asParagraph?.runs.first?.text, "one")
        XCTAssertEqual(read.children.last?.asParagraph?.runs.first?.text, "two")
        XCTAssertEqual(read.author.first?.text, "Ada")
    }

    func test_anExpandedQuoteIsUnchangedByThisRung() {
        load([quote("q", [para("a", "one")], author: "Ada")])
        XCTAssertEqual(strings(), ["one", "Ada"], "child then author line, exactly as before")
        XCTAssertEqual(editor.currentRoles[0].ancestry.count, 1, "still an ancestor when open")
    }

    func test_aCollapsedQuoteInsideAnOpenOneKeepsTheOuterAncestry() {
        load([quote("outer", [para("a", "top"), quote("inner", [para("b", "deep")], collapsed: true)])])
        guard let atom = editor.currentRoles.firstIndex(where: {
            if case .standalone(.collapsedQuote) = $0.position { return true }
            return false
        }) else { return XCTFail("no folded atom") }
        XCTAssertEqual(editor.currentRoles[atom].ancestry.map(\.id), [BlockID("outer")],
                       "the OUTER quote still encloses it; only the folded one leaves")
    }

    func test_aCollapsedQuoteInsideADetailsRoundTrips() {
        load([.details(DetailsBlock(id: BlockID("d"), title: [TextRun(text: "T")],
                                    children: [quote("q", [para("a", "one")], collapsed: true)],
                                    expanded: true))])
        guard case let .details(read) = editor.document.blocks[0],
              case let .blockQuote(inner) = read.children.first else {
            return XCTFail("shape lost: \(editor.document.blocks)")
        }
        XCTAssertTrue(inner.collapsed)
        XCTAssertEqual(inner.children.first?.asParagraph?.runs.first?.text, "one")
    }
}
