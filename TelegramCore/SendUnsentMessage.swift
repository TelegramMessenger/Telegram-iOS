import Foundation
import SwiftSignalKit
import Postbox

func sendUnsentMessage(account: Account, message: Message) -> Signal<Void, NoError> {
    return account.postbox.peerWithId(message.id.peerId)
        |> take(1)
        //|> delay(2.0, queue: Queue.concurrentDefaultQueue())
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputPeer = apiInputPeer(peer) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                return account.network.request(Api.functions.messages.sendMessage(flags: 0, peer: inputPeer, replyToMsgId: 0, message: message.text, randomId: randomId, replyMarkup: nil, entities: nil))
                    |> mapError { _ -> NoError in
                        return NoError()
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        let messageId = result.messageIds.first
                        let apiMessage = result.messages.first
                        
                        let modify = account.postbox.modify { modifier -> Void in
                            modifier.updateMessage(MessageIndex(message), update: { currentMessage in
                                let updatedId: MessageId
                                if let messageId = messageId {
                                    updatedId = MessageId(peerId: currentMessage.id.peerId, namespace: Namespaces.Message.Cloud, id: messageId)
                                } else {
                                    updatedId = currentMessage.id
                                }
                                
                                let media: [Media]
                                let attributes: [MessageAttribute]
                                let text: String
                                if let apiMessage = apiMessage, let updatedMessage = StoreMessage(apiMessage: apiMessage) {
                                    media = updatedMessage.media
                                    attributes = updatedMessage.attributes
                                    text = updatedMessage.text
                                } else if case let .updateShortSentMessage(_, _, _, _, _, apiMedia, entities) = result {
                                    let (_, mediaValue) = textAndMediaFromApiMedia(apiMedia)
                                    if let mediaValue = mediaValue {
                                        media = [mediaValue]
                                    } else {
                                        media = []
                                    }
                                    
                                    var updatedAttributes: [MessageAttribute] = []
                                    if let entities = entities, !entities.isEmpty {
                                        updatedAttributes.append(TextEntitiesMessageAttribute(entities: messageTextEntitiesFromApiEntities(entities)))
                                    }
                                    attributes = updatedAttributes
                                    text = currentMessage.text
                                } else {
                                    media = currentMessage.media
                                    attributes = currentMessage.attributes
                                    text = currentMessage.text
                                }
                                
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                return StoreMessage(id: updatedId, timestamp: currentMessage.timestamp, flags: [], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: text, attributes: attributes, media: media)
                            })
                        } |> afterDisposed {
                            account.stateManager.addUpdates(result)
                        }
                        
                        return modify
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        let modify = account.postbox.modify { modifier -> Void in
                            modifier.updateMessage(MessageIndex(message), update: { currentMessage in
                                var storeForwardInfo: StoreMessageForwardInfo?
                                if let forwardInfo = currentMessage.forwardInfo {
                                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date)
                                }
                                return StoreMessage(id: message.id, timestamp: currentMessage.timestamp, flags: [.Failed], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media)
                            })
                        }
                        
                        return modify
                    }
            } else {
                return complete(Void.self, NoError.self)
            }
        }
}
