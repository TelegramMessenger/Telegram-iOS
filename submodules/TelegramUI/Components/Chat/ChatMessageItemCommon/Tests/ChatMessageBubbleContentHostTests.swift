import XCTest
import ChatMessageItemCommon

// Where a bubble keeps a content node, decided on every layout rather than only when the node is created: a lone message
// of an album of files becomes the album in place (and back), reusing its node, which then has to move between the
// bubble and its message's container (#123).
final class ChatMessageBubbleContentHostTests: XCTestCase {
    private let first: UInt32 = 10
    private let second: UInt32 = 11

    func testAMessageWithoutContainersIsInTheBubble() {
        XCTAssertEqual(chatMessageBubbleContentHost(messageStableId: self.second, isAttachment: false, containerStableIds: []), .bubble)
    }

    func testAFileOfAnAlbumIsInItsMessagesContainer() {
        let containers = [self.first, self.second]
        XCTAssertEqual(chatMessageBubbleContentHost(messageStableId: self.first, isAttachment: false, containerStableIds: containers), .messageContainer(stableId: self.first))
        XCTAssertEqual(chatMessageBubbleContentHost(messageStableId: self.second, isAttachment: false, containerStableIds: containers), .messageContainer(stableId: self.second))
    }

    func testAnAlbumsAttachmentStaysInTheBubble() {
        XCTAssertEqual(chatMessageBubbleContentHost(messageStableId: self.first, isAttachment: true, containerStableIds: [self.first, self.second]), .bubble)
    }

    // The lone message was laid out in the bubble; once the rest of the album loads, the same node belongs in its
    // message's container, under the album's other file.
    func testALoneMessageJoiningItsAlbumMovesIntoItsContainer() {
        let lone = chatMessageBubbleContentHost(messageStableId: self.second, isAttachment: false, containerStableIds: [])
        let album = chatMessageBubbleContentHost(messageStableId: self.second, isAttachment: false, containerStableIds: [self.first, self.second])
        XCTAssertEqual(lone, .bubble)
        XCTAssertEqual(album, .messageContainer(stableId: self.second))
    }

    // The other way: the album's other message is deleted, and the remaining node goes back to the bubble while both
    // containers go.
    func testAnAlbumLeftWithOneMessageGoesBackToTheBubble() {
        XCTAssertEqual(chatMessageBubbleContentHost(messageStableId: self.second, isAttachment: false, containerStableIds: []), .bubble)
        XCTAssertEqual(chatMessageBubbleStaleContentContainers(existing: [self.first, self.second], laidOut: []), [self.first, self.second])
    }

    func testOnlyContainersNoLongerLaidOutAreStale() {
        XCTAssertEqual(chatMessageBubbleStaleContentContainers(existing: [], laidOut: [self.first, self.second]), [])
        XCTAssertEqual(chatMessageBubbleStaleContentContainers(existing: [self.first, self.second], laidOut: [self.first, self.second]), [])
        XCTAssertEqual(chatMessageBubbleStaleContentContainers(existing: [self.first, self.second, 12], laidOut: [self.second, 12]), [self.first])
    }
}
