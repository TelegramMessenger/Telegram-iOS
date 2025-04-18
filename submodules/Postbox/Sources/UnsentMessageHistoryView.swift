import Foundation

final class UnsentMessageHistoryView {
    var ids: Set<MessageId>
    
    init(ids: [MessageId]) {
        self.ids = Set(ids)
    }
    
    func refreshDueToExternalTransaction(fetchUnsentMessageIds: () -> [MessageId]) -> Bool {
        let ids = Set(fetchUnsentMessageIds())
        postboxLog("UnsentMessageHistoryView: refreshDueToExternalTransaction: \(ids)")
        if ids != self.ids {
            self.ids = ids
            return true
        } else {
            return false
        }
    }
    
    func replay(_ operations: [IntermediateMessageHistoryUnsentOperation]) -> Bool {
        var updated = false
        for operation in operations {
            postboxLog("UnsentMessageHistoryView: operation: \(operation)")
            switch operation {
                case let .Insert(id):
                    if !self.ids.contains(id) {
                        self.ids.insert(id)
                        updated = true
                    }
                case let .Remove(id):
                    if self.ids.contains(id) {
                        self.ids.remove(id)
                        updated = true
                    }
            }
        }
        
        return updated
    }
}
