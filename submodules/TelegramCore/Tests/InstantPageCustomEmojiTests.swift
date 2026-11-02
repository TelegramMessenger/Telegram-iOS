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

    func testTextRunsKeepPlainTextRepeatsAndAltText() {
        let result = page([
            .paragraph(.concat([.textCustomEmoji(fileId: 1, alt: "🙂"), .plain(" a "), .bold(.textCustomEmoji(fileId: 2, alt: "🔥"))])),
            .list(items: [.text(.textCustomEmoji(fileId: 1, alt: "🙂"), nil, nil)], ordered: false)
        ]).customEmojiTextRuns
        // Each block-level text unit (the paragraph, the list item) starts with a "\n" run.
        XCTAssertEqual(result.map(\.customEmojiFileId), [nil, 1, nil, 2, nil, 1])
        XCTAssertEqual(result.map(\.text), ["\n", "🙂", " a ", "🔥", "\n", "🙂"])
    }

    /// A rendered rich message carries its stored emoji files as associated media, which is where the chat list
    /// preview looks for them.
    func testAttributeAssociatesTheEmojiOfBothPages() {
        let attribute = RichTextMessageAttribute(
            instantPage: page([.paragraph(.concat([emoji(1), emoji(2)]))]),
            fullInstantPage: page([.paragraph(emoji(2)), .paragraph(emoji(3))])
        )
        XCTAssertEqual(attribute.associatedMediaIds, [1, 2, 3].map { MediaId(namespace: Namespaces.Media.CloudFile, id: $0) })
    }
}
