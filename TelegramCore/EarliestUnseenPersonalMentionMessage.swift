import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func earliestUnseenPersonalMentionMessage(postbox: Postbox, peerId: PeerId) -> Signal<MessageId?, NoError> {
    return postbox.modify { modifier -> Signal<MessageId?, NoError> in
        var resultMessageId: MessageId?
        modifier.scanMessages(peerId: peerId, tagMask: .unseenPersonalMessage, { entry in
            switch entry {
                case let .message(message):
                    for attribute in message.attributes {
                        if let attribute = attribute as? ConsumablePersonalMentionMessageAttribute, !attribute.pending {
                            resultMessageId = message.id
                            return false
                        }
                    }
                    break
                case let .hole(hole):
                    break
            }
            return true
        })
        
        if let resultMessageId = resultMessageId {
            return .single(resultMessageId)
        }
        
        return .single(nil)
    } |> switchToLatest
}
