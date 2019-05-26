import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension MessageFlags {
    public var isSending: Bool {
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
    
    public var muted: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? NotificationInfoMessageAttribute {
                return attribute.flags.contains(.muted)
            }
        }
        return false
    }
    
    public var personal: Bool {
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
    
    public var sourceReference: SourceReferenceMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? SourceReferenceMessageAttribute {
                return attribute
            }
        }
        return nil
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
    }
    
    for media in message.media {
        for peerId in media.peerIds {
            if let peer = peers[peerId] {
                messagePeers[peer.id] = peer
            }
        }
    }
    
    return Message(stableId: 0, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, timestamp: message.timestamp, flags: MessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: nil, author: author, text: message.text, attributes: message.attributes, media: message.media, peers: messagePeers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
}
