import Foundation
import XCTest
import TelegramCore
import AccountContext
@testable import TelegramCallsUI

/// Pins the conference "Add Member" sheet's selection: who can be picked, how many slots of the call's participant
/// limit are already taken, and who is invited when the selection is confirmed.
final class ConferenceAddParticipantSelectionTests: XCTestCase {
    private func peerId(_ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    private func user(_ id: Int64, isBot: Bool = false) -> EnginePeer {
        return .user(TelegramUser(
            id: self.peerId(id), accessHash: nil, firstName: "U\(id)", lastName: nil, username: nil, phone: nil, photo: [],
            botInfo: isBot ? BotUserInfo(flags: [], inlinePlaceholder: nil) : nil, restrictionInfo: nil, flags: [], emojiStatus: nil,
            usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
            profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil
        ))
    }

    func testTheAccountParticipantsAndPendingInviteesAreDisabledOnce() {
        let selection = ConferenceAddParticipantSelection(
            accountPeerId: self.peerId(1),
            participantPeerIds: [self.peerId(1), self.peerId(2), self.peerId(2), self.peerId(3)],
            totalParticipantCount: 3,
            invitedPeerIds: [self.peerId(4)]
        )
        XCTAssertEqual(selection.disabledPeerIds, [self.peerId(1), self.peerId(2), self.peerId(3), self.peerId(4)])
        XCTAssertFalse(selection.isPeerEnabled(self.user(1)))
        XCTAssertFalse(selection.isPeerEnabled(self.user(3)))
        XCTAssertFalse(selection.isPeerEnabled(self.user(4)))
        XCTAssertTrue(selection.isPeerEnabled(self.user(5)))
    }

    func testBotsAreDisabled() {
        let selection = ConferenceAddParticipantSelection(accountPeerId: self.peerId(1), participantPeerIds: [], totalParticipantCount: 0, invitedPeerIds: [])
        XCTAssertFalse(selection.isPeerEnabled(self.user(5, isBot: true)))
    }

    func testOccupiedSlotsCountTheAccountParticipantsAndPendingInvitees() {
        let selection = ConferenceAddParticipantSelection(
            accountPeerId: self.peerId(1),
            participantPeerIds: [self.peerId(1), self.peerId(2)],
            totalParticipantCount: 2,
            invitedPeerIds: [self.peerId(4)]
        )
        XCTAssertEqual(selection.occupiedSlotCount, 3)
    }

    func testOccupiedSlotsCountParticipantsNotLoadedYet() {
        // 10 in the call, only the first 2 loaded into the list.
        let selection = ConferenceAddParticipantSelection(
            accountPeerId: self.peerId(1),
            participantPeerIds: [self.peerId(1), self.peerId(2)],
            totalParticipantCount: 10,
            invitedPeerIds: [self.peerId(4)]
        )
        XCTAssertEqual(selection.occupiedSlotCount, 11)
    }

    func testOccupiedSlotsCountTheAccountBeforeItJoins() {
        // A 1:1 call being turned into a conference: the account and the other party, neither of them listed yet.
        let selection = ConferenceAddParticipantSelection(accountPeerId: self.peerId(1), participantPeerIds: [self.peerId(2)], totalParticipantCount: 0, invitedPeerIds: [])
        XCTAssertEqual(selection.occupiedSlotCount, 2)
    }

    func testEverySelectedUserIsInvitedInTheGivenOrderWithTheVideoOption() {
        let selection = ConferenceAddParticipantSelection(accountPeerId: self.peerId(1), participantPeerIds: [self.peerId(2)], totalParticipantCount: 2, invitedPeerIds: [])
        let invites = selection.invites(selectedPeerIds: [.peer(self.peerId(7)), .peer(self.peerId(5)), .peer(self.peerId(6))], isVideo: true)
        XCTAssertEqual(invites.map(\.id), [self.peerId(7), self.peerId(5), self.peerId(6)])
        XCTAssertEqual(invites.map(\.isVideo), [true, true, true])
    }

    func testDisabledDuplicateAndDeviceContactSelectionsAreNotInvited() {
        let selection = ConferenceAddParticipantSelection(accountPeerId: self.peerId(1), participantPeerIds: [self.peerId(2)], totalParticipantCount: 2, invitedPeerIds: [])
        let invites = selection.invites(selectedPeerIds: [.peer(self.peerId(2)), .peer(self.peerId(5)), .deviceContact("c"), .peer(self.peerId(5)), .peer(self.peerId(1))], isVideo: false)
        XCTAssertEqual(invites.map(\.id), [self.peerId(5)])
        XCTAssertEqual(invites.map(\.isVideo), [false])
    }
}
