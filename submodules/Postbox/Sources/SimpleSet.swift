import Foundation

public struct SimpleSet<T: Equatable> {
    private var items: [T] = []
    
    public init() {
    }
    
    public mutating func insert(_ item: T) {
        if !self.contains(item) {
            self.items.append(item)
        }
    }
    
    public func contains(_ item: T) -> Bool {
        for currentItem in self.items {
            if currentItem == item {
                return true
            }
        }
        return false
    }
}
