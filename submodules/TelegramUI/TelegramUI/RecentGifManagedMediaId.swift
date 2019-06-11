import Foundation
import TelegramCore
import Postbox

struct RecentGifManagedMediaId: ManagedMediaId {
    let id: MediaId
    
    init(id: MediaId) {
        self.id = id
    }
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    func isEqual(to: ManagedMediaId) -> Bool {
        if let to = to as? RecentGifManagedMediaId {
            return self.id == to.id
        } else {
            return false
        }
    }
}
