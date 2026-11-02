import XCTest
import Display
import Postbox
import TelegramCore
import ChatMessageItemCommon

private func headerId(_ value: Int64) -> ListViewItemNode.HeaderId {
    return ListViewItemNode.HeaderId(space: 0, id: value)
}

final class ChatHistoryItemNeighborsTests: XCTestCase {
    func testDecodesChatNeighbors() {
        let unread = ChatHistoryItemNeighbor.unread(dateHeaderId: headerId(7))
        let neighbors = ChatHistoryItemNeighbors(
            ListViewItemNeighbors(previous: AnyEquatable(unread), next: nil))
        XCTAssertEqual(neighbors.previous, unread)
        XCTAssertNil(neighbors.next)
    }

    func testForeignDescriptorDecodesToNil() {
        let neighbors = ChatHistoryItemNeighbors(
            ListViewItemNeighbors(previous: AnyEquatable.noNeighborInfluence, next: nil))
        XCTAssertNil(neighbors.previous)
    }

    /// A neighbor that publishes nothing and no neighbor at all must be indistinguishable to chat
    /// code — that equivalence is why ChatHistoryItemNeighbor has no `.other` case.
    func testForeignDescriptorAndAbsentNeighborAgree() {
        let foreign = ChatHistoryItemNeighbors(
            ListViewItemNeighbors(previous: AnyEquatable.noNeighborInfluence, next: nil))
        let absent = ChatHistoryItemNeighbors(ListViewItemNeighbors.none)
        XCTAssertEqual(foreign, absent)
    }

    func testDateHeaderIdIsAvailableForEveryCase() {
        XCTAssertEqual(ChatHistoryItemNeighbor.unread(dateHeaderId: headerId(1)).dateHeaderId, headerId(1))
        XCTAssertEqual(ChatHistoryItemNeighbor.replyCount(dateHeaderId: headerId(2)).dateHeaderId, headerId(2))
    }

    func testCommonDateHeader() {
        XCTAssertTrue(chatItemsHaveCommonDateHeader(headerId(1), .unread(dateHeaderId: headerId(1))))
        XCTAssertFalse(chatItemsHaveCommonDateHeader(headerId(1), .unread(dateHeaderId: headerId(2))))
        XCTAssertFalse(chatItemsHaveCommonDateHeader(headerId(1), nil))
    }

    func testDistinctCasesWithEqualHeaderIdsAreNotEqual() {
        XCTAssertNotEqual(ChatHistoryItemNeighbor.unread(dateHeaderId: headerId(1)),
                          ChatHistoryItemNeighbor.replyCount(dateHeaderId: headerId(1)))
    }
    // Without bubbles a row reads whether its neighbours are selected, to join its selection band to theirs (spec 5.8,
    // 6.7, 3.3 #14).
    private func messageNeighbor(dateHeader: Int64, topicHeader: Int64? = nil, isSelected: Bool?) -> ChatHistoryItemNeighbor {
        let message = makeMessage(peer: makeGroupChannel(id: 100), author: makeUser(id: 2))
        return .message(dateHeaderId: headerId(dateHeader), topicHeaderId: topicHeader.map(headerId), merge: ChatMessageMergeFingerprint(message: message, accountPeerId: accountPeerIdForTests, bubbleless: isSelected != nil), isSelected: isSelected)
    }

    func testWithBubblesDescriptorsCarryNoSelection() {
        XCTAssertNil(chatMessageBubblelessNeighborSelection(bubbleMode: true, selected: [true], drawsBand: true))
        XCTAssertNil(chatMessageBubblelessNeighborSelection(bubbleMode: true, selected: [false], drawsBand: true))
        XCTAssertEqual(chatMessageBubblelessNeighborSelection(bubbleMode: false, selected: [true, true], drawsBand: true), true)
        XCTAssertEqual(chatMessageBubblelessNeighborSelection(bubbleMode: false, selected: [true, false], drawsBand: true), false)
        XCTAssertEqual(chatMessageBubblelessNeighborSelection(bubbleMode: false, selected: [], drawsBand: true), false)
        // With bubbles selecting a message leaves what its neighbours read unchanged, so nothing relayouts.
        XCTAssertEqual(self.messageNeighbor(dateHeader: 1, isSelected: chatMessageBubblelessNeighborSelection(bubbleMode: true, selected: [true], drawsBand: true)), self.messageNeighbor(dateHeader: 1, isSelected: chatMessageBubblelessNeighborSelection(bubbleMode: true, selected: [false], drawsBand: true)))
    }

    // A selected round video or torn strip draws no band, so a selected neighbour's band ends rounded beside it rather than
    // joining toward it.
    func testARowWithoutABandIsNotJoined() {
        XCTAssertEqual(chatMessageBubblelessNeighborSelection(bubbleMode: false, selected: [true], drawsBand: false), false)
        XCTAssertEqual(chatMessageBubblelessNeighborSelection(bubbleMode: false, selected: [true], drawsBand: true), true)
        XCTAssertNil(chatMessageBubblelessNeighborSelection(bubbleMode: true, selected: [true], drawsBand: false))
    }

    func testSelectedNeighborsMapAboveAndBelow() {
        let selected = chatMessageBubblelessSelectedNeighbors(above: self.messageNeighbor(dateHeader: 1, isSelected: true), below: self.messageNeighbor(dateHeader: 1, isSelected: false), dateHeaderId: headerId(1), topicHeaderId: nil)
        XCTAssertTrue(selected.above)
        XCTAssertFalse(selected.below)
        // A date or topic header between two rows keeps their bands apart.
        let acrossDate = chatMessageBubblelessSelectedNeighbors(above: self.messageNeighbor(dateHeader: 2, isSelected: true), below: self.messageNeighbor(dateHeader: 1, isSelected: true), dateHeaderId: headerId(1), topicHeaderId: nil)
        XCTAssertFalse(acrossDate.above)
        XCTAssertTrue(acrossDate.below)
        let acrossTopic = chatMessageBubblelessSelectedNeighbors(above: self.messageNeighbor(dateHeader: 1, topicHeader: 5, isSelected: true), below: self.messageNeighbor(dateHeader: 1, topicHeader: 6, isSelected: true), dateHeaderId: headerId(1), topicHeaderId: headerId(5))
        XCTAssertTrue(acrossTopic.above)
        XCTAssertFalse(acrossTopic.below)
        XCTAssertFalse(chatMessageBubblelessSelectedNeighbors(above: .unread(dateHeaderId: headerId(1)), below: nil, dateHeaderId: headerId(1), topicHeaderId: nil).above)
    }

    // A, B and C in a row, A and C selected: C's band stands apart until B goes, then joins A's in the same layout.
    func testJoinsFollowTheNeighbors() {
        let a = self.messageNeighbor(dateHeader: 1, isSelected: true)
        let b = self.messageNeighbor(dateHeader: 1, isSelected: false)
        let withB = chatMessageBubblelessSelectedNeighbors(above: b, below: nil, dateHeaderId: headerId(1), topicHeaderId: nil)
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: true, aboveSelected: withB.above, belowSelected: withB.below, headerBetweenAbove: false, headerBetweenBelow: false).above, false)
        let withoutB = chatMessageBubblelessSelectedNeighbors(above: a, below: nil, dateHeaderId: headerId(1), topicHeaderId: nil)
        XCTAssertEqual(chatMessageBubblelessBandJoins(isSelected: true, aboveSelected: withoutB.above, belowSelected: withoutB.below, headerBetweenAbove: false, headerBetweenBelow: false).above, true)
    }
}
