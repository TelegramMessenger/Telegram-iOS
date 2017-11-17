//
//  SourceReferenceMessageAttribute.swift
//  TelegramCore
//
//  Created by keepcoder on 16/11/2017.
//  Copyright © 2017 Peter. All rights reserved.
//

import Cocoa
import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif


public class SourceReferenceMessageAttribute: MessageAttribute {
    public let messageId: MessageId
    
    public var associatedMessageIds: [MessageId] {
        return [self.messageId]
    }
    
    public init(messageId: MessageId) {
        self.messageId = messageId
    }
    
    required public init(decoder: PostboxDecoder) {
        let namespaceAndId: Int64 = decoder.decodeInt64ForKey("i", orElse: 0)
        self.messageId = MessageId(peerId: PeerId(decoder.decodeInt64ForKey("p", orElse: 0)), namespace: Int32(namespaceAndId & 0xffffffff), id: Int32((namespaceAndId >> 32) & 0xffffffff))
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        let namespaceAndId = Int64(self.messageId.namespace) | (Int64(self.messageId.id) << 32)
        encoder.encodeInt64(namespaceAndId, forKey: "i")
        encoder.encodeInt64(self.messageId.peerId.toInt64(), forKey: "p")
    }
}


