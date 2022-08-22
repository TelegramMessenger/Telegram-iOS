import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


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
    case textTooLong
    case invalidGrouping
}

func _internal_requestEditMessage(account: Account, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool = false, scheduleTime: Int32? = nil) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
    return requestEditMessage(postbox: account.postbox, network: account.network, stateManager: account.stateManager, transformOutgoingMessageMedia: account.transformOutgoingMessageMedia, messageMediaPreuploadManager: account.messageMediaPreuploadManager, mediaReferenceRevalidationContext: account.mediaReferenceRevalidationContext, messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime)
}

func requestEditMessage(postbox: Postbox, network: Network, stateManager: AccountStateManager, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, messageMediaPreuploadManager: MessageMediaPreuploadManager, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool, scheduleTime: Int32?) -> Signal<RequestEditMessageResult, RequestEditMessageError> {
    return requestEditMessageInternal(postbox: postbox, network: network, stateManager: stateManager, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messageMediaPreuploadManager: messageMediaPreuploadManager, mediaReferenceRevalidationContext: mediaReferenceRevalidationContext, messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime, forceReupload: false)
    |> `catch` { error -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
        if case .invalidReference = error {
            return requestEditMessageInternal(postbox: postbox, network: network, stateManager: stateManager, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messageMediaPreuploadManager: messageMediaPreuploadManager, mediaReferenceRevalidationContext: mediaReferenceRevalidationContext, messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview, scheduleTime: scheduleTime, forceReupload: true)
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

private func requestEditMessageInternal(postbox: Postbox, network: Network, stateManager: AccountStateManager, transformOutgoingMessageMedia: TransformOutgoingMessageMedia?, messageMediaPreuploadManager: MessageMediaPreuploadManager, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext, messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool, scheduleTime: Int32?, forceReupload: Bool) -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> {
    let uploadedMedia: Signal<PendingMessageUploadedContentResult?, NoError>
    switch media {
    case .keep:
        uploadedMedia = .single(.progress(0.0))
        |> then(.single(nil))
    case let .update(media):
        let generateUploadSignal: (Bool) -> Signal<PendingMessageUploadedContentResult, PendingMessageUploadError>? = { forceReupload in
            let augmentedMedia = augmentMediaWithReference(media)
            return mediaContentToUpload(network: network, postbox: postbox, auxiliaryMethods: stateManager.auxiliaryMethods, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messageMediaPreuploadManager: messageMediaPreuploadManager, revalidationContext: mediaReferenceRevalidationContext, forceReupload: forceReupload, isGrouped: false, peerId: messageId.peerId, media: augmentedMedia, text: "", autoremoveMessageAttribute: nil, autoclearMessageAttribute: nil, messageId: nil, attributes: [])
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
    |> mapError { _ -> RequestEditMessageInternalError in }
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
        return postbox.transaction { transaction -> (Peer?, Message?, SimpleDictionary<PeerId, Peer>) in
            guard let message = transaction.getMessage(messageId) else {
                return (nil, nil, SimpleDictionary())
            }
            
            for (_, file) in inlineStickers {
                transaction.storeMediaIfNotPresent(media: file)
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
        |> mapError { _ -> RequestEditMessageInternalError in }
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
                
                return network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: text, media: inputMedia, replyMarkup: nil, entities: apiEntities, scheduleDate: effectiveScheduleTime))
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
                    } else if error.errorDescription.hasSuffix("_TOO_LONG") {
                        return .error(.textTooLong)
                    } else if error.errorDescription.hasPrefix("MEDIA_GROUPED_INVALID") {
                        return .error(.invalidGrouping)
                    } else if error.errorDescription.hasPrefix("CHAT_SEND_") && error.errorDescription.hasSuffix("_FORBIDDEN") {
                        return .error(.restricted)
                    }
                    return .error(.generic)
                }
                |> mapToSignal { result -> Signal<RequestEditMessageResult, RequestEditMessageInternalError> in
                    if let result = result {
                        return postbox.transaction { transaction -> RequestEditMessageResult in
                            var toMedia: Media?
                            if let message = result.messages.first.flatMap({ StoreMessage(apiMessage: $0) }) {
                                toMedia = message.media.first
                            }
                            
                            if case let .update(fromMedia) = media, let toMedia = toMedia {
                                applyMediaResourceChanges(from: fromMedia.media, to: toMedia, postbox: postbox, force: true)
                            }
                            
                            switch result {
                            case let .updates(updates, users, chats, _, _):
                                for update in updates {
                                    switch update {
                                    case .updateEditMessage(let message, _, _), .updateNewMessage(let message, _, _), .updateEditChannelMessage(let message, _, _), .updateNewChannelMessage(let message, _, _):
                                        var peers: [Peer] = []
                                        for chat in chats {
                                            if let groupOrChannel = parseTelegramGroupOrChannel(chat: chat) {
                                                peers.append(groupOrChannel)
                                            }
                                        }
                                        for user in users {
                                            let telegramUser = TelegramUser(user: user)
                                            peers.append(telegramUser)
                                        }
                                        
                                        updatePeers(transaction: transaction, peers: peers, update: { _, updated in updated })
                                        
                                        if let message = StoreMessage(apiMessage: message), case let .Id(id) = message.id {
                                            transaction.updateMessage(id, update: { previousMessage in
                                                var updatedFlags = message.flags
                                                var updatedLocalTags = message.localTags
                                                if previousMessage.localTags.contains(.OutgoingLiveLocation) {
                                                    updatedLocalTags.insert(.OutgoingLiveLocation)
                                                }
                                                if previousMessage.flags.contains(.Incoming) {
                                                    updatedFlags.insert(.Incoming)
                                                } else {
                                                    updatedFlags.remove(.Incoming)
                                                }
                                                return .update(message.withUpdatedLocalTags(updatedLocalTags).withUpdatedFlags(updatedFlags))
                                            })
                                        }
                                    default:
                                        break
                                    }
                                }
                            default:
                                break
                            }
                            
                            stateManager.addUpdates(result)
                            
                            return .done(true)
                        }
                        |> mapError { _ -> RequestEditMessageInternalError in
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

func _internal_requestEditLiveLocation(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId, stop: Bool, coordinate: (latitude: Double, longitude: Double, accuracyRadius: Int32?)?, heading: Int32?, proximityNotificationRadius: Int32?) -> Signal<Void, NoError> {
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
        if let liveBroadcastingTimeout = media.liveBroadcastingTimeout, !stop {
            var flags: Int32 = 1 << 1
            let inputGeoPoint: Api.InputGeoPoint
            if let coordinate = coordinate {
                var geoFlags: Int32 = 0
                if let _ = coordinate.accuracyRadius {
                    geoFlags |= 1 << 0
                }
                inputGeoPoint = .inputGeoPoint(flags: geoFlags, lat: coordinate.latitude, long: coordinate.longitude, accuracyRadius: coordinate.accuracyRadius.flatMap({ Int32($0) }))
            } else {
                var geoFlags: Int32 = 0
                if let _ = media.accuracyRadius {
                    geoFlags |= 1 << 0
                }
                inputGeoPoint = .inputGeoPoint(flags: geoFlags, lat: media.latitude, long: media.longitude, accuracyRadius: media.accuracyRadius.flatMap({ Int32($0) }))
            }
            if let _ = heading {
                flags |= 1 << 2
            }
            if let _ = proximityNotificationRadius {
                flags |= 1 << 3
            }
            inputMedia = .inputMediaGeoLive(flags: flags, geoPoint: inputGeoPoint, heading: heading, period: liveBroadcastingTimeout, proximityNotificationRadius: proximityNotificationRadius)
        } else {
            inputMedia = .inputMediaGeoLive(flags: 1 << 0, geoPoint: .inputGeoPoint(flags: 0, lat: media.latitude, long: media.longitude, accuracyRadius: nil), heading: nil, period: nil, proximityNotificationRadius: nil)
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
            if coordinate == nil && proximityNotificationRadius == nil {
                return postbox.transaction { transaction -> Void in
                    transaction.updateMessage(messageId, update: { currentMessage in
                        var storeForwardInfo: StoreMessageForwardInfo?
                        if let forwardInfo = currentMessage.forwardInfo {
                            storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                        }
                        var updatedLocalTags = currentMessage.localTags
                        updatedLocalTags.remove(.OutgoingLiveLocation)
                        return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: updatedLocalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                    })
                }
            } else {
                return .complete()
            }
        }
    }
}
