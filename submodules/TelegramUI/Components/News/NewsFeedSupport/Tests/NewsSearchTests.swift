import XCTest
import TelegramCore
@testable import NewsFeedSupport

final class NewsSearchTests: XCTestCase {
    private let channel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let otherChannel = EnginePeer.Id(namespace: Namespaces.Peer.CloudChannel, id: EnginePeer.Id.Id._internalFromInt64Value(2))

    private func entry(_ id: Int32, date: Int32, peerId: EnginePeer.Id? = nil) -> EngineFeedEntry {
        let peerId = peerId ?? self.channel
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: peerId, id: id), messageIds: [EngineMessage.Id(peerId: peerId, namespace: Namespaces.Message.Cloud, id: id)], groupingKey: nil)
    }

    private func album(_ ids: [Int32], date: Int32, groupingKey: Int64) -> EngineFeedEntry {
        return EngineFeedEntry(position: EngineFeedPosition(date: date, peerId: self.channel, id: ids.last!), messageIds: ids.map { EngineMessage.Id(peerId: self.channel, namespace: Namespaces.Message.Cloud, id: $0) }, groupingKey: groupingKey)
    }

    private func document(_ text: String, title: String = "Daily", id: Int32 = 1, date: Int32 = 100) -> NewsSearchDocument {
        return NewsSearchDocument(entry: self.entry(id, date: date), texts: [text], channelTitle: title)
    }

    private func matches(_ query: String, _ document: NewsSearchDocument) -> Bool {
        return newsSearchMatches(queryWords: newsSearchQueryWords(query), document: document)
    }

    func testAQueryWordMatchesTheStartOfAWord() {
        let document = self.document("Elections are near")
        XCTAssertTrue(self.matches("elec", document))
        XCTAssertTrue(self.matches("elections", document))
        XCTAssertFalse(self.matches("lections", document))
        XCTAssertFalse(self.matches("electionsx", document))
    }

    func testEveryQueryWordMustMatch() {
        let document = self.document("Elections are near")
        XCTAssertTrue(self.matches("near elec", document))
        XCTAssertFalse(self.matches("near moon", document))
    }

    func testCaseAndDiacriticsAreIgnored() {
        XCTAssertTrue(self.matches("cafe", self.document("A new Café opens")))
        XCTAssertTrue(self.matches("CAFÉ", self.document("a new cafe opens")))
        XCTAssertTrue(self.matches("москва", self.document("Новости: Москва сегодня")))
    }

    func testPunctuationSeparatesWords() {
        let document = self.document("hello,world — (breaking)")
        XCTAssertTrue(self.matches("world", document))
        XCTAssertTrue(self.matches("break", document))
        XCTAssertTrue(self.matches("hello, world!", document))
    }

    func testTheChannelTitleIsSearched() {
        let document = self.document("Markets closed higher", title: "Reuters World")
        XCTAssertTrue(self.matches("reut", document))
        XCTAssertTrue(self.matches("reuters markets", document))
    }

    func testAnAlbumIsFoundByAnyOfItsCaptions() {
        let document = NewsSearchDocument(entry: self.album([10, 11], date: 100, groupingKey: 5), texts: ["", "Sunset over the bay"], channelTitle: "Daily")
        XCTAssertTrue(self.matches("sunset", document))
    }

    func testAQueryWithoutLettersOrDigitsHasNoWordsAndFindsNothing() {
        XCTAssertEqual(newsSearchQueryWords(""), [])
        XCTAssertEqual(newsSearchQueryWords("   "), [])
        XCTAssertEqual(newsSearchQueryWords("!? —"), [])
        XCTAssertEqual(newsSearchResults(queryWords: [], documents: [self.document("anything")]).count, 0)
    }

    func testResultsAreNewestFirst() {
        let documents = [
            self.document("rain today", id: 1, date: 100),
            self.document("rain tomorrow", id: 3, date: 300),
            self.document("sun", id: 4, date: 400),
            self.document("rain yesterday", id: 2, date: 200)
        ]
        let results = newsSearchResults(queryWords: newsSearchQueryWords("rain"), documents: documents)
        XCTAssertEqual(results.map(\.entry.position.id), [3, 2, 1])
    }

    func testAPostHeldByBothFeedsIsFoundOnce() {
        let forYou = NewsSearchDocument(entry: self.entry(7, date: 100), texts: ["rain"], channelTitle: "Daily")
        let added = NewsSearchDocument(entry: self.entry(7, date: 100), texts: ["rain"], channelTitle: "Daily")
        let sameIdInAnotherChannel = NewsSearchDocument(entry: self.entry(7, date: 100, peerId: self.otherChannel), texts: ["rain"], channelTitle: "Other")
        let results = newsSearchResults(queryWords: newsSearchQueryWords("rain"), documents: [forYou, added, sameIdInAnotherChannel])
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(Set(results.map { newsPostIdentity($0.entry) }).count, 2)
    }

    func testTheFullerCopyOfAnAlbumWins() {
        let partial = NewsSearchDocument(entry: self.album([10], date: 100, groupingKey: 5), texts: ["rain"], channelTitle: "Daily")
        let full = NewsSearchDocument(entry: self.album([10, 11], date: 110, groupingKey: 5), texts: ["rain", ""], channelTitle: "Daily")
        let results = newsSearchResults(queryWords: newsSearchQueryWords("rain"), documents: [partial, full])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.entry.messageIds.count, 2)
    }

    func testAnAlbumKeepsItsIdentityWhenAMessageIsAdded() {
        XCTAssertEqual(newsPostIdentity(self.album([10], date: 100, groupingKey: 5)), newsPostIdentity(self.album([10, 11], date: 110, groupingKey: 5)))
        XCTAssertNotEqual(newsPostIdentity(self.entry(10, date: 100)), newsPostIdentity(self.entry(10, date: 100, peerId: self.otherChannel)))
    }
}
