import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func installInteractiveReadMessagesAction(postbox: Postbox, peerId: PeerId) -> Disposable {
    return postbox.installStoreMessageAction(peerId: peerId, { messages, modifier in
        var consumeMessageIds: [MessageId] = []
        
        for message in messages {
            if case let .Id(id) = message.id {
                if message.tags.contains(.unseenPersonalMessage) {
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.consumed, !attribute.pending {
                            consumeMessageIds.append(id)
                            break inner
                        }
                    }
                }
            }
        }
        
        for id in consumeMessageIds {
            modifier.updateMessage(id, update: { currentMessage in
                var attributes = currentMessage.attributes
                loop: for j in 0 ..< attributes.count {
                    if let attribute = attributes[j] as? ConsumablePersonalMentionMessageAttribute {
                        attributes[j] = ConsumablePersonalMentionMessageAttribute(consumed: attribute.consumed, pending: true)
                        break loop
                    }
                }
                return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, forwardInfo: currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
            })
            
            modifier.setPendingMessageAction(type: .consumeUnseenPersonalMessage, id: id, action: ConsumePersonalMessageAction())
        }
    })
}
