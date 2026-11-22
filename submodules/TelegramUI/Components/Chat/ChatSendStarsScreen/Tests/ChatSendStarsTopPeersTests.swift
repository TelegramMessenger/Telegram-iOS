import XCTest
import TelegramCore
@testable import ChatSendStarsScreen

private func userId(_ id: Int64) -> EnginePeer.Id {
    return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id))
}

private func user(_ id: Int64) -> EnginePeer {
    return .user(TelegramUser(
        id: userId(id),
        accessHash: nil,
        firstName: "U\(id)",
        lastName: nil,
        username: nil,
        phone: nil,
        photo: [],
        botInfo: nil,
        restrictionInfo: nil,
        flags: UserInfoFlags(),
        emojiStatus: nil,
        usernames: [],
        storiesHidden: nil,
        nameColor: nil,
        backgroundEmojiId: nil,
        profileColor: nil,
        profileBackgroundEmojiId: nil,
        subscriberCount: nil,
        verificationIconFileId: nil
    ))
}

private func reactor(_ id: Int64?, count: Int32, isMy: Bool = false, isAnonymous: Bool = false) -> ReactionsMessageAttribute.TopPeer {
    return ReactionsMessageAttribute.TopPeer(peerId: id.flatMap(userId), count: count, isTop: !isMy, isMy: isMy, isAnonymous: isAnonymous)
}

private func shown(_ topPeers: [ReactionsMessageAttribute.TopPeer], known: [Int64]) -> [ChatSendStarsShownTopPeer] {
    let peers = Dictionary(uniqueKeysWithValues: known.map { (userId($0), user($0)) })
    return chatSendStarsShownTopPeers(topPeers, peer: { peers[$0] }, limit: 3)
}

final class ChatSendStarsTopPeersTests: XCTestCase {
    func testThreeKnownSendersAreShownMostStarsFirst() {
        let result = shown([reactor(1, count: 5173), reactor(2, count: 10000), reactor(3, count: 900)], known: [1, 2, 3])
        XCTAssertEqual(result.map(\.peer?.id), [userId(2), userId(1), userId(3)])
        XCTAssertEqual(result.map(\.count), [10000, 5173, 900])
    }

    func testSenderMissingLocallyLeavesItsSlotToTheNext() {
        // Sender 2 is not stored locally: the fourth sender takes the third slot instead of the list ending at two.
        // (A message's reactions carry only the top three; a longer list, as a live stream's, can fill the slot.)
        let result = shown([reactor(1, count: 10000), reactor(2, count: 6000), reactor(3, count: 5173), reactor(4, count: 100)], known: [1, 3, 4])
        XCTAssertEqual(result.map(\.peer?.id), [userId(1), userId(3), userId(4)])
    }

    func testAnonymousSenderIsShownWithoutItsPeer() {
        // An anonymous sender needs no stored peer: it is drawn as "Anonymous" either way.
        let result = shown([reactor(1, count: 10000), reactor(2, count: 6000, isAnonymous: true), reactor(nil, count: 5500), reactor(3, count: 5173)], known: [1, 3])
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.map(\.peer?.id), [userId(1), nil, nil])
        XCTAssertEqual(result.map(\.count), [10000, 6000, 5500])
    }

    func testOwnEntryIsKeptAmongTheTopAndFlagged() {
        let result = shown([reactor(1, count: 10000), reactor(9, count: 7000, isMy: true), reactor(2, count: 5173), reactor(3, count: 900)], known: [1, 2, 3, 9])
        XCTAssertEqual(result.map(\.peer?.id), [userId(1), userId(9), userId(2)])
        XCTAssertEqual(result.map(\.isMy), [false, true, false])
    }

    func testOwnEntryBelowTheTopTakesTheSlotOfAnUnstoredSender() {
        // The server's shape: the top three, one of them not stored, plus the account's own entry below them.
        let result = shown([reactor(1, count: 10000), reactor(2, count: 6000), reactor(3, count: 5173), reactor(9, count: 50, isMy: true)], known: [1, 3, 9])
        XCTAssertEqual(result.map(\.peer?.id), [userId(1), userId(3), userId(9)])
        XCTAssertEqual(result.map(\.isMy), [false, false, true])
    }

    func testFewerShowableSendersThanTheLimit() {
        let result = shown([reactor(1, count: 10000), reactor(2, count: 6000)], known: [1])
        XCTAssertEqual(result.map(\.peer?.id), [userId(1)])
    }
}
