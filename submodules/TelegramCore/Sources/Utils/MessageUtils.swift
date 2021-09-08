import Foundation
import Postbox


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
    
    var effectiveAuthor: Peer? {
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

func locallyRenderedMessage(message: StoreMessage, peers: [PeerId: Peer]) -> Message? {
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
    
    return Message(stableId: stableId, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: message.threadId, timestamp: message.timestamp, flags: MessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: forwardInfo, author: author, text: message.text, attributes: message.attributes, media: message.media, peers: messagePeers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
}

public extension Message {
    func effectivelyIncoming(_ accountPeerId: PeerId) -> Bool {
        if self.id.peerId == accountPeerId {
            if self.forwardInfo != nil {
                return true
            } else {
                return false
            }
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
}

public extension Message {
    var secretMediaDuration: Int32? {
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
}

