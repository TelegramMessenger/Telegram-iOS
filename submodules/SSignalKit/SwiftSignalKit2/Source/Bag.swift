import Foundation

public final class Weak<T: AnyObject> {
    private weak var _value: T?

    public var value: T? {
        return self._value
    }

    public init(_ value: T) {
        self._value = value
    }
}

public final class Bag<T> {
    public typealias Index = Int
    @usableFromInline
    var nextIndex: Index = 0
    @usableFromInline
    var items: [T] = []
    @usableFromInline
    var itemKeys: [Index] = []
    
    public init() {
    }
    
    @inlinable
    func position(of index: Index) -> Int? {
        var lower = 0
        var upper = self.itemKeys.count
        while lower < upper {
            let middle = (lower + upper) >> 1
            let key = self.itemKeys[middle]
            if key == index {
                return middle
            } else if key < index {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return nil
    }
    
    @inlinable
    public func add(_ item: T) -> Index {
        let key = self.nextIndex
        self.nextIndex += 1
        self.items.append(item)
        self.itemKeys.append(key)
        
        return key
    }
    
    @inlinable
    public func get(_ index: Index) -> T? {
        if let position = self.position(of: index) {
            return self.items[position]
        }
        return nil
    }
    
    @inlinable
    public func remove(_ index: Index) {
        if let position = self.position(of: index) {
            self.items.remove(at: position)
            self.itemKeys.remove(at: position)
        }
    }
    
    @inlinable
    public func removeAll() {
        self.items.removeAll()
        self.itemKeys.removeAll()
    }
    
    @inlinable
    public func copyItems() -> [T] {
        return self.items
    }
    
    @inlinable
    public func copyItemsWithIndices() -> [(Index, T)] {
        var result: [(Index, T)] = []
        result.reserveCapacity(self.items.count)
        var i = 0
        for key in self.itemKeys {
            result.append((key, self.items[i]))
            i += 1
        }
        return result
    }
    
    @inlinable
    public var isEmpty: Bool {
        return self.items.isEmpty
    }
    
    @inlinable
    public var first: (Index, T)? {
        if !self.items.isEmpty {
            return (self.itemKeys[0], self.items[0])
        } else {
            return nil
        }
    }
}

public final class SparseBag<T>: Sequence {
    public typealias Index = Int
    private var nextIndex: Index = 0
    private var items: [Index: T] = [:]

    public init() {
    }

    public func add(_ item: T) -> Index {
        let key = self.nextIndex
        self.nextIndex += 1
        self.items[key] = item

        return key
    }

    public func get(_ index: Index) -> T? {
        return self.items[index]
    }

    public func remove(_ index: Index) {
        self.items.removeValue(forKey: index)
    }

    public func removeAll() {
        self.items.removeAll()
    }

    public var isEmpty: Bool {
        return self.items.isEmpty
    }

    public func makeIterator() -> AnyIterator<T> {
        var iterator = self.items.makeIterator()
        return AnyIterator { () -> T? in
            return iterator.next()?.value
        }
    }
}

public final class CounterBag {
    private var nextIndex: Int = 1
    private var items = Set<Int>()
    
    public init() {
    }
    
    public func add() -> Int {
        let index = self.nextIndex
        self.nextIndex += 1
        self.items.insert(index)
        return index
    }
    
    public func remove(_ index: Int) {
        self.items.remove(index)
    }
    
    public var isEmpty: Bool {
        return self.items.isEmpty
    }
}
