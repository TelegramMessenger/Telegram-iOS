import Foundation
import UIKit
import Postbox

struct ChatHistoryNavigationStack {
    private var messageIndices: [MessageIndex] = []
    
    mutating func add(_ index: MessageIndex) {
        self.messageIndices.append(index)
    }
    
    mutating func removeLast() -> MessageIndex? {
        if messageIndices.isEmpty {
            return nil
        }
        return messageIndices.removeLast()
    }
    
    var isEmpty: Bool {
        return self.messageIndices.isEmpty
    }
    
    mutating func filterOutIndicesLessThan(_ index: MessageIndex) {
        for i in (0 ..< self.messageIndices.count).reversed() {
            if self.messageIndices[i] <= index {
                self.messageIndices.remove(at: i)
            }
        }
    }
}
