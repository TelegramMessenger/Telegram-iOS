import Foundation
import UIKit
import TelegramCore

struct ChatHistoryNavigationStack {
    private var messageIndices: [EngineMessage.Index] = []
    
    mutating func add(_ index: EngineMessage.Index) {
        self.messageIndices.append(index)
    }
    
    mutating func removeLast() -> EngineMessage.Index? {
        if messageIndices.isEmpty {
            return nil
        }
        return messageIndices.removeLast()
    }
    
    var isEmpty: Bool {
        return self.messageIndices.isEmpty
    }
    
    mutating func filterOutIndicesLessThan(_ index: EngineMessage.Index) {
        for i in (0 ..< self.messageIndices.count).reversed() {
            if self.messageIndices[i] <= index {
                self.messageIndices.remove(at: i)
            }
        }
    }
}
