import Foundation
import Postbox
import TelegramApi

public class ReplyMessageAttribute: MessageAttribute {
    public let messageId: MessageId
    public let threadMessageId: MessageId?
    public let quote: EngineMessageReplyQuote?
    public let isQuote: Bool
    public let todoItemId: Int32?
    
    public var associatedMessageIds: [MessageId] {
        return [self.messageId]
    }
    
    public init(messageId: MessageId, threadMessageId: MessageId?, quote: EngineMessageReplyQuote?, isQuote: Bool, todoItemId: Int32?) {
        self.messageId = messageId
        self.threadMessageId = threadMessageId
        self.quote = quote
        self.isQuote = isQuote
        self.todoItemId = todoItemId
    }
    
    required public init(decoder: PostboxDecoder) {
        let namespaceAndId: Int64 = decoder.decodeInt64ForKey("i", orElse: 0)
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: Int32(namespaceAndId & 0xffffffff), id: Int32((namespaceAndId >> 32) & 0xffffffff))
        
        if let threadNamespaceAndId = decoder.decodeOptionalInt64ForKey("ti"), let threadPeerId = decoder.decodeOptionalInt64ForKey("tp") {
            self.threadMessageId = MessageId(peerId: PeerId(threadPeerId), namespace: Int32(threadNamespaceAndId & 0xffffffff), id: Int32((threadNamespaceAndId >> 32) & 0xffffffff))
        } else {
            self.threadMessageId = nil
        }
        
        self.quote = decoder.decodeCodable(EngineMessageReplyQuote.self, forKey: "qu")
        self.isQuote = decoder.decodeBoolForKey("iq", orElse: self.quote != nil)
        self.todoItemId = decoder.decodeOptionalInt32ForKey("tid")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let namespaceAndId = Int64(self.messageId.namespace) | (Int64(self.messageId.id) << 32)
        encoder.encodeInt64(namespaceAndId, forKey: "i")
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
        if let threadMessageId = self.threadMessageId {
            let threadNamespaceAndId = Int64(threadMessageId.namespace) | (Int64(threadMessageId.id) << 32)
            encoder.encodeInt64(threadNamespaceAndId, forKey: "ti")
            encoder.encodeInt64(threadMessageId.peerId.toInt64(), forKey: "tp")
        }
        if let quote = self.quote {
            encoder.encodeCodable(quote, forKey: "qu")
        } else {
            encoder.encodeNil(forKey: "qu")
        }
        encoder.encodeBool(self.isQuote, forKey: "iq")
        if let todoItemId = self.todoItemId {
            encoder.encodeInt32(todoItemId, forKey: "tid")
        } else {
            encoder.encodeNil(forKey: "tid")
        }
    }
}

public class QuotedReplyMessageAttribute: MessageAttribute {
    public let peerId: PeerId?
    public let authorName: String?
    public let quote: EngineMessageReplyQuote?
    public let isQuote: Bool
    
    public var associatedMessageIds: [MessageId] {
        return []
    }
    
    public var associatedPeerIds: [PeerId] {
        if let peerId = self.peerId {
            return [peerId]
        } else {
            return []
        }
    }
    
    public init(peerId: PeerId?, authorName: String?, quote: EngineMessageReplyQuote?, isQuote: Bool) {
        self.peerId = peerId
        self.authorName = authorName
        self.quote = quote
        self.isQuote = isQuote
    }
    
    required public init(decoder: PostboxDecoder) {
        self.peerId = decoder.decodeOptionalInt64ForKey("p").flatMap(PeerId.init)
        self.authorName = decoder.decodeOptionalStringForKey("a")
        self.quote = decoder.decodeCodable(EngineMessageReplyQuote.self, forKey: "qu")
        self.isQuote = decoder.decodeBoolForKey("iq", orElse: true)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let peerId = self.peerId {
            encoder.encodeInt64(peerId.toInt64(), forKey: "p")
        } else {
            encoder.encodeNil(forKey: "p")
        }
        
        if let authorName = self.authorName {
            encoder.encodeString(authorName, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        
        if let quote = self.quote {
            encoder.encodeCodable(quote, forKey: "qu")
        } else {
            encoder.encodeNil(forKey: "qu")
        }
        
        encoder.encodeBool(self.isQuote, forKey: "iq")
    }
}

extension QuotedReplyMessageAttribute {
    convenience init(apiHeader: Api.MessageFwdHeader, quote: EngineMessageReplyQuote?, isQuote: Bool) {
        switch apiHeader {
        case let .messageFwdHeader(_, fromId, fromName, _, _, _, _, _, _, _, _, _):
            self.init(peerId: fromId?.peerId, authorName: fromName, quote: quote, isQuote: isQuote)
        }
    }
}

public class ReplyStoryAttribute: MessageAttribute {
    public let storyId: StoryId
    
    public var associatedStoryIds: [StoryId] {
        return [self.storyId]
    }
    
    public var associatedPeerIds: [PeerId] {
        return [self.storyId.peerId]
    }
    
    public init(storyId: StoryId) {
        self.storyId = storyId
    }
    
    required public init(decoder: PostboxDecoder) {
        self.storyId = decoder.decode(StoryId.self, forKey: "i") ?? StoryId(peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(1)), id: 1)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encode(self.storyId, forKey: "i")
    }
}
