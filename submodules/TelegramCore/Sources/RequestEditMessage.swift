import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public enum RequestEditMessageMedia : Equatable {
    case keep
    case update(AnyMediaReference)
}

public enum RequestEditMessageResult {
    case progress(Float)
    case done(Bool)
}

private enum RequestEditMessageInternalError {
    case error(RequestEditMessageError)
    case invalidReference
}

public enum RequestEditMessageError {
    case generic
    case restricted
}

public func requestEditMessage(account: Account, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute? = nil, disableUrlPreview: Bool = false, scheduleTime: Int32? = nil) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
    return requestEditMessageInternal(account: account, messageId: messageId, text: text, media: media, entities: entities, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime, forceReupload: false)
    |> `catch` { error -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
        if case .invalidReference = error {
            return requestEditMessageInternal(account: account, messageId: messageId, text: text, media: media, entities: entities, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime, forceReupload: true)
        } else {
            return .fail(error)
        }
    }
    |> mapError { error -> RequestEditMessageError in
        switch error {
            case let .error(error):
                return error
            default:
                return .generic
        }
    }
}

private func requestEditMessageInternal(account: Account, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, disableUrlPreview: Bool, scheduleTime: Int32?, forceReupload: Bool) -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> {
    let uploadedMedia: Signal<PendingMessageUploadedContentResult?, NoError>
    switch media {
        case .keep:
            uploadedMedia = .single(.progress(0.0))
            |> then(.single(nil))
        case let .update(media):
            let generateUploadSignal: (Bool) -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>? = { forceReupload in
                let augmentedMedia = augmentMediaWithReference(media)
                return mediaContentToUpload(network: account.network, postbox: account.postbox, auxiliaryMethods: account.auxiliaryMethods, transformOutgoingMessageMedia: account.transformOutgoingMessageMedia, messageMediaPreuploadManager: account.messageMediaPreuploadManager, revalidationContext: account.mediaReferenceRevalidationContext, forceReupload: forceReupload, isGrouped: false, peerId: messageId.peerId, media: augmentedMedia, text: "", autoremoveAttribute: nil, messageId: nil, attributes: [])
            }
            if let uploadSignal = generateUploadSignal(forceReupload) {
                uploadedMedia = .single(.progress(0.027))
                |> then(uploadSignal)
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
    |> mapError { _ -> RequestEditMessageInternalError in return .error(.generic) }
    |> mapToSignal { uploadedMediaResult -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
        var pendingMediaContent: PendingMessageUploadedContent?
        if let uploadedMediaResult = uploadedMediaResult {
            switch uploadedMediaResult {
                case let .progress(value):
                    return .single(.progress(value))
                case let .content(content):
                    pendingMediaContent = content.content
            }
        }
        return account.postbox.transaction { transaction -> (Peer?, Message?, SimpleDictionary<PeerId, Peer>) in
            guard let message = transaction.getMessage(messageId) else {
                return (nil, nil, SimpleDictionary())
            }
        
            if text.isEmpty {
                for media in message.media {
                    switch media {
                        case _ as TelegramMediaImage, _ as TelegramMediaFile:
                            break
                        default:
                            if let _ = scheduleTime {
                                break
                            } else {
                                return (nil, nil, SimpleDictionary())
                            }
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
            return (transaction.getPeer(messageId.peerId), message, peers)
        }
        |> mapError { _ -> RequestEditMessageInternalError in return .error(.generic) }
        |> mapToSignal { peer, message, associatedPeers -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
            if let peer = peer, let message = message, let inputPeer = apiInputPeer(peer) {
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
                
                var effectiveScheduleTime: Int32?
                if messageId.namespace == Namespaces.Message.ScheduledCloud {
                    if let scheduleTime = scheduleTime {
                        effectiveScheduleTime = scheduleTime
                    } else {
                        effectiveScheduleTime = message.timestamp
                    }
                    flags |= Int32(1 << 15)
                }
                
                return account.network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: text, media: inputMedia, replyMarkup: nil, entities: apiEntities, scheduleDate: effectiveScheduleTime))
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
                |> mapError { error -> RequestEditMessageInternalError in
                    if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_") {
                        return .invalidReference
                    } else if error.errorDescription.hasPrefix("CHAT_SEND_") && error.errorDescription.hasSuffix("_FORBIDDEN") {
                        return .error(.restricted)
                    }
                    return .error(.generic)
                }
                |> mapToSignal { result -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
                    if let result = result {
                        return account.postbox.transaction { transaction -> RequestEditMessageResult in
                            var toMedia: Media?
                            if let message = result.messages.first.flatMap({ StoreMessage(apiMessage: $0) }) {
                                toMedia = message.media.first
                            }
                            
                            if case let .update(fromMedia) = media, let toMedia = toMedia {
                                applyMediaResourceChanges(from: fromMedia.media, to: toMedia, postbox: account.postbox)
                            }
                            account.stateManager.addUpdates(result)
                            
                            return .done(true)
                        }
                        |> mapError { _ -> RequestEditMessageInternalError in
                            return .error(.generic)
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
    return postbox.transaction { transaction -> (Api.InputPeer, TelegramMediaMap)? in
        guard let inputPeer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        guard let message = transaction.getMessage(messageId) else {
            return nil
        }
        for media in message.media {
            if let media = media as? TelegramMediaMap {
                return (inputPeer, media)
            }
        }
        return nil
    }
    |> mapToSignal { inputPeerAndMedia -> Signal<Void, NoError> in
        guard let (inputPeer, media) = inputPeerAndMedia else {
            return .complete()
        }
        let inputMedia: Api.InputMedia
        if let coordinate = coordinate, let liveBroadcastingTimeout = media.liveBroadcastingTimeout {
            inputMedia = .inputMediaGeoLive(flags: 1 << 1, geoPoint: .inputGeoPoint(lat: coordinate.latitude, long: coordinate.longitude), period: liveBroadcastingTimeout)
        } else {
            inputMedia = .inputMediaGeoLive(flags: 1 << 0, geoPoint: .inputGeoPoint(lat: media.latitude, long: media.longitude), period: nil)
        }
        return network.request(Api.functions.messages.editMessage(flags: 1 << 14, peer: inputPeer, id: messageId.id, message: nil, media: inputMedia, replyMarkup: nil, entities: nil, scheduleDate: nil))
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
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
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
    }
}

