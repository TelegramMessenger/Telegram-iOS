import Foundation
import XCTest
import SwiftSignalKit
import Postbox
import TelegramApi
@testable import TelegramCore

private let getHistory = "messages.getHistory"
private let getMessages = "messages.getMessages"

/// A preload fill (`ChatHistoryPreloadManager`, source `.download`) confirms the stored messages its answer left
/// out through its own download session, as `fetchMessageHistoryHole` passes its source to
/// `confirmStoredMessages`. The fill and its confirmation go to the scripted server's worker session
/// (`ScriptedServer.onWorker`); nothing goes through the main session. Helpers are in
/// HistoryFillReconciliationTests.swift.
final class PreloadFillConfirmationTests: StateSyncTestCase {
    /// The download session `ChatHistoryPreloadManager` fills through: the account's own datacenter, not media.
    private func makeDownload(file: StaticString = #filePath, line: UInt = #line) -> Download? {
        return self.fixture.wait(self.network.download(datacenterId: self.network.datacenterId, isMedia: false, tag: nil), file: file, line: line)
    }

    /// 11 was deleted during the gap. A preload fill (count 60, as the preload manager asks) gets [10] for the
    /// range 10...top; the stored 11 it left out is confirmed with messages.getMessages on the download session,
    /// deleted, and the hole closes as for a view's fill.
    func testAPreloadFillConfirmsThroughItsDownloadSession() {
        self.fixture.seedAccount(state: self.state(pts: 100))
        let peerId = self.seedUserChat(500)
        self.storeHistoryFillMessages(peerId: peerId, ids: [10, 11])
        self.addHistoryFillHole(peerId)
        self.server.onWorker(getHistory, .result(StateSyncApi.messages([
            StateSyncApi.privateMessage(id: 10, peerUserId: 500, fromUserId: 500, date: self.baseDate + 10)
        ])))
        self.server.onWorker(getMessages, .result(StateSyncApi.messages([])))
        guard let download = self.makeDownload() else {
            XCTFail("no download session")
            return
        }

        let result = self.fixture.wait(fetchMessageHistoryHole(
            accountPeerId: StateSyncFixture.accountPeerId,
            source: .download(download),
            postbox: self.fixture.postbox,
            peerInput: .direct(peerId: peerId, threadId: nil),
            namespace: Namespaces.Message.Cloud,
            direction: self.downwardFillDirection(peerId),
            space: .everywhere,
            count: 60
        )) ?? nil

        XCTAssertEqual(self.server.requestNames, [], "a request of the preload fill went through the main session")
        XCTAssertEqual(self.server.workerRequests.map { $0.name }, [getHistory, getMessages])
        XCTAssertEqual(self.server.workerRequests.map { $0.datacenterId }, [self.network.datacenterId, self.network.datacenterId])
        XCTAssertEqual(self.server.workerRequestPayloads.last, HistoryFillApi.getMessagesPayload(ids: [11]), "exactly the stored message the answer left out is asked for")
        XCTAssertNil(self.fixture.message(self.messageId(peerId, 11)), "11 is gone from the server: deleted as a received deletion deletes")
        XCTAssertNotNil(self.fixture.message(self.messageId(peerId, 10)))
        XCTAssertEqual(result?.removedIndices, IndexSet(integersIn: 10 ... Int(Int32.max - 1)))
        XCTAssertEqual(self.fixture.holes(peerId: peerId), IndexSet(integersIn: 1 ... 9))
    }
}
