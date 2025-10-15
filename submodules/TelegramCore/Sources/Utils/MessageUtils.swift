import Foundation
import Postbox
import TelegramApi

public extension MessageFlags {
    var isSending: Bool {
        return (self.contains(.Unsent) || self.contains(.Sending)) && !self.contains(.Failed)
    }
}

public extension Message {
    var visibleButtonKeyboardMarkup: ReplyMarkupMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) && !attribute.rows.isEmpty {
                    if attribute.flags.contains(.personal) {
                        if !personal {
                            return nil
                        }
                    }
                    return attribute
                }
            }
        }
        return nil
    }

    var visibleReplyMarkupPlaceholder: String? {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) {
                    if attribute.flags.contains(.personal) {
                        if !personal {
                            return nil
                        }
                    }
                    return attribute.placeholder
                }
            }
        }
        return nil
    }
    
    var muted: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted)
            }
        }
        return false
    }
    
    var personal: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.personal)
            }
        }
        return false
    }
    
    var requestsSetupReply: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) {
                    if attribute.flags.contains(.personal) {
                        if !personal {
                            return false
                        }
                    }
                    return attribute.flags.contains(.setupReply)
                }
            }
        }
        return false
    }
    
    var isScam: Bool {
        if let author = self.author, author.isScam {
            return true
        }
        if let forwardAuthor = self.forwardInfo?.author, forwardAuthor.isScam {
            return true
        }
        for attribute in self.attributes {
            if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId, let bot = self.peers[peerId] as? TelegramUser, bot.isScam {
               return true
            }
        }
        return false
    }
    
    var isFake: Bool {
        if let author = self.author, author.isFake {
            return true
        }
        if let forwardAuthor = self.forwardInfo?.author, forwardAuthor.isFake {
            return true
        }
        for attribute in self.attributes {
            if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId, let bot = self.peers[peerId] as? TelegramUser, bot.isFake {
               return true
            }
        }
        return false
    }
    
    var sourceReference: SourceReferenceMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var sourceAuthorInfo: SourceAuthorInfoMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? SourceAuthorInfoMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var effectiveAuthor: Peer? {
        if let sourceAuthorInfo = self.sourceAuthorInfo {
            if let sourceAuthorId = sourceAuthorInfo.originalAuthor, let peer = self.peers[sourceAuthorId] {
                return peer
            }
        }
        if let forwardInfo = self.forwardInfo, let sourceReference = self.sourceReference, forwardInfo.author?.id == sourceReference.messageId.peerId {
            if let peer = self.peers[sourceReference.messageId.peerId] {
                return peer
            }
        } else if let forwardInfo = self.forwardInfo, forwardInfo.flags.contains(.isImported), let author = forwardInfo.author {
            return author
        }
        return self.author
    }
}

func messagesIdsGroupedByPeerId(_ ids: Set<MessageId>) -> [PeerId: [MessageId]] {
    var dict: [PeerId: [MessageId]] = [:]
    
    for id in ids {
        let peerId = id.peerId
        if dict[peerId] == nil {
            dict[peerId] = [id]
        } else {
            dict[peerId]!.append(id)
        }
    }
    
    return dict
}

func messagesIdsGroupedByPeerId(_ ids: [MessageId]) -> [PeerId: [MessageId]] {
    var dict: [PeerId: [MessageId]] = [:]
    
    for id in ids {
        let peerId = id.peerId
        if dict[peerId] == nil {
            dict[peerId] = [id]
        } else {
            dict[peerId]!.append(id)
        }
    }
    
    return dict
}

func messagesIdsGroupedByPeerId(_ ids: ReferencedReplyMessageIds) -> [PeerId: ReferencedReplyMessageIds] {
    var dict: [PeerId: ReferencedReplyMessageIds] = [:]
    
    for (targetId, sourceId) in ids.targetIdsBySourceId {
        let peerId = sourceId.peerId
        dict[peerId, default: ReferencedReplyMessageIds()].add(sourceId: sourceId, targetId: targetId)
    }
    
    return dict
}

func messagesIdsGroupedByPeerId(_ ids: Set<MessageAndThreadId>) -> [PeerAndThreadId: [MessageId]] {
    var dict: [PeerAndThreadId: [MessageId]] = [:]
    
    for id in ids {
        let peerAndThreadId = PeerAndThreadId(peerId: id.messageId.peerId, threadId: id.threadId)
        if dict[peerAndThreadId] == nil {
            dict[peerAndThreadId] = [id.messageId]
        } else {
            dict[peerAndThreadId]!.append(id.messageId)
        }
    }
    
    return dict
}

func messagesIdsGroupedByPeerId(_ ids: [MessageAndThreadId]) -> [PeerAndThreadId: [MessageId]] {
    var dict: [PeerAndThreadId: [MessageId]] = [:]
    
    for id in ids {
        let peerAndThreadId = PeerAndThreadId(peerId: id.messageId.peerId, threadId: id.threadId)
        if dict[peerAndThreadId] == nil {
            dict[peerAndThreadId] = [id.messageId]
        } else {
            dict[peerAndThreadId]!.append(id.messageId)
        }
    }
    
    return dict
}

func locallyRenderedMessage(message: StoreMessage, peers: [PeerId: Peer], associatedThreadInfo: Message.AssociatedThreadInfo? = nil, associatedMessages: SimpleDictionary<MessageId, Message> = SimpleDictionary()) -> Message? {
    guard case let .Id(id) = message.id else {
        return nil
    }
    
    var messagePeers = SimpleDictionary<PeerId, Peer>()
    
    var author: Peer?
    if let authorId = message.authorId {
        author = peers[authorId]
        if let author = author {
            messagePeers[author.id] = author
        }
    }
    
    if let peer = peers[id.peerId] {
        messagePeers[peer.id] = peer
        
        if let group = peer as? TelegramGroup, let migrationReference = group.migrationReference {
            if let channelPeer = peers[migrationReference.peerId] {
                messagePeers[channelPeer.id] = channelPeer
            }
        }
        
        if let channel = peer as? TelegramChannel, channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId {
            if let channelPeer = peers[linkedMonoforumId] {
                messagePeers[channelPeer.id] = channelPeer
            }
            
            if let threadId = message.threadId {
                if let threadPeer = peers[PeerId(threadId)] {
                    messagePeers[threadPeer.id] = threadPeer
                }
            }
        }
    }
    
    for media in message.media {
        for peerId in media.peerIds {
            if let peer = peers[peerId] {
                messagePeers[peer.id] = peer
            }
        }
    }
    
    var forwardInfo: MessageForwardInfo?
    if let info = message.forwardInfo {
        forwardInfo = MessageForwardInfo(author: info.authorId.flatMap({ peers[$0] }), source: info.sourceId.flatMap({ peers[$0] }), sourceMessageId: info.sourceMessageId, date: info.date, authorSignature: info.authorSignature, psaType: info.psaType, flags: info.flags)
        if let author = forwardInfo?.author {
            messagePeers[author.id] = author
        }
        if let source = forwardInfo?.source {
            messagePeers[source.id] = source
        }
    }

    var hasher = Hasher()
    hasher.combine(id.id)
    hasher.combine(id.peerId)
    
    let hashValue = Int64(hasher.finalize())
    let first = UInt32((hashValue >> 32) & 0xffffffff)
    let second = UInt32(hashValue & 0xffffffff)
    let stableId = first &+ second
        
    return Message(stableId: stableId, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: message.timestamp, flags: MessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, customTags: [], forwardInfo: forwardInfo, author: author, text: message.text, attributes: message.attributes, media: message.media, peers: messagePeers, associatedMessages: associatedMessages, associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: associatedThreadInfo, associatedStories: [:])
}

func locallyRenderedMessage(message: StoreMessage, peers: AccumulatedPeers, associatedThreadInfo: Message.AssociatedThreadInfo? = nil) -> Message? {
    guard case let .Id(id) = message.id else {
        return nil
    }
    
    var messagePeers = SimpleDictionary<PeerId, Peer>()
    
    var author: Peer?
    if let authorId = message.authorId {
        author = peers.get(authorId)
        if let author = author {
            messagePeers[author.id] = author
        }
    }
    
    if let peer = peers.get(id.peerId) {
        messagePeers[peer.id] = peer
        
        if let group = peer as? TelegramGroup, let migrationReference = group.migrationReference {
            if let channelPeer = peers.get(migrationReference.peerId) {
                messagePeers[channelPeer.id] = channelPeer
            }
        }
    }
    
    for media in message.media {
        for peerId in media.peerIds {
            if let peer = peers.get(peerId) {
                messagePeers[peer.id] = peer
            }
        }
    }
    
    var forwardInfo: MessageForwardInfo?
    if let info = message.forwardInfo {
        forwardInfo = MessageForwardInfo(author: info.authorId.flatMap({ peers.get($0) }), source: info.sourceId.flatMap({ peers.get($0) }), sourceMessageId: info.sourceMessageId, date: info.date, authorSignature: info.authorSignature, psaType: info.psaType, flags: info.flags)
        if let author = forwardInfo?.author {
            messagePeers[author.id] = author
        }
        if let source = forwardInfo?.source {
            messagePeers[source.id] = source
        }
    }

    var hasher = Hasher()
    hasher.combine(id.id)
    hasher.combine(id.peerId)
    
    let hashValue = Int64(hasher.finalize())
    let first = UInt32((hashValue >> 32) & 0xffffffff)
    let second = UInt32(hashValue & 0xffffffff)
    let stableId = first &+ second
        
    return Message(stableId: stableId, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: message.timestamp, flags: MessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, customTags: [], forwardInfo: forwardInfo, author: author, text: message.text, attributes: message.attributes, media: message.media, peers: messagePeers, associatedMessages: SimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: associatedThreadInfo, associatedStories: [:])
}

public extension Message {
    func effectivelyIncoming(_ accountPeerId: PeerId) -> Bool {
        if self.id.peerId == accountPeerId {
            if let sourceAuthorInfo = self.sourceAuthorInfo {
                if sourceAuthorInfo.originalOutgoing {
                    return false
                } else if let originalAuthor = sourceAuthorInfo.originalAuthor, originalAuthor == accountPeerId {
                    return false
                }
            } else if let forwardInfo = self.forwardInfo {
                if let author = forwardInfo.author, author.id == accountPeerId {
                    return false
                }
            }
            
            if self.forwardInfo != nil {
                return true
            } else {
                return false
            }
        } else if self.author?.id == accountPeerId {
            if let channel = self.peers[self.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
                return true
            }
            return false
        } else if self.flags.contains(.Incoming) {
            return true
        } else if let channel = self.peers[self.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return true
        } else {
            return false
        }
    }
    
    func effectivelyFailed(timestamp: Int32) -> Bool {
        if self.flags.contains(.Failed) {
            return true
        } else if self.id.namespace == Namespaces.Message.ScheduledCloud && self.timestamp != scheduleWhenOnlineTimestamp {
            return timestamp > self.timestamp + 60
        } else {
            return false
        }
    }
    
    func isCopyProtected() -> Bool {
        if self.flags.contains(.CopyProtected) {
            return true
        } else if let group = self.peers[self.id.peerId] as? TelegramGroup, group.flags.contains(.copyProtectionEnabled) {
            return true
        } else if let channel = self.peers[self.id.peerId] as? TelegramChannel, channel.flags.contains(.copyProtectionEnabled) {
            return true
        } else {
            return false
        }
    }
    
    func isSensitiveContent(platform: String) -> Bool {
        if let rule = self.restrictedContentAttribute?.rules.first(where: { $0.reason == "sensitive" }) {
            if rule.platform == "all" || rule.platform == platform {
                return true
            }
        }
        if let peer = self.peers[self.id.peerId], peer.hasSensitiveContent(platform: platform) {
            return true
        }
        return false
    }
}

public extension Message {
    var secretMediaDuration: Double? {
        var found = false
        for attribute in self.attributes {
            if let _ = attribute as? AutoremoveTimeoutMessageAttribute {
                found = true
                break
            } else if let _ = attribute as? AutoclearTimeoutMessageAttribute {
                found = true
                break
            }
        }
        
        if !found {
            return nil
        }
        
        for media in self.media {
            switch media {
            case _ as TelegramMediaImage:
                return nil
            case let file as TelegramMediaFile:
                return file.duration
            default:
                break
            }
        }
        
        return nil
    }
}

public extension Message {
    var isSentOrAcknowledged: Bool {
        if self.flags.contains(.Failed) {
            return false
        } else if self.flags.isSending {
            for attribute in self.attributes {
                if let attribute = attribute as? OutgoingMessageInfoAttribute {
                    if attribute.acknowledged {
                        return true
                    }
                }
            }
            return false
        } else {
            return true
        }
    }
}

public extension Message {
    var adAttribute: AdMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? AdMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var factCheckAttribute: FactCheckMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? FactCheckMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var inlineBotAttribute: InlineBusinessBotMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? InlineBusinessBotMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var derivedDataAttribute: DerivedDataMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? DerivedDataMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var forwardVideoTimestampAttribute: ForwardVideoTimestampAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? ForwardVideoTimestampAttribute {
                return attribute
            }
        }
        return nil
    }
}
public extension Message {
    var reactionsAttribute: ReactionsMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? ReactionsMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    func effectiveReactionsAttribute(isTags: Bool) -> ReactionsMessageAttribute? {
        if !self.hasReactions {
            return nil
        }
        
        if let result = mergedMessageReactions(attributes: self.attributes, isTags: isTags) {
            return result
        } else {
            return nil
        }
    }
    func effectiveReactions(isTags: Bool) -> [MessageReaction]? {
        if !self.hasReactions {
            return nil
        }
        
        if let result = mergedMessageReactions(attributes: self.attributes, isTags: isTags) {
            return result.reactions
        } else {
            return nil
        }
    }
    var hasReactions: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? ReactionsMessageAttribute {
                if !attribute.reactions.isEmpty {
                    return true
                }
            }
        }
        for attribute in self.attributes {
            if let attribute = attribute as? PendingReactionsMessageAttribute {
                if !attribute.reactions.isEmpty {
                    return true
                }
            }
        }
        return false
    }
    
    var textEntitiesAttribute: TextEntitiesMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var restrictedContentAttribute: RestrictedContentMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? RestrictedContentMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var paidContent: TelegramMediaPaidContent? {
        return self.media.first(where: { $0 is TelegramMediaPaidContent }) as? TelegramMediaPaidContent
    }
    
    var authorSignatureAttribute: AuthorSignatureMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? AuthorSignatureMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var paidStarsAttribute: PaidStarsMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? PaidStarsMessageAttribute {
                return attribute
            }
        }
        return nil
    }
}

public extension Message {
    var webpagePreviewAttribute: WebpagePreviewMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? WebpagePreviewMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    var invertMedia: Bool {
        for attribute in self.attributes {
            if let _ = attribute as? InvertMediaMessageAttribute {
                return true
            }
        }
        return false
    }
    var invertMediaAttribute: InvertMediaMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? InvertMediaMessageAttribute {
                return attribute
            }
        }
        return nil
    }
}

public extension Message {
    var pendingProcessingAttribute: PendingProcessingMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? PendingProcessingMessageAttribute {
                return attribute
            }
        }
        return nil
    }
}

public extension Message {
    func areReactionsTags(accountPeerId: PeerId) -> Bool {
        if self.id.peerId == accountPeerId {
            if let reactionsAttribute = self.reactionsAttribute, !reactionsAttribute.reactions.isEmpty {
                return reactionsAttribute.isTags
            } else {
                return true
            }
        }
        return false
    }
}

public func _internal_parseMediaAttachment(data: Data) -> Media? {
    guard let object = Api.parse(Buffer(buffer: MemoryBuffer(data: data))) else {
        return nil
    }
    if let photo = object as? Api.Photo {
        return telegramMediaImageFromApiPhoto(photo)
    } else if let file = object as? Api.Document {
        return telegramMediaFileFromApiDocument(file, altDocuments: [])
    } else {
        return nil
    }
}

public extension Message {
    func messageEffect(availableMessageEffects: AvailableMessageEffects?) -> AvailableMessageEffects.MessageEffect? {
        guard let availableMessageEffects else {
            return nil
        }
        for attribute in self.attributes {
            if let attribute = attribute as? EffectMessageAttribute {
                for effect in availableMessageEffects.messageEffects {
                    if effect.id == attribute.id {
                        return effect
                    }
                }
                break
            }
        }
        return nil
    }
}
