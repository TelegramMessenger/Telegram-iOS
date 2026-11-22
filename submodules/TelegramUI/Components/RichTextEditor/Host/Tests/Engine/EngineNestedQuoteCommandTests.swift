import XCTest
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// Nesting design §8: Quote toggles — the deepest quote every touched block shares is dissolved,
/// otherwise the touched top-level units are wrapped (so a selection across a quote and a neighbour
/// nests it); unwrapBlockQuoteLevel lifts the caret's innermost quote; blockQuoteDepth is real.
@available(iOS 18.4, *)
final class EngineNestedQuoteCommandTests: XCTestCase {
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
    private func table(_ id: String) -> Block {
        .table(TableBlock(id: BlockID(id), columns: [ColumnSpec(width: 100)],
                          rows: [Row(id: BlockID("\(id)r"), cells: [Cell(id: BlockID("\(id)a"), blocks: [para("\(id)ap", "a")])])]))
    }
    private func roles() -> [String] {
        editor.currentRoles.map { role in
            let kind: String
            if role.owningTable != nil { kind = "cell" }
            else if let secondary = role.secondaryKind { kind = "\(secondary)" }
            else { kind = "p" }
            return "\(kind)@\(role.containerDepth)"
        }
    }
    private func strings() -> [String] { editor.engine.attributedBlocks.map(\.string) }
    private func load(_ blocks: [Block]) { editor.document = Document(blocks: blocks); XCTAssertTrue(editor.engine.becomeFirstResponder()) }
    private var nested: [Block] { [quote("q", [para("a", "one"), quote("q2", [para("b", "two")]), para("c", "three")])] }
    // nested on the engine axis: one 0..3 | two 4..7 | q2 author 8 | three 9..14 | q author 15

    func test_quoteWrapsThenTogglesBackOff() {
        load([para("a", "one"), para("b", "two")])
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@1", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0), "caret at the start of the first wrapped block")
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@0", "p@0"], "every touched block shared the quote: it is dissolved, author line and all")
        XCTAssertEqual(strings(), ["one", "two"])
    }

    func test_quoteInsideANestedQuoteDissolvesTheInnerOnly() {
        load(nested)
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["one", "two", "three", ""])
    }

    func test_quoteAcrossAQuoteAndItsNeighbourNestsTheQuote() {
        load([quote("q", [para("a", "one")]), para("p", "two")])
        // one 0..3 | q author 4 | two 5..8
        editor.engineSelectedRange = NSRange(location: 0, length: 7)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"], "the old quote is a child of the new one")
        XCTAssertEqual(strings(), ["one", "", "two", ""])
        // The primary caret lookup (by the FIRST wrapped block's own id) misses here: the first
        // wrapped top-level unit IS a quote, which is never a role's `blockID` (it lives in
        // `ancestry`) and whose only role with a matching `containerID` is its author line —
        // excluded by `secondaryKind == nil`. The fallback lands on the first role now within the
        // new outer quote instead: "one", at the very start.
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 0, length: 0), "caret at the start of \"one\", not stranded on the new quote's own author line")
        guard case let .blockQuote(outer)? = editor.document.blocks.first, outer.children.count == 2,
              case .blockQuote = outer.children[0] else { return XCTFail("\(editor.document.blocks)") }
    }

    /// Two DIFFERENT top-level quotes: the selection touches both, so BOTH become children of the
    /// one new outer quote — the general form of "a selection across a quote and a neighbour nests
    /// the quote" when the neighbour is ALSO a quote, not a plain paragraph.
    func test_quoteAcrossTwoDifferentTopLevelQuotesWrapsBoth() {
        load([quote("q1", [para("a", "one")]), quote("q2", [para("b", "two")])])
        // one 0..3 | q1 author 4 | two 5..8 | q2 author 9
        editor.engineSelectedRange = NSRange(location: 0, length: 8)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@2", "blockQuoteAuthor@2", "p@2", "blockQuoteAuthor@2", "blockQuoteAuthor@1"])
        guard case let .blockQuote(outer)? = editor.document.blocks.first, outer.children.count == 2,
              case .blockQuote = outer.children[0], case .blockQuote = outer.children[1] else {
            return XCTFail("\(editor.document.blocks)")
        }
    }

    func test_quoteOverAWholeTableWrapsIt() {
        load([para("a", "one"), table("t"), para("c", "three")])
        // one 0..3 | cell a 4..5 | three 6..11
        editor.engineSelectedRange = NSRange(location: 0, length: 8)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@1", "cell@1", "p@1", "blockQuoteAuthor@1"])
        guard case let .blockQuote(quote)? = editor.document.blocks.first, quote.children.count == 3,
              case .table = quote.children[1] else { return XCTFail("\(editor.document.blocks)") }
    }

    func test_quoteIsRefusedFromInsideACell() {
        load([para("a", "one"), table("t")])
        editor.engineSelectedRange = NSRange(location: 4, length: 1)
        let before = roles()
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), before, "an endpoint inside a cell: refused, as legacy refuses")
    }

    func test_blockQuoteDepthIsTheCaretsDepth() {
        load(nested)
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        XCTAssertEqual(editor.currentState().blockQuoteDepth, 1)
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        XCTAssertEqual(editor.currentState().blockQuoteDepth, 2)
        editor.engineSelectedRange = NSRange(location: 8, length: 0)
        XCTAssertEqual(editor.currentState().blockQuoteDepth, 2, "the inner author line is inside the inner quote")
    }

    func test_unwrapBlockQuoteLevelLiftsTheInnermostQuoteAndUndoRestoresIt() {
        load(nested)
        editor.engineSelectedRange = NSRange(location: 4, length: 0)
        editor.unwrapBlockQuoteLevel()
        XCTAssertEqual(roles(), ["p@1", "p@1", "p@1", "blockQuoteAuthor@1"])
        XCTAssertEqual(strings(), ["one", "two", "three", ""])
        XCTAssertEqual(editor.engineSelectedRange, NSRange(location: 4, length: 0))
        editor.engine.undoManager?.undo()
        XCTAssertEqual(strings(), ["one", "two", "", "three", ""], "undo brings the inner quote's author line back")
        XCTAssertEqual(roles(), ["p@1", "p@2", "blockQuoteAuthor@2", "p@1", "blockQuoteAuthor@1"], "…and the roles")
    }

    func test_unwrapBlockQuoteLevelAtTopLevelIsANoOp() {
        load([para("a", "one")])
        editor.engineSelectedRange = NSRange(location: 0, length: 0)
        editor.unwrapBlockQuoteLevel()
        XCTAssertEqual(roles(), ["p@0"])
    }

    /// Controller ruling: the author line's own ancestry ends in its own quote, so a caret parked
    /// there ALONE toggles the quote OFF rather than doing nothing (spec §8.1).
    func test_quoteToggleWithTheCaretInTheAuthorLineAloneUnwrapsTheQuote() {
        load([quote("q", [para("a", "one"), para("b", "two")], author: "Ada")])
        guard let line = editor.currentRoles.firstIndex(where: { $0.secondaryKind == .blockQuoteAuthor }) else {
            return XCTFail("no author line: \(editor.currentRoles.map(\.secondaryKind))")
        }
        editor.engineSelectedRange = NSRange(location: editor.flatOffset(ofRoleAt: line), length: 0)
        editor.wrapInBlockQuote()
        XCTAssertEqual(roles(), ["p@0", "p@0"], "the quote dissolved, author line and all")
        XCTAssertEqual(strings(), ["one", "two"])
    }

    // MARK: §3.1 a ••• verb keeps a quoted medium in its quote

    private func photo(_ id: String) -> Block {
        .media(MediaBlock(id: BlockID(id), items: [MediaItem(mediaID: "m-\(id)", kind: .image, naturalSize: Size2D(width: 1000, height: 500))]))
    }

    /// `applyMediaShape` rewrites the atom's role and its caption's on every ••• verb. Built through
    /// the FACTORY those two roles come back at top level, which reads as nothing at all until the
    /// document is regrouped and the medium has silently left its quote — the roles are the only
    /// record of the nesting. The second half of the same line is the atom's own indent: rendered at
    /// depth 0 the re-derived attachment would take the whole column back.
    func test_aMediaVerbOnAQuotedMediumKeepsItInItsQuoteAndItsIndent() {
        editor.mediaBlockStyle = MediaBlockStyle(horizontalBleed: 0)
        load([quote("q", [photo("ph")])])
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(roles(), ["p@1", "mediaCaption@1", "blockQuoteAuthor@1"])
        let before = editor.engine.id_attachmentFrame(forCanonicalOffset: UInt(editor.flatOffset(ofRoleAt: 0)))

        editor.toggleMediaSpoiler(blockID: BlockID("ph"), itemIndex: nil)

        XCTAssertEqual(roles(), ["p@1", "mediaCaption@1", "blockQuoteAuthor@1"], "still inside the quote")
        XCTAssertTrue(editor.currentRoles[0].isWithin(BlockID("q")))
        guard case let .blockQuote(quote) = editor.document.blocks.first, case .media = quote.children.first else {
            return XCTFail("the medium left its quote: \(editor.document.blocks)")
        }
        editor.setNeedsLayout(); editor.layoutIfNeeded()
        XCTAssertEqual(editor.engine.id_attachmentFrame(forCanonicalOffset: UInt(editor.flatOffset(ofRoleAt: 0))), before,
                       "\u{2026}and the attachment the verb re-derived still carries the quote's indent")
    }
}
