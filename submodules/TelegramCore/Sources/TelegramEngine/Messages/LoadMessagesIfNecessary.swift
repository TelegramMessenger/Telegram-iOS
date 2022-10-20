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
            
            var signals: [Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>] = []
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
                                    return (messages, chats, users)
                                case let .messagesSlice(_, _, _, _, messages, chats, users):
                                    return (messages, chats, users)
                                case let .channelMessages(_, _, _, _, messages, chats, users):
                                    return (messages, chats, users)
                                case .messagesNotModified:
                                    return ([], [], [])
                            }
                            } |> `catch` { _ in
                                return Signal<([Api.Message], [Api.Chat], [Api.User]), NoError>.single(([], [], []))
                            })
                    }
                }
            }
            
            return combineLatest(signals) |> mapToSignal { results -> Signal<[Message], NoError> in
                return postbox.transaction { transaction -> [Message] in
                    
                    for (messages, chats, users) in results {
                        if !messages.isEmpty {
                            var storeMessages: [StoreMessage] = []
                            
                            for message in messages {
                                if let message = StoreMessage(apiMessage: message) {
                                    storeMessages.append(message)
                                }
                            }
                            _ = transaction.addMessages(storeMessages, location: .Random)
                        }
                        
                        var peers: [Peer] = []
                        var peerPresences: [PeerId: Api.User] = [:]
                        for chat in chats {
                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                peers.append(groupOrChannel)
                            }
                        }
                        for user in users {
                            let telegramUser = TelegramUser(user: user)
                            peers.append(telegramUser)
                            peerPresences[telegramUser.id] = user
                        }
                        
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated -> Peer in
                            return updated
                        })
                        updatePeerPresences(transaction: transaction, accountPeerId: accountPeerId, peerPresences: peerPresences)
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
