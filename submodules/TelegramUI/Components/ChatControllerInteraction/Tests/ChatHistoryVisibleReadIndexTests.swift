import XCTest
import CoreGraphics
import TelegramCore
@testable import ChatControllerInteraction

final class ChatHistoryVisibleReadIndexTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let topInset: CGFloat = 100.0

    private func index(_ id: Int32, namespace: EngineMessage.Id.Namespace = Namespaces.Message.Cloud) -> EngineMessage.Index {
        return EngineMessage.Index(id: EngineMessage.Id(peerId: self.peerId, namespace: namespace, id: id), timestamp: 1000 + id)
    }

    private func row(minY: CGFloat, height: CGFloat = 50.0, _ messages: [EngineMessage.Index]) -> ChatHistoryVisibleReadRow {
        return ChatHistoryVisibleReadRow(frame: CGRect(x: 0.0, y: minY, width: 320.0, height: height), messages: messages)
    }

    private func maxIndex(_ rows: [ChatHistoryVisibleReadRow], lastMessageId: EngineMessage.Id? = nil, isThread: Bool = false) -> EngineMessage.Index? {
        return chatHistoryMaxVisibleReadIndex(rows: rows, topInset: self.topInset, lastMessageId: lastMessageId, isThread: isThread)
    }

    func testNoRowsReadsNothing() {
        XCTAssertNil(self.maxIndex([]))
    }

    func testReadsTheNewestMessageOfTheRowsInView() {
        let rows = [
            self.row(minY: 300.0, [self.index(7)]),
            self.row(minY: 200.0, [self.index(9)]),
            self.row(minY: 400.0, [self.index(8)])
        ]
        XCTAssertEqual(self.maxIndex(rows), self.index(9))
    }

    func testAnAlbumCountsWithItsNewestMessage() {
        let rows = [
            self.row(minY: 200.0, [self.index(11), self.index(13), self.index(12)]),
            self.row(minY: 300.0, [self.index(10)])
        ]
        XCTAssertEqual(self.maxIndex(rows), self.index(13))
    }

    func testARowUnderTheTopInsetIsNotRead() {
        let rows = [
            self.row(minY: 40.0, height: 50.0, [self.index(20)]),
            self.row(minY: 300.0, [self.index(5)])
        ]
        XCTAssertEqual(self.maxIndex(rows), self.index(5))
    }

    func testARowStartingAtMost100PointsAboveTheTopInsetIsRead() {
        XCTAssertEqual(self.maxIndex([self.row(minY: 0.0, height: 300.0, [self.index(20)])]), self.index(20))
    }

    func testTheBandEndsExactly100PointsAboveTheTopInset() {
        XCTAssertEqual(self.maxIndex([self.row(minY: self.topInset - 100.0, height: 300.0, [self.index(20)])]), self.index(20))
        XCTAssertNil(self.maxIndex([self.row(minY: self.topInset - 100.5, height: 300.0, [self.index(20)])]))
    }

    func testATallerRowIsReadOnlyWhenItIsTheLastMessage() {
        let tall = [self.row(minY: -50.0, height: 400.0, [self.index(20)]), self.row(minY: 400.0, [self.index(5)])]
        XCTAssertEqual(self.maxIndex(tall), self.index(5))
        XCTAssertEqual(self.maxIndex(tall, lastMessageId: self.index(20).id), self.index(20))
    }

    // A forum topic, a reply thread or a monoforum thread reads up to a cloud message id (`readDiscussion`), so a row
    // holding a pending or local message there is left out; a plain chat reads it.
    func testAThreadSkipsARowWithANonCloudMessage() {
        let rows = [
            self.row(minY: 200.0, [self.index(30, namespace: Namespaces.Message.Local)]),
            self.row(minY: 300.0, [self.index(6)])
        ]
        XCTAssertEqual(self.maxIndex(rows, isThread: true), self.index(6))
        XCTAssertEqual(self.maxIndex(rows, isThread: false), self.index(30, namespace: Namespaces.Message.Local))
    }

    func testAThreadSkipsATallLastMessageRowWithANonCloudMessage() {
        let lastMessage = self.index(31)
        let rows = [
            self.row(minY: -50.0, height: 400.0, [lastMessage, self.index(32, namespace: Namespaces.Message.Local)]),
            self.row(minY: 400.0, [self.index(6)])
        ]
        XCTAssertEqual(self.maxIndex(rows, lastMessageId: lastMessage.id, isThread: true), self.index(6))
    }

    func testAThreadReadsTheNewestCloudMessageInView() {
        let rows = [
            self.row(minY: 200.0, [self.index(27)]),
            self.row(minY: 300.0, [self.index(26)])
        ]
        XCTAssertEqual(self.maxIndex(rows, isThread: true), self.index(27))
    }
}
