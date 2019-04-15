import Foundation

struct MessageIndexSet {
    typealias ElementType = MessageIndex
    
    private var sortedRanges: [ClosedRange<ElementType>] = []
    
    init() {
        
    }
    
    mutating func insert(indicesIn range: ClosedRange<ElementType>) {
    }
    
    mutating func remove(indicesIn range: ClosedRange<ElementType>) {
        
    }
}
