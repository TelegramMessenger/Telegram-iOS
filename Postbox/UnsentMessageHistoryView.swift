import Foundation

final class UnsentMessageHistoryView {
    var indices: [MessageIndex]
    
    init(indices: [MessageIndex]) {
        self.indices = indices
    }
    
    func replay(_ operations: [IntermediateMessageHistoryUnsentOperation]) -> Bool {
        var updated = false
        for operation in operations {
            switch operation {
                case let .Insert(index):
                    var inserted = false
                    for i in 0 ..< self.indices.count {
                        if self.indices[i] > index {
                            self.indices.insert(index, at: i)
                            inserted = true
                            break
                        }
                    }
                    if !inserted {
                        self.indices.append(index)
                    }
                    updated = true
                case let .Remove(index):
                    for i in 0 ..< self.indices.count {
                        if self.indices[i] == index {
                            self.indices.remove(at: i)
                            updated = true
                            break
                        }
                    }
            }
        }
        
        return updated
    }
}
