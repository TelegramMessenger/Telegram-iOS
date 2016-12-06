import Foundation
import Postbox

struct PeerMessageManagedMediaId: ManagedMediaId {
    let messageId: MessageId
    
    init(messageId: MessageId) {
        self.messageId = messageId
    }
    
    var hashValue: Int {
        return self.messageId.hashValue
    }
    
    func isEqual(to: ManagedMediaId) -> Bool {
        if let to = to as? PeerMessageManagedMediaId {
            return self.messageId == to.messageId
        } else {
            return false
        }
    }
}
