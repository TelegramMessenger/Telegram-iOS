import Foundation

final class UnsentMessageHistoryView {
    var indices: Set<MessageIndex>
    
    init(indices: [MessageIndex]) {
        self.indices = Set(indices)
    }
    
    func refreshDueToExternalTransaction(fetchUnsendMessageIndices: () -> [MessageIndex]) -> Bool {
        let indices = Set(fetchUnsendMessageIndices())
        if indices != self.indices {
            self.indices = indices
            return true
        } else {
            return false
        }
    }
    
    func replay(_ operations: [IntermediateMessageHistoryUnsentOperation]) -> Bool {
        var updated = false
        for operation in operations {
            switch operation {
                case let .Insert(index):
                    if !self.indices.contains(index) {
                        self.indices.insert(index)
                        updated = true
                    }
                case let .Remove(index):
                    if self.indices.contains(index) {
                        self.indices.remove(index)
                        updated = true
                    }
            }
        }
        
        return updated
    }
}
