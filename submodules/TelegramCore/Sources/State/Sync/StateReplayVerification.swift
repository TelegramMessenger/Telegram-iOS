import Foundation
import Postbox

/// Why `replayFinalState` refused a final state built from a snapshot of the stored state (`ReplayPolicy.verified`,
/// `.verifiedKeepingStoredDate`): something the snapshot was taken over has moved since. A refused replay writes
/// nothing and `replayFinalState` returns nil for it; the reason is only logged, so each caller of
/// `FinalStateReplayer.applyReplay` treats a rejection as it treats `replayFinalState` returning nil.
enum ReplayRejection: Equatable {
    /// Peers the snapshot was taken for (`initialState.peerIds`) that the final state's `peers` does not hold, in the
    /// set's iteration order. Checked first: when one is missing, no stored state is read.
    case missingPeers([PeerId])
    /// The replay moves the account state (an `.UpdateState`) and the stored account state is not the snapshot's, or
    /// there is none. Reported over `.channelStateChanged` when both hold; every channel is still checked and logged.
    case accountStateChanged
    /// Channels whose state the replay moves (an `.UpdateChannelState`) whose stored pts is not the snapshot's, or
    /// with a stored state the snapshot had not, or the reverse; in the order they were checked.
    case channelStateChanged([PeerId])

    /// The three checks, in this order and with these logs: the missing peers; then, when the replay moves the account
    /// state, the stored account state against the snapshot's; then each channel whose state the replay moves. nil:
    /// the replay may go ahead.
    static func verify(_ transaction: Transaction, finalState: AccountMutableState) -> ReplayRejection? {
        let missingPeerIds = ReplayRejection.missingPeerIds(finalState.initialState.peerIds, in: finalState.peers)
        if !missingPeerIds.isEmpty {
            Logger.shared.log("State", "missing peers \(missingPeerIds)")
            return .missingPeers(missingPeerIds)
        }

        let moved = ReplayRejection.statesMoved(by: finalState.operations)

        var accountStateChanged = false
        if moved.accountState {
            let currentState = (transaction.getState() as? AuthorizedAccountState)?.state
            let previousState = finalState.initialState.state
            if !ReplayRejection.accountStateMatches(stored: currentState, snapshot: previousState) {
                Logger.shared.log("State", ".UpdateState previous state \(previousState) doesn't match current state \(String(describing: currentState))")
                accountStateChanged = true
            }
        }

        var changedChannelIds: [PeerId] = []
        for peerId in moved.channels {
            let currentState = transaction.getPeerChatState(peerId)
            let previousState = finalState.initialState.channelStates[peerId]
            if !ReplayRejection.channelStateMatches(stored: currentState, snapshot: previousState) {
                Logger.shared.log("State", ".UpdateChannelState for \(peerId), previous state \(String(describing: previousState)) doesn't match current state \(String(describing: currentState))")
                changedChannelIds.append(peerId)
            }
        }

        if accountStateChanged {
            return .accountStateChanged
        } else if !changedChannelIds.isEmpty {
            return .channelStateChanged(changedChannelIds)
        } else {
            return nil
        }
    }

    /// The ids of `peerIds` that `peers` does not hold, in `peerIds`' iteration order.
    static func missingPeerIds(_ peerIds: Set<PeerId>, in peers: [PeerId: Peer]) -> [PeerId] {
        var missingPeerIds: [PeerId] = []
        for peerId in peerIds {
            if peers[peerId] == nil {
                missingPeerIds.append(peerId)
            }
        }
        return missingPeerIds
    }

    /// Whether `operations` move the account state (an `.UpdateState`), and the channels whose state they move (an
    /// `.UpdateChannelState`), inserted in operation order.
    static func statesMoved(by operations: [AccountStateMutationOperation]) -> (accountState: Bool, channels: Set<PeerId>) {
        var hadUpdateState = false
        var channelsWithUpdatedStates = Set<PeerId>()
        for operation in operations {
            switch operation {
                case let .UpdateChannelState(peerId, _):
                    channelsWithUpdatedStates.insert(peerId)
                case .UpdateState:
                    hadUpdateState = true
                default:
                    break
            }
        }
        return (hadUpdateState, channelsWithUpdatedStates)
    }

    /// The stored account state is the snapshot's. No stored state never matches.
    static func accountStateMatches(stored: AuthorizedAccountState.State?, snapshot: AuthorizedAccountState.State) -> Bool {
        if let stored = stored {
            return snapshot == stored
        } else {
            return false
        }
    }

    /// The stored channel state has the snapshot's pts, or neither has a state. A stored state that is not a
    /// `ChannelState` never matches.
    static func channelStateMatches(stored: PeerChatState?, snapshot: AccountStateChannelState?) -> Bool {
        if let stored = stored as? ChannelState, let snapshot = snapshot {
            return stored.pts == snapshot.pts
        } else if stored == nil && snapshot == nil {
            return true
        } else {
            return false
        }
    }
}
