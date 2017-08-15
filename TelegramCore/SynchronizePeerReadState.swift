import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private enum VerifyReadStateError {
    case Abort
    case Retry
}

private enum PeerReadStateMarker: Equatable {
    case Global(Int32)
    case Channel(Int32)
}

private func inputPeer(postbox: Postbox, peerId: PeerId) -> Signal<Api.InputPeer, VerifyReadStateError> {
    return postbox.loadedPeerWithId(peerId)
        |> mapToSignalPromotingError { peer -> Signal<Api.InputPeer, VerifyReadStateError> in
            if let inputPeer = apiInputPeer(peer) {
                return .single(inputPeer)
            } else {
                return .fail(.Abort)
            }
        } |> take(1)
}

private func inputSecretChat(postbox: Postbox, peerId: PeerId) -> Signal<Api.InputEncryptedChat, VerifyReadStateError> {
    return postbox.loadedPeerWithId(peerId)
        |> mapToSignalPromotingError { peer -> Signal<Api.InputEncryptedChat, VerifyReadStateError> in
            if let inputPeer = apiInputSecretChat(peer) {
                return .single(inputPeer)
            } else {
                return .fail(.Abort)
            }
        } |> take(1)
}

private func dialogTopMessage(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<(Int32, Int32), VerifyReadStateError> {
    return inputPeer(postbox: postbox, peerId: peerId)
        |> mapToSignal { inputPeer -> Signal<(Int32, Int32), VerifyReadStateError> in
            return network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: Int32.max, offsetDate: Int32.max, addOffset: 0, limit: 1, maxId: Int32.max, minId: 1))
                |> retryRequest
                |> mapToSignalPromotingError { result -> Signal<(Int32, Int32), VerifyReadStateError> in
                    let apiMessages: [Api.Message]
                    switch result {
                        case let .channelMessages(_, _, _, messages, _, _):
                            apiMessages = messages
                        case let .messages(messages, _, _):
                            apiMessages = messages
                        case let .messagesSlice(_, messages, _, _):
                            apiMessages = messages
                    }
                    if let message = apiMessages.first, let timestamp = message.timestamp {
                        return .single((message.rawId, timestamp))
                    } else {
                        return .fail(.Abort)
                    }
                }
    }
}

func fetchPeerCloudReadState(network: Network, postbox: Postbox, peerId: PeerId, inputPeer: Api.InputPeer) -> Signal<PeerReadState?, NoError> {
    return network.request(Api.functions.messages.getPeerDialogs(peers: [inputPeer]))
        |> map { result -> PeerReadState? in
            switch result {
                case let .peerDialogs(dialogs, _, _, _, _):
                    if let dialog = dialogs.filter({ $0.peerId == peerId }).first {
                        let apiTopMessage: Int32
                        let apiReadInboxMaxId: Int32
                        let apiReadOutboxMaxId: Int32
                        let apiUnreadCount: Int32
                        switch dialog {
                            case let .dialog(_, _, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, _, _, _, _):
                                apiTopMessage = topMessage
                                apiReadInboxMaxId = readInboxMaxId
                                apiReadOutboxMaxId = readOutboxMaxId
                                apiUnreadCount = unreadCount
                        }
                        
                        return .idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount)
                    } else {
                        return nil
                    }
            }
        }
        |> `catch` { _ -> Signal<PeerReadState?, NoError> in
            return .single(nil)
        }
}

private func dialogReadState(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<(PeerReadState, PeerReadStateMarker), VerifyReadStateError> {
    return dialogTopMessage(network: network, postbox: postbox, peerId: peerId)
        |> mapToSignal { topMessage -> Signal<(PeerReadState, PeerReadStateMarker), VerifyReadStateError> in
            return inputPeer(postbox: postbox, peerId: peerId)
                |> mapToSignal { inputPeer -> Signal<(PeerReadState, PeerReadStateMarker), VerifyReadStateError> in
                    return network.request(Api.functions.messages.getPeerDialogs(peers: [inputPeer]))
                        |> retryRequest
                        |> mapToSignalPromotingError { result -> Signal<(PeerReadState, PeerReadStateMarker), VerifyReadStateError> in
                            switch result {
                                case let .peerDialogs(dialogs, _, _, _, state):
                                    if let dialog = dialogs.filter({ $0.peerId == peerId }).first {
                                        let apiTopMessage: Int32
                                        let apiReadInboxMaxId: Int32
                                        let apiReadOutboxMaxId: Int32
                                        let apiUnreadCount: Int32
                                        var apiChannelPts: Int32 = 0
                                        switch dialog {
                                            case let .dialog(_, _, topMessage, readInboxMaxId, readOutboxMaxId, unreadCount, _, _, pts, _):
                                                apiTopMessage = topMessage
                                                apiReadInboxMaxId = readInboxMaxId
                                                apiReadOutboxMaxId = readOutboxMaxId
                                                apiUnreadCount = unreadCount
                                                if let pts = pts {
                                                    apiChannelPts = pts
                                                }
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
                                        
                                        return .single((.idBased(maxIncomingReadId: apiReadInboxMaxId, maxOutgoingReadId: apiReadOutboxMaxId, maxKnownId: apiTopMessage, count: apiUnreadCount), marker))
                                    } else {
                                        return .fail(.Abort)
                                }
                            }
                        }
                }
        }
}

private func ==(lhs: PeerReadStateMarker, rhs: PeerReadStateMarker) -> Bool {
    switch lhs {
        case let .Global(lhsPts):
            switch rhs {
                case let .Global(rhsPts) where lhsPts == rhsPts:
                    return true
                default:
                    return false
            }
        case let .Channel(lhsPts):
            switch rhs {
                case let .Channel(rhsPts) where lhsPts == rhsPts:
                    return true
                default:
                    return false
            }
    }
}

private func localReadStateMarker(modifier: Modifier, peerId: PeerId) -> PeerReadStateMarker? {
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        if let state = modifier.getPeerChatState(peerId) as? ChannelState {
            return .Channel(state.pts)
        } else {
            return nil
        }
    } else {
        if let state = (modifier.getState() as? AuthorizedAccountState)?.state {
            return .Global(state.pts)
        } else {
            return nil
        }
    }
}

private func localReadStateMarker(network: Network, postbox: Postbox, peerId: PeerId) -> Signal<PeerReadStateMarker, VerifyReadStateError> {
    return postbox.modify { modifier -> PeerReadStateMarker? in
        return localReadStateMarker(modifier: modifier, peerId: peerId)
    } |> mapToSignalPromotingError { marker -> Signal<PeerReadStateMarker, VerifyReadStateError> in
        if let marker = marker {
            return .single(marker)
        } else {
            return .fail(.Abort)
        }
    }
}

private func validatePeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Void, NoError> {
    let readStateWithInitialState = localReadStateMarker(network: network, postbox: postbox, peerId: peerId)
        |> mapToSignal { marker -> Signal<(PeerReadState, PeerReadStateMarker, PeerReadStateMarker), VerifyReadStateError> in
            return dialogReadState(network: network, postbox: postbox, peerId: peerId)
                |> map { ($0.0, marker, $0.1) }
    }
    
    let maybeAppliedReadState = readStateWithInitialState |> mapToSignal { (readState, initialMarker, finalMarker) -> Signal<Void, VerifyReadStateError> in
        return stateManager.addCustomOperation(postbox.modify { modifier -> VerifyReadStateError? in
                if initialMarker == finalMarker {
                    modifier.resetIncomingReadStates([peerId: [Namespaces.Message.Cloud: readState]])
                    return nil
                } else {
                    return .Retry
                }
            }
            |> mapToSignalPromotingError { error -> Signal<Void, VerifyReadStateError> in
                if let error = error {
                    return .fail(error)
                } else {
                    return .complete()
                }
            })
        }
    
    return maybeAppliedReadState
        |> `catch` { error -> Signal<Void, VerifyReadStateError> in
            switch error {
            case .Abort:
                return .complete()
            case .Retry:
                return .fail(error)
            }
        }
        |> retry(0.1, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
}

private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, readState: PeerReadState) -> Signal<PeerReadState, VerifyReadStateError> {
    if peerId.namespace == Namespaces.Peer.SecretChat {
        return inputSecretChat(postbox: postbox, peerId: peerId)
            |> mapToSignal { inputPeer -> Signal<PeerReadState, VerifyReadStateError> in
                switch readState {
                    case .idBased:
                        return .single(readState)
                    case let .indexBased(maxIncomingReadIndex, _, _):
                        return network.request(Api.functions.messages.readEncryptedHistory(peer: inputPeer, maxDate: maxIncomingReadIndex.timestamp))
                        |> retryRequest
                            |> mapToSignalPromotingError { _ -> Signal<PeerReadState, VerifyReadStateError> in
                                return .single(readState)
                        }
                }
            }
    } else {
        return inputPeer(postbox: postbox, peerId: peerId)
            |> mapToSignal { inputPeer -> Signal<PeerReadState, VerifyReadStateError> in
                switch inputPeer {
                    case let .inputPeerChannel(channelId, accessHash):
                        switch readState {
                            case let .idBased(maxIncomingReadId, _, _, _):
                                return network.request(Api.functions.channels.readHistory(channel: Api.InputChannel.inputChannel(channelId: channelId, accessHash: accessHash), maxId: maxIncomingReadId))
                                    |> retryRequest
                                    |> mapToSignalPromotingError { _ -> Signal<PeerReadState, VerifyReadStateError> in
                                        return .single(readState)
                                    }
                            case .indexBased:
                                return .single(readState)
                        }
                    
                    default:
                        switch readState {
                            case let .idBased(maxIncomingReadId, _, _, _):
                                return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxIncomingReadId))
                                    |> retryRequest
                                    |> mapToSignalPromotingError { result -> Signal<PeerReadState, VerifyReadStateError>
                                        in
                                        switch result {
                                            case let .affectedMessages(pts, ptsCount):
                                                stateManager.addUpdateGroups([.updatePts(pts: pts, ptsCount: ptsCount)])
                                        }
                                        return .single(readState)
                                    }
                            case .indexBased:
                                return .single(readState)
                        }
                }
            }
    }
}

private func pushPeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId) -> Signal<Void, NoError> {
    let currentReadState = postbox.modify { modifier -> PeerReadState? in
        if let readStates = modifier.getPeerReadStates(peerId) {
            for (namespace, readState) in readStates {
                if namespace == Namespaces.Message.Cloud || namespace == Namespaces.Message.SecretIncoming {
                    return readState
                }
            }
        }
        return nil
    }
    
    let pushedState = currentReadState
        |> mapToSignalPromotingError { readState -> Signal<PeerReadState, VerifyReadStateError> in
            if let readState = readState {
                return pushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId, readState: readState)
            } else {
                return .complete()
            }
        }
    
    let verifiedState = pushedState
        |> mapToSignal { readState -> Signal<Void, VerifyReadStateError> in
            return stateManager.addCustomOperation(postbox.modify { modifier -> VerifyReadStateError? in
                if let readStates = modifier.getPeerReadStates(peerId) {
                    for (namespace, currentReadState) in readStates where namespace == Namespaces.Message.Cloud {
                        if currentReadState == readState {
                            modifier.confirmSynchronizedIncomingReadState(peerId)
                            return nil
                        }
                    }
                    return .Retry
                } else {
                    modifier.confirmSynchronizedIncomingReadState(peerId)
                    return nil
                }
            }
            |> mapToSignalPromotingError { error -> Signal<Void, VerifyReadStateError> in
                if let error = error {
                    return .fail(error)
                } else {
                    return .complete()
                }
            })
        }
    
    return verifiedState
        |> `catch` { error -> Signal<Void, VerifyReadStateError> in
            switch error {
            case .Abort:
                return .complete()
            case .Retry:
                return .fail(error)
            }
        }
        |> retry(0.1, maxDelay: 5.0, onQueue: Queue.concurrentDefaultQueue())
}

func synchronizePeerReadState(network: Network, postbox: Postbox, stateManager: AccountStateManager, peerId: PeerId, push: Bool, validate: Bool) -> Signal<Void, NoError> {
    var signal: Signal<Void, NoError> = .complete()
    if push {
        signal = signal |> then(pushPeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId))
    }
    if validate {
        signal = signal |> then(validatePeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId))
    }
    return signal
}
