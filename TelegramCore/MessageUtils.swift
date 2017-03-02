import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public extension Message {
    var effectivelyIncoming: Bool {
        if self.flags.contains(.Incoming) {
            return true
        } else if let channel = self.peers[self.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            return true
        } else {
            return false
        }
    }
}

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
                        if !self.flags.contains(.Personal) {
                            return nil
                        }
                    }
                    return attribute
                }
            }
        }
        return nil
    }
    
    var requestsSetupReply: Bool {
        for attribute in self.attributes {
            if let attribute = attribute as? ReplyMarkupMessageAttribute {
                if !attribute.flags.contains(.inline) {
                    if attribute.flags.contains(.personal) {
                        if !self.flags.contains(.Personal) {
                            return false
                        }
                    }
                    return attribute.flags.contains(.setupReply)
                }
            }
        }
        return false
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
    
    return Message(stableId: 0, stableVersion: 0, id: id, globallyUniqueId: nil, timestamp: message.timestamp, flags: MessageFlags(message.flags), tags: message.tags, forwardInfo: nil, author: author, text: message.text, attributes: message.attributes, media: message.media, peers: messagePeers, associatedMessages: SimpleDictionary(), associatedMessageIds: [])
}
