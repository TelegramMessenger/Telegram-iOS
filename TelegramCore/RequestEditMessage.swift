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

public enum RequestEditMessageMedia {
    case keep
    case update(Media)
}

public enum RequestEditMessageResult {
    case progress(Float)
    case done(Bool)
}

public enum RequestEditMessageError {
    case generic
    case restricted
}

public func requestEditMessage(account: Account, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute? = nil, disableUrlPreview: Bool = false) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
    let uploadedMedia: Signal<PendingMessageUploadedContentResult?, NoError>
    switch media {
        case .keep:
            uploadedMedia = .single(.progress(0.0))
            |> then(.single(nil))
        case let .update(media):
            if let uploadSignal = mediaContentToUpload(network: account.network, postbox: account.postbox, auxiliaryMethods: account.auxiliaryMethods, transformOutgoingMessageMedia: account.transformOutgoingMessageMedia, messageMediaPreuploadManager: account.messageMediaPreuploadManager, revalidationContext: account.mediaReferenceRevalidationContext, forceReupload: false, peerId: messageId.peerId, media: media, text: "", autoremoveAttribute: nil, messageId: nil, attributes: []) {
                uploadedMedia = .single(.progress(0.027)) |> then(uploadSignal)
                |> map { result -> PendingMessageUploadedContentResult? in
                    switch result {
                        case let .progress(value):
                            return .progress(max(value, 0.027))
                        case let .content(content):
                            return .content(content)
                    }
                }
                |> `catch` { _ -> Signal<PendingMessageUploadedContentResult?, NoError> in
                    return .single(nil)
                }
            } else {
                uploadedMedia = .single(nil)
            }
    }
    return uploadedMedia
    |> mapError { _ -> RequestEditMessageError in return .generic }
    |> mapToSignal { uploadedMediaResult -> Signal<RequestEditMessageResult, RequestEditMessageError> in
        var pendingMediaContent: PendingMessageUploadedContent?
        if let uploadedMediaResult = uploadedMediaResult {
            switch uploadedMediaResult {
                case let .progress(value):
                    return .single(.progress(value))
                case let .content(content):
                    pendingMediaContent = content.content
            }
        }
        return account.postbox.transaction { transaction -> (Peer?, SimpleDictionary<PeerId, Peer>) in
            guard let message = transaction.getMessage(messageId) else {
                return (nil, SimpleDictionary())
            }
        
            if text.isEmpty {
                for media in message.media {
                    switch media {
                        case _ as TelegramMediaImage, _ as TelegramMediaFile:
                            break
                        default:
                            return (nil, SimpleDictionary())
                    }
                }
            }
        
            var peers = SimpleDictionary<PeerId, Peer>()

            if let entities = entities {
                for peerId in entities.associatedPeerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peer.id] = peer
                    }
                }
            }
            return (transaction.getPeer(messageId.peerId), peers)
        }
        |> mapError { _ -> RequestEditMessageError in return .generic }
        |> mapToSignal { peer, associatedPeers -> Signal<RequestEditMessageResult, RequestEditMessageError> in
            if let peer = peer, let inputPeer = apiInputPeer(peer) {
                var flags: Int32 = 1 << 11
                
                var apiEntities: [Api.MessageEntity]?
                if let entities = entities {
                    apiEntities = apiTextAttributeEntities(entities, associatedPeers: associatedPeers)
                    flags |= Int32(1 << 3)
                }
                
                if disableUrlPreview {
                    flags |= Int32(1 << 1)
                }
                
                var inputMedia: Api.InputMedia? = nil
                if let pendingMediaContent = pendingMediaContent {
                    switch pendingMediaContent {
                        case let .media(media, _):
                            inputMedia = media
                        default:
                            break
                    }
                }
                if let _ = inputMedia {
                    flags |= Int32(1 << 14)
                }
                
                return account.network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: text, media: inputMedia, replyMarkup: nil, entities: apiEntities, geoPoint: nil))
                    |> map { result -> Api.Updates? in
                        return result
                    }
                    |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                        if error.errorDescription == "MESSAGE_NOT_MODIFIED" {
                            return .single(nil)
                        } else {
                            return .fail(error)
                        }
                    }
                    |> mapError { error -> RequestEditMessageError in
                        if error.errorDescription.hasPrefix("CHAT_SEND_") && error.errorDescription.hasSuffix("_FORBIDDEN") {
                            return .restricted
                        }
                        return .generic
                    }
                    |> mapToSignal { result -> Signal<RequestEditMessageResult, RequestEditMessageError> in
                        if let result = result {
                            return account.postbox.transaction { transaction -> RequestEditMessageResult in
                                var toMedia: Media?
                                if let message = result.messages.first.flatMap(StoreMessage.init(apiMessage:)) {
                                    toMedia = message.media.first
                                }
                                
                                if case let .update(fromMedia) = media, let toMedia = toMedia {
                                    applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: account.postbox)
                                }
                                account.stateManager.addUpdates(result)
                                
                                return .done(true)
                            }
                            |> mapError { _ -> RequestEditMessageError in
                                return .generic
                            }
                        } else {
                            return .single(.done(false))
                        }
                    }
            } else {
                return .single(.done(false))
            }
        }
    }
}

public func requestEditLiveLocation(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId, coordinate: (latitude: Double, longitude: Double)?) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Void, NoError> in
        if let inputPeer = inputPeer {
            var flags: Int32 = 0
            if coordinate != nil {
                flags |= 1 << 13
            } else {
                flags |= 1 << 12
            }
            return network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: nil, media: nil, replyMarkup: nil, entities: nil, geoPoint:  coordinate.flatMap { Api.InputGeoPoint.inputGeoPoint(lat: $0.latitude, long: $0.longitude) }))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    stateManager.addUpdates(updates)
                }
                if coordinate == nil {
                    return postbox.transaction { transaction -> Void in
                        transaction.updateMessage(messageId, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                            }
                            var updatedLocalTags = currentMessage.localTags
                            updatedLocalTags.remove(.OutgoingLiveLocation)
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: updatedLocalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                        })
                    }
                } else {
                    return .complete()
                }
            }
        } else {
            return .complete()
        }
    }
}
