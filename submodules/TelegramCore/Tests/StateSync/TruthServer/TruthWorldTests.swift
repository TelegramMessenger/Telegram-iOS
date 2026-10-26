import Foundation
import XCTest
import TelegramApi
@testable import TelegramCore

/// `TruthWorld` and `truthAnswer` (TruthWorld.swift, TruthAnswers.swift): the model server's rules, each against
/// hand-computed answers, so a wrong answer cannot pass for a client bug.
final class TruthWorldTests: XCTestCase {
    private let baseDate: Int32 = 1_700_000_000

    private func emptyWorld() -> TruthWorld {
        return TruthWorld(seed: 1, initialMessagesPerChat: 0 ... 0, baseDate: self.baseDate)
    }

    private func ids(_ messages: [Api.Message]) -> [Int32] {
        return messages.map { message -> Int32 in
            switch message {
            case let .message(data):
                return data.id
            case let .messageService(data):
                return data.id
            case let .messageEmpty(data):
                return -data.id
            }
        }
    }

    private func answer(_ request: TruthRequest, _ world: TruthWorld, limits: TruthLimits = TruthLimits()) -> Any? {
        return truthAnswer(request, world: world, limits: limits)
    }

    func testPrivateChatsAndBasicGroupsShareIdsAndPts() {
        let world = self.emptyWorld()
        let first = world.receive(in: .user(201), from: nil, text: "a")
        let second = world.receive(in: .chat(801), from: 202, text: "b")
        let third = world.sendFromOtherDevice(in: .user(202), text: "c")
        let deletion = world.delete(.user(201), [1])
        XCTAssertEqual(world.existing(.chat(801)).map { $0.id }, [2])
        XCTAssertEqual(world.existing(.user(202)).map { $0.id }, [3])
        XCTAssertEqual([first.pts, second.pts, third.pts, deletion.pts], [2, 3, 4, 5])
        XCTAssertEqual(world.pts, 5)
        XCTAssertEqual(world.accountLog(after: 3).map { $0.pts }, [4, 5])
        XCTAssertEqual(world.accountMessage(2)?.chat, .chat(801))
        XCTAssertNil(world.accountMessage(1))
    }

    /// An edit carries the time it was made as `edit_date` (flags.15), as the server's edited messages do: the app's
    /// channel revalidation tells an edited post from an unchanged one by it (`validateBatch`).
    func testAnEditCarriesItsEditDate() {
        let world = self.emptyWorld()
        world.receive(in: .channel(301), from: nil, text: "post")
        let sentDate = world.date
        let entry = world.edit(.channel(301), 1, text: "edited")
        guard case let .edit(edited) = entry.event, case let .message(data) = TruthApi.message(edited) else {
            XCTFail("not an edited message")
            return
        }
        XCTAssertEqual(data.date, sentDate, "an edit keeps the message's date")
        XCTAssertEqual(data.editDate, world.date)
        XCTAssertGreaterThan(world.date, sentDate)
        XCTAssertNotEqual(data.flags & (1 << 15), 0)
        guard case let .message(unedited) = TruthApi.message(TruthMessage(id: 2, chat: .channel(301), fromUserId: nil, outgoing: false, date: sentDate, text: "post")) else {
            XCTFail("not a message")
            return
        }
        XCTAssertNil(unedited.editDate)
        XCTAssertEqual(unedited.flags & (1 << 15), 0)
    }

    func testChannelsHaveTheirOwnIdsAndPts() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "a")
        world.receive(in: .channel(301), from: nil, text: "post")
        world.receive(in: .channel(301), from: nil, text: "post")
        world.receive(in: .channel(302), from: 203, text: "group")
        let deletion = world.delete(.channel(301), [1, 2])
        XCTAssertEqual(world.existing(.channel(302)).map { $0.id }, [1])
        XCTAssertEqual(world.channelPts[301], 5)
        XCTAssertEqual(deletion.ptsCount, 2)
        XCTAssertEqual(world.channelPts[302], 2)
        XCTAssertEqual(world.pts, 2)
        XCTAssertNil(world.existing(.channel(301)).last)
    }

    /// A cleared chat holds nothing; the chat list keeps its old top as a history-cleared service message with the old
    /// id and date (K1, 2026-10-24), and history and `getMessages` do not have it. A new message ends that.
    func testClearHistoryLeavesTheOldTopAsAService() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "a")
        world.receive(in: .user(201), from: nil, text: "b")
        let topDate = world.existing(.user(201)).last!.date
        world.clearHistory(.user(201))
        XCTAssertEqual(world.existing(.user(201)).count, 0)
        guard case let .dialogs(dialogs)? = self.answer(.getDialogs(folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 100), world) as? Api.messages.Dialogs else {
            return XCTFail("not dialogs")
        }
        XCTAssertEqual(self.ids(dialogs.messages), [2])
        if case let .messageService(service) = dialogs.messages[0] {
            XCTAssertEqual(service.date, topDate)
        } else {
            XCTFail("the cleared chat's top is not a service message")
        }
        guard case let .messages(history)? = self.answer(.getHistory(peer: .user(201), offsetId: 0, addOffset: 0, limit: 100, maxId: 0, minId: 0), world) as? Api.messages.Messages else {
            return XCTFail("not messages")
        }
        XCTAssertEqual(history.messages.count, 0)
        guard case let .messages(lookup)? = self.answer(.getMessages(ids: [2]), world) as? Api.messages.Messages else {
            return XCTFail("not messages")
        }
        XCTAssertEqual(self.ids(lookup.messages), [-2])
        world.receive(in: .user(201), from: nil, text: "c")
        XCTAssertNil(world.clearedTop[.user(201)])
    }

    /// A channel: its ids are contiguous (1…30), so the windows are easy to check by hand.
    private func channelWithThirtyPosts() -> TruthWorld {
        let world = self.emptyWorld()
        for _ in 1 ... 30 {
            world.receive(in: .channel(301), from: nil, text: "post")
        }
        return world
    }

    private func channelHistory(_ request: TruthRequest, _ world: TruthWorld) -> (ids: [Int32], count: Int32, offsetIdOffset: Int32?) {
        guard case let .channelMessages(data)? = self.answer(request, world) as? Api.messages.Messages else {
            XCTFail("not channelMessages")
            return ([], 0, nil)
        }
        return (self.ids(data.messages), data.count, data.offsetIdOffset)
    }

    /// What a downward fill from the top asks (Holes.swift: offsetId start + 1, addOffset 0, maxId start + 1).
    func testGetHistoryDownwardFromTheTop() {
        let answer = self.channelHistory(.getHistory(peer: .channel(301), offsetId: 31, addOffset: 0, limit: 10, maxId: 31, minId: 0), self.channelWithThirtyPosts())
        XCTAssertEqual(answer.ids, Array((21 ... 30).reversed()))
        XCTAssertEqual(answer.count, 30)
        XCTAssertEqual(answer.offsetIdOffset, 1)
    }

    /// What an upward fill from the bottom asks (offsetId 1, addOffset -limit, minId start - 1): the oldest ten.
    func testGetHistoryUpwardFromTheBottom() {
        let answer = self.channelHistory(.getHistory(peer: .channel(301), offsetId: 1, addOffset: -10, limit: 10, maxId: 31, minId: 0), self.channelWithThirtyPosts())
        XCTAssertEqual(answer.ids, Array((1 ... 10).reversed()))
    }

    /// What an around fill asks (offsetId anchor, addOffset -limit/2, maxId Int32.max, minId 0): the anchor, four
    /// newer and five older; `offset_id_offset` is the anchor's 1-based position from the newest.
    func testGetHistoryAroundAnAnchor() {
        let answer = self.channelHistory(.getHistory(peer: .channel(301), offsetId: 15, addOffset: -5, limit: 10, maxId: Int32.max, minId: 0), self.channelWithThirtyPosts())
        XCTAssertEqual(answer.ids, Array((10 ... 19).reversed()))
        XCTAssertEqual(answer.offsetIdOffset, 16)
    }

    /// A private chat answers `.messages` when the window is the whole chat, `.messagesSlice` when it is not.
    func testGetHistoryOfAWholeShortChatIsMessages() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "a")
        world.receive(in: .user(202), from: nil, text: "b")
        world.receive(in: .user(201), from: nil, text: "c")
        guard case let .messages(whole)? = self.answer(.getHistory(peer: .user(201), offsetId: Int32.max, addOffset: 0, limit: 100, maxId: Int32.max, minId: 0), world) as? Api.messages.Messages else {
            return XCTFail("not messages")
        }
        XCTAssertEqual(self.ids(whole.messages), [3, 1])
        guard case let .messagesSlice(part)? = self.answer(.getHistory(peer: .user(201), offsetId: Int32.max, addOffset: 0, limit: 1, maxId: Int32.max, minId: 0), world) as? Api.messages.Messages else {
            return XCTFail("not messagesSlice")
        }
        XCTAssertEqual(self.ids(part.messages), [3])
        XCTAssertEqual(part.count, 2)
    }

    func testGetMessagesAnswersEveryIdInOrder() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "a")
        world.receive(in: .chat(801), from: 201, text: "b")
        world.delete(.user(201), [1])
        guard case let .messages(data)? = self.answer(.getMessages(ids: [2, 1, 99]), world) as? Api.messages.Messages else {
            return XCTFail("not messages")
        }
        XCTAssertEqual(self.ids(data.messages), [2, -1, -99])
    }

    func testDifferenceEmptySliceAndTooLong() {
        let world = self.emptyWorld()
        for _ in 1 ... 5 {
            world.receive(in: .user(201), from: nil, text: "a")
        }
        guard case .differenceEmpty? = self.answer(.getDifference(pts: 6, ptsLimit: nil, ptsTotalLimit: nil, date: 0, qts: 0), world) as? Api.updates.Difference else {
            return XCTFail("not empty")
        }
        guard case let .differenceSlice(slice)? = self.answer(.getDifference(pts: 1, ptsLimit: nil, ptsTotalLimit: nil, date: 0, qts: 0), world, limits: TruthLimits(differenceSlice: 2)) as? Api.updates.Difference else {
            return XCTFail("not a slice")
        }
        XCTAssertEqual(self.ids(slice.newMessages), [1, 2])
        if case let .state(state) = slice.intermediateState {
            XCTAssertEqual(state.pts, 3)
        }
        // Message k was made at pts k + 1: after pts 4 come 4 and 5, which fit in one answer.
        guard case let .difference(whole)? = self.answer(.getDifference(pts: 4, ptsLimit: nil, ptsTotalLimit: 10, date: 0, qts: 0), world, limits: TruthLimits(differenceSlice: 2)) as? Api.updates.Difference else {
            return XCTFail("not a difference")
        }
        XCTAssertEqual(self.ids(whole.newMessages), [4, 5])
        guard case let .differenceTooLong(tooLong)? = self.answer(.getDifference(pts: 1, ptsLimit: nil, ptsTotalLimit: 4, date: 0, qts: 0), world) as? Api.updates.Difference else {
            return XCTFail("not too long")
        }
        XCTAssertEqual(tooLong.pts, 6)
    }

    /// A message created and deleted after the client's pts is not in `new_messages`; its deletion is. An edit of a
    /// message older than the client's pts is an `updateEditMessage` with the text now.
    func testDifferenceOmitsMessagesDeletedSinceAndCarriesTheDeletion() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "old")
        let clientPts = world.pts
        world.receive(in: .user(201), from: nil, text: "new")
        world.edit(.user(201), 1, text: "edited")
        world.delete(.user(201), [2])
        guard case let .difference(difference)? = self.answer(.getDifference(pts: clientPts, ptsLimit: nil, ptsTotalLimit: nil, date: 0, qts: 0), world) as? Api.updates.Difference else {
            return XCTFail("not a difference")
        }
        XCTAssertEqual(difference.newMessages.count, 0)
        XCTAssertEqual(difference.otherUpdates.count, 2)
        if case let .updateEditMessage(edit) = difference.otherUpdates[0], case let .message(message) = edit.message {
            XCTAssertEqual(message.message, "edited")
            XCTAssertEqual(edit.pts, 4)
        } else {
            XCTFail("the first update is not the edit")
        }
        if case let .updateDeleteMessages(deletion) = difference.otherUpdates[1] {
            XCTAssertEqual(deletion.messages, [2])
            XCTAssertEqual(deletion.pts, 5)
        } else {
            XCTFail("the second update is not the deletion")
        }
    }

    func testChannelDifferenceEmptyPartialAndTooLong() {
        let world = self.channelWithThirtyPosts()
        guard case .channelDifferenceEmpty? = self.answer(.getChannelDifference(channelId: 301, pts: 31, limit: 100), world) as? Api.updates.ChannelDifference else {
            return XCTFail("not empty")
        }
        guard case let .channelDifference(partial)? = self.answer(.getChannelDifference(channelId: 301, pts: 21, limit: 4), world) as? Api.updates.ChannelDifference else {
            return XCTFail("not a difference")
        }
        XCTAssertEqual(self.ids(partial.newMessages), [21, 22, 23, 24])
        XCTAssertEqual(partial.pts, 25)
        XCTAssertEqual(partial.flags & 1, 0, "a partial difference is not final")
        guard case let .channelDifferenceTooLong(tooLong)? = self.answer(.getChannelDifference(channelId: 301, pts: 1, limit: 100), world, limits: TruthLimits(channelDifferenceTooLong: 10)) as? Api.updates.ChannelDifference else {
            return XCTFail("not too long")
        }
        XCTAssertEqual(self.ids(tooLong.messages).first, 30)
        if case let .dialog(dialog) = tooLong.dialog {
            XCTAssertEqual(dialog.pts, 31)
            XCTAssertEqual(dialog.topMessage, 30)
        }
    }

    /// Newest top first; a page continues below the given offset; the archive folder is empty.
    /// The chat a dialog or message names.
    private func truthPeer(_ peer: Api.Peer) -> TruthPeer {
        switch peer {
        case let .peerUser(data):
            return .user(data.userId)
        case let .peerChat(data):
            return .chat(data.chatId)
        case let .peerChannel(data):
            return .channel(data.channelId)
        }
    }

    /// The large shape: 129 chats, every quiet chat's messages older than any other chat's, and two long histories.
    func testTheLargeShapeHasMoreThanAPageOfChatsAndLongHistories() {
        let world = TruthWorld(seed: 1, initialMessagesPerChat: 3 ... 8, baseDate: self.baseDate, shape: .large)
        XCTAssertEqual(world.chats().count, 129)
        let quiet = Set(TruthShape.large.quietChats)
        let newestQuiet = quiet.compactMap { world.existing($0).last?.date }.max() ?? Int32.max
        let oldestActive = world.chats().filter { !quiet.contains($0) }.compactMap { world.existing($0).first?.date }.min() ?? 0
        XCTAssertLessThan(newestQuiet, oldestActive)
        XCTAssertTrue(quiet.allSatisfy { (1 ... 3).contains(world.existing($0).count) })
        XCTAssertTrue((300 ... 400).contains(world.existing(.user(201)).count))
        XCTAssertTrue((300 ... 400).contains(world.existing(.channel(301)).count))
        XCTAssertTrue((3 ... 8).contains(world.existing(.user(202)).count))
    }

    /// Two pages of 100 cover the large world's 129 chats once each, newest first: the second starts after the first
    /// page's last dialog (its top's date and id, and its peer).
    /// Two tops with the same date and id (a private chat's message and a channel's post share no id space): the page
    /// after the first, asked from its last dialog with `offset_peer`, holds the other one.
    func testDialogsPageOnATieOfDateAndIdByOffsetPeer() {
        let world = self.emptyWorld()
        world.holdsClock = true
        let _ = world.receive(in: .user(201), from: nil, text: "a")
        let _ = world.receive(in: .channel(301), from: nil, text: "b")
        guard case let .dialogsSlice(first)? = self.answer(.getDialogs(folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 1), world) as? Api.messages.Dialogs, case let .message(lastTop)? = first.messages.last else {
            return XCTFail("no first page")
        }
        XCTAssertEqual(first.count, 2)
        guard let second = self.answer(.getDialogs(folderId: nil, offsetDate: lastTop.date, offsetId: lastTop.id, offsetPeer: self.truthPeer(lastTop.peerId), limit: 1), world) as? Api.messages.Dialogs, case let .dialogsSlice(page) = second, case let .message(secondTop)? = page.messages.first else {
            return XCTFail("no second page")
        }
        XCTAssertEqual(secondTop.date, lastTop.date)
        XCTAssertEqual(secondTop.id, lastTop.id)
        XCTAssertEqual(Set([self.truthPeer(lastTop.peerId), self.truthPeer(secondTop.peerId)]), [.user(201), .channel(301)])
    }

    func testDialogsPagesOfALargeChatList() {
        let world = TruthWorld(seed: 1, initialMessagesPerChat: 3 ... 8, baseDate: self.baseDate, shape: .large)
        guard case let .dialogsSlice(first)? = self.answer(.getDialogs(folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 100), world) as? Api.messages.Dialogs else {
            return XCTFail("not a slice")
        }
        XCTAssertEqual(first.count, 129)
        XCTAssertEqual(first.dialogs.count, 100)
        guard case let .message(lastTop)? = first.messages.last else {
            return XCTFail("no last top message")
        }
        guard case let .dialogsSlice(second)? = self.answer(.getDialogs(folderId: nil, offsetDate: lastTop.date, offsetId: lastTop.id, offsetPeer: self.truthPeer(lastTop.peerId), limit: 100), world) as? Api.messages.Dialogs else {
            return XCTFail("not a slice")
        }
        XCTAssertEqual(second.dialogs.count, 29)
        let peers = (first.dialogs + second.dialogs).compactMap { dialog -> TruthPeer? in
            if case let .dialog(data) = dialog {
                return self.truthPeer(data.peer)
            }
            return nil
        }
        XCTAssertEqual(Set(peers), Set(world.chats()))
        XCTAssertEqual(peers.count, 129)
        let dates = (first.messages + second.messages).compactMap { message -> Int32? in
            if case let .message(data) = message {
                return data.date
            }
            return nil
        }
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func testDialogsPageNewestFirst() {
        let world = self.emptyWorld()
        world.receive(in: .user(201), from: nil, text: "a")
        world.receive(in: .channel(302), from: 201, text: "b")
        world.receive(in: .chat(801), from: 201, text: "c")
        guard case let .dialogsSlice(first)? = self.answer(.getDialogs(folderId: nil, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 2), world) as? Api.messages.Dialogs else {
            return XCTFail("not a slice")
        }
        // chat801's 2 is newest, then channel302's 1, then user201's 1.
        XCTAssertEqual(self.ids(first.messages), [2, 1])
        XCTAssertEqual(first.count, 3)
        let secondDate = world.existing(.channel(302)).last!.date
        guard case let .dialogsSlice(second)? = self.answer(.getDialogs(folderId: nil, offsetDate: secondDate, offsetId: 1, offsetPeer: .channel(302), limit: 2), world) as? Api.messages.Dialogs else {
            return XCTFail("not a slice")
        }
        XCTAssertEqual(self.ids(second.messages), [1])
        guard case let .dialogs(archive)? = self.answer(.getDialogs(folderId: 1, offsetDate: 0, offsetId: 0, offsetPeer: nil, limit: 100), world) as? Api.messages.Dialogs else {
            return XCTFail("not dialogs")
        }
        XCTAssertEqual(archive.dialogs.count, 0)
    }
}
