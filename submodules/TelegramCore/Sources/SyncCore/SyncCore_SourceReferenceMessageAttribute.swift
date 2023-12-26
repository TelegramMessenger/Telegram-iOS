import Foundation
import Postbox

public class SourceReferenceMessageAttribute: MessageAttribute {
    public let messageId: MessageId
    
    public let associatedMessageIds: [MessageId] = []
    public let associatedPeerIds: [PeerId]
    
    public init(messageId: MessageId) {
        self.messageId = messageId
        
        self.associatedPeerIds = [messageId.peerId]
    }
    
    required public init(decoder: PostboxDecoder) {
        let namespaceAndId: Int64 = decoder.decodeInt64ForKey("i", orElse: 0)
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: Int32(namespaceAndId & 0xffffffff), id: Int32((namespaceAndId >> 32) & 0xffffffff))
        
        self.associatedPeerIds = [self.messageId.peerId]
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let namespaceAndId = Int64(self.messageId.namespace) | (Int64(self.messageId.id) << 32)
        encoder.encodeInt64(namespaceAndId, forKey: "i")
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
    }
}

public class SourceAuthorInfoMessageAttribute: MessageAttribute {
    public let originalAuthor: PeerId?
    public let originalAuthorName: String?
    public let orignalDate: Int32?
    public let originalOutgoing: Bool
    
    public let associatedMessageIds: [MessageId] = []
    public let associatedPeerIds: [PeerId]
    
    public init(originalAuthor: PeerId?, originalAuthorName: String?, orignalDate: Int32?, originalOutgoing: Bool) {
        self.originalAuthor = originalAuthor
        self.originalAuthorName = originalAuthorName
        self.orignalDate = orignalDate
        self.originalOutgoing = originalOutgoing
        
        if let originalAuthor = self.originalAuthor {
            self.associatedPeerIds = [originalAuthor]
        } else {
            self.associatedPeerIds = []
        }
    }
    
    required public init(decoder: PostboxDecoder) {
        self.originalAuthor = decoder.decodeOptionalInt64ForKey("oa").flatMap(PeerId.init)
        self.originalAuthorName = decoder.decodeOptionalStringForKey("oan")
        self.orignalDate = decoder.decodeOptionalInt32ForKey("od")
        self.originalOutgoing = decoder.decodeBoolForKey("oout", orElse: false)
        
        if let originalAuthor = self.originalAuthor {
            self.associatedPeerIds = [originalAuthor]
        } else {
            self.associatedPeerIds = []
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        if let originalAuthor = self.originalAuthor {
            encoder.encodeInt64(originalAuthor.toInt64(), forKey: "oa")
        } else {
            encoder.encodeNil(forKey: "oa")
        }
        if let originalAuthorName = self.originalAuthorName {
            encoder.encodeString(originalAuthorName, forKey: "oan")
        } else {
            encoder.encodeNil(forKey: "oan")
        }
        if let orignalDate = self.orignalDate {
            encoder.encodeInt32(orignalDate, forKey: "od")
        } else {
            encoder.encodeNil(forKey: "od")
        }
        encoder.encodeBool(self.originalOutgoing, forKey: "oout")
    }
}
