import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private func uploadedMessageMedia(network: Network, postbox: Postbox, media: Media) -> Signal<Api.InputMedia?, NoError> {
    if let image = media as? TelegramMediaImage {
        if let largestRepresentation = largestImageRepresentation(image.representations) {
            if let resource = largestRepresentation.resource as? LocalFileMediaResource {
                return multipartUpload(network: network, postbox: postbox, resource: resource)
                    |> mapToSignal { result -> Signal<Api.InputMedia?, NoError> in
                        switch result {
                            case let .inputFile(file):
                                return .single(Api.InputMedia.inputMediaUploadedPhoto(file: file, caption: ""))
                            default:
                                return .complete()
                        }
                    }
            } else {
                return .single(nil)
            }
        } else {
            return .single(nil)
        }
    } else {
        return .single(nil)
    }
}

private func applyMediaResourceChanges(from: Media, to: Media, postbox: Postbox) {
    if let fromImage = from as? TelegramMediaImage, let toImage = to as? TelegramMediaImage {
        if let fromLargestRepresentation = largestImageRepresentation(fromImage.representations), let toLargestRepresentation = largestImageRepresentation(toImage.representations) {
            postbox.mediaBox.moveResourceData(from: fromLargestRepresentation.resource.id, to: toLargestRepresentation.resource.id)
        }
    }
}

func sendUnsentMessage(network: Network, postbox: Postbox, stateManager: StateManager, message: Message) -> Signal<Void, NoError> {
    return postbox.loadedPeerWithId(message.id.peerId)
        |> take(1)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            if let inputPeer = apiInputPeer(peer) {
                var randomId: Int64 = 0
                arc4random_buf(&randomId, 8)
                
                var replyMessageId: Int32?
                for attribute in message.attributes {
                    if let replyAttribute = attribute as? ReplyMessageAttribute {
                        replyMessageId = replyAttribute.messageId.id
                        break
                    }
                }
                
                var flags: Int32 = 0
                if let replyMessageId = replyMessageId {
                    flags |= Int32(1 << 0)
                }
                
                var sendMessageRequest: Signal<Api.Updates, NoError>
                
                if let media = message.media.first {
                    sendMessageRequest = uploadedMessageMedia(network: network, postbox: postbox, media: media)
                        |> mapToSignal { inputMedia -> Signal<Api.Updates, NoError> in
                            if let inputMedia = inputMedia {
                                return network.request(Api.functions.messages.sendMedia(flags: 0, peer: inputPeer, replyToMsgId: replyMessageId, media: inputMedia, randomId: randomId, replyMarkup: nil))
                                    |> mapError { _ -> NoError in
                                        return NoError()
                                    }
                            } else {
                                preconditionFailure()
                            }
                        }
                } else {
                    sendMessageRequest = network.request(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, message: message.text, randomId: randomId, replyMarkup: nil, entities: nil))
                        |> mapError { _ -> NoError in
                            return NoError()
                        }
                }
                
                return sendMessageRequest
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        let messageId = result.rawMessageIds.first
                        let apiMessage = result.messages.first
                        
                        let modify = postbox.modify { modifier -> Void in
                            modifier.updateMessage(message.id, update: { currentMessage in
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
                                    
                                    var updatedAttributes: [MessageAttribute] = currentMessage.attributes
                                    if let entities = entities, !entities.isEmpty {
                                        for i in 0 ..< updatedAttributes.count {
                                            if updatedAttributes[i] is TextEntitiesMessageAttribute {
                                                updatedAttributes.remove(at: i)
                                                break
                                            }
                                        }
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
                                
                                if let fromMedia = currentMessage.media.first, let toMedia = media.first {
                                    applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: postbox)
                                }
                                
                                return StoreMessage(id: updatedId, timestamp: currentMessage.timestamp, flags: [], tags: currentMessage.tags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: text, attributes: attributes, media: media)
                            })
                        } |> afterDisposed {
                            stateManager.addUpdates(result)
                        }
                        
                        return modify
                    }
                    |> `catch` { _ -> Signal<Void, NoError> in
                        let modify = postbox.modify { modifier -> Void in
                            modifier.updateMessage(message.id, update: { currentMessage in
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
