import Foundation
import SwiftSignalKit
import Postbox

public func enqueueMessage(account: Account, peerId: PeerId, text: String) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        modifier.addMessages([StoreMessage(peerId: peerId, namespace: Namespaces.Message.Local, timestamp: Int32(account.network.context.globalTime()), flags: [.Unsent], tags: [], forwardInfo: nil, authorId: account.peerId, text: text, attributes: [], media: [])], location: .Random)
    }
}
