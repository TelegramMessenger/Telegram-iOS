import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// The channels an update batch could not apply in place. `UpdateInterpreter` (Sync/UpdateInterpreter.swift)
/// collects them while it interprets the batch, and `finalStateWithChannelRecovery` (below) recovers them: each is
/// polled with getChannelDifference on the push path, or reset on the difference path.
///
/// It wraps the two containers the interpreter kept as locals, unchanged: `channelIds` is built from them exactly as
/// before, and its iteration order is the order the polled branches are merged in.
struct ChannelRecoveryRequests {
    /// A key is a poll request; its value is the pts an `updateChannelTooLong` named (nil: none). Optional-valued,
    /// so a request is inserted with `updateValue(_:forKey:)`: `polls[peerId] = nil` REMOVES the key, which is how
    /// seven sites requested nothing from 2023-01-31 until G1 was fixed.
    private var polls: [PeerId: Int32?] = [:]
    /// Channels whose update arrived after a pts gap.
    private var gaps = Set<PeerId>()
    
    /// Nothing to recover.
    var isEmpty: Bool {
        return self.polls.isEmpty && self.gaps.isEmpty
    }
    
    /// Every channel to recover, built afresh on each read.
    var channelIds: Set<PeerId> {
        return Set(self.polls.keys).union(self.gaps)
    }
    
    func isPollRequested(_ peerId: PeerId) -> Bool {
        if case .none = self.polls[peerId] {
            return false
        } else {
            return true
        }
    }
    
    /// The pts hint of the poll request for `peerId`; nil without a hint or without a request (a gap only).
    func ptsHint(for peerId: PeerId) -> Int32? {
        if let hint = self.polls[peerId] {
            return hint
        } else {
            return nil
        }
    }
    
    /// Requests a poll of `peerId` (a reset on the difference path) unless one is already requested, which keeps
    /// its hint. Returns whether this call requested it.
    @discardableResult
    mutating func requestPoll(_ peerId: PeerId, ptsHint: Int32?) -> Bool {
        if case .none = self.polls[peerId] {
            self.polls.updateValue(ptsHint, forKey: peerId)
            return true
        } else {
            return false
        }
    }
    
    /// An update for a channel the batch has no `ChannelState` for: a poll request without a hint (G1). Returns
    /// whether this call requested it.
    @discardableResult
    mutating func noteUnknownChannelState(_ peerId: PeerId) -> Bool {
        return self.requestPoll(peerId, ptsHint: nil)
    }
    
    /// An update for `peerId` arrived after a pts gap. Returns whether it is the batch's first for the channel.
    mutating func markGap(_ peerId: PeerId) -> Bool {
        return self.gaps.insert(peerId).inserted
    }
}

/// Recovers the channels an update batch could not apply in place (`channelRecovery`), then resolves what the
/// state references. On the push path (`shouldResetChannels` false) each channel is polled on its own branch of the
/// state (`pollChannel`) and the branches are merged back in `channelRecovery.channelIds` order. On the difference
/// path the channels are reset (`resetChannels`), inline, or after the difference through `asyncResetChannels`
/// when the caller passes it. Then forum threads, associated messages, associated stories and missing chat infos
/// are resolved, in that order.
func finalStateWithChannelRecovery(accountPeerId: PeerId, postbox: Postbox, network: Network, state updatedState: AccountMutableState, channelRecovery: ChannelRecoveryRequests, shouldPoll: Bool, missingUpdates: Bool, shouldResetChannels: Bool, asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?) -> Signal<AccountFinalState, NoError> {
    var pollChannelSignals: [Signal<ChannelPollOutcome, NoError>] = []
    if channelRecovery.isEmpty {
        pollChannelSignals = []
    } else if shouldResetChannels {
        var channelPeers: [Peer] = []
        for peerId in channelRecovery.channelIds {
            if let peer = updatedState.peers[peerId] {
                channelPeers.append(peer)
            } else {
                Logger.shared.log("State", "can't reset channel \(peerId): no peer found")
            }
        }
        
        if let asyncResetChannels = asyncResetChannels {
            pollChannelSignals = []
            asyncResetChannels(channelPeers.map({ peer -> (peer: Peer, pts: Int32?) in
                return (peer, channelRecovery.ptsHint(for: peer.id))
            }))
        } else {
            if !channelPeers.isEmpty {
                let resetSignal = resetChannels(accountPeerId: accountPeerId, postbox: postbox, network: network, peers: channelPeers, state: updatedState)
                |> map { resultState -> ChannelPollOutcome in
                    return .applied(resultState, timeout: nil)
                }
                pollChannelSignals = [resetSignal]
            } else {
                pollChannelSignals = []
            }
        }
    } else {
        for peerId in channelRecovery.channelIds {
            if let peer = updatedState.peers[peerId] {
                pollChannelSignals.append(pollChannel(accountPeerId: accountPeerId, postbox: postbox, network: network, peer: peer, state: updatedState.branch()))
            } else {
                Logger.shared.log("State", "can't poll channel \(peerId): no peer found")
            }
        }
    }
    
    return combineLatest(pollChannelSignals)
    |> mapToSignal { states -> Signal<AccountFinalState, NoError> in
        var finalState: AccountMutableState = updatedState
        var hadError = false
        
        if shouldResetChannels && states.count != 0 {
            assert(states.count == 1)
            finalState = states[0].state
        } else {
            for outcome in states {
                finalState.merge(outcome.state)
                switch outcome {
                case .channelUnavailable:
                    hadError = true
                case .applied, .noInputChannel:
                    break
                }
            }
        }
        
        return resolveForumThreads(accountPeerId: accountPeerId, postbox: postbox, source: .network(network), state: finalState)
        |> mapToSignal { finalState in
            return resolveAssociatedMessages(accountPeerId: accountPeerId, postbox: postbox, network: network, state: finalState)
            |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                return resolveAssociatedStories(postbox: postbox, network: network, accountPeerId: accountPeerId, state: resultingState)
                |> mapToSignal { resultingState -> Signal<AccountFinalState, NoError> in
                    return resolveMissingPeerChatInfos(accountPeerId: accountPeerId, network: network, state: resultingState)
                    |> map { resultingState, resolveError -> AccountFinalState in
                        return AccountFinalState(state: resultingState, shouldPoll: shouldPoll || hadError || resolveError, incomplete: missingUpdates, discard: resolveError)
                    }
                }
            }
        }
    }
}
