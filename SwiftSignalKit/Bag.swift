import Foundation

public final class Bag<T> {
    public typealias Index = Int
    private var nextIndex: Index = 0
    private var items: [T] = []
    private var itemKeys: [Index] = []
    
    public init() {
    }
    
    public func add(item: T) -> Index {
        let key = self.nextIndex
        self.nextIndex++
        self.items.append(item)
        self.itemKeys.append(key)
        
        return key
    }
    
    public func remove(index: Index) {
        var i = 0
        for key in self.itemKeys {
            if key == index {
                self.items.removeAtIndex(i)
                self.itemKeys.removeAtIndex(i)
                break
            }
            i++
        }
    }
    
    public func copyItems() -> [T] {
        return self.items
    }
}
