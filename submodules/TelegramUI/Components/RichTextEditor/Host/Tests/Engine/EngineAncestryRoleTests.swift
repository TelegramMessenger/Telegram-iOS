import XCTest
import RichTextEditorCore
import RichTextEditorUIKit
@testable import RichTextEngineEditor

/// The role model of the nesting design (spec §3): a role is an ancestry plus a position, an engine
/// block belongs to quote Q iff Q is in its ancestry, and the regroup is a stack walk over ancestries.
@available(iOS 18.4, *)
final class EngineAncestryRoleTests: XCTestCase {
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: text.isEmpty ? [] : [TextRun(text: text)]))
    }
    private func shape(_ id: String) -> EngineBlockShape { .paragraph(ParagraphShape(id: BlockID(id))) }
    private let q = QuoteShape(id: BlockID("q"))
    private let q2 = QuoteShape(id: BlockID("q2"))

    func test_aChildIsAStandaloneBlockWithinItsQuote() {
        let role = EngineBlockRole.standalone(shape("c"), within: [.blockQuote(q)])
        XCTAssertEqual(role.innermostAncestor?.quote, q)
        XCTAssertEqual(role.containerDepth, 1)
        XCTAssertTrue(role.isWithin(BlockID("q")))
        XCTAssertEqual(role.blockID, BlockID("c"))
        XCTAssertEqual(role.containerID, BlockID("c"), "the immediate container is the block itself (spec §3.1)")
        XCTAssertNil(role.secondaryKind)
        XCTAssertEqual(EngineBlockRole.standalone(shape("c"), within: []).containerDepth, 0)
    }

    func test_theAuthorLineSharesItsQuotesAncestry() {
        let line = EngineBlockRole.secondary(owner: .blockQuote(q), line: BlockID("q#author"),
                                             kind: .blockQuoteAuthor, within: [.blockQuote(q)])
        XCTAssertEqual(line.innermostAncestor?.quote, q, "spec §3.2: the author line ends in its own quote")
        XCTAssertEqual(line.containerID, BlockID("q"))
        XCTAssertEqual(line.secondaryKind, .blockQuoteAuthor)
    }

    func test_replacingShapeAndWithinKeepTheOtherHalf() {
        let role = EngineBlockRole.standalone(shape("c"), within: [.blockQuote(q)])
        let restyled = role.replacingShape(.paragraph(ParagraphShape(id: BlockID("c"), style: .heading1)))
        XCTAssertEqual(restyled.ancestry, role.ancestry)
        XCTAssertEqual(restyled.shape.paragraph?.style, .heading1)
        let lifted = role.within([])
        XCTAssertEqual(lifted.position, role.position)
        XCTAssertEqual(lifted.containerDepth, 0)
    }

    func test_nestedQuotesRegroupByAncestryWithAnAuthorAtEachLevel() {
        let inner: [EngineAncestor] = [.blockQuote(q), .blockQuote(q2)]
        let roles: [EngineBlockRole] = [
            .standalone(shape("a"), within: [.blockQuote(q)]),
            .standalone(shape("b"), within: inner),
            .secondary(owner: .blockQuote(q2), line: BlockID("q2#author"), kind: .blockQuoteAuthor, within: inner),
            .standalone(shape("c"), within: [.blockQuote(q)]),
            .secondary(owner: .blockQuote(q), line: BlockID("q#author"), kind: .blockQuoteAuthor, within: [.blockQuote(q)]),
            .standalone(shape("d"), within: []),
        ]
        let blocks = [para("a", "a"), para("b", "b"), para("q2#author", "Inner"),
                      para("c", "c"), para("q#author", "Outer"), para("d", "d")]
        let document = EngineBlockRole.document(roles: roles, blocks: blocks)
        XCTAssertEqual(document.blocks, [
            .blockQuote(BlockQuote(id: BlockID("q"), children: [
                para("a", "a"),
                .blockQuote(BlockQuote(id: BlockID("q2"), children: [para("b", "b")], author: [TextRun(text: "Inner")])),
                para("c", "c"),
            ], author: [TextRun(text: "Outer")])),
            para("d", "d"),
        ])
    }

    func test_aTableInsideAQuoteRegroupsAtItsLevel() {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
                               rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("cell"))])])
        let shape = TableShape(table)
        let roles: [EngineBlockRole] = [
            .standalone(self.shape("a"), within: [.blockQuote(q)]),
            .tableCell(table: shape, row: 0, column: 0, cell: BlockID("cell"), within: [.blockQuote(q)]),
            .standalone(self.shape("c"), within: [.blockQuote(q)]),
        ]
        let blocks = [para("a", "a"), para("cell", "x"), para("c", "c")]
        let document = EngineBlockRole.document(roles: roles, blocks: blocks)
        guard document.blocks.count == 1, case let .blockQuote(quote) = document.blocks[0] else {
            return XCTFail("\(document.blocks)")
        }
        XCTAssertEqual(quote.children.count, 3)
        guard case let .table(back) = quote.children[1] else { return XCTFail("\(quote.children)") }
        XCTAssertEqual(back.rows[0].cells[0].blocks.first?.flatText, "x")
    }

    func test_twoSameIdQuotesSeparatedByABlockStayTwo() {
        let roles: [EngineBlockRole] = [
            .standalone(shape("a"), within: [.blockQuote(q)]),
            .standalone(shape("p"), within: []),
            .standalone(shape("b"), within: [.blockQuote(q)]),
        ]
        let document = EngineBlockRole.document(roles: roles, blocks: [para("a", "a"), para("p", "p"), para("b", "b")])
        XCTAssertEqual(document.blocks.count, 3)
        guard case .blockQuote = document.blocks[0], case .paragraph = document.blocks[1],
              case .blockQuote = document.blocks[2] else { return XCTFail("\(document.blocks)") }
    }

    func test_commonAncestryIsTheLongestCommonPrefixById() {
        let a: [EngineAncestor] = [.blockQuote(q), .blockQuote(q2)]
        let b: [EngineAncestor] = [.blockQuote(q), .blockQuote(QuoteShape(id: BlockID("other")))]
        XCTAssertEqual(RichTextEngineEditorView.commonAncestry(a, b).map(\.id), [BlockID("q")])
        XCTAssertEqual(RichTextEngineEditorView.commonAncestry(a, []).count, 0)
        XCTAssertEqual(RichTextEngineEditorView.commonAncestry(a, a).count, 2)
    }

    // MARK: R7-details §3.1/§3.3/§3.4 — a second container kind

    private func detailsShape(_ id: String, expanded: Bool = true) -> DetailsShape {
        DetailsShape(id: BlockID(id), expanded: expanded, foldedChildren: [])
    }

    func test_anAncestryMayInterleaveQuotesAndDetails() {
        let role = EngineBlockRole.standalone(shape("p"), within: [
            .blockQuote(q),
            .details(detailsShape("d")),
            .blockQuote(q2),
        ])
        XCTAssertEqual(role.containerDepth, 3, "containerDepth counts CONTAINERS, of either kind")
        XCTAssertTrue(role.isWithin(BlockID("d")))
        XCTAssertEqual(role.innermostAncestor?.id, BlockID("q2"))
    }

    // MARK: - Depth counts CONTAINERS; the quote affordances count QUOTES

    /// The distinction `containerDepth` was renamed for, and the three affordances that exist so a
    /// caller never has to make it by hand. Nothing pinned them before this: the raw depth had a name
    /// claiming to count quotes, so the reads that meant quotes used IT and were wrong the moment a
    /// details existed.
    func test_aDetailsCountsTowardTheContainerDepthButNotTheQuoteCount() {
        let role = EngineBlockRole.standalone(shape("p"), within: [
            .blockQuote(q),
            .details(detailsShape("d")),
            .blockQuote(q2),
        ])
        XCTAssertEqual(role.containerDepth, 3, "three containers")
        XCTAssertEqual(role.enclosingQuoteCount, 2, "but only two of them are quotes")
        XCTAssertTrue(role.isInsideAQuote)
        XCTAssertEqual(role.innermostEnclosingQuote, q2)
    }

    /// The exact shape that broke three reads: inside a details and inside NO quote. Asked as a
    /// depth it answers 1 and every quote-shaped consumer believes it — the host's quote-level
    /// control reported 1, `unwrapBlockQuoteLevel`'s "None" un-DETAILED the block, and the
    /// quote-sized 15pt mapper was chosen for a body that is in no quote at all.
    func test_aRoleInsideADetailsAloneIsInsideNoQuote() {
        let role = EngineBlockRole.standalone(shape("p"), within: [.details(detailsShape("d"))])
        XCTAssertEqual(role.containerDepth, 1, "one container")
        XCTAssertEqual(role.enclosingQuoteCount, 0, "and it is not a quote")
        XCTAssertFalse(role.isInsideAQuote)
        XCTAssertNil(role.innermostEnclosingQuote)
    }

    /// The innermost QUOTE skips whatever is nested inside it — a quote holding a details holding
    /// this block is still the quote this block is in.
    func test_theInnermostEnclosingQuoteSkipsANonQuoteBetween() {
        let role = EngineBlockRole.standalone(shape("p"), within: [
            .blockQuote(q),
            .details(detailsShape("d")),
        ])
        XCTAssertEqual(role.innermostAncestor?.id, BlockID("d"), "the container it is DIRECTLY in")
        XCTAssertEqual(role.innermostEnclosingQuote, q, "but the quote it is IN is still q")
        XCTAssertEqual(role.enclosingQuoteCount, 1)
    }

    /// `innermostQuote` returned nil the moment a non-quote ancestor was innermost, which is why the
    /// membership reads move to the kind-agnostic `innermostAncestor`.
    func test_theInnermostAncestorIsFoundWhateverKindItIs() {
        let inDetails = EngineBlockRole.standalone(shape("p"), within: [
            .blockQuote(q),
            .details(detailsShape("d")),
        ])
        XCTAssertEqual(inDetails.innermostAncestor?.id, BlockID("d"))
        XCTAssertNil(inDetails.innermostAncestor?.quote, "…and it is not a quote")
        XCTAssertEqual(inDetails.innermostAncestor?.details?.id, BlockID("d"))
    }

    /// A details contributes NOTHING to the indent its children sit at (§3.4): legacy indents only
    /// the title's glyphs, and the body sits flush.
    func test_aDetailsContributesNoContentIndent() {
        let sheet = StyleSheet()
        XCTAssertEqual(EngineAncestor.blockQuote(q).contentIndent(styleSheet: sheet),
                       sheet.quoteIndent, accuracy: 0.001)
        XCTAssertEqual(EngineAncestor.details(detailsShape("d")).contentIndent(styleSheet: sheet),
                       0.0, accuracy: 0.001)
        let role = EngineBlockRole.standalone(shape("p"), within: [.blockQuote(q), .details(detailsShape("d"))])
        XCTAssertEqual(role.contentIndent(styleSheet: sheet), sheet.quoteIndent, accuracy: 0.001,
                       "ONE quoteIndent for the quote; the details adds nothing")
    }
}
