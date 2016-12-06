import Foundation
import TelegramCore
import Postbox

struct ChatContextResultManagedMediaId: ManagedMediaId {
    let result: ChatContextResult
    
    init(result: ChatContextResult) {
        self.result = result
    }
    
    var hashValue: Int {
        return self.result.id.hashValue
    }
    
    func isEqual(to: ManagedMediaId) -> Bool {
        if let to = to as? ChatContextResultManagedMediaId {
            return self.result == to.result
        } else {
            return false
        }
    }
}
