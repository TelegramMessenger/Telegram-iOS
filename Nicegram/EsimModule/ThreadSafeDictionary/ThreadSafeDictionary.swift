import Foundation

public class ThreadSafeDictionary<V: Hashable,T>: Collection {

    private var dictionary: [V: T]
    private let concurrentQueue = DispatchQueue(label: "ThreadSafeDictionaryQueue", attributes: .concurrent)
    
    public var startIndex: Dictionary<V, T>.Index {
        self.concurrentQueue.sync {
            return self.dictionary.startIndex
        }
    }

    public var endIndex: Dictionary<V, T>.Index {
        self.concurrentQueue.sync {
            return self.dictionary.endIndex
        }
    }

    public init(dict: [V: T] = [V:T]()) {
        self.dictionary = dict
    }
    
    // swiftlint:disable identifier_name
    public func index(after i: Dictionary<V, T>.Index) -> Dictionary<V, T>.Index {
        self.concurrentQueue.sync {
            return self.dictionary.index(after: i)
        }
    }
    // swiftlint:enable identifier_name

    public subscript(key: V) -> T? {
        set(newValue) {
            self.concurrentQueue.async(flags: .barrier) {[weak self] in
                self?.dictionary[key] = newValue
            }
        }
        get {
            self.concurrentQueue.sync {
                return self.dictionary[key]
            }
        }
    }

    public subscript(index: Dictionary<V, T>.Index) -> Dictionary<V, T>.Element {
        self.concurrentQueue.sync {
            return self.dictionary[index]
        }
    }
    
    public func removeValue(forKey key: V) {
        self.concurrentQueue.async(flags: .barrier) {[weak self] in
            self?.dictionary.removeValue(forKey: key)
        }
    }

    public func removeAll() {
        self.concurrentQueue.async(flags: .barrier) {[weak self] in
            self?.dictionary.removeAll()
        }
    }
}
