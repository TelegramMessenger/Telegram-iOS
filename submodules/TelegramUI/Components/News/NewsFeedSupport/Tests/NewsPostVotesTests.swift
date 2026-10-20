import XCTest
import TelegramCore
@testable import NewsFeedSupport

final class NewsPostVotesTests: XCTestCase {
    private let channel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func message(_ id: Int32) -> EngineMessage.Id {
        return EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: id)
    }

    func testAVoteGoesOutAtOnceWhenNoneIsInFlight() {
        var queue = NewsPostVoteQueue()
        XCTAssertEqual(queue.cast(.like, messageId: self.message(1)), NewsPostVoteRequest(messageId: self.message(1), vote: .like))
    }

    func testUndosLikeWaitsForTheDislikeItTakesBack() {
        var queue = NewsPostVoteQueue()
        XCTAssertEqual(queue.cast(.dislike, messageId: self.message(1)), NewsPostVoteRequest(messageId: self.message(1), vote: .dislike))
        XCTAssertNil(queue.cast(.like, messageId: self.message(1)))
        XCTAssertEqual(queue.finished(), NewsPostVoteRequest(messageId: self.message(1), vote: .like))
        XCTAssertNil(queue.finished())
    }

    func testVotesGoOutInTheOrderTheyWereCast() {
        var queue = NewsPostVoteQueue()
        XCTAssertNotNil(queue.cast(.dislike, messageId: self.message(1)))
        XCTAssertNil(queue.cast(.like, messageId: self.message(2)))
        XCTAssertNil(queue.cast(.like, messageId: self.message(1)))
        XCTAssertEqual(queue.finished(), NewsPostVoteRequest(messageId: self.message(2), vote: .like))
        XCTAssertEqual(queue.finished(), NewsPostVoteRequest(messageId: self.message(1), vote: .like))
        XCTAssertNil(queue.finished())
        XCTAssertEqual(queue.cast(.dislike, messageId: self.message(3)), NewsPostVoteRequest(messageId: self.message(3), vote: .dislike))
    }
}
