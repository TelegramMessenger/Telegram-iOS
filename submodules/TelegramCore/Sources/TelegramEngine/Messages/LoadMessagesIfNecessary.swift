import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum GetMessagesStrategy  {
    case local
    case cloud(skipLocal: Bool)
}

func _internal_getMessagesLoadIfNecessary(_ messageIds: [MessageId], postbox: Postbox, network: Network, accountPeerId: PeerId, strategy: GetMessagesStrategy = .cloud(skipLocal: false)) -> Signal <[Message], NoError> {
    let postboxSignal = postbox.transaction { transaction -> ([Message], Set<MessageId>, SimpleDictionary<PeerId, Peer>) in
        var ids = messageIds
        
        if let cachedData = transaction.getPeerCachedData(peerId: messageIds[0].peerId) as? CachedChannelData {
            if let minAvailableMessageId = cachedData.minAvailableMessageId {
                ids = ids.filter({$0 < minAvailableMessageId})
            }
        }
        
        var messages:[Message] = []
        var missingMessageIds:Set<MessageId> = Set()
        var supportPeers: SimpleDictionary<PeerId, Peer> = SimpleDictionary()
        for messageId in ids {
            if case let .cloud(skipLocal) = strategy, skipLocal {
                missingMessageIds.insert(messageId)
                if let peer = transaction.getPeer(messageId.peerId) {
                    supportPeers[messageId.peerId] = peer
                }
            } else {
                if let message = transaction.getMessage(messageId) {
                    messages.append(message)
                    
                } else {
                    missingMessageIds.insert(messageId)
                    if let peer = transaction.getPeer(messageId.peerId) {
                        supportPeers[messageId.peerId] = peer
                    }
                }
            }
        }
        return (messages, missingMessageIds, supportPeers)
    }
    
    if case .cloud = strategy {
        return postboxSignal
        |> mapToSignal { (existMessages, missingMessageIds, supportPeers) in
            var signals: [Signal<(Peer, [Api.Message], [Api.Chat], [Api.User]), NoError>] = []
            for (peerId, messageIds) in messagesIdsGroupedByPeerId(missingMessageIds) {
                if let peer = supportPeers[peerId] {
                    var signal: Signal<Api.messages.Messages, MTRpcError>?
                    if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                        signal = network.request(Api.functions.messages.getMessages(id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        if let inputChannel = apiInputChannel(peer) {
                            signal = network.request(Api.functions.channels.getMessages(channel: inputChannel, id: messageIds.map({ Api.InputMessage.inputMessageID(id: $0.id) })))
                        }
                    }
                    if let signal = signal {
                        signals.append(signal |> map { result in
                            switch result {
                                case let .messages(messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .messagesSlice(_, _, _, _, messages, chats, users):
                                    return (peer, messages, chats, users)
                                case let .channelMessages(_, _, _, _, messages, apiTopics, chats, users):
                                    let _ = apiTopics
                                    return (peer, messages, chats, users)
                                case .messagesNotModified:
                                    return (peer, [], [], [])
                            }
                            } |> `catch` { _ in
                                return Signal<(Peer, [Api.Message], [Api.Chat], [Api.User]), NoError>.single((peer, [], [], []))
                            })
                    }
                }
            }
            
            return combineLatest(signals) |> mapToSignal { results -> Signal<[Message], NoError> in
                return postbox.transaction { transaction -> [Message] in
                    for (peer, messages, chats, users) in results {
                        if !messages.isEmpty {
                            var storeMessages: [StoreMessage] = []
                            
                            for message in messages {
                                if let message = StoreMessage(apiMessage: message, peerIsForum: peer.isForum) {
                                    storeMessages.append(message)
                                }
                            }
                            _ = transaction.addMessages(storeMessages, location: .Random)
                        }
                        
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    }
                    var loadedMessages:[Message] = []
                    for messageId in missingMessageIds {
                        if let message = transaction.getMessage(messageId) {
                            loadedMessages.append(message)
                        }
                    }
                    
                    return existMessages + loadedMessages
                }
            }
            
        }
    } else {
        return postboxSignal |> map {$0.0}
    }
    
}
