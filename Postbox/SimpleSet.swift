import Foundation

public struct SimpleSet<T: Equatable> {
    private var items: [T] = []
    
    public init() {
    }
    
    public mutating func insert(item: T) {
        if !self.contains(item) {
            self.items.append(item)
        }
    }
    
    public func contains(item: T) -> Bool {
        for currentItem in self.items {
            if currentItem == item {
                return true
            }
        }
        return false
    }
}