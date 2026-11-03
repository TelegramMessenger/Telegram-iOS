import XCTest
import TelegramCore
@testable import InstantPageUI

private let emptyCaption = InstantPageCaption(text: .empty, credit: .empty)

private func imageBlock(_ id: Int64 = 1) -> InstantPageBlock {
    return .image(id: EngineMedia.Id(namespace: 0, id: id), caption: emptyCaption, url: nil, webpageId: nil, spoiler: false)
}

/// Which pages meet their top edge with no gap of their own.
///
/// The chat bubble reads this to space a rich message below its header (author name, "Forwarded
/// from", reply). The header ends in an overlap that assumes the content brings its own top inset,
/// as text does; a page opening with a photo or a code band brings none and ran into the header.
/// These pin both sides of the split, so a block that stops being flush (or starts) fails here
/// rather than silently re-cramping, or over-spacing, every rich message that opens with it.
final class InstantPageV2LeadingEdgeTests: XCTestCase {
    func testPagesOpeningWithEdgeToEdgeContentStartFlush() {
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([imageBlock(), .paragraph(.plain("caption"))]))
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.video(id: EngineMedia.Id(namespace: 0, id: 1), caption: emptyCaption, autoplay: false, loop: false, spoiler: false)]))
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.collage(items: [imageBlock(1), imageBlock(2)], caption: emptyCaption)]))
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.preformatted(text: .plain("let x = 1"), language: "swift")]))
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.document(id: EngineMedia.Id(namespace: 0, id: 1), caption: emptyCaption)]))
    }

    /// A caption credit changes the media's spacing BELOW it, never above: still flush at the top.
    func testCaptionedMediaStillStartsFlush() {
        let credited = InstantPageCaption(text: .plain("text"), credit: .plain("credit"))
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.image(id: EngineMedia.Id(namespace: 0, id: 1), caption: credited, url: nil, webpageId: nil, spoiler: false)]))
    }

    /// Text-like first blocks carry their own leading padding, which is what already lines a rich
    /// message's first line up with a plain message's under a header. They must NOT get the gap.
    func testPagesOpeningWithPaddedContentDoNotStartFlush() {
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.paragraph(.plain("hello")), imageBlock()]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.heading(text: .plain("Title"), level: 1)]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.list(items: [.text(.plain("one"), nil, nil)], ordered: false)]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.blockQuote(blocks: [imageBlock()], caption: .empty, collapsed: nil)]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.table(title: .empty, rows: [], bordered: true, striped: false, compact: false)]))
    }

    /// The "please update" pill is a padded card, including a collage that renders as one.
    func testUnsupportedContentDoesNotStartFlush() {
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.unsupported, imageBlock()]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.collage(items: [imageBlock(), .unsupported], caption: emptyCaption)]))
    }

    /// An anchor is a zero-height marker, so the layout hands the edge to the block after it.
    func testLeadingAnchorsAreTransparent() {
        XCTAssertTrue(instantPageV2ContentStartsFlushAtTop([.anchor("top"), .anchor("again"), imageBlock()]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.anchor("top"), .paragraph(.plain("hello"))]))
    }

    func testEmptyPagesDoNotStartFlush() {
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([]))
        XCTAssertFalse(instantPageV2ContentStartsFlushAtTop([.anchor("only")]))
    }
}
