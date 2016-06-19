import UIKit
import XCTest
import SwiftSignalKit
import Foundation

final class DisposableLock {
    private var action: (() -> Void)?
    private var lock = pthread_mutex_t()
    
    init(action: () -> Void) {
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
    
    init(action: () -> Void) {
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
    
    init(action: () -> Void) {
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
    
    init(action: () -> Void) {
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
}
