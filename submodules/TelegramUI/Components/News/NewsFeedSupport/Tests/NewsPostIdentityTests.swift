import XCTest
import TelegramCore
@testable import NewsFeedSupport

final class NewsPostIdentityTests: XCTestCase {
    private let channel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let otherChannel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(2))

    private func entry(_ id: Int32, date: Int32, peerId: EnginePeer.Id? = nil) -> EngineFeedEntry {
        let peerId = peerId ?? self.channel
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: peerId, id: id), messageIds: [EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)], groupingKey: nil)
    }

    private func album(_ ids: [Int32], date: Int32, groupingKey: Int64) -> EngineFeedEntry {
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: self.channel, id: ids.last!), messageIds: ids.map { EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: $0) }, groupingKey: groupingKey)
    }

    func testAnAlbumKeepsItsIdentityWhenAMessageIsAdded() {
        XCTAssertEqual(newsPostIdentity(self.album([10], date: 100, groupingKey: 5)), newsPostIdentity(self.album([10, 11], date: 110, groupingKey: 5)))
        XCTAssertNotEqual(newsPostIdentity(self.entry(10, date: 100)), newsPostIdentity(self.entry(10, date: 100, peerId: self.otherChannel)))
    }
}
