//
//  https://github.com/peterprokop/SwiftConcurrentCollections
//  ConcurrentDictionary.swift
//  
//
//  Created by Sergey Akentev on 30.7.2023.
//

import Foundation

/// Thread-safe dictionary wrapper
/// - Important: Note that this is a `class`, i.e. reference (not value) type
public final class ConcurrentDictionary<Key: Hashable, Value> {

    private var container: [Key: Value] = [:]
    private let rwlock = RWLock()

    public var keys: [Key] {
        let result: [Key]
        rwlock.readLock()
        result = Array(container.keys)
        rwlock.unlock()
        return result
    }

    public var values: [Value] {
        let result: [Value]
        rwlock.readLock()
        result = Array(container.values)
        rwlock.unlock()
        return result
    }

    public init() {}

    /// Sets the value for key
    ///
    /// - Parameters:
    ///   - value: The value to set for key
    ///   - key: The key to set value for
    public func set(value: Value, forKey key: Key) {
        rwlock.writeLock()
        _set(value: value, forKey: key)
        rwlock.unlock()
    }

    @discardableResult
    public func remove(_ key: Key) -> Value? {
        let result: Value?
        rwlock.writeLock()
        result = _remove(key)
        rwlock.unlock()
        return result
    }
    
    @discardableResult
    public func removeValue(forKey: Key) -> Value? {
        return self.remove(forKey)
    }

    public func contains(_ key: Key) -> Bool {
        let result: Bool
        rwlock.readLock()
        result = container.index(forKey: key) != nil
        rwlock.unlock()
        return result
    }

    public func value(forKey key: Key) -> Value? {
        let result: Value?
        rwlock.readLock()
        result = container[key]
        rwlock.unlock()
        return result
    }

    public func mutateValue(forKey key: Key, mutation: (Value) -> Value) {
        rwlock.writeLock()
        if let value = container[key] {
            container[key] = mutation(value)
        }
        rwlock.unlock()
    }
    
    public var isEmpty: Bool {
        return self.keys.isEmpty
    }

    // MARK: Subscript
    public subscript(key: Key) -> Value? {
        get {
            return value(forKey: key)
        }
        set {
            rwlock.writeLock()
            defer {
                rwlock.unlock()
            }
            guard let newValue = newValue else {
                _remove(key)
                return
            }
            _set(value: newValue, forKey: key)
        }
    }

    // MARK: Private
    @inline(__always)
    private func _set(value: Value, forKey key: Key) {
        self.container[key] = value
    }

    @inline(__always)
    @discardableResult
    private func _remove(_ key: Key) -> Value? {
        guard let index = container.index(forKey: key) else { return nil }

        let tuple = container.remove(at: index)
        return tuple.value
    }

}
