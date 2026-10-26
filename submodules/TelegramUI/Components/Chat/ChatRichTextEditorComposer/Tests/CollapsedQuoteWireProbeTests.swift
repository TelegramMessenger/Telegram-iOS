import XCTest
import Foundation
import Postbox
import TelegramCore
import RichTextEditorCore
@testable import ChatRichTextEditorComposer

/// WHERE a folded quote's `collapsed` flag dies on the way to the wire — measured, and pinned so the
/// next person does not re-derive it.
///
/// Reported 2026-09-15 as "sending or editing a folded quote produces no folding". The composer's
/// send chain is
///
///   editor `Document` → `ChatInputContent` → `isEntityExpressible()` → `InstantPage` → Api.PageBlock
///
/// and every client hop preserves the flag. The loss is at the LAST one and is a schema gap rather
/// than a defect in any of this code: `pageBlockBlockquote` carries `collapsed` in its `flags`, but
/// `pageBlockBlockquoteBlocks` — the constructor a quote of two or more blocks MUST use — has no
/// such field (`InstantPage.swift`, `apiInputBlock`). So the flag survives for an empty or
/// single-paragraph quote and is dropped for every other shape, arriving back as `false`.
///
/// Closing it needs `pageBlockBlockquoteBlocks flags:# collapsed:flags.0?true` server-side. Until
/// then these are CHARACTERIZATION tests: they assert what the code does, and the multi-block one
/// documents a known loss rather than blessing a bug. When the schema gains the field, that test
/// should FAIL and be rewritten to assert preservation.
final class CollapsedQuoteWireProbeTests: XCTestCase {
    private func para(_ id: String, _ text: String) -> Block {
        .paragraph(ParagraphBlock(id: BlockID(id), runs: [TextRun(text: text)]))
    }
    private func foldedQuote(children: [Block], author: String = "") -> Document {
        Document(blocks: [.blockQuote(BlockQuote(
            id: BlockID("q"), children: children, collapsed: true,
            author: author.isEmpty ? [] : [TextRun(text: author)]))])
    }
    /// The composer's own send chain, up to the shape the Api encoder branches on.
    private func sent(_ document: Document) -> (collapsed: Bool?, innerBlocks: Int, entityExpressible: Bool) {
        let content = chatInputContent(fromDocument: document, media: [:], emojiFiles: [:])
        let page = instantPage(from: content)
        guard case let .blockQuote(blocks, _, collapsed)? = page.blocks.first else {
            return (nil, -1, content.isEntityExpressible())
        }
        return (collapsed, blocks.count, content.isEntityExpressible())
    }

    /// A folded quote is never entity-expressible, so the composer always takes the RICH path for
    /// one. That is the only path that could carry a fold at all, and it is intact.
    func test_aFoldedQuoteAlwaysTakesTheRichPath() {
        XCTAssertFalse(sent(foldedQuote(children: [para("a", "one")])).entityExpressible)
        XCTAssertFalse(sent(foldedQuote(children: [para("a", "one"), para("b", "two")])).entityExpressible)
    }

    /// Every CLIENT hop preserves the flag, whatever the quote's shape. The loss is at the wire.
    func test_theClientChainPreservesTheFlagForEveryShape() {
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one")])).collapsed, true)
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one"), para("b", "two")])).collapsed, true)
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one")], author: "Ada")).collapsed, true)
    }

    /// A one-paragraph quote lands on `pageBlockBlockquote`, whose `flags` carry `collapsed` — so
    /// this shape DOES fold when sent and when re-opened for editing.
    func test_aSingleParagraphQuoteKeepsAShapeTheWireCanExpress() {
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one")])).innerBlocks, 1)
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one")], author: "Ada")).innerBlocks, 1,
                       "an author line rides in the caption and does not change the block count")
    }

    /// KNOWN GAP, asserted so it is visible rather than folklore: two or more blocks force
    /// `pageBlockBlockquoteBlocks`, which has no `collapsed` field, and the fold is lost on send.
    /// Rewrite this to assert preservation once the schema carries the flag.
    func test_aMultiBlockQuoteHasAShapeTheWireCannotExpress() {
        XCTAssertEqual(sent(foldedQuote(children: [para("a", "one"), para("b", "two")])).innerBlocks, 2,
                       "2 blocks → pageBlockBlockquoteBlocks → the collapsed flag is dropped on the wire")
    }
}
