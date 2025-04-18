import Foundation
import Postbox

enum InternalAccountState {
    static func addMessages(transaction: Transaction, messages: [StoreMessage], location: AddMessagesLocation) -> [Int64 : MessageId] {
        return transaction.addMessages(messages, location: location)
    }
    
    static func deleteMessages(transaction: Transaction, ids: [MessageId], forEachMedia: ((Media) -> Void)?) {
        transaction.deleteMessages(ids, forEachMedia: forEachMedia)
    }
    
    static func invalidateChannelState(peerId: PeerId) {
        
    }
}
