import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum EnqueueMessage {
    case message(text: String, attributes: [MessageAttribute], media: Media?, replyToMessageId: MessageId?)
    case forward(source: MessageId)
    
    public func withUpdatedReplyToMessageId(_ replyToMessageId: MessageId?) -> EnqueueMessage {
        switch self {
            case let .message(text, attributes, media, _):
                return .message(text: text, attributes: attributes, media: media, replyToMessageId: replyToMessageId)
            case .forward:
                return self
        }
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
            default:
                return false
        }
    }
}

func opportunisticallyTransformMessageWithMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, media: Media, userInteractive: Bool) -> Signal<Media?, NoError> {
    return transformOutgoingMessageMedia(postbox, network, media, userInteractive)
        |> timeout(2.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

private func opportunisticallyTransformOutgoingMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, messages: [EnqueueMessage], userInteractive: Bool) -> Signal<[(Bool, EnqueueMessage)], NoError> {
    var hasMedia = false
    loop: for message in messages {
        switch message {
            case let .message(_, _, media, _):
                if media != nil {
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
            case let .message(text, attributes, media, replyToMessageId):
                if let media = media {
                    signals.append(opportunisticallyTransformMessageWithMedia(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, media: media, userInteractive: userInteractive) |> map { result -> (Bool, EnqueueMessage) in
                        if let result = result {
                            return (true, .message(text: text, attributes: attributes, media: result, replyToMessageId: replyToMessageId))
                        } else {
                            return (false, .message(text: text, attributes: attributes, media: media, replyToMessageId: replyToMessageId))
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
        return account.postbox.modify { modifier -> [MessageId?] in
            return enqueueMessages(modifier: modifier, account: account, peerId: peerId, messages: messages)
        }
    }
}

public func resendMessages(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        var removeMessageIds: [MessageId] = []
        for (peerId, ids) in messagesIdsGroupedByPeerId(messageIds) {
            var messages: [EnqueueMessage] = []
            for id in ids {
                if let message = modifier.getMessage(id), !message.flags.contains(.Incoming) {
                    removeMessageIds.append(id)
                    
                    var replyToMessageId: MessageId?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            replyToMessageId = attribute.messageId
                        }
                    }
                    
                    messages.append(.message(text: message.text, attributes: message.attributes, media: message.media.first, replyToMessageId: replyToMessageId))
                }
            }
            let _ = enqueueMessages(modifier: modifier, account: account, peerId: peerId, messages: messages.map { (false, $0) })
        }
        modifier.deleteMessages(removeMessageIds)
    }
}

func enqueueMessages(modifier: Modifier, account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)]) -> [MessageId?] {
    if let peer = modifier.getPeer(peerId) {
        var storeMessages: [StoreMessage] = []
        var timestamp = Int32(account.network.context.globalTime())
        switch peerId.namespace {
            case Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudUser:
                if let topIndex = modifier.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    timestamp = max(timestamp, topIndex.timestamp)
                }
            default:
                break
        }
        
        var globallyUniqueIds: [Int64] = []
        for (transformedMedia, message) in messages {
            var attributes: [MessageAttribute] = []
            var flags = StoreMessageFlags()
            flags.insert(.Unsent)
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            var infoFlags = OutgoingMessageInfoFlags()
            if transformedMedia {
                infoFlags.insert(.transformedMedia)
            }
            attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: infoFlags))
            globallyUniqueIds.append(randomId)
            
            switch message {
                case let .message(text, requestedAttributes, media, replyToMessageId):
                    if let peer = peer as? TelegramSecretChat {
                        var isAction = false
                        if let _ = media as? TelegramMediaAction {
                            isAction = true
                        }
                        if let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                            attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                        }
                    }
                    
                    attributes.append(contentsOf: filterMessageAttributesForOutgoingMessage(requestedAttributes))
                        
                    if let replyToMessageId = replyToMessageId {
                        attributes.append(ReplyMessageAttribute(messageId: replyToMessageId))
                    }
                    var mediaList: [Media] = []
                    if let media = media {
                        mediaList.append(media)
                    }
                    
                    if let file = media as? TelegramMediaFile, file.isVoice {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    }
                    
                    var entitiesAttribute: TextEntitiesMessageAttribute?
                    for attribute in attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            entitiesAttribute = attribute
                            break
                        }
                    }
                
                    let authorId:PeerId?
                    if let peer = peer as? TelegramChannel, case let .broadcast(info) = peer.info, !info.flags.contains(.messagesShouldHaveSignatures) {
                        authorId = peer.id
                    }  else {
                        authorId = account.peerId
                    }
                    
                    storeMessages.append(StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: randomId, timestamp: timestamp, flags: flags, tags: tagsForStoreMessage(media: mediaList, textEntities: entitiesAttribute?.entities), forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: mediaList))
                case let .forward(source):
                    if let sourceMessage = modifier.getMessage(source), let author = sourceMessage.author ?? sourceMessage.peers[sourceMessage.id.peerId] {
                        if let peer = peer as? TelegramSecretChat {
                            var isAction = false
                            for media in sourceMessage.media {
                                if let _ = media as? TelegramMediaAction {
                                    isAction = true
                                    break
                                }
                            }
                            if let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                            }
                        }
                        
                        attributes.append(ForwardSourceInfoAttribute(messageId: sourceMessage.id))
                        attributes.append(contentsOf: filterMessageAttributesForForwardedMessage(sourceMessage.attributes))
                        let forwardInfo: StoreMessageForwardInfo?
                        if let sourceForwardInfo = sourceMessage.forwardInfo {
                            forwardInfo = StoreMessageForwardInfo(authorId: sourceForwardInfo.author.id, sourceId: sourceForwardInfo.source?.id, sourceMessageId: sourceForwardInfo.sourceMessageId, date: sourceForwardInfo.date)
                        } else {
                            if sourceMessage.id.peerId != account.peerId {
                                var sourceId:PeerId? = nil
                                var sourceMessageId:MessageId? = nil
                                if let peer = messageMainPeer(sourceMessage) as? TelegramChannel, case .broadcast = peer.info {
                                    sourceId = peer.id
                                    sourceMessageId = sourceMessage.id
                                }
                                forwardInfo = StoreMessageForwardInfo(authorId: author.id, sourceId: sourceId, sourceMessageId: sourceMessageId, date: sourceMessage.timestamp)
                            } else {
                                forwardInfo = nil
                            }

                        }
                        
                        var entitiesAttribute: TextEntitiesMessageAttribute?
                        for attribute in attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                entitiesAttribute = attribute
                                break
                            }
                        }
                        
                        storeMessages.append(StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, globallyUniqueId: randomId, timestamp: timestamp, flags: flags, tags: tagsForStoreMessage(media: sourceMessage.media, textEntities: entitiesAttribute?.entities), forwardInfo: forwardInfo, authorId: account.peerId, text: sourceMessage.text, attributes: attributes, media: sourceMessage.media))
                    }
            }
        }
        var messageIds: [MessageId?] = []
        if !storeMessages.isEmpty {
            let globallyUniqueIdToMessageId = modifier.addMessages(storeMessages, location: .Random)
            for globallyUniqueId in globallyUniqueIds {
                messageIds.append(globallyUniqueIdToMessageId[globallyUniqueId])
            }
        }
        return messageIds
    } else {
        return []
    }
}
