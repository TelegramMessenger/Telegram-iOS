import XCTest
import Display
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
}
