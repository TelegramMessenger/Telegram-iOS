import Foundation
import Postbox
import SwiftSignalKit

/// The asynchronous channel resets of one poll cycle (state-sync spec 3.5). A getDifference that finds channels it
/// cannot bring up to date (an `updateChannelTooLong`, a channel without state, a previous launch's
/// `invalidatedChannels` records) hands them here instead of resetting them inline (`asyncResetChannels` of
/// `finalStateWithDifference`; inline when the app config sets `ios_disable_parallel_channel_reset_v2`). Each
/// channel gets an `InvalidatedChannel` record with this launch's validity marker and its own `resetChannels` (one
/// messages.getPeerDialogs), beside the difference chain; a channel already pending is reset again only when both
/// requests carry a pts and the new one is lower. The resets of a cycle share one context, and the cycle's end waits
/// for them: once the difference chain has ended (`differenceChainEnded`, set by `endDifferenceChain(events:)`, which
/// also hands over the chain's events) and every reset has answered (`allChannelsDone`), the states are merged in
/// channel-id order and replayed unverified (`.unverifiedChannelReset`) in one transaction that also clears every
/// record, and `cycleEnded` gets the events. The Impl then ends the cycle through `finishPollCycle`, which finds the
/// context dropped.
///
/// Known gaps, kept as they are (docs/state-sync-audit-2026-10.md; stage 4 preserves behaviour):
/// - C1: the replay is unverified and runs outside the operation queue, so a gap poll or a view poll of the same
///   channel replayed before it is rolled back (pts, invalidatedPts, synchronizedUntil, read counts); it heals
///   with extra requests.
/// - Q9: the context is dropped only when the replay's result is delivered. A poll cycle that ends in between finds
///   the context complete and replays the same states again (duplicate events); a channel added in between is
///   dropped with the context (its reset is cancelled); and the delivery clears isUpdating even while another
///   poll runs. With AUTH_KEY_DUPLICATED the resets retry on a dead key, so the context never completes and
///   isUpdating stays true (still open). `EventDeliveryOrderTests` pins the window that works.
///
/// Every method is called on `queue`, and every signal it starts delivers there. `AccountStateManager.Impl` owns the
/// coordinator; the coordinator reaches it only through `cycleEnded`, which holds it weakly.
final class ChannelResetCoordinator {
    private final class ChannelOperationData {
        let pts: Int32?
        let disposable: Disposable
        var isCompleted: Bool = false

        init(pts: Int32?, disposable: Disposable) {
            self.pts = pts
            self.disposable = disposable
        }

        deinit {
            self.disposable.dispose()
        }
    }

    private final class ChannelOperationsContext {
        var pendingChannels: [PeerId: ChannelOperationData] = [:]
        var channelResults: [PeerId: AccountMutableState] = [:]

        var events: AccountFinalStateEvents = AccountFinalStateEvents()

        /// The cycle's difference chain has ended (`endDifferenceChain(events:)`), its events are in `events`.
        var differenceChainEnded: Bool = false

        /// Every reset of the context has answered (a replaced reset counts by its replacement).
        var allChannelsDone: Bool {
            return !self.pendingChannels.contains(where: { !$0.value.isCompleted })
        }
    }

    private let queue: Queue
    private let accountPeerId: PeerId
    private let postbox: Postbox
    private let network: Network
    private let currentValidityMarker: Int64
    private let replayer: FinalStateReplayer
    /// Ends the cycle in the Impl (`channelResetsEnded`): the events to queue, nil when the replay returned nothing,
    /// and whether the queue must be started (true after an asynchronous replay, Q12). Called only once
    /// `currentChannelOperationsContext` is nil: the Impl ends the cycle through `finishPollCycle`, which calls
    /// `endDifferenceChain(events:)` again and must find no context.
    private let cycleEnded: (AccountFinalStateEvents?, Bool) -> Void

    private var currentChannelOperationsContext: ChannelOperationsContext?

    init(queue: Queue, accountPeerId: PeerId, postbox: Postbox, network: Network, currentValidityMarker: Int64, replayer: FinalStateReplayer, cycleEnded: @escaping (AccountFinalStateEvents?, Bool) -> Void) {
        self.queue = queue
        self.accountPeerId = accountPeerId
        self.postbox = postbox
        self.network = network
        self.currentValidityMarker = currentValidityMarker
        self.replayer = replayer
        self.cycleEnded = cycleEnded
    }

    /// Starts a reset for each of `peers` that is not pending yet, or is pending with a higher pts than the one given;
    /// the first call of a cycle creates the context. The Impl calls it only while a poll runs at the head of its
    /// queue (it checks that first).
    func addAsyncResetChannels(peers: [(peer: Peer, pts: Int32?)]) {
        let channelOperationsContext: ChannelOperationsContext
        if let current = self.currentChannelOperationsContext {
            channelOperationsContext = current
        } else {
            channelOperationsContext = ChannelOperationsContext()
            self.currentChannelOperationsContext = channelOperationsContext
        }

        for peer in peers {
            let replaceChannelOperation: Bool
            if let current = channelOperationsContext.pendingChannels[peer.peer.id] {
                if let pts = peer.pts, let currentPts = current.pts {
                    replaceChannelOperation = currentPts > pts
                } else {
                    replaceChannelOperation = false
                }
            } else {
                replaceChannelOperation = true
            }
            if replaceChannelOperation {
                let currentValidityMarker = self.currentValidityMarker
                let _ = (self.postbox.transaction { transaction -> Void in
                    if let state = transaction.getState() as? AuthorizedAccountState {
                        var invalidatedChannels = state.invalidatedChannels.filter({ $0.peerId != peer.peer.id })
                        invalidatedChannels.append(AuthorizedAccountState.InvalidatedChannel(
                            peerId: peer.peer.id,
                            pts: peer.pts,
                            validityMarker: currentValidityMarker
                        ))
                        transaction.setState(state.withInvalidatedChannels(invalidatedChannels))
                    }
                }).start()

                let channelDisposable = MetaDisposable()
                channelOperationsContext.pendingChannels[peer.peer.id] = ChannelOperationData(pts: peer.pts, disposable: channelDisposable)
                channelDisposable.set((self.postbox.transaction { transaction -> AccountMutableState in
                    return initialStateWithPeerIds(
                        transaction,
                        peerIds: Set([peer.peer.id]),
                        activeChannelIds: Set(),
                        referencedReplyMessageIds: ReferencedReplyMessageIds(),
                        referencedGeneralMessageIds: Set(),
                        peerIdsRequiringLocalChatState: Set(),
                        locallyGeneratedMessageTimestamps: [:],
                        storedStories: [:]
                    )
                }
                |> mapToSignal { state -> Signal<AccountMutableState, NoError> in
                    return resetChannels(
                        accountPeerId: self.accountPeerId,
                        postbox: self.postbox,
                        network: self.network, peers: [peer.peer],
                        state: state
                    )
                }
                |> deliverOn(self.queue)).start(next: { [weak self] result in
                    guard let self = self else {
                        return
                    }
                    guard let channelOperationsContext = self.currentChannelOperationsContext else {
                        assertionFailure("Invalid state")
                        return
                    }
                    if let pendingChannelData = channelOperationsContext.pendingChannels[peer.peer.id] {
                        pendingChannelData.isCompleted = true
                    } else {
                        assertionFailure("Invalid state")
                    }

                    channelOperationsContext.channelResults[peer.peer.id] = result

                    self.checkChannelOperationsCompletion()
                }))
            }
        }
    }

    /// The running cycle's difference chain ended with `events` (`finishPollCycle`). With a context pending, the
    /// context takes the events and the cycle ends once its resets are done, which can be before this returns
    /// (`cycleEnded`, not starting the queue); returns true. Without one, returns false and the caller ends the cycle.
    func endDifferenceChain(events: AccountFinalStateEvents) -> Bool {
        if let currentChannelOperationsContext = self.currentChannelOperationsContext {
            currentChannelOperationsContext.differenceChainEnded = true
            currentChannelOperationsContext.events = currentChannelOperationsContext.events.union(with: events)

            self.checkChannelOperationsCompletion()
            return true
        } else {
            return false
        }
    }

    /// Replays the context once the chain has ended and every reset has answered; does nothing before that.
    private func checkChannelOperationsCompletion() {
        guard let channelOperationsContext = self.currentChannelOperationsContext else {
            return
        }
        if !channelOperationsContext.differenceChainEnded {
            return
        }
        if !channelOperationsContext.allChannelsDone {
            return
        }

        let states = channelOperationsContext.channelResults.sorted(by: { $0.key < $1.key }).map(\.value)
        if !states.isEmpty {
            var finalMutableState = states[0]
            if states.count > 1 {
                for i in 1 ..< states.count {
                    finalMutableState.merge(states[i])
                }
            }

            let replayer = self.replayer
            let events = channelOperationsContext.events

            let _ = (self.postbox.transaction { transaction -> AccountReplayedFinalState? in
                if let state = transaction.getState() as? AuthorizedAccountState {
                    transaction.setState(state.withInvalidatedChannels([]))
                }

                return replayer.applyReplay(
                    AccountFinalState(
                        state: finalMutableState,
                        shouldPoll: false,
                        incomplete: false,
                        discard: false
                    ),
                    policy: .unverifiedChannelReset,
                    removePossiblyDeliveredMessagesUniqueIds: [:],
                    transaction: transaction
                )
            }
            |> deliverOn(self.queue)).start(next: { [weak self] finalState in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.currentChannelOperationsContext = nil
                if let finalState = finalState {
                    var mergedEvents = events
                    mergedEvents = mergedEvents.union(with: AccountFinalStateEvents(state: finalState))
                    // The events go in at the head of a queue that may be idle, so it is started (Q12).
                    strongSelf.cycleEnded(mergedEvents, true)
                } else {
                    strongSelf.cycleEnded(nil, true)
                }
            })
        } else {
            self.currentChannelOperationsContext = nil
            let events = channelOperationsContext.events
            // No reset was asked for (an empty list of channels): nothing to replay. Reached only from
            // `endDifferenceChain(events:)`, whose caller starts the queue.
            self.cycleEnded(events, false)
        }
    }
}
