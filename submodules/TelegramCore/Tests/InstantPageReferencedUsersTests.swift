import XCTest
import Postbox
@testable import TelegramCore

/// A rich message names users by bare id (mention names, "User Profile" buttons); sending lists them
/// again as `inputRichMessage.users`, and a rendered message carries them through `associatedPeerIds`.
final class InstantPageReferencedUsersTests: XCTestCase {
    private func user(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
    }

    private func mention(_ id: Int64) -> RichText {
        return .textMentionName(text: .plain("@\(id)"), peerId: id)
    }

    private func profileButton(_ id: Int64) -> InstantPageButton {
        return InstantPageButton(text: .plain("Profile"), action: .openUserProfile(peerId: self.user(id)), color: nil)
    }

    private func page(_ blocks: [InstantPageBlock]) -> InstantPage {
        return InstantPage(blocks: blocks, media: [:], isComplete: true, rtl: false, url: "", views: nil)
    }

    func testPageWithoutUsersRefersToNone() {
        let urlButton = InstantPageButton(text: .plain("Open"), action: .url("https://t.me"), color: nil)
        XCTAssertEqual(page([.paragraph(.plain("hello")), .buttonRow(alignment: .center, buttons: [urlButton])]).referencedUserIds, [])
    }

    func testCollectsNestedUsersInReadingOrderOnce() {
        let caption = InstantPageCaption(text: mention(5), credit: .empty)
        let cell = InstantPageTableCell(text: .italic(mention(6)), header: false, alignment: .left, verticalAlignment: .top, colspan: 1, rowspan: 1)
        let result = page([
            .paragraph(.concat([.plain("a"), .bold(mention(1)), .textButton(profileButton(2))])),
            .list(items: [.blocks([.blockQuote(blocks: [.paragraph(mention(3))], caption: .empty, collapsed: true)], nil, nil)], ordered: false),
            .details(title: mention(4), blocks: [.image(id: MediaId(namespace: 0, id: 1), caption: caption, url: nil, webpageId: nil, spoiler: false)], expanded: false),
            .table(title: .empty, rows: [InstantPageTableRow(cells: [cell])], bordered: false, striped: false, compact: false),
            .buttonRow(alignment: .center, buttons: [profileButton(7), InstantPageButton(text: mention(8), action: .url(""), color: nil)]),
            .paragraph(.concat([mention(1), .textButton(profileButton(2))]))
        ]).referencedUserIds
        XCTAssertEqual(result, [1, 2, 3, 4, 5, 6, 7, 8].map(user))
    }

    func testMentionOfAnImpossibleUserIdIsSkipped() {
        XCTAssertEqual(page([.paragraph(.concat([mention(0), mention(-(1 << 40)), mention(3)]))]).referencedUserIds, [user(3)])
    }

    func testAttributeAssociatesTheUsersOfBothPages() {
        let attribute = RichTextMessageAttribute(
            instantPage: page([.paragraph(.concat([mention(1), mention(2)]))]),
            fullInstantPage: page([.paragraph(mention(2)), .buttonRow(alignment: .center, buttons: [profileButton(3)])])
        )
        XCTAssertEqual(attribute.associatedPeerIds, [1, 2, 3].map(user))
    }

    func testAttributeWithoutFullPageAssociatesItsPageUsers() {
        let attribute = RichTextMessageAttribute(instantPage: page([.buttonRow(alignment: .center, buttons: [profileButton(9)])]), fullInstantPage: nil)
        XCTAssertEqual(attribute.associatedPeerIds, [user(9)])
    }
}
