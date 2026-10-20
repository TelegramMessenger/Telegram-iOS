import XCTest
import TelegramCore
@testable import InstantPageUI

private func makePage(_ blocks: [InstantPageBlock]) -> InstantPage {
    return InstantPage(blocks: blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil)
}

private func shown(_ blocks: [InstantPageBlock]) -> [InstantPageBlock] {
    return instantPageForSuspiciousSender(makePage(blocks)).blocks
}

private func shownText(_ text: RichText) -> RichText {
    guard case let .paragraph(result) = shown([.paragraph(text)]).first else {
        XCTFail("a paragraph stays a paragraph")
        return .empty
    }
    return result
}

private func makeButton(_ label: String, isLink: Bool) -> InstantPageButton {
    return InstantPageButton(text: .plain(label), action: .url("https://example.com"), color: nil, isLink: isLink)
}

final class InstantPageSuspiciousSenderTests: XCTestCase {
    /// The kinds a plain message from the same sender loses (`.Url`, `.TextUrl`, `.Email`, `.Mention`,
    /// `.TextMention`, `.Hashtag` with cashtags, `.BankCard`, `.TonAddress`) become their text,
    /// formatting inside them kept.
    func testLinkLikeRunsBecomeTheirText() {
        let inner = RichText.bold(.plain("x"))
        let stripped: [RichText] = [
            .url(text: inner, url: "https://example.com", webpageId: nil),
            .email(text: inner, email: "a@b.c"),
            .textAutoEmail(text: inner),
            .textAutoUrl(text: inner),
            .textBankCard(text: inner),
            .textTonAddress(text: inner),
            .textCashtag(text: inner),
            .textHashtag(text: inner),
            .textMention(text: inner),
            .textMentionName(text: inner, peerId: 1)
        ]
        for text in stripped {
            XCTAssertEqual(shownText(.concat([.plain("a "), text])), .concat([.plain("a "), inner]), "\(text)")
        }
    }

    /// What a plain message keeps (phone numbers, bot commands, dates) stays, and so do anchors.
    func testOtherRunsStay() {
        let kept: [RichText] = [
            .phone(text: .plain("+1"), phone: "+1"),
            .textAutoPhone(text: .plain("+1")),
            .textBotCommand(text: .plain("/start")),
            .textDate(text: .plain("today"), date: 1, format: nil),
            .anchor(text: .plain("a"), name: "a"),
            .textCustomEmoji(fileId: 1, alt: "a"),
            .textSpoiler(text: .plain("s"))
        ]
        for text in kept {
            XCTAssertEqual(shownText(text), text)
        }
    }

    /// A link inside a kept wrapper is still stripped.
    func testLinksInsideKeptRunsAreStripped() {
        let link = RichText.url(text: .plain("x"), url: "https://example.com", webpageId: nil)
        XCTAssertEqual(shownText(.textSpoiler(text: link)), .textSpoiler(text: .plain("x")))
        XCTAssertEqual(shownText(.italic(.underline(link))), .italic(.underline(.plain("x"))))
    }

    /// An inline pill is not shown; a link-styled button reads as a link, so its label stays as text.
    func testInlineButtons() {
        XCTAssertEqual(shownText(.concat([.plain("a"), .textButton(makeButton("Pay", isLink: false))])), .concat([.plain("a"), .empty]))
        XCTAssertEqual(shownText(.concat([.plain("a"), .textButton(makeButton("here", isLink: true))])), .concat([.plain("a"), .plain("here")]))
    }

    /// A button row loses its buttons but keeps its index, so the blocks after it keep their paths,
    /// which are the rich-quote node ids.
    func testButtonRowKeepsItsPlace() {
        let blocks: [InstantPageBlock] = [
            .paragraph(.plain("one")),
            .buttonRow(alignment: .center, buttons: [makeButton("Open", isLink: false)]),
            .paragraph(.url(text: .plain("two"), url: "https://example.com", webpageId: nil))
        ]
        let result = shown(blocks)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[1], .buttonRow(alignment: .center, buttons: []))

        let originalNodes = instantPageQuotableNodes(blocks)
        let shownNodes = instantPageQuotableNodes(result)
        XCTAssertEqual(shownNodes.map(\.id), originalNodes.map(\.id))
        XCTAssertEqual(shownNodes.map(\.flatText), originalNodes.map(\.flatText))
    }

    /// Nested containers are walked: list items, table cells and titles, details, quotes and captions.
    func testNestedTextIsStripped() {
        let link = RichText.url(text: .plain("x"), url: "https://example.com", webpageId: nil)
        let caption = InstantPageCaption(text: link, credit: link)
        let blocks: [InstantPageBlock] = [
            .list(items: [.text(link, nil, nil), .blocks([.paragraph(link)], nil, nil)], ordered: false),
            .table(title: link, rows: [InstantPageTableRow(cells: [InstantPageTableCell(text: link, header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)])], bordered: false, striped: false, compact: false),
            .details(title: link, blocks: [.paragraph(link)], expanded: false),
            .blockQuote(blocks: [.paragraph(link)], caption: link, collapsed: nil),
            .image(id: EngineMedia.Id(namespace: 0, id: 1), caption: caption, url: "https://example.com", webpageId: nil, spoiler: false)
        ]
        let plain = RichText.plain("x")
        let plainCaption = InstantPageCaption(text: plain, credit: plain)
        XCTAssertEqual(shown(blocks), [
            .list(items: [.text(plain, nil, nil), .blocks([.paragraph(plain)], nil, nil)], ordered: false),
            .table(title: plain, rows: [InstantPageTableRow(cells: [InstantPageTableCell(text: plain, header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)])], bordered: false, striped: false, compact: false),
            .details(title: plain, blocks: [.paragraph(plain)], expanded: false),
            .blockQuote(blocks: [.paragraph(plain)], caption: plain, collapsed: nil),
            .image(id: EngineMedia.Id(namespace: 0, id: 1), caption: plainCaption, url: nil, webpageId: nil, spoiler: false)
        ])
    }

    /// A page with nothing to strip comes back equal.
    func testPlainPageIsUnchanged() {
        let blocks: [InstantPageBlock] = [.heading(text: .bold(.plain("h")), level: 1), .paragraph(.plain("p")), .formula(latex: "x")]
        XCTAssertEqual(shown(blocks), blocks)
    }
}
