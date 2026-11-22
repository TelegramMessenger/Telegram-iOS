import Foundation
import TelegramCore
import AccountContext

/// The conference "Add Member" sheet's selection: who can be picked, how many slots of the call's participant limit are
/// already taken, and who is invited when the selection is confirmed. The sheet is the call-creation multi-select
/// picker, which counts the selection on top of `occupiedSlotCount`.
struct ConferenceAddParticipantSelection {
    /// Not selectable: the account itself, everyone already in the call and everyone with a pending invitation.
    let disabledPeerIds: [EnginePeer.Id]
    let occupiedSlotCount: Int
    // Asked for every row of the list and of search results.
    private let disabledPeerIdSet: Set<EnginePeer.Id>

    /// `participantPeerIds` are the call's listed participants; `totalParticipantCount` also counts those not loaded
    /// into the list yet.
    init(accountPeerId: EnginePeer.Id, participantPeerIds: [EnginePeer.Id], totalParticipantCount: Int, invitedPeerIds: [EnginePeer.Id]) {
        var disabledPeerIds: [EnginePeer.Id] = [accountPeerId]
        for peerId in participantPeerIds + invitedPeerIds {
            if !disabledPeerIds.contains(peerId) {
                disabledPeerIds.append(peerId)
            }
        }
        self.disabledPeerIds = disabledPeerIds
        self.disabledPeerIdSet = Set(disabledPeerIds)

        var participantCount = totalParticipantCount
        if !participantPeerIds.contains(accountPeerId) {
            participantCount += 1
        }
        let pendingInviteeCount = invitedPeerIds.filter({ !participantPeerIds.contains($0) && $0 != accountPeerId }).count
        self.occupiedSlotCount = max(disabledPeerIds.count, participantCount + pendingInviteeCount)
    }

    func isPeerEnabled(_ peer: EnginePeer) -> Bool {
        guard case let .user(user) = peer else {
            return false
        }
        if self.disabledPeerIdSet.contains(user.id) {
            return false
        }
        if user.botInfo != nil {
            return false
        }
        return true
    }

    func invites(selectedPeerIds: [ContactListPeerId], isVideo: Bool) -> [(id: EnginePeer.Id, isVideo: Bool)] {
        var result: [(id: EnginePeer.Id, isVideo: Bool)] = []
        for selectedPeerId in selectedPeerIds {
            guard case let .peer(peerId) = selectedPeerId else {
                continue
            }
            if self.disabledPeerIdSet.contains(peerId) || result.contains(where: { $0.id == peerId }) {
                continue
            }
            result.append((peerId, isVideo))
        }
        return result
    }
}
