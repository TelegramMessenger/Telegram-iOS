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
    case file(data: Data, mimeType: String, attributes: [TelegramMediaFileAttribute])
}

private enum StandaloneMessageContent {
    case text(String)
    case media(Api.InputMedia)
}

public func standaloneSendMessage(account: Account, peerId: PeerId, text: String, attributes: [MessageAttribute], media: StandaloneMedia?, replyToMessageId: MessageId?) -> Signal<Void, NoError> {
    let content: Signal<StandaloneMessageContent, NoError>
    if let media = media {
        switch media {
            case let .image(data):
                content = uploadedImage(account: account, text: text, data: data)
                    |> map { next -> StandaloneMessageContent in
                        return .media(next)
                    }
            case let .file(data, mimeType, attributes):
                content = uploadedFile(account: account, text: text, data: data, mimeType: mimeType, attributes: attributes)
                    |> map { next -> StandaloneMessageContent in
                        return .media(next)
                    }
        }
    } else {
        content = .single(.text(text))
    }
    
    return content
        |> mapToSignal { content -> Signal<Void, NoError> in
            return sendMessageContent(account: account, peerId: peerId, attributes: attributes, content: content)
        }
}

private func sendMessageContent(account: Account, peerId: PeerId, attributes: [MessageAttribute], content: StandaloneMessageContent) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            return .complete()
        } else if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var uniqueId: Int64 = arc4random64()
            //var forwardSourceInfoAttribute: ForwardSourceInfoAttribute?
            var messageEntities: [Api.MessageEntity]?
            var replyMessageId: Int32?
            
            var flags: Int32 = 0
            
            flags |= (1 << 7)
            
            for attribute in attributes {
                if let replyAttribute = attribute as? ReplyMessageAttribute {
                    replyMessageId = replyAttribute.messageId.id
                } else if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                    uniqueId = outgoingInfo.uniqueId
                } else if let _ = attribute as? ForwardSourceInfoAttribute {
                    //forwardSourceInfoAttribute = attribute
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

private func uploadedImage(account: Account, text: String, data: Data) -> Signal<Api.InputMedia, NoError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false)
        |> mapToSignal { next -> Signal<Api.InputMedia, NoError> in
            switch next {
                case let .inputFile(inputFile):
                    return .single(Api.InputMedia.inputMediaUploadedPhoto(flags: 0, file: inputFile, caption: text, stickers: nil))
                case .inputSecretFile, .progress:
                    return .complete()
            }
        }
}

private func uploadedFile(account: Account, text: String, data: Data, mimeType: String, attributes: [TelegramMediaFileAttribute]) -> Signal<Api.InputMedia, NoError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false)
        |> mapToSignal { next -> Signal<Api.InputMedia, NoError> in
            switch next {
                case let .inputFile(inputFile):
                    return .single(Api.InputMedia.inputMediaUploadedDocument(flags: 0, file: inputFile, mimeType: mimeType, attributes: inputDocumentAttributesFromFileAttributes(attributes), caption: text, stickers: nil))
                case .inputSecretFile, .progress:
                    return .complete()
            }
    }
}
