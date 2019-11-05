import UIKit
import XCTest
import SwiftSignalKit
import Foundation

/*final class DisposableLock {
    private var action: (() -> Void)?
    private var lock = pthread_mutex_t()
    
    init(action: @escaping () -> Void) {
        self.action = action
        pthread_mutex_init(&self.lock, nil)
    }
    
    func dispose() {
        var action: (() -> Void)?
        pthread_mutex_lock(&self.lock)
        action = self.action
        self.action = nil
        pthread_mutex_unlock(&self.lock)
        if let action = action {
            action()
        }
    }
}

final class DisposableSpinLock {
    private var action: (() -> Void)?
    private var lock = OSSpinLock()
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    func dispose() {
        var action: (() -> Void)?
        OSSpinLockLock(&self.lock)
        action = self.action
        self.action = nil
        OSSpinLockUnlock(&self.lock)
        if let action = action {
            action()
        }
    }
}

final class DisposableNoLock {
    private var action: (() -> Void)?
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    func dispose() {
        var action: (() -> Void)?
        action = self.action
        self.action = nil
        if let action = action {
            action()
        }
    }
}

final class DisposableAtomic {
    private var action: () -> Void
    private var disposed: Int32 = 0
    
    init(action: @escaping () -> Void) {
        self.action = action
    }
    
    func dispose() {
        if OSAtomicCompareAndSwap32(0, 1, &self.disposed) {
            self.action()
        }
    }
}

class PerformanceTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMeasureLock() {
        measure {
            for _ in 0 ..< 1000000 {
                let disposable = DisposableLock(action: {})
                disposable.dispose()
            }
        }
    }
    
    func testMeasureSpinlock() {
        measure {
            for _ in 0 ..< 1000000 {
                let disposable = DisposableSpinLock(action: {})
                disposable.dispose()
            }
        }
    }
    
    func testMeasureAtomic() {
        measure {
            for _ in 0 ..< 1000000 {
                let disposable = DisposableAtomic(action: {})
                disposable.dispose()
            }
        }
    }
    
    func read(_ idxin: Int, _ size: Int, _ tree: inout [Int: Int], _ reads: inout Set<Int>) -> Int {
        var idx = idxin
        var sum = 0
        while idx <= size {
            print("read at \(idx)")
            if let value = tree[idx] {
                sum += value
            }
            reads.insert(idx)
            idx += (idx & -idx)
        }
        return sum
    }
    
    func update(_ idxin: Int, _ val: Int, _ tree: inout [Int: Int], _ updates: inout Set<Int>) {
        var idx = idxin
        while (idx > 0) {
            if let value = tree[idx] {
                tree[idx] = value + val
            } else {
                tree[idx] = val
            }
            //print("write at \(idx)")
            updates.insert(idx)
            idx -= (idx & -idx)
        }
    }
    
    func testTree() {
        let size = 2_000_000
        var dict: [Int: Int] = [:]
        
        var updates = Set<Int>()
        var index = 0
        for _ in 1 ..< 100_000 {
            //update(Int(1 + arc4random_uniform(UInt32(size))), 1, &dict, &updates)
            update(index, 1, &dict, &updates)
            index += Int(1 + arc4random_uniform(100))
        }
        update(size - 1, 1, &dict, &updates)
        print("update ops = \(updates.count), tree = \(dict.count) items")
        
        var reads = Set<Int>()
        let sum = read(1, size, &dict, &reads)
        print("read = \(sum) ops = \(reads.count)")
        
        update(99, -2, &dict, &updates)
        reads.removeAll()
        let sum2 = read(1, size, &dict, &reads)
        print("read2 = \(sum2) ops = \(reads.count)")
    }
}
*/
