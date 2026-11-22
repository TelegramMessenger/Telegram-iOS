import XCTest
import TelegramCore
import ChatPresentationInterfaceState

/// In-chat search keeps its results oldest first; "Show as List" and the "n of N" counter count from the newest.
/// Picking the nth row of the list makes that result the current one, so the counter reads "n of N" and the arrows go
/// on to its neighbours.
final class ChatSearchResultsNavigationTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func index(_ id: Int32) -> EngineMessage.Index {
        return EngineMessage.Index(id: EngineMessage.Id(peerId: self.peerId, namespace: Namespaces.Message.Cloud, id: id), timestamp: 1000 + id)
    }

    // Results 10…50, oldest first, as the chat stores them.
    private lazy var messageIndices: [EngineMessage.Index] = [10, 20, 30, 40, 50].map { self.index($0) }

    func testTheNewestResultIsFirst() {
        XCTAssertEqual(chatSearchResultsPosition(messageIndices: self.messageIndices, currentId: self.index(50).id), 1)
        XCTAssertEqual(chatSearchResultsPosition(messageIndices: self.messageIndices, currentId: self.index(10).id), 5)
    }

    func testNoCurrentResultHasNoPosition() {
        XCTAssertNil(chatSearchResultsPosition(messageIndices: self.messageIndices, currentId: nil))
        XCTAssertNil(chatSearchResultsPosition(messageIndices: self.messageIndices, currentId: self.index(35).id))
    }

    // The list shows the results newest first: its third row is message 30, which the counter shows as "3 of 5".
    func testPickingTheNthListRowMakesItTheNthResult() {
        let listRows = self.messageIndices.reversed().map { $0.id }
        for (row, messageId) in listRows.enumerated() {
            let currentId = chatSearchResultsCurrentId(selecting: messageId, in: self.messageIndices)
            XCTAssertEqual(currentId, messageId)
            XCTAssertEqual(chatSearchResultsPosition(messageIndices: self.messageIndices, currentId: currentId), row + 1)
        }
    }

    // A message that is not one of the loaded results leaves the current result as it is.
    func testPickingAMessageOutsideTheResultsSelectsNothing() {
        XCTAssertNil(chatSearchResultsCurrentId(selecting: self.index(35).id, in: self.messageIndices))
    }
}
