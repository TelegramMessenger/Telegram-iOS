import XCTest
import Postbox
@testable import TelegramCore

/// A rich message carries its custom emoji inside the page, not as message entities, so the
/// context menu's emoji-pack tip saw none of them. `customEmojiFileIds` is what it reads instead.
final class InstantPageCustomEmojiTests: XCTestCase {
    private func emoji(_ id: Int64) -> RichText {
        return .textCustomEmoji(fileId: id, alt: "😀")
    }

    private func page(_ blocks: [InstantPageBlock]) -> InstantPage {
        return InstantPage(blocks: blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil)
    }

    func testPlainPageHasNoEmoji() {
        XCTAssertEqual(page([.paragraph(.plain("hello"))]).customEmojiFileIds, [])
    }

    func testCollectsNestedEmojiInReadingOrderOnce() {
        let caption = InstantPageCaption(text: emoji(5), credit: .empty)
        let cell = InstantPageTableCell(text: .bold(emoji(6)), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)
        let button = InstantPageButton(text: emoji(7), action: .url(""), color: nil)
        let result = page([
            .paragraph(.concat([.plain("a"), emoji(1), .italic(.textSpoiler(text: emoji(2)))])),
            .list(items: [.blocks([.blockQuote(blocks: [.paragraph(emoji(3))], caption: .empty, collapsed: true)], nil, nil)], ordered: false),
            .details(title: emoji(4), blocks: [.image(id: MediaId(namespace: 0, id: 1), caption: caption, url: nil, webpageId: nil, spoiler: false)], expanded: false),
            .table(title: .empty, rows: [InstantPageTableRow(cells: [cell])], bordered: false, striped: false, compact: false),
            .buttonRow(alignment: .center, buttons: [button]),
            .paragraph(.concat([emoji(1), .url(text: emoji(8), url: "", webpageId: nil)]))
        ]).customEmojiFileIds
        XCTAssertEqual(result, [1, 2, 3, 4, 5, 6, 7, 8])
    }
}
