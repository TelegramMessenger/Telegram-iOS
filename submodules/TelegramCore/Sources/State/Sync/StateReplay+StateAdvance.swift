import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// The account and channel state operations: the account state (pts, qts, date, seq) and each channel's pts,
/// invalidated pts and synchronized-until message id. They run after every content operation of a final state.
extension ReplayContext {
    /// Applies the state operations `batchContentAndDeferStateOperations` deferred, after every content operation, one
    /// kind at a time: the account state, then every channel's pts, then every channel's invalidated pts, then every
    /// channel's synchronized-until message id, each through the method its operation's case calls, each dictionary
    /// iterated once.
    func applyStateAdvance(_ stateAdvance: StateAdvance) {
        if let accountState = stateAdvance.accountState {
            self.applyUpdateState(accountState)
        }
        for (peerId, state) in stateAdvance.channelStates {
            self.applyUpdateChannelState(peerId, state.pts)
        }
        for (peerId, pts) in stateAdvance.invalidatedChannelPts {
            self.applyUpdateChannelInvalidationPts(peerId, pts)
        }
        for (peerId, id) in stateAdvance.channelSynchronizedUntilMessageIds {
            self.applyUpdateChannelSynchronizedUntilMessage(peerId, id)
        }
    }
    
    func applyUpdateState(_ innerState: AuthorizedAccountState.State) {
        let currentState = transaction.getState() as! AuthorizedAccountState
        var updatedInnerState = innerState
        if policy.keepsStoredDate, let previousInnerState = currentState.state {
            updatedInnerState = AuthorizedAccountState.State(pts: updatedInnerState.pts, qts: updatedInnerState.qts, date: previousInnerState.date, seq: updatedInnerState.seq)
        }
        transaction.setState(currentState.changedState(updatedInnerState))
        Logger.shared.log("State", "apply state \(updatedInnerState)")
    }
    
    func applyUpdateChannelState(_ peerId: PeerId, _ pts: Int32) {
        var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: pts, invalidatedPts: nil, synchronizedUntilMessageId: nil)
        state = state.withUpdatedPts(pts)
        transaction.setPeerChatState(peerId, state: state)
        Logger.shared.log("State", "apply channel state \(peerId): \(state)")
    }
    
    func applyUpdateChannelInvalidationPts(_ peerId: PeerId, _ pts: Int32) {
        var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: 0, invalidatedPts: pts, synchronizedUntilMessageId: nil)
        state = state.withUpdatedInvalidatedPts(pts)
        transaction.setPeerChatState(peerId, state: state)
        Logger.shared.log("State", "apply channel invalidation pts \(peerId): \(state)")
    }
    
    func applyUpdateChannelSynchronizedUntilMessage(_ peerId: PeerId, _ id: MessageId.Id) {
        var state = (transaction.getPeerChatState(peerId) as? ChannelState) ?? ChannelState(pts: 0, invalidatedPts: nil, synchronizedUntilMessageId: id)
        state = state.withUpdatedSynchronizedUntilMessageId(id)
        transaction.setPeerChatState(peerId, state: state)
        Logger.shared.log("State", "apply channel synchronized until message \(peerId): \(state)")
    }
}
