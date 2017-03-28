import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public enum StandaloneMedia {
    case image(Data)
    case file(Data)
}

public func standaloneSendMessage(account: Account, peerId: PeerId, text: String, attributes: [MessageAttribute], replyToMessageId: MessageId?) -> Signal<Void, NoError> {
    let contentToUpload = messageContentToUpload(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: nil, peerId: peerId, messageId: nil, attributes: attributes, text: text, media: [])
    
    switch contentToUpload {
        case let .ready(content):
            return sendMessageContent(account: account, peerId: peerId, attributes: attributes, content: content)
        case let .upload(uploadSignal):
            return .complete()
            /*if strongSelf.canBeginUploadingMessage(id: message.id) {
                strongSelf.beginUploadingMessage(messageContext: messageContext, id: message.id, uploadSignal: uploadSignal)
            } else {
                messageContext.state = .waitingForUploadToStart(uploadSignal)
            }*/
    }
}

private func sendMessageContent(account: Account, peerId: PeerId, attributes: [MessageAttribute], content: PendingMessageUploadedContent) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .complete()
        } else if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var uniqueId: Int64 = 0
            var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
            var messageEntities: [Api.MessageEntity]?
            var replyMessageId: Int32?
            
            var flags: Int32 = 0
            
            flags |= (1 << 7)
            
            for attribute in attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    replyMessageId = replyAttribute.messageId.id
                } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                    uniqueId = outgoingInfo.uniqueId
                } else if let attribute = attribute as? ForwardSourceInfoAttribute {
                    forwardSourceInfoAttribute = attribute
                } else if let attribute = attribute as? TextEntitiesMessageAttribute {
                    messageEntities = apiTextAttributeEntities(attribute, associatedPeers: SimpleDictionary())
                } else if let attribute = attribute as? OutgoingContentInfoMessageAttribute {
                    if attribute.flags.contains(.disableLinkPreviews) {
                        flags |= Int32(1 << 1)
                    }
                }
            }
            
            if let _ = replyMessageId {
                flags |= Int32(1 << 0)
            }
            if let _ = messageEntities {
                flags |= Int32(1 << 3)
            }
            
            let sendMessageRequest: Signal<Api.Updates, NoError>
            switch content {
                case let .text(text):
                    sendMessageRequest = account.network.request(Api.functions.messages.sendMessage(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, message: text, randomId: uniqueId, replyMarkup: nil, entities: messageEntities))
                        |> mapError { _ -> NoError in
                            return NoError()
                    }
                case let .media(inputMedia):
                    sendMessageRequest = account.network.request(Api.functions.messages.sendMedia(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, media: inputMedia, randomId: uniqueId, replyMarkup: nil))
                        |> mapError { _ -> NoError in
                            return NoError()
                    }
                case let .forward(sourceInfo):
                    if let forwardSourceInfoAttribute = forwardSourceInfoAttribute, let sourcePeer = modifier.getPeer(forwardSourceInfoAttribute.messageId.peerId), let sourceInputPeer = apiInputPeer(sourcePeer) {
                        sendMessageRequest = account.network.request(Api.functions.messages.forwardMessages(flags: 0, fromPeer: sourceInputPeer, id: [sourceInfo.messageId.id], randomId: [uniqueId], toPeer: inputPeer))
                            |> mapError { _ -> NoError in
                                return NoError()
                        }
                    } else {
                        sendMessageRequest = .fail(NoError())
                    }
                case let .chatContextResult(chatContextResult):
                    sendMessageRequest = account.network.request(Api.functions.messages.sendInlineBotResult(flags: flags, peer: inputPeer, replyToMsgId: replyMessageId, randomId: uniqueId, queryId: chatContextResult.queryId, id: chatContextResult.id))
                        |> mapError { _ -> NoError in
                            return NoError()
                    }
                case .secretMedia:
                    assertionFailure()
                    sendMessageRequest = .fail(NoError())
            }
            
            return sendMessageRequest
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return .complete()
                    /*if let strongSelf = self {
                        return strongSelf.applySentMessage(postbox: postbox, stateManager: stateManager, message: message, result: result)
                    } else {
                        return .never()
                    }*/
                }
                |> `catch` { _ -> Signal<Void, NoError> in
                    return .complete()
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
