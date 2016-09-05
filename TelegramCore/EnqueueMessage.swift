import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func enqueueMessage(account: Account, peerId: PeerId, text: String, replyMessageId: MessageId?) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        var attributes: [MessageAttribute] = []
        if let replyMessageId = replyMessageId {
            attributes.append(ReplyMessageAttribute(messageId: replyMessageId))
        }
        
        modifier.addMessages([StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, timestamp: Int32(account.network.context.globalTime()), flags: [.Unsent], tags: [], forwardInfo: nil, authorId: account.peerId, text: text, attributes: attributes, media: [])], location: .Random)
    }
}
