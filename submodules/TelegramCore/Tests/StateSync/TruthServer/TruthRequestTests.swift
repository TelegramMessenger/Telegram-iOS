import Foundation
import XCTest
import TelegramApi
@testable import TelegramCore

/// `decodeTruthRequest` (TruthRequest.swift): the truth server reads each request from the bytes `ScriptedServer`
/// records. Every case is a round trip through the function builders the client itself uses.
final class TruthRequestTests: XCTestCase {
    private func decode<T>(_ name: String, _ function: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>)) -> TruthRequest {
        return decodeTruthRequest(name: name, payload: function.1.makeData())
    }

    func testDecodesGetDifferenceWithAndWithoutLimits() {
        XCTAssertEqual(self.decode("updates.getDifference", Api.functions.updates.getDifference(flags: 0, pts: 100, ptsLimit: nil, ptsTotalLimit: nil, date: 5000, qts: 7, qtsLimit: nil)), .getDifference(pts: 100, ptsLimit: nil, ptsTotalLimit: nil, date: 5000, qts: 7))
        XCTAssertEqual(self.decode("updates.getDifference", Api.functions.updates.getDifference(flags: (1 << 0) | (1 << 1), pts: 100, ptsLimit: 50, ptsTotalLimit: 10, date: 5000, qts: 7, qtsLimit: nil)), .getDifference(pts: 100, ptsLimit: 50, ptsTotalLimit: 10, date: 5000, qts: 7))
        XCTAssertEqual(self.decode("updates.getDifference", Api.functions.updates.getDifference(flags: (1 << 0) | (1 << 2), pts: 3, ptsLimit: nil, ptsTotalLimit: 10000, date: 1, qts: 2, qtsLimit: 9)), .getDifference(pts: 3, ptsLimit: nil, ptsTotalLimit: 10000, date: 1, qts: 2))
    }

    func testDecodesGetChannelDifference() {
        let request = Api.functions.updates.getChannelDifference(flags: 0, channel: .inputChannel(.init(channelId: 300, accessHash: 1)), filter: .channelMessagesFilterEmpty, pts: 40, limit: 100)
        XCTAssertEqual(self.decode("updates.getChannelDifference", request), .getChannelDifference(channelId: 300, pts: 40, limit: 100))
    }

    func testDecodesGetHistoryForEachPeerKind() {
        XCTAssertEqual(self.decode("messages.getHistory", Api.functions.messages.getHistory(peer: .inputPeerUser(.init(userId: 200, accessHash: 1)), offsetId: 31, offsetDate: 0, addOffset: 0, limit: 100, maxId: 31, minId: 0, hash: 0)), .getHistory(peer: .user(200), offsetId: 31, addOffset: 0, limit: 100, maxId: 31, minId: 0))
        XCTAssertEqual(self.decode("messages.getHistory", Api.functions.messages.getHistory(peer: .inputPeerChat(.init(chatId: 800)), offsetId: 1, offsetDate: 0, addOffset: -100, limit: 100, maxId: 50, minId: 0, hash: 0)), .getHistory(peer: .chat(800), offsetId: 1, addOffset: -100, limit: 100, maxId: 50, minId: 0))
        XCTAssertEqual(self.decode("messages.getHistory", Api.functions.messages.getHistory(peer: .inputPeerChannel(.init(channelId: 300, accessHash: 1)), offsetId: 15, offsetDate: 0, addOffset: -50, limit: 100, maxId: Int32.max, minId: 1, hash: 0)), .getHistory(peer: .channel(300), offsetId: 15, addOffset: -50, limit: 100, maxId: Int32.max, minId: 1))
        XCTAssertEqual(self.decode("messages.getHistory", Api.functions.messages.getHistory(peer: .inputPeerSelf, offsetId: 0, offsetDate: 0, addOffset: 0, limit: 10, maxId: 0, minId: 0, hash: 0)), .getHistory(peer: .selfUser, offsetId: 0, addOffset: 0, limit: 10, maxId: 0, minId: 0))
    }

    func testDecodesGetMessagesIdsAndReplyTo() {
        let request = Api.functions.messages.getMessages(id: [.inputMessageID(.init(id: 11)), .inputMessageReplyTo(.init(id: 12)), .inputMessageID(.init(id: 13))])
        XCTAssertEqual(self.decode("messages.getMessages", request), .getMessages(ids: [11, 12, 13]))
    }

    func testDecodesChannelsGetMessages() {
        let request = Api.functions.channels.getMessages(channel: .inputChannel(.init(channelId: 301, accessHash: 1)), id: [.inputMessageID(.init(id: 5)), .inputMessageID(.init(id: 6))])
        XCTAssertEqual(self.decode("channels.getMessages", request), .channelsGetMessages(channelId: 301, ids: [5, 6]))
    }

    func testDecodesGetDialogsWithAndWithoutFolder() {
        XCTAssertEqual(self.decode("messages.getDialogs", Api.functions.messages.getDialogs(flags: 0, folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: .inputPeerEmpty, limit: 100, hash: 0)), .getDialogs(folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 100))
        XCTAssertEqual(self.decode("messages.getDialogs", Api.functions.messages.getDialogs(flags: (1 << 0) | (1 << 1), folderId: 1, offsetDate: 900, offsetId: 44, offsetPeer: .inputPeerUser(.init(userId: 201, accessHash: 1)), limit: 20, hash: 0)), .getDialogs(folderId: 1, offsetDate: 900, offsetId: 44, offsetPeer: .user(201), limit: 20))
    }

    func testDecodesGetPinnedAndPeerDialogs() {
        XCTAssertEqual(self.decode("messages.getPinnedDialogs", Api.functions.messages.getPinnedDialogs(folderId: 0)), .getPinnedDialogs(folderId: 0))
        let peerDialogs = Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(.init(peer: .inputPeerUser(.init(userId: 201, accessHash: 1)))), .inputDialogPeer(.init(peer: .inputPeerChannel(.init(channelId: 302, accessHash: 1))))])
        XCTAssertEqual(self.decode("messages.getPeerDialogs", peerDialogs), .getPeerDialogs(peers: [.user(201), .channel(302)]))
    }

    func testUnknownNameIsOther() {
        XCTAssertEqual(decodeTruthRequest(name: "help.getConfig", payload: Data([1, 2, 3, 4])), .other(name: "help.getConfig"))
        XCTAssertEqual(self.decode("updates.getState", Api.functions.updates.getState()), .getState)
    }
}
