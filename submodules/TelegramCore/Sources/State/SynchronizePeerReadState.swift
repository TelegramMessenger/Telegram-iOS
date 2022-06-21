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
                case let .channelMessages(_, _, _, _, messages, _, _):
                    apiMessages = messages
                case let .messages(messages, _, _):
                    apiMessages = messages
                case let .messagesSlice(_, _, _, _, messages, _, _):
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
            return network.request(Api.functions.messages.getPeerDialogs(peers: [.inputDialogPeer(peer: inputPeer)]))
            |> retryRequest
            |> mapToSignalPromotingError { result -> Signal<(PeerReadState, PeerReadStateMarker)?, PeerReadStateValidationError> in
                switch result {
                case let .peerDialogs(dialogs, _, _, _, state):
                    if let dialog = dialogs.filter({ $0.peerId == peerId }).first {
                        let apiTopMessage: Int32
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiUnreadCount: Int32
                        let apiMarkedUnread: Bool
                        var apiChannelPts: Int32 = 0
                        switch dialog {
                            case let .dialog(flags, _, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, _, _, _, pts, _, _):
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                                apiMarkedUnread = (flags & (1 << 3)) != 0
                                if let pts = pts {
                                    apiChannelPts = pts
                                }
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
                            case let .state(statePts, _, _, _, _):
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

private func validatePeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Never, PeerReadStateValidationError> {
    let readStateWithInitialState = dialogReadState(network: network, postbox: postbox, peerId: peerId)
    
    let maybeAppliedReadState = readStateWithInitialState
    |> mapToSignal { data -> Signal<Never, PeerReadStateValidationError> in
        guard let (readState, _) = data else {
            return postbox.transaction { transaction -> Void in
                transaction.confirmSynchronizedIncomingReadState(peerId)
            }
            |> castError(PeerReadStateValidationError.self)
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
        return inputSecretChat(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<PeerReadState, PeerReadStateValidationError> in
            switch readState {
            case .idBased:
                return .single(readState)
            case let .indexBased(maxIncomingReadIndex, _, _, _):
                return network.request(Api.functions.messages.readEncryptedHistory(peer: inputPeer, maxDate: maxIncomingReadIndex.timestamp))
                    |> mapError { _ in
                        return PeerReadStateValidationError.retry
                    }
                |> mapToSignal { _ -> Signal<PeerReadState, PeerReadStateValidationError> in
                    return .single(readState)
                }
            }
        }
    } else {
        return inputPeer(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<PeerReadState, PeerReadStateValidationError> in
            switch inputPeer {
            case let .inputPeerChannel(channelId, accessHash):
                switch readState {
                case let .idBased(maxIncomingReadId, _, _, _, markedUnread):
                    var pushSignal: Signal<Void, NoError> = network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(channelId: channelId, accessHash: accessHash), maxId: maxIncomingReadId))
                    |> `catch` { _ -> Signal<Api.Bool, NoError> in
                        return .complete()
                    }
                    |> mapToSignal { _ -> Signal<Void, NoError> in
                        return .complete()
                    }
                    if markedUnread {
                        pushSignal = pushSignal
                        |> then(network.request(Api.functions.messages.markDialogUnread(flags: 1 << 0, peer: .inputDialogPeer(peer: inputPeer)))
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
                                case let .affectedMessages(pts, ptsCount):
                                    stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                            }
                        }
                        return .complete()
                    }
                    
                    if markedUnread {
                        pushSignal = pushSignal
                        |> then(network.request(Api.functions.messages.markDialogUnread(flags: 1 << 0, peer: .inputDialogPeer(peer: inputPeer)))
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

private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Never, PeerReadStateValidationError> {
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
        } else {
            return .complete()
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
        |> then(pushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId))
    }
    if validate {
        signal = signal
        |> then(validatePeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId))
    }
    return signal
}
