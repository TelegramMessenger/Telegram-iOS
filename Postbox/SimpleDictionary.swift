import Foundation

public struct SimpleDictionary<K: Equatable, V>: SequenceType {
    private var items: [(K, V)] = []
    
    public subscript(key: K) -> V? {
        get {
            for (k, value) in self.items {
                if k == key {
                    return value
                }
            }
            return nil
        } set(value) {
            var index = 0
            for (k, _) in self.items {
                if k == key {
                    if let value = value {
                        self.items[index] = (k, value)
                    } else {
                        self.items.removeAtIndex(index)
                    }
                    return
                }
                index += 1
            }
            if let value = value {
                self.items.append((key, value))
            }
        }
    }
    
    public func generate() -> AnyGenerator<(K, V)> {
        var index = 0
        return AnyGenerator { () -> (K, V)? in
            if index < self.items.count {
                let currentIndex = index
                index += 1
                return self.items[currentIndex]
            }
            return nil
        }
    }
}

