import XCTest
import Postbox
import TelegramCore
@testable import ChatListUI

final class ChatListSupportSearchTests: XCTestCase {
    private func peerId(_ value: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(value))
    }

    private func rows(_ peers: [Int64], shown: inout Set<EnginePeer.Id>, removed: Set<Int> = Set()) -> [Int] {
        let indexed = Array(peers.enumerated())
        return supportOneRowPerChat(indexed, peerId: { self.peerId($0.element) }, isRemoved: { removed.contains($0.offset) }, shownPeerIds: &shown).map(\.offset)
    }

    func testKeepsTheFirstRowOfEachChatInOrder() {
        var shown = Set<EnginePeer.Id>()
        XCTAssertEqual(self.rows([1, 2, 1, 3, 2, 1], shown: &shown), [0, 1, 3])
    }

    func testDropsAChatThatHasARowAbove() {
        var shown: Set<EnginePeer.Id> = [self.peerId(2)]
        XCTAssertEqual(self.rows([1, 2, 3], shown: &shown), [0, 2])
    }

    func testARemovedMessageDoesNotUseUpItsChat() {
        var shown = Set<EnginePeer.Id>()
        XCTAssertEqual(self.rows([1, 1, 2], shown: &shown, removed: [0]), [1, 2])
    }

    func testAChatIsNotRepeatedAcrossResultSets() {
        var shown = Set<EnginePeer.Id>()
        XCTAssertEqual(self.rows([1, 2], shown: &shown), [0, 1])
        XCTAssertEqual(self.rows([2, 3], shown: &shown), [1])
    }

    func testABareHashShowsEveryRecentHashtag() {
        XCTAssertEqual(supportRecentHashtags(["#order", "#refund", "#otp"], matching: "#"), ["#order", "#refund", "#otp"])
    }

    func testTypingNarrowsRecentHashtagsByPrefixIgnoringCase() {
        XCTAssertEqual(supportRecentHashtags(["#Order", "#refund", "#orders"], matching: "#or"), ["#Order", "#orders"])
    }

    func testTheTypedHashtagItselfIsNotSuggested() {
        XCTAssertEqual(supportRecentHashtags(["#order", "#orders"], matching: "#ORDER"), ["#orders"])
    }

    func testNarrowedRecentHashtagsAreCapped() {
        let hashtags = (0 ..< 8).map { "#tag\($0)" }
        XCTAssertEqual(supportRecentHashtags(hashtags, matching: "#tag").count, 5)
    }

    func testRecentHashtagsNeedAHashtagQuery() {
        XCTAssertEqual(supportRecentHashtags(["#order"], matching: "order"), [])
        XCTAssertEqual(supportRecentHashtags(["#order"], matching: "#or der"), [])
    }

    func testOnlyASingleHashtagIsSavedAsASearch() {
        XCTAssertEqual(supportSearchedHashtag(" #order "), "#order")
        XCTAssertNil(supportSearchedHashtag("#"))
        XCTAssertNil(supportSearchedHashtag("order"))
        XCTAssertNil(supportSearchedHashtag("#order now"))
    }

    func testChatResultsComeBeforeSupportPublicPostsWhateverTheirDates() {
        XCTAssertEqual(supportSearchSectionComesFirst(.generic, .supportPublicPosts), true)
        XCTAssertEqual(supportSearchSectionComesFirst(.supportPublicPosts, .generic), false)
    }

    func testOtherSectionsKeepTheirDateOrder() {
        XCTAssertNil(supportSearchSectionComesFirst(.generic, .generic))
        XCTAssertNil(supportSearchSectionComesFirst(.supportPublicPosts, .supportPublicPosts))
        XCTAssertNil(supportSearchSectionComesFirst(.generic, .publicPosts))
        XCTAssertNil(supportSearchSectionComesFirst(.publicPosts, .generic))
    }

    func testAppliesOnlyToTheChatsTabOfAChatListOnASupportAccount() {
        XCTAssertTrue(supportSearchAppliesToPane(hasSupportContext: true, key: .chats, location: .chatList(groupId: .root)))
        XCTAssertTrue(supportSearchAppliesToPane(hasSupportContext: true, key: .chats, location: .chatList(groupId: .archive)))
        XCTAssertFalse(supportSearchAppliesToPane(hasSupportContext: false, key: .chats, location: .chatList(groupId: .root)))
        XCTAssertFalse(supportSearchAppliesToPane(hasSupportContext: true, key: .chats, location: .forum(peerId: self.peerId(1))))
        for key: ChatListSearchPaneKey in [.topics, .publicPosts, .channels, .apps, .globalPosts, .media, .downloads, .links, .files, .music, .voice, .instantVideo] {
            XCTAssertFalse(supportSearchAppliesToPane(hasSupportContext: true, key: key, location: .chatList(groupId: .root)))
        }
    }
}
