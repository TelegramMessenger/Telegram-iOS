import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit


public enum EarliestUnseenPersonalMentionMessageResult: Equatable {
    case loading
    case result(MessageId?)
}

func _internal_earliestUnseenPersonalMentionMessage(account: Account, peerId: PeerId) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
    return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId), index: .lowerBound, anchorIndex: .lowerBound, count: 4, fixedCombinedReadStates: nil, tagMask: .unseenPersonalMessage, additionalData: [.peerChatState(peerId)])
    |> mapToSignal { view -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
        if view.0.isLoading {
            return .single(.loading)
        }
        if case .FillHole = view.1 {
            return _internal_earliestUnseenPersonalMentionMessage(account: account, peerId: peerId)
        }
        if let message = view.0.entries.first?.message {
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                var invalidatedPts: Int32?
                for data in view.0.additionalData {
                    switch data {
                        case let .peerChatState(_, state):
                            if let state = state as? ChannelState {
                                invalidatedPts = state.invalidatedPts
                            }
                        default:
                            break
                    }
                }
                if let invalidatedPts = invalidatedPts {
                    var messagePts: Int32?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                            messagePts = attribute.pts
                            break
                        }
                    }
                    
                    if let messagePts = messagePts {
                        if messagePts < invalidatedPts {
                            return .single(.loading)
                        }
                    }
                }
                return .single(.result(message.id))
            } else {
                return .single(.result(message.id))
            }
        } else {
            return account.postbox.transaction { transaction -> EarliestUnseenPersonalMentionMessageResult in
                if let topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, count: 0, maxId: topId.id)
                    
                    transaction.removeHole(peerId: peerId, namespace: Namespaces.Message.Cloud, space: .tag(.unseenPersonalMessage), range: 1 ... (Int32.max - 1))
                    let ids = transaction.getMessageIndicesWithTag(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: .unseenPersonalMessage).map({ $0.id })
                    for id in ids {
                        markUnseenPersonalMessage(transaction: transaction, id: id, addSynchronizeAction: false)
                    }
                }
                
                return .result(nil)
            }
        }
    }
    |> distinctUntilChanged
    |> take(until: { value in
        if case .result = value {
            return SignalTakeAction(passthrough: true, complete: true)
        } else {
            return SignalTakeAction(passthrough: true, complete: false)
        }
    })
}

func _internal_earliestUnseenPersonalReactionMessage(account: Account, peerId: PeerId) -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> {
    return account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId), index: .lowerBound, anchorIndex: .lowerBound, count: 4, fixedCombinedReadStates: nil, tagMask: .unseenReaction, additionalData: [.peerChatState(peerId)])
    |> mapToSignal { view -> Signal<EarliestUnseenPersonalMentionMessageResult, NoError> in
        if view.0.isLoading {
            return .single(.loading)
        }
        if case .FillHole = view.1 {
            return _internal_earliestUnseenPersonalReactionMessage(account: account, peerId: peerId)
        }
        if let message = view.0.entries.first?.message {
            if peerId.namespace == Namespaces.Peer.CloudChannel {
                var invalidatedPts: Int32?
                for data in view.0.additionalData {
                    switch data {
                        case let .peerChatState(_, state):
                            if let state = state as? ChannelState {
                                invalidatedPts = state.invalidatedPts
                            }
                        default:
                            break
                    }
                }
                if let invalidatedPts = invalidatedPts {
                    var messagePts: Int32?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ChannelMessageStateVersionAttribute {
                            messagePts = attribute.pts
                            break
                        }
                    }
                    
                    if let messagePts = messagePts {
                        if messagePts < invalidatedPts {
                            return .single(.loading)
                        }
                    }
                }
                return .single(.result(message.id))
            } else {
                return .single(.result(message.id))
            }
        } else {
            return account.postbox.transaction { transaction -> EarliestUnseenPersonalMentionMessageResult in
                if let topId = transaction.getTopPeerMessageId(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    transaction.replaceMessageTagSummary(peerId: peerId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, count: 0, maxId: topId.id)
                    
                    transaction.removeHole(peerId: peerId, namespace: Namespaces.Message.Cloud, space: .tag(.unseenReaction), range: 1 ... (Int32.max - 1))
                    let ids = transaction.getMessageIndicesWithTag(peerId: peerId, namespace: Namespaces.Message.Cloud, tag: .unseenReaction).map({ $0.id })
                    for id in ids {
                        markUnseenReactionMessage(transaction: transaction, id: id, addSynchronizeAction: false)
                    }
                }
                
                return .result(nil)
            }
        }
    }
    |> distinctUntilChanged
    |> take(until: { value in
        if case .result = value {
            return SignalTakeAction(passthrough: true, complete: true)
        } else {
            return SignalTakeAction(passthrough: true, complete: false)
        }
    })
}
