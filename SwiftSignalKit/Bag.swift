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
        self.nextIndex += 1
        self.items.append(item)
        self.itemKeys.append(key)
        
        return key
    }
    
    public func get(index: Index) -> T? {
        var i = 0
        for key in self.itemKeys {
            if key == index {
                return self.items[i]
            }
            i += 1
        }
        return nil
    }
    
    public func remove(index: Index) {
        var i = 0
        for key in self.itemKeys {
            if key == index {
                self.items.removeAtIndex(i)
                self.itemKeys.removeAtIndex(i)
                break
            }
            i += 1
        }
    }
    
    public func removeAll() {
        self.items.removeAll()
        self.itemKeys.removeAll()
    }
    
    public func copyItems() -> [T] {
        return self.items
    }
    
    public var isEmpty: Bool {
        return self.items.isEmpty
    }
    
    public var first: (Index, T)? {
        if !self.items.isEmpty {
            return (self.itemKeys[0], self.items[0])
        } else {
            return nil
        }
    }
}
