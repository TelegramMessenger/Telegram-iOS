import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


private enum PeerReadStateMarker: Equatable {
    case Global(Int32)
    case Channel(Int32)
}

private func inputPeer(postbox: Postbox, peerId: PeerId) -> Signal<Api.InputPeer, PeerReadStateValidationError> {
    return postbox.loadedPeerWithId(peerId)
    |> mapToSignalPromotingError { peer -> Signal<Api.InputPeer, PeerReadStateValidationError> in
        if let inputPeer = apiInputPeer(peer) {
            return .single(inputPeer)
        } else {
            return .fail(.retry)
        }
    }
    |> take(1)
}

private func inputSecretChat(postbox: Postbox, peerId: PeerId) -> Signal<Api.InputEncryptedChat, PeerReadStateValidationError> {
    return postbox.loadedPeerWithId(peerId)
    |> mapToSignalPromotingError { peer -> Signal<Api.InputEncryptedChat, PeerReadStateValidationError> in
        if let inputPeer = apiInputSecretChat(peer) {
            return .single(inputPeer)
        } else {
            return .fail(.retry)
        }
    }
    |> take(1)
}

private func dialogTopMessage(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<(Int32, Int32)?, PeerReadStateValidationError> {
    return inputPeer(postbox: postbox, peerId: peerId)
    |> mapToSignal { inputPeer -> Signal<(Int32, Int32)?, PeerReadStateValidationError> in
        return network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: Int32.max, offsetDate: Int32.max, addOffset: 0, limit: 1, maxId: Int32.max, minId: 1, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.Messages?, NoError> in
            return .single(nil)
        }
        |> mapToSignalPromotingError { result -> Signal<(Int32, Int32)?, PeerReadStateValidationError> in
            guard let result = result else {
                return .single(nil)
            }
            let apiMessages: [Api.Message]
            switch result {
                case let .channelMessages(channelMessagesData):
                    let messages = channelMessagesData.messages
                    apiMessages = messages
                case let .messages(messagesData):
                    let messages = messagesData.messages
                    apiMessages = messages
                case let .messagesSlice(messagesSliceData):
                    let messages = messagesSliceData.messages
                    apiMessages = messages
                case .messagesNotModified:
                    apiMessages = []
            }
            if let message = apiMessages.first, let timestamp = message.timestamp {
                return .single((message.rawId, timestamp))
            } else {
                return .single(nil)
            }
        }
    }
}

private func dialogReadState(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<(PeerReadState, PeerReadStateMarker)?, PeerReadStateValidationError> {
    return dialogTopMessage(network: network, postbox: postbox, peerId: peerId)
    |> mapToSignal { topMessage -> Signal<(PeerReadState, PeerReadStateMarker)?, PeerReadStateValidationError> in
        guard let _ = topMessage else {
            return .single(nil)
        }
        
        return inputPeer(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<(PeerReadState, PeerReadStateMarker)?, PeerReadStateValidationError> in
            return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(.init(peer: inputPeer))]))
            |> retryRequest
            |> mapToSignalPromotingError { result -> Signal<(PeerReadState, PeerReadStateMarker)?, PeerReadStateValidationError> in
                switch result {
                case let .peerDialogs(peerDialogsData):
                    let (dialogs, state) = (peerDialogsData.dialogs, peerDialogsData.state)
                    if let dialog = dialogs.filter({ $0.peerId == peerId }).first {
                        let apiTopMessage: Int32
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiUnreadCount: Int32
                        let apiMarkedUnread: Bool
                        var apiChannelPts: Int32 = 0
                        switch dialog {
                            case let .dialog(dialogData):
                                let (flags, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, pts) = (dialogData.flags, dialogData.topMessage, dialogData.readInboxMaxId, dialogData.readOutboxMaxId, dialogData.unreadCount, dialogData.pts)
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiMarkedUnread = (flags & (1 << 3)) != 0
                                if let pts = pts {
                                    apiChannelPts = pts
                                }
                            case .dialogCommunity:
                                return .single(nil)
                            case .dialogFolder:
                                assertionFailure()
                                return .fail(.retry)
                        }
                        
                        let marker: PeerReadStateMarker
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            marker = .Channel(apiChannelPts)
                        } else {
                            let pts: Int32
                            switch state {
                            case let .state(stateData):
                                let (statePts) = (stateData.pts)
                                pts = statePts
                            }
                            
                            marker = .Global(pts)
                        }
                        
                        return .single((.idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount, markedUnread: apiMarkedUnread), marker))
                    } else {
                        return .fail(.retry)
                    }
                }
            }
        }
    }
}

private func localReadStateMarker(transaction: Transaction, peerId: PeerId) -> PeerReadStateMarker? {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        if let state = transaction.getPeerChatState(peerId) as? ChannelState {
            return .Channel(state.pts)
        } else {
            return nil
        }
    } else {
        if let state = (transaction.getState() as? AuthorizedAccountState)?.state {
            return .Global(state.pts)
        } else {
            return nil
        }
    }
}

private func localReadStateMarker(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<PeerReadStateMarker, PeerReadStateValidationError> {
    return postbox.transaction { transaction -> PeerReadStateMarker? in
        return localReadStateMarker(transaction: transaction, peerId: peerId)
    }
    |> mapToSignalPromotingError { marker -> Signal<PeerReadStateMarker, PeerReadStateValidationError> in
        if let marker = marker {
            return .single(marker)
        } else {
            return .fail(.retry)
        }
    }
}

enum PeerReadStateValidationError {
    case retry
}

/// Clears the peer's pending synchronization operation. Every path that decides there is
/// nothing left to do must end here: the operation is persisted, and
/// `SynchronizePeerReadStatesContextImpl` restarts whatever it still finds in the table.
private func confirmSynchronized(postbox: Postbox, peerId: PeerId) -> Signal<Void, PeerReadStateValidationError> {
    return postbox.transaction { transaction -> Void in
        transaction.confirmSynchronizedIncomingReadState(peerId)
    }
    |> castError(PeerReadStateValidationError.self)
}

private func validatePeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Never, PeerReadStateValidationError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        // A secret chat has no Api.InputPeer, so there is no dialog to read an authoritative
        // read state from: every step below fails at inputPeer and asks to retry, forever.
        // Treat it like a peer the server reports no dialog for, which is already confirmed
        // rather than retried. This does discard a validation that a detected inconsistency
        // asked for - a hole among deleted unread messages, an undercount - without
        // recounting, so a wrong unread badge survives until something else corrects it. A
        // local recount is the honest answer, since for a secret chat the client is the
        // authority; the loop this replaces recounted nothing either.
        return confirmSynchronized(postbox: postbox, peerId: peerId)
        |> ignoreValues
    }

    let readStateWithInitialState = dialogReadState(network: network, postbox: postbox, peerId: peerId)
    
    let maybeAppliedReadState = readStateWithInitialState
    |> mapToSignal { data -> Signal<Never, PeerReadStateValidationError> in
        guard let (readState, _) = data else {
            return confirmSynchronized(postbox: postbox, peerId: peerId)
            |> ignoreValues
        }
        return stateManager.addCustomOperation(postbox.transaction { transaction -> PeerReadStateValidationError? in
            if let currentReadState = transaction.getCombinedPeerReadState(peerId) {
                loop: for (namespace, currentState) in currentReadState.states {
                    if namespace == Namespaces.Message.Cloud {
                        switch currentState {
                        case let .idBased(localMaxIncomingReadId, _, _, _, _):
                            if case let .idBased(updatedMaxIncomingReadId, _, _, updatedCount, updatedMarkedUnread) = readState {
                                if updatedCount != 0 || updatedMarkedUnread {
                                    if localMaxIncomingReadId > updatedMaxIncomingReadId {
                                        return .retry
                                    }
                                }
                            }
                        default:
                            break
                        }
                        break loop
                    }
                }
            }
            var updatedReadState = readState
            if case let .idBased(updatedMaxIncomingReadId, updatedMaxOutgoingReadId, updatedMaxKnownId, updatedCount, updatedMarkedUnread) = readState, let readStates = transaction.getPeerReadStates(peerId) {
                for (namespace, state) in readStates {
                    if namespace == Namespaces.Message.Cloud {
                        switch state {
                        case let .idBased(_, maxOutgoingReadId, _, _, _):
                            updatedReadState = .idBased(maxIncomingReadId: updatedMaxIncomingReadId, maxOutgoingReadId: max(updatedMaxOutgoingReadId, maxOutgoingReadId), maxKnownId: updatedMaxKnownId, count: updatedCount, markedUnread: updatedMarkedUnread)
                        case .indexBased:
                            break
                        }
                        break
                    }
                }
            }
            transaction.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: updatedReadState]])
            return nil
        }
        |> mapToSignalPromotingError { error -> Signal<Never, PeerReadStateValidationError> in
            if let error = error {
                return .fail(error)
            } else {
                return .complete()
            }
        })
    }
    
    return maybeAppliedReadState
}

private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, readState: PeerReadState) -> Signal<PeerReadState, PeerReadStateValidationError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        // Decide whether a request is needed before looking the peer up: inputSecretChat goes
        // through loadedPeerWithId, which never emits when the peer row is missing and fails
        // with .retry when it is not a TelegramSecretChat. Either would strand or respin an
        // operation that has already been decided against.
        guard case let .indexBased(maxIncomingReadIndex, _, _, _) = readState else {
            return .single(readState)
        }
        // The marker is still at MessageIndex.lowerBound while nothing has been read, and
        // several paths schedule a push without moving it - marking the chat unread, or a
        // bare .Push that no read state change accompanied. Its zero date is not one the
        // server accepts: it answers MAX_DATE_INVALID, and there is nothing to report.
        if maxIncomingReadIndex.timestamp <= 0 {
            return .single(readState)
        }
        return inputSecretChat(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<PeerReadState, PeerReadStateValidationError> in
            // A rejected push must not be retried: the operation is only cleared once it
            // succeeds, so a permanent rejection would loop without end. The cloud branches
            // below drop their errors the same way.
            return network.request(Api.functions.messages.readEncryptedHistory(peer: inputPeer, maxDate: maxIncomingReadIndex.timestamp))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .complete()
            }
            |> mapToSignal { _ -> Signal<PeerReadState, NoError> in
                return .complete()
            }
            |> castError(PeerReadStateValidationError.self)
            |> then(Signal<PeerReadState, PeerReadStateValidationError>.single(readState))
        }
    } else {
        return inputPeer(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<PeerReadState, PeerReadStateValidationError> in
            switch inputPeer {
            case let .inputPeerChannel(inputPeerChannelData):
                let (channelId, accessHash) = (inputPeerChannelData.channelId, inputPeerChannelData.accessHash)
                switch readState {
                case let .idBased(maxIncomingReadId, _, _, _, markedUnread):
                    var pushSignal: Signal<Void, NoError> = network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(.init(channelId: channelId, accessHash: accessHash)), maxId: maxIncomingReadId))
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
                    if markedUnread {
                        pushSignal = pushSignal
                        |> then(network.request(Api.functions.messages.markDialogUnread(flags: 1 << 0, parentPeer: nil, peer: .inputDialogPeer(.init(peer: inputPeer))))
                        |> `catch` { _ -> Signal<Api.Bool, NoError> in
                            return .complete()
                        }
                        |> mapToSignal { _ -> Signal<Void, NoError> in
                            return .complete()
                        })
                    }
                    return pushSignal
                    |> mapError { _ -> PeerReadStateValidationError in
                    }
                    |> mapToSignal { _ -> Signal<PeerReadState, PeerReadStateValidationError> in
                        return .complete()
                    }
                    |> then(Signal<PeerReadState, PeerReadStateValidationError>.single(readState))
                case .indexBased:
                    return .single(readState)
                }
            default:
                switch readState {
                case let .idBased(maxIncomingReadId, _, _, _, markedUnread):
                    var pushSignal: Signal<Void, NoError> = network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxIncomingReadId))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<Api.messages.AffectedMessages?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        if let result = result {
                            switch result {
                                case let .affectedMessages(affectedMessagesData):
                                    let (pts, ptsCount) = (affectedMessagesData.pts, affectedMessagesData.ptsCount)
                                    stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                            }
                        }
                        return .complete()
                    }

                    if markedUnread {
                        pushSignal = pushSignal
                        |> then(network.request(Api.functions.messages.markDialogUnread(flags: 1 << 0, parentPeer: nil, peer: .inputDialogPeer(.init(peer: inputPeer))))
                        |> `catch` { _ -> Signal<Api.Bool, NoError> in
                            return .complete()
                        }
                        |> mapToSignal { _ -> Signal<Void, NoError> in
                            return .complete()
                        })
                    }
                    
                    return pushSignal
                    |> mapError { _ -> PeerReadStateValidationError in
                    }
                    |> mapToSignal { _ -> Signal<PeerReadState, PeerReadStateValidationError> in
                        return .complete()
                    }
                    |> then(Signal<PeerReadState, PeerReadStateValidationError>.single(readState))
                case .indexBased:
                    return .single(readState)
                }
            }
        }
    }
}

private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, willValidate: Bool) -> Signal<Never, PeerReadStateValidationError> {
    let currentReadState = postbox.transaction { transaction -> (MessageId.Namespace, PeerReadState)? in
        if let readStates = transaction.getPeerReadStates(peerId) {
            for (namespace, readState) in readStates {
                if namespace == Namespaces.Message.Cloud || namespace == Namespaces.Message.SecretIncoming {
                    return (namespace, readState)
                }
            }
        }
        return nil
    }
    
    let pushedState = currentReadState
    |> mapToSignalPromotingError { namespaceAndReadState -> Signal<(MessageId.Namespace, PeerReadState), PeerReadStateValidationError> in
        if let (namespace, readState) = namespaceAndReadState {
            return pushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId, readState: readState)
            |> map { updatedReadState -> (MessageId.Namespace, PeerReadState) in
                return (namespace, updatedReadState)
            }
        } else if willValidate {
            // Validation runs next and owns the confirm; leave the operation in place so it
            // survives a crash in between.
            return .complete()
        } else {
            // No read state to push, so the verification below never runs and would never
            // confirm. Completing on its own leaves the persisted operation in place for the
            // manager to pick straight back up - the same unbounded restart this guards.
            return confirmSynchronized(postbox: postbox, peerId: peerId)
            |> mapToSignal { _ -> Signal<(MessageId.Namespace, PeerReadState), PeerReadStateValidationError> in
                return .complete()
            }
        }
    }
    
    let verifiedState = pushedState
    |> mapToSignal { namespaceAndReadState -> Signal<Never, PeerReadStateValidationError> in
        return stateManager.addCustomOperation(postbox.transaction { transaction -> PeerReadStateValidationError? in
            if let readStates = transaction.getPeerReadStates(peerId) {
                for (namespace, currentReadState) in readStates where namespace == namespaceAndReadState.0 {
                    if currentReadState.count == namespaceAndReadState.1.count {
                        transaction.confirmSynchronizedIncomingReadState(peerId)
                        return nil
                    }
                }
                return .retry
            } else {
                transaction.confirmSynchronizedIncomingReadState(peerId)
                return nil
            }
        }
        |> mapToSignalPromotingError { error -> Signal<Never, PeerReadStateValidationError> in
            if let error = error {
                return .fail(error)
            } else {
                return .complete()
            }
        })
    }
    
    return verifiedState
}

func synchronizePeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, push: Bool, validate: Bool) -> Signal<Never, PeerReadStateValidationError> {
    var signal: Signal<Never, PeerReadStateValidationError> = .complete()
    if push {
        signal = signal
        |> then(pushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId, willValidate: validate))
    }
    if validate {
        signal = signal
        |> then(validatePeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId))
    }
    return signal
}
