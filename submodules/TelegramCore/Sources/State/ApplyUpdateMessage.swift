import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit


private func copyOrMoveResourceData(from fromResource: MediaResource, to toResource: MediaResource, mediaBox: MediaBox) {
    if fromResource is CloudFileMediaResource || fromResource is CloudDocumentMediaResource || fromResource is SecretFileMediaResource {
        mediaBox.copyResourceData(from: fromResource.id, to: toResource.id)
    } else if let fromResource = fromResource as? LocalFileMediaResource, fromResource.isSecretRelated {
        mediaBox.copyResourceData(from: fromResource.id, to: toResource.id)
    } else {
        mediaBox.moveResourceData(from: fromResource.id, to: toResource.id)
    }
}

func applyMediaResourceChanges(from: Media, to: Media, postbox: Postbox, force: Bool, skipPreviews: Bool = false) {
    if let fromImage = from as? TelegramMediaImage, let toImage = to as? TelegramMediaImage {
        let fromSmallestRepresentation = smallestImageRepresentation(fromImage.representations)
        if let fromSmallestRepresentation = fromSmallestRepresentation, let toSmallestRepresentation = smallestImageRepresentation(toImage.representations) {
            let leeway: Int32 = 4
            let widthDifference = fromSmallestRepresentation.dimensions.width - toSmallestRepresentation.dimensions.width
            let heightDifference = fromSmallestRepresentation.dimensions.height - toSmallestRepresentation.dimensions.height
            if abs(widthDifference) < leeway && abs(heightDifference) < leeway {
                copyOrMoveResourceData(from: fromSmallestRepresentation.resource, to: toSmallestRepresentation.resource, mediaBox: postbox.mediaBox)
            }
        }
        if let fromLargestRepresentation = largestImageRepresentation(fromImage.representations), let toLargestRepresentation = largestImageRepresentation(toImage.representations) {
            if fromLargestRepresentation.resource is CloudPeerPhotoSizeMediaResource {
            } else {
                copyOrMoveResourceData(from: fromLargestRepresentation.resource, to: toLargestRepresentation.resource, mediaBox: postbox.mediaBox)
            }
        }
    } else if let fromFile = from as? TelegramMediaFile, let toFile = to as? TelegramMediaFile {
        if !skipPreviews {
            if let fromPreview = smallestImageRepresentation(fromFile.previewRepresentations), let toPreview = smallestImageRepresentation(toFile.previewRepresentations) {
                copyOrMoveResourceData(from: fromPreview.resource, to: toPreview.resource, mediaBox: postbox.mediaBox)
            }
            if let fromVideoThumbnail = fromFile.videoThumbnails.first, let toVideoThumbnail = toFile.videoThumbnails.first, fromVideoThumbnail.resource.id != toVideoThumbnail.resource.id {
                copyOrMoveResourceData(from: fromVideoThumbnail.resource, to: toVideoThumbnail.resource, mediaBox: postbox.mediaBox)
            }
        }
        let videoFirstFrameFromPath = postbox.mediaBox.cachedRepresentationCompletePath(fromFile.resource.id, keepDuration: .general, representationId: "first-frame")
        let videoFirstFrameToPath = postbox.mediaBox.cachedRepresentationCompletePath(toFile.resource.id, keepDuration: .general, representationId: "first-frame")
        if FileManager.default.fileExists(atPath: videoFirstFrameFromPath) {
            let _ = try? FileManager.default.copyItem(atPath: videoFirstFrameFromPath, toPath: videoFirstFrameToPath)
        }
        
        if (force || fromFile.size == toFile.size || fromFile.resource.size == toFile.resource.size) && fromFile.mimeType == toFile.mimeType {
            copyOrMoveResourceData(from: fromFile.resource, to: toFile.resource, mediaBox: postbox.mediaBox)
        }
    } else if let fromPaidContent = from as? TelegramMediaPaidContent, let toPaidContent = to as? TelegramMediaPaidContent {
        for (fromMedia, toMedia) in zip(fromPaidContent.extendedMedia, toPaidContent.extendedMedia) {
            if case let .full(fullFromMedia) = fromMedia, case let .full(fullToMedia) = toMedia {
                applyMediaResourceChanges(from: fullFromMedia, to: fullToMedia, postbox: postbox, force: force)
            }
        }
    }
}

func applyUpdateMessage(postbox: Postbox, stateManager: AccountStateManager, message: Message, cacheReferenceKey: CachedSentMediaReferenceKey?, result: Api.Updates, accountPeerId: PeerId, pendingMessageEvent: @escaping (PeerPendingMessageDelivered) -> Void) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        let messageId: Int32?
        var apiMessage: Api.Message?
        
        var correspondingMessageId: Int32?
        
        for update in result.allUpdates {
            switch update {
            case let .updateMessageID(id, randomId):
                for attribute in message.attributes {
                    if let attribute = attribute as? OutgoingMessageInfoAttribute {
                        if attribute.uniqueId == randomId {
                            correspondingMessageId = id
                            break
                        }
                    }
                }
            default:
                break
            }
        }
        
        for resultMessage in result.messages {
            if let id = resultMessage.id() {
                if let correspondingMessageId = correspondingMessageId {
                    if id.id != correspondingMessageId {
                        continue
                    }
                }
                if id.peerId == message.id.peerId {
                    apiMessage = resultMessage
                    break
                }
            }
        }
        
        if let apiMessage = apiMessage, let id = apiMessage.id() {
            messageId = id.id
        } else {
            messageId = result.rawMessageIds.first
        }
        
        var updatedTimestamp: Int32?
        if let apiMessage = apiMessage {
            switch apiMessage {
                case let .message(_, _, _, _, _, _, _, _, _, _, _, date, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _):
                    updatedTimestamp = date
                case .messageEmpty:
                    break
                case let .messageService(_, _, _, _, _, date, _, _, _):
                    updatedTimestamp = date
            }
        } else {
            switch result {
                case let .updateShortSentMessage(_, _, _, _, date, _, _, _):
                    updatedTimestamp = date
                default:
                    break
            }
        }
        
        let channelPts = result.channelPts
        
        var sentStickers: [TelegramMediaFile] = []
        var sentGifs: [TelegramMediaFile] = []
        
        if let updatedTimestamp {
            transaction.offsetPendingMessagesTimestamps(lowerBound: message.id, excludeIds: Set([message.id]), timestamp: updatedTimestamp)
        }
        
        var updatedMessage: StoreMessage?
        
        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
        
        transaction.updateMessage(message.id, update: { currentMessage in
            let media: [Media]
            var attributes: [MessageAttribute]
            let text: String
            let forwardInfo: StoreMessageForwardInfo?
            let threadId: Int64?
            
            var namespace = Namespaces.Message.Cloud
            if message.id.namespace == Namespaces.Message.ScheduledLocal {
                namespace = Namespaces.Message.ScheduledCloud
            }
            
            if let apiMessage = apiMessage, let apiMessagePeerId = apiMessage.peerId, let updatedMessage = StoreMessage(apiMessage: apiMessage, accountPeerId: accountPeerId, peerIsForum: transaction.getPeer(apiMessagePeerId)?.isForumOrMonoForum ?? false, namespace: namespace) {
                media = updatedMessage.media
                attributes = updatedMessage.attributes
                text = updatedMessage.text
                forwardInfo = updatedMessage.forwardInfo
                threadId = updatedMessage.threadId
            } else if case let .updateShortSentMessage(_, _, _, _, _, apiMedia, entities, ttlPeriod) = result {
                let (mediaValue, _, nonPremium, hasSpoiler, _, _) = textMediaAndExpirationTimerFromApiMedia(apiMedia, currentMessage.id.peerId)
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
                
                updatedAttributes = updatedAttributes.filter({ !($0 is AutoremoveTimeoutMessageAttribute) })
                if let ttlPeriod = ttlPeriod {
                    updatedAttributes.append(AutoremoveTimeoutMessageAttribute(timeout: ttlPeriod, countdownBeginTime: updatedTimestamp))
                }
                
                updatedAttributes = updatedAttributes.filter({ !($0 is NonPremiumMessageAttribute) })
                if let nonPremium = nonPremium, nonPremium {
                    updatedAttributes.append(NonPremiumMessageAttribute())
                }
                
                if let hasSpoiler = hasSpoiler, hasSpoiler {
                    updatedAttributes.append(MediaSpoilerMessageAttribute())
                }
                
                for i in 0 ..< updatedAttributes.count {
                    if updatedAttributes[i] is OutgoingScheduleInfoMessageAttribute {
                        updatedAttributes.remove(at: i)
                        break
                    }
                }
                if Namespaces.Message.allQuickReply.contains(message.id.namespace) {
                    for i in 0 ..< updatedAttributes.count {
                        if updatedAttributes[i] is OutgoingQuickReplyMessageAttribute {
                            updatedAttributes.remove(at: i)
                            break
                        }
                    }
                }
                
                attributes = updatedAttributes
                text = currentMessage.text
                
                forwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                threadId = currentMessage.threadId
            } else {
                media = currentMessage.media
                attributes = currentMessage.attributes
                text = currentMessage.text
                forwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                threadId = currentMessage.threadId
            }
            
            let updatedId: MessageId
            if let messageId = messageId {
                var namespace: MessageId.Namespace = Namespaces.Message.Cloud
                if attributes.contains(where: { $0 is PendingProcessingMessageAttribute }) {
                    namespace = Namespaces.Message.ScheduledCloud
                }
                if Namespaces.Message.allQuickReply.contains(message.id.namespace) {
                    namespace = Namespaces.Message.QuickReplyCloud
                } else if let updatedTimestamp = updatedTimestamp {
                    if attributes.contains(where: { $0 is PendingProcessingMessageAttribute }) {
                        namespace = Namespaces.Message.ScheduledCloud
                    } else {
                        if message.scheduleTime != nil && message.scheduleTime == updatedTimestamp {
                            namespace = Namespaces.Message.ScheduledCloud
                        }
                    }
                } else if Namespaces.Message.allScheduled.contains(message.id.namespace) {
                    namespace = Namespaces.Message.ScheduledCloud
                }
                updatedId = MessageId(peerId: currentMessage.id.peerId, namespace: namespace, id: messageId)
            } else {
                updatedId = currentMessage.id
            }
            
            for attribute in currentMessage.attributes {
                if let attribute = attribute as? OutgoingMessageInfoAttribute {
                    bubbleUpEmojiOrStickersets = attribute.bubbleUpEmojiOrStickersets
                } else if let attribute = attribute as? OutgoingQuickReplyMessageAttribute {
                    if let threadId {
                        _internal_applySentQuickReplyMessage(transaction: transaction, shortcut: attribute.shortcut, quickReplyId: Int32(clamping: threadId))
                    }
                }
            }
            
            if let channelPts = channelPts {
                for i in 0 ..< attributes.count {
                    if let _ = attributes[i] as? ChannelMessageStateVersionAttribute {
                        attributes.remove(at: i)
                        break
                    }
                }
                attributes.append(ChannelMessageStateVersionAttribute(pts: channelPts))
            }
            
            if let fromMedia = currentMessage.media.first, let toMedia = media.first {
                applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: postbox, force: false)
            }
            
            if forwardInfo == nil {
                inner: for media in media {
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            switch attribute {
                            case let .Sticker(_, packReference, _):
                                if packReference != nil {
                                    sentStickers.append(file)
                                }
                            case .Animated:
                                if !file.isAnimatedSticker && !file.isVideoSticker {
                                    sentGifs.append(file)
                                }
                            default:
                                break
                            }
                        }
                        break inner
                    }
                }
            }
            
            var entitiesAttribute: TextEntitiesMessageAttribute?
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entitiesAttribute = attribute
                    break
                }
            }
            
            let (tags, globalTags) = tagsForStoreMessage(incoming: currentMessage.flags.contains(.Incoming), attributes: attributes, media: media, textEntities: entitiesAttribute?.entities, isPinned: currentMessage.tags.contains(.pinned))
            
            if currentMessage.id.peerId.namespace == Namespaces.Peer.CloudChannel, !currentMessage.flags.contains(.Incoming), !Namespaces.Message.allNonRegular.contains(currentMessage.id.namespace) {
                let peerId = currentMessage.id.peerId
                if let peer = transaction.getPeer(peerId) {
                    if let peer = peer as? TelegramChannel {
                        inner: switch peer.info {
                        case let .group(info):
                            if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator) {
                                transaction.updatePeerCachedData(peerIds: [peerId], update: { peerId, current in
                                    var cachedData = current as? CachedChannelData ?? CachedChannelData()
                                    if let slowModeTimeout = cachedData.slowModeTimeout {
                                        cachedData = cachedData.withUpdatedSlowModeValidUntilTimestamp(currentMessage.timestamp + slowModeTimeout)
                                        return cachedData
                                    } else {
                                        return current
                                    }
                                })
                            }
                        default:
                            break inner
                        }
                    }
                }
            }
            
            let updatedMessageValue = StoreMessage(id: updatedId, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: updatedTimestamp ?? currentMessage.timestamp, flags: [], tags: tags, globalTags: globalTags, localTags: currentMessage.localTags, forwardInfo: forwardInfo, authorId: currentMessage.author?.id, text: text, attributes: attributes, media: media)
            updatedMessage = updatedMessageValue
            
            return .update(updatedMessageValue)
        })
        if let updatedMessage = updatedMessage, case let .Id(updatedId) = updatedMessage.id {
            if message.id.namespace == Namespaces.Message.Local && updatedId.namespace == Namespaces.Message.Cloud && updatedId.peerId.namespace == Namespaces.Peer.CloudChannel {
                if let threadId = updatedMessage.threadId {
                    if let authorId = updatedMessage.authorId {
                        updateMessageThreadStats(transaction: transaction, threadKey: MessageThreadKey(peerId: updatedMessage.id.peerId, threadId: threadId), removedCount: 0, addedMessagePeers: [ReplyThreadUserMessage(id: authorId, messageId: updatedId, isOutgoing: true)])
                    }
                }
            }
            
            if updatedMessage.id.namespace == Namespaces.Message.Cloud, let cacheReferenceKey = cacheReferenceKey {
                var storeMedia: Media?
                var mediaCount = 0
                for media in updatedMessage.media {
                    if let image = media as? TelegramMediaImage {
                        storeMedia = image
                        mediaCount += 1
                    } else if let file = media as? TelegramMediaFile {
                        storeMedia = file
                        mediaCount += 1
                    }
                }
                if mediaCount > 1 {
                    storeMedia = nil
                }
                
                if let storeMedia = storeMedia {
                    storeCachedSentMediaReference(transaction: transaction, key: cacheReferenceKey, media: storeMedia)
                }
            }
        }
        for file in sentStickers {
            if let entry = CodableEntry(RecentMediaItem(file)) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
            }
        }
        for file in sentGifs {
            if !file.hasLinkedStickers {
                if let entry = CodableEntry(RecentMediaItem(file)) {
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
                }
            }
        }
        if !bubbleUpEmojiOrStickersets.isEmpty {
            applyBubbleUpEmojiOrStickersets(transaction: transaction, ids: bubbleUpEmojiOrStickersets)
        }
        
        stateManager.addUpdates(result)
        stateManager.addUpdateGroups([.ensurePeerHasLocalState(id: message.id.peerId)])
        
        if let updatedMessage, case let .Id(id) = updatedMessage.id {
            pendingMessageEvent(PeerPendingMessageDelivered(
                id: id,
                isSilent: updatedMessage.attributes.contains(where: { attribute in
                    if let attribute = attribute as? NotificationInfoMessageAttribute {
                        return attribute.flags.contains(.muted)
                    } else {
                        return false
                    }
                }),
                isPendingProcessing: updatedMessage.attributes.contains(where: { $0 is PendingProcessingMessageAttribute })
            ))
        }
    }
}

func applyUpdateGroupMessages(postbox: Postbox, stateManager: AccountStateManager, messages: [Message], result: Api.Updates, pendingMessageEvents: @escaping ([PeerPendingMessageDelivered]) -> Void) -> Signal<Void, NoError> {
    guard !messages.isEmpty else {
        return .single(Void())
    }
    
    return postbox.transaction { transaction -> Void in
        let updatedRawMessageIds = result.updatedRawMessageIds
        
        var namespace = Namespaces.Message.Cloud
        if Namespaces.Message.allQuickReply.contains(messages[0].id.namespace) {
            namespace = Namespaces.Message.QuickReplyCloud
        } else if let message = messages.first, let apiMessage = result.messages.first {
            if message.scheduleTime != nil && message.scheduleTime == apiMessage.timestamp {
                namespace = Namespaces.Message.ScheduledCloud
            } else if let apiMessage = result.messages.first, case let .message(_, flags2, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _) = apiMessage, (flags2 & (1 << 4)) != 0 {
                namespace = Namespaces.Message.ScheduledCloud
            }
        }
        
        var resultMessages: [MessageId: StoreMessage] = [:]
        for apiMessage in result.messages {
            var peerIsForum = false
            if let apiMessagePeerId = apiMessage.peerId, let peer = transaction.getPeer(apiMessagePeerId) {
                if peer.isForumOrMonoForum {
                    peerIsForum = true
                }
            }
            
            if let resultMessage = StoreMessage(apiMessage: apiMessage, accountPeerId: stateManager.accountPeerId, peerIsForum: peerIsForum, namespace: namespace), case let .Id(id) = resultMessage.id {
                resultMessages[id] = resultMessage
            }
        }

        var mapping: [(Message, MessageIndex, StoreMessage)] = []
        
        for message in messages {
            var uniqueId: Int64?
            inner: for attribute in message.attributes {
                if let outgoingInfo = attribute as? OutgoingMessageInfoAttribute {
                    uniqueId = outgoingInfo.uniqueId
                    break inner
                }
            }
            if let uniqueId = uniqueId {
                if let updatedId = updatedRawMessageIds[uniqueId] {
                    if let storeMessage = resultMessages[MessageId(peerId: message.id.peerId, namespace: namespace, id: updatedId)], case let .Id(id) = storeMessage.id {
                        mapping.append((message, MessageIndex(id: id, timestamp: storeMessage.timestamp), storeMessage))
                    }
                } else {
                  //  assertionFailure()
                }
            } else {
                assertionFailure()
            }
        }
        
        mapping.sort { $0.1 < $1.1 }
        
        let latestPreviousId = mapping.map({ $0.0.id }).max()
        
        var sentStickers: [TelegramMediaFile] = []
        var sentGifs: [TelegramMediaFile] = []
        
        var updatedGroupingKey: [Int64 : [MessageId]] = [:]
        for (message, _, updatedMessage) in mapping {
            if let groupingKey = updatedMessage.groupingKey {
                var ids = updatedGroupingKey[groupingKey] ?? []
                ids.append(message.id)
                updatedGroupingKey[groupingKey] = ids
            }
        }
        
        if let latestPreviousId = latestPreviousId, let latestIndex = mapping.last?.1 {
            transaction.offsetPendingMessagesTimestamps(lowerBound: latestPreviousId, excludeIds: Set(mapping.map { $0.0.id }), timestamp: latestIndex.timestamp)
        }
        
        for (key, ids) in updatedGroupingKey {
            transaction.updateMessageGroupingKeysAtomically(ids, groupingKey: key)
        }
        
        var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
        
        if let (message, _, updatedMessage) = mapping.first {
            for attribute in message.attributes {
                if let attribute = attribute as? OutgoingQuickReplyMessageAttribute {
                    if let threadId = updatedMessage.threadId {
                        _internal_applySentQuickReplyMessage(transaction: transaction, shortcut: attribute.shortcut, quickReplyId: Int32(clamping: threadId))
                    }
                }
            }
        }
        
        for (message, _, updatedMessage) in mapping {
            transaction.updateMessage(message.id, update: { currentMessage in
                let updatedId: MessageId
                if case let .Id(id) = updatedMessage.id {
                    updatedId = id
                } else {
                    updatedId = currentMessage.id
                }
                
                for attribute in currentMessage.attributes {
                    if let attribute = attribute as? OutgoingMessageInfoAttribute {
                        for id in attribute.bubbleUpEmojiOrStickersets {
                            if !bubbleUpEmojiOrStickersets.contains(id) {
                                bubbleUpEmojiOrStickersets.append(id)
                            }
                        }
                    }
                }
                
                let media: [Media]
                let attributes: [MessageAttribute]
                let text: String
 
                media = updatedMessage.media
                attributes = updatedMessage.attributes
                text = updatedMessage.text
                
                var storeForwardInfo: StoreMessageForwardInfo?
                if let forwardInfo = currentMessage.forwardInfo {
                    storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
                }
                
                if let fromMedia = currentMessage.media.first, let toMedia = media.first {
                    applyMediaResourceChanges(from: fromMedia, to: toMedia, postbox: postbox, force: false)
                }
                
                if storeForwardInfo == nil {
                    inner: for media in message.media {
                        if let file = media as? TelegramMediaFile {
                            for attribute in file.attributes {
                                switch attribute {
                                case let .Sticker(_, packReference, _):
                                    if packReference != nil {
                                        sentStickers.append(file)
                                    }
                                case .Animated:
                                    if !file.isAnimatedSticker && !file.isVideoSticker {
                                        sentGifs.append(file)
                                    }
                                default:
                                    break
                                }
                            }
                            break inner
                        }
                    }
                }
                
                var entitiesAttribute: TextEntitiesMessageAttribute?
                for attribute in attributes {
                    if let attribute = attribute as? TextEntitiesMessageAttribute {
                        entitiesAttribute = attribute
                        break
                    }
                }
                
                let (tags, globalTags) = tagsForStoreMessage(incoming: currentMessage.flags.contains(.Incoming), attributes: attributes, media: media, textEntities: entitiesAttribute?.entities, isPinned: currentMessage.tags.contains(.pinned))
                
                return .update(StoreMessage(id: updatedId, globallyUniqueId: nil, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: updatedMessage.timestamp, flags: [], tags: tags, globalTags: globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: text, attributes: attributes, media: media))
            })
        }
        
        for file in sentStickers {
            if let entry = CodableEntry(RecentMediaItem(file)) {
                transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
            }
        }
        for file in sentGifs {
            if !file.hasLinkedStickers {
                if let entry = CodableEntry(RecentMediaItem(file)) {
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
                }
            }
        }
        if !bubbleUpEmojiOrStickersets.isEmpty {
            applyBubbleUpEmojiOrStickersets(transaction: transaction, ids: bubbleUpEmojiOrStickersets)
        }
        stateManager.addUpdates(result)
        stateManager.addUpdateGroups([.ensurePeerHasLocalState(id: messages[0].id.peerId)])
        
        pendingMessageEvents(mapping.compactMap { message, _, updatedMessage -> PeerPendingMessageDelivered? in
            guard case let .Id(id) = updatedMessage.id else {
                return nil
            }
            return PeerPendingMessageDelivered(
                id: id,
                isSilent: updatedMessage.attributes.contains(where: { attribute in
                    if let attribute = attribute as? NotificationInfoMessageAttribute {
                        return attribute.flags.contains(.muted)
                    } else {
                        return false
                    }
                }),
                isPendingProcessing: updatedMessage.attributes.contains(where: { $0 is PendingProcessingMessageAttribute })
            )
        })
    }
}

private func applyBubbleUpEmojiOrStickersets(transaction: Transaction, ids: [ItemCollectionId]) {
    let namespaces: [ItemCollectionId.Namespace] = [Namespaces.ItemCollection.CloudStickerPacks, Namespaces.ItemCollection.CloudEmojiPacks]
    for namespace in namespaces {
        let namespaceIds = ids.filter { $0.namespace == namespace }
        if !namespaceIds.isEmpty {
            let infos = transaction.getItemCollectionsInfos(namespace: namespace)
            
            var packDict: [ItemCollectionId: Int] = [:]
            for i in 0 ..< infos.count {
                packDict[infos[i].0] = i
            }
            var topSortedPacks: [(ItemCollectionId, ItemCollectionInfo)] = []
            var processedPacks = Set<ItemCollectionId>()
            for id in namespaceIds {
                if let index = packDict[id] {
                    topSortedPacks.append(infos[index])
                    processedPacks.insert(id)
                }
            }
            let restPacks = infos.filter { !processedPacks.contains($0.0) }
            let sortedPacks = topSortedPacks + restPacks
            transaction.replaceItemCollectionInfos(namespace: namespace, itemCollectionInfos: sortedPacks)
        }
    }
}
