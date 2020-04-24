import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

import SyncCore

public enum EnqueueMessageGrouping {
    case none
    case auto
}

public enum EnqueueMessage {
    case message(text: String, attributes: [MessageAttribute], mediaReference: AnyMediaReference?, replyToMessageId: MessageId?, localGroupingKey: Int64?)
    case forward(source: MessageId, grouping: EnqueueMessageGrouping, attributes: [MessageAttribute])
    
    public func withUpdatedReplyToMessageId(_ replyToMessageId: MessageId?) -> EnqueueMessage {
        switch self {
            case let .message(text, attributes, mediaReference, _, localGroupingKey):
                return .message(text: text, attributes: attributes, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey)
            case .forward:
                return self
        }
    }
    
    public func withUpdatedAttributes(_ f: ([MessageAttribute]) -> [MessageAttribute]) -> EnqueueMessage {
        switch self {
            case let .message(text, attributes, mediaReference, replyToMessageId, localGroupingKey):
                return .message(text: text, attributes: f(attributes), mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey)
            case let .forward(source, grouping, attributes):
                return .forward(source: source, grouping: grouping, attributes: f(attributes))
        }
    }
}

func augmentMediaWithReference(_ mediaReference: AnyMediaReference) -> Media {
    if let file = mediaReference.media as? TelegramMediaFile {
        if file.partialReference != nil {
            return file
        } else {
            return file.withUpdatedPartialReference(mediaReference.partial)
        }
    } else if let image = mediaReference.media as? TelegramMediaImage {
        if image.partialReference != nil {
            return image
        } else {
            return image.withUpdatedPartialReference(mediaReference.partial)
        }
    } else {
        return mediaReference.media
    }
}

private func convertForwardedMediaForSecretChat(_ media: Media) -> Media {
    if let file = media as? TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: arc4random64()), partialReference: file.partialReference, resource: file.resource, previewRepresentations: file.previewRepresentations, immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes)
    } else if let image = media as? TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64()), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: image.reference, partialReference: image.partialReference, flags: [])
    } else {
        return media
    }
}

private func filterMessageAttributesForOutgoingMessage(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
            case _ as TextEntitiesMessageAttribute:
                return true
            case _ as InlineBotMessageAttribute:
                return true
            case _ as OutgoingMessageInfoAttribute:
                return true
            case _ as OutgoingContentInfoMessageAttribute:
                return true
            case _ as ReplyMarkupMessageAttribute:
                return true
            case _ as OutgoingChatContextResultMessageAttribute:
                return true
            case _ as AutoremoveTimeoutMessageAttribute:
                return true
            case _ as NotificationInfoMessageAttribute:
                return true
            case _ as OutgoingScheduleInfoMessageAttribute:
                return true
            case _ as EmbeddedMediaStickersMessageAttribute:
                return true
            default:
                return false
        }
    }
}

private func filterMessageAttributesForForwardedMessage(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
            case _ as TextEntitiesMessageAttribute:
                return true
            case _ as InlineBotMessageAttribute:
                return true
            case _ as NotificationInfoMessageAttribute:
                return true
            case _ as OutgoingScheduleInfoMessageAttribute:
                return true
            default:
                return false
        }
    }
}

func opportunisticallyTransformMessageWithMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, mediaReference: AnyMediaReference, userInteractive: Bool) -> Signal<AnyMediaReference?, NoError> {
    return transformOutgoingMessageMedia(postbox, network, mediaReference, userInteractive)
    |> timeout(2.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

private func forwardedMessageToBeReuploaded(transaction: Transaction, id: MessageId) -> Message? {
    if let message = transaction.getMessage(id) {
        if message.id.namespace != Namespaces.Message.Cloud {
            return message
        } else {
            return nil
        }
    } else {
        return nil
    }
}

private func opportunisticallyTransformOutgoingMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, messages: [EnqueueMessage], userInteractive: Bool) -> Signal<[(Bool, EnqueueMessage)], NoError> {
    var hasMedia = false
    loop: for message in messages {
        switch message {
            case let .message(_, _, mediaReference, _, _):
                if mediaReference != nil {
                    hasMedia = true
                    break loop
                }
            case .forward:
                break
        }
    }
    
    if !hasMedia {
        return .single(messages.map { (true, $0) })
    }
    
    var signals: [Signal<(Bool, EnqueueMessage), NoError>] = []
    for message in messages {
        switch message {
            case let .message(text, attributes, mediaReference, replyToMessageId, localGroupingKey):
                if let mediaReference = mediaReference {
                    signals.append(opportunisticallyTransformMessageWithMedia(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, mediaReference: mediaReference, userInteractive: userInteractive)
                    |> map { result -> (Bool, EnqueueMessage) in
                        if let result = result {
                            return (true, .message(text: text, attributes: attributes, mediaReference: .standalone(media: result.media), replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey))
                        } else {
                            return (false, .message(text: text, attributes: attributes, mediaReference: mediaReference, replyToMessageId: replyToMessageId, localGroupingKey: localGroupingKey))
                        }
                    })
                } else {
                    signals.append(.single((false, message)))
                }
            case .forward:
                signals.append(.single((false, message)))
        }
    }
    return combineLatest(signals)
}

public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId?], NoError> in
        return account.postbox.transaction { transaction -> [MessageId?] in
            return enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages)
        }
    }
}

public func enqueueMessagesToMultiplePeers(account: Account, peerIds: [PeerId], messages: [EnqueueMessage]) -> Signal<[MessageId], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId], NoError> in
        return account.postbox.transaction { transaction -> [MessageId] in
            var messageIds: [MessageId] = []
            for peerId in peerIds {
                for id in enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages, disableAutoremove: false) {
                    if let id = id {
                        messageIds.append(id)
                    }
                }
            }
            return messageIds
        }
    }
}

public func resendMessages(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        var removeMessageIds: [MessageId] = []
        for (peerId, ids) in messagesIdsGroupedByPeerId(messageIds) {
            var messages: [EnqueueMessage] = []
            for id in ids {
                if let message = transaction.getMessage(id), !message.flags.contains(.Incoming) {
                    removeMessageIds.append(id)
                    
                    var filteredAttributes: [MessageAttribute] = []
                    var replyToMessageId: MessageId?
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            replyToMessageId = attribute.messageId
                        } else if attribute is OutgoingMessageInfoAttribute {
                            continue inner
                        } else {
                            filteredAttributes.append(attribute)
                        }
                    }
                    
                    messages.append(.message(text: message.text, attributes: filteredAttributes, mediaReference: message.media.first.flatMap(AnyMediaReference.standalone), replyToMessageId: replyToMessageId, localGroupingKey: message.groupingKey))
                }
            }
            let _ = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages.map { (false, $0) })
        }
        deleteMessages(transaction: transaction, mediaBox: account.postbox.mediaBox, ids: removeMessageIds, deleteMedia: false)
    }
}

func enqueueMessages(transaction: Transaction, account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)], disableAutoremove: Bool = false) -> [MessageId?] {
    var updatedMessages: [(Bool, EnqueueMessage)] = []
    outer: for (transformedMedia, message) in messages {
        switch message {
            case let .message(desc):
                if let replyToMessageId = desc.replyToMessageId, replyToMessageId.peerId != peerId, let replyMessage = transaction.getMessage(replyToMessageId) {
                    var canBeForwarded = true
                    if replyMessage.id.namespace != Namespaces.Message.Cloud {
                        canBeForwarded = false
                    }
                    inner: for media in replyMessage.media {
                        if media is TelegramMediaAction {
                            canBeForwarded = false
                            break inner
                        }
                    }
                    if canBeForwarded {
                        updatedMessages.append((true, .forward(source: replyToMessageId, grouping: .none, attributes: [])))
                    }
                }
            case let .forward(sourceId, _, _):
                if let sourceMessage = forwardedMessageToBeReuploaded(transaction: transaction, id: sourceId) {
                    var mediaReference: AnyMediaReference?
                    if sourceMessage.id.peerId.namespace == Namespaces.Peer.SecretChat {
                        if let media = sourceMessage.media.first {
                            mediaReference = .standalone(media: media)
                        }
                    }
                    updatedMessages.append((transformedMedia, .message(text: sourceMessage.text, attributes: sourceMessage.attributes, mediaReference: mediaReference, replyToMessageId: nil, localGroupingKey: nil)))
                    continue outer
                }
        }
        updatedMessages.append((transformedMedia, message))
    }
    
    if let peer = transaction.getPeer(peerId), let accountPeer = transaction.getPeer(account.peerId) {
        let peerPresence = transaction.getPeerPresence(peerId: peerId)
        
        var storeMessages: [StoreMessage] = []
        var timestamp = Int32(account.network.context.globalTime())
        switch peerId.namespace {
            case Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudUser:
                if let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    timestamp = max(timestamp, topIndex.timestamp)
                }
            default:
                break
        }
        
        var addedHashtags: [String] = []
        
        var localGroupingKeyBySourceKey: [Int64: Int64] = [:]
        
        var globallyUniqueIds: [Int64] = []
        for (transformedMedia, message) in updatedMessages {
            var attributes: [MessageAttribute] = []
            var flags = StoreMessageFlags()
            flags.insert(.Unsent)
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            var infoFlags = OutgoingMessageInfoFlags()
            if transformedMedia {
                infoFlags.insert(.transformedMedia)
            }
            attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: infoFlags, acknowledged: false))
            globallyUniqueIds.append(randomId)
            
            switch message {
                case let .message(text, requestedAttributes, mediaReference, replyToMessageId, localGroupingKey):
                    if let peer = peer as? TelegramSecretChat {
                        var isAction = false
                        if let _ = mediaReference?.media as? TelegramMediaAction {
                            isAction = true
                        }
                        if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                        }
                    }
                    
                    attributes.append(contentsOf: filterMessageAttributesForOutgoingMessage(requestedAttributes))
                        
                    if let replyToMessageId = replyToMessageId, replyToMessageId.peerId == peerId {
                        attributes.append(ReplyMessageAttribute(messageId: replyToMessageId))
                    }
                    var mediaList: [Media] = []
                    if let mediaReference = mediaReference {
                        let augmentedMedia = augmentMediaWithReference(mediaReference)
                        mediaList.append(augmentedMedia)
                    }
                    
                    if let file = mediaReference?.media as? TelegramMediaFile, file.isVoice || file.isInstantVideo {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.SecretChat {
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    }
                    
                    var entitiesAttribute: TextEntitiesMessageAttribute?
                    for attribute in attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            entitiesAttribute = attribute
                            var maybeNsText: NSString?
                            for entity in attribute.entities {
                                if case .Hashtag = entity.type {
                                    let nsText: NSString
                                    if let maybeNsText = maybeNsText {
                                        nsText = maybeNsText
                                    } else {
                                        nsText = text as NSString
                                        maybeNsText = nsText
                                    }
                                    var entityRange = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    if entityRange.location + entityRange.length > nsText.length {
                                        entityRange.location = max(0, nsText.length - entityRange.length)
                                        entityRange.length = nsText.length - entityRange.location
                                    }
                                    if entityRange.length > 1 {
                                        entityRange.location += 1
                                        entityRange.length -= 1
                                        let hashtag = nsText.substring(with: entityRange)
                                        addedHashtags.append(hashtag)
                                    }
                                }
                            }
                            break
                        }
                    }
                
                    let authorId: PeerId?
                    if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                        authorId = peer.id
                    }  else {
                        authorId = account.peerId
                    }
                    
                    let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: mediaList, textEntities: entitiesAttribute?.entities)
                    
                    var localTags: LocalMessageTags = []
                    for media in mediaList {
                        if let media = media as? TelegramMediaMap, media.liveBroadcastingTimeout != nil {
                            localTags.insert(.OutgoingLiveLocation)
                        }
                    }
                    
                    var messageNamespace = Namespaces.Message.Local
                    var effectiveTimestamp = timestamp
                    for attribute in attributes {
                        if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                            if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                            } else {
                                messageNamespace = Namespaces.Message.ScheduledLocal
                                effectiveTimestamp = attribute.scheduleTime
                            }
                            break
                        }
                    }
                    
                    if messageNamespace != Namespaces.Message.ScheduledLocal {
                        attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                    }
                                        
                    if let peer = peer as? TelegramChannel {
                        switch peer.info {
                            case let .broadcast(info):
                                if messageNamespace != Namespaces.Message.ScheduledLocal {
                                    attributes.append(ViewCountMessageAttribute(count: 1))
                                }
                                if info.flags.contains(.messagesShouldHaveSignatures) {
                                    attributes.append(AuthorSignatureMessageAttribute(signature: accountPeer.debugDisplayTitle))
                                }
                            case .group:
                                break
                        }
                    }
                    
                    storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, globallyUniqueId: randomId, groupingKey: localGroupingKey, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: mediaList))
                case let .forward(source, grouping, requestedAttributes):
                    let sourceMessage = transaction.getMessage(source)
                    if let sourceMessage = sourceMessage, let author = sourceMessage.author ?? sourceMessage.peers[sourceMessage.id.peerId] {
                        if let peer = peer as? TelegramSecretChat {
                            var isAction = false
                            for media in sourceMessage.media {
                                if let _ = media as? TelegramMediaAction {
                                    isAction = true
                                }
                            }
                            if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                            }
                        }
                        
                        var forwardInfo: StoreMessageForwardInfo?
                        
                        if sourceMessage.id.namespace == Namespaces.Message.Cloud && peerId.namespace != Namespaces.Peer.SecretChat {
                            attributes.append(ForwardSourceInfoAttribute(messageId: sourceMessage.id))
                        
                            if peerId == account.peerId {
                                attributes.append(SourceReferenceMessageAttribute(messageId: sourceMessage.id))
                            }
                            
                            attributes.append(contentsOf: filterMessageAttributesForForwardedMessage(requestedAttributes))
                            attributes.append(contentsOf: filterMessageAttributesForForwardedMessage(sourceMessage.attributes))
                            
                            var sourceReplyMarkup: ReplyMarkupMessageAttribute? = nil
                            var sourceSentViaBot = false
                            for attribute in attributes {
                                if let attribute = attribute as? ReplyMarkupMessageAttribute {
                                    sourceReplyMarkup = attribute
                                } else if let _ = attribute as? InlineBotMessageAttribute {
                                    sourceSentViaBot = true
                                }
                            }
                            
                            if let sourceReplyMarkup = sourceReplyMarkup {
                                var rows: [ReplyMarkupRow] = []
                                loop: for row in sourceReplyMarkup.rows {
                                    var buttons: [ReplyMarkupButton] = []
                                    for button in row.buttons {
                                        if case .url = button.action {
                                            buttons.append(button)
                                        } else if case .urlAuth = button.action {
                                            buttons.append(button)
                                        } else if case let .switchInline(samePeer, query) = button.action, sourceSentViaBot {
                                            let samePeer = samePeer && peerId == sourceMessage.id.peerId
                                            let updatedButton = ReplyMarkupButton(title: button.titleWhenForwarded ?? button.title, titleWhenForwarded: button.titleWhenForwarded,  action: .switchInline(samePeer: samePeer, query: query))
                                            buttons.append(updatedButton)
                                        } else {
                                            rows.removeAll()
                                            break loop
                                        }
                                    }
                                    rows.append(ReplyMarkupRow(buttons: buttons))
                                }
                                
                                if !rows.isEmpty {
                                    attributes.append(ReplyMarkupMessageAttribute(rows: rows, flags: sourceReplyMarkup.flags))
                                }
                            }
                            
                            if let sourceForwardInfo = sourceMessage.forwardInfo {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceForwardInfo.author?.id, sourceId: sourceForwardInfo.source?.id, sourceMessageId: sourceForwardInfo.sourceMessageId, date: sourceForwardInfo.date, authorSignature: sourceForwardInfo.authorSignature, psaType: nil)
                            } else {
                                if sourceMessage.id.peerId != account.peerId {
                                    var hasHiddenForwardMedia = false
                                    for media in sourceMessage.media {
                                        if let file = media as? TelegramMediaFile {
                                            if file.isMusic {
                                                hasHiddenForwardMedia = true
                                            }
                                        }
                                    }
                                    
                                    if !hasHiddenForwardMedia {
                                        var sourceId: PeerId? = nil
                                        var sourceMessageId: MessageId? = nil
                                        if let peer = messageMainPeer(sourceMessage) as? TelegramChannel, case .broadcast = peer.info {
                                            sourceId = peer.id
                                            sourceMessageId = sourceMessage.id
                                        }
                                        
                                        var authorSignature: String?
                                        for attribute in sourceMessage.attributes {
                                            if let attribute = attribute as? AuthorSignatureMessageAttribute {
                                                authorSignature = attribute.signature
                                                break
                                            }
                                        }
                                        
                                        let psaType: String? = nil
                                        
                                        forwardInfo = StoreMessageForwardInfo(authorId: author.id, sourceId: sourceId, sourceMessageId: sourceMessageId, date: sourceMessage.timestamp, authorSignature: authorSignature, psaType: psaType)
                                    }
                                } else {
                                    forwardInfo = nil
                                }
                            }
                        } else {
                            attributes.append(contentsOf: filterMessageAttributesForOutgoingMessage(sourceMessage.attributes))
                        }
                        
                        let authorId: PeerId?
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            authorId = peer.id
                        }  else {
                            authorId = account.peerId
                        }
                        
                        var messageNamespace = Namespaces.Message.Local
                        var entitiesAttribute: TextEntitiesMessageAttribute?
                        var effectiveTimestamp = timestamp
                        for attribute in attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                entitiesAttribute = attribute
                            }
                            if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                                if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                                } else {
                                    messageNamespace = Namespaces.Message.ScheduledLocal
                                    effectiveTimestamp = attribute.scheduleTime
                                }
                            }
                        }
                        
                        if messageNamespace != Namespaces.Message.ScheduledLocal {
                            attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                        }
                        
                        let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: sourceMessage.media, textEntities: entitiesAttribute?.entities)
                        
                        let localGroupingKey: Int64?
                        switch grouping {
                            case .none:
                                localGroupingKey = nil
                            case .auto:
                                if let groupingKey = sourceMessage.groupingKey {
                                    if let generatedKey = localGroupingKeyBySourceKey[groupingKey] {
                                        localGroupingKey = generatedKey
                                    } else {
                                        let generatedKey = arc4random64()
                                        localGroupingKeyBySourceKey[groupingKey] = generatedKey
                                        localGroupingKey = generatedKey
                                    }
                                } else {
                                    localGroupingKey = nil
                                }
                        }
                        
                        var augmentedMediaList = sourceMessage.media.map { media -> Media in
                            return augmentMediaWithReference(.message(message: MessageReference(sourceMessage), media: media))
                        }
                        
                        if peerId.namespace == Namespaces.Peer.SecretChat {
                            augmentedMediaList = augmentedMediaList.map(convertForwardedMediaForSecretChat)
                        }
                                                
                        storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, globallyUniqueId: randomId, groupingKey: localGroupingKey, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: sourceMessage.text, attributes: attributes, media: augmentedMediaList))
                    }
            }
        }
        var messageIds: [MessageId?] = []
        if !storeMessages.isEmpty {
            let globallyUniqueIdToMessageId = transaction.addMessages(storeMessages, location: .Random)
            for globallyUniqueId in globallyUniqueIds {
                messageIds.append(globallyUniqueIdToMessageId[globallyUniqueId])
            }
            
            if peerId.namespace == Namespaces.Peer.CloudUser {
                if case .notIncluded = transaction.getPeerChatListInclusion(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
                }
            }
        }
        for hashtag in addedHashtags {
            addRecentlyUsedHashtag(transaction: transaction, string: hashtag)
        }
        return messageIds
    } else {
        return []
    }
}
