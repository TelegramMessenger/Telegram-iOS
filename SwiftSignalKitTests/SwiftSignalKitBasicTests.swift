import UIKit
import XCTest
import SwiftSignalKit

class SwiftSignalKitTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testActionDisposableDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
            object = nil
            XCTAssertFalse(deallocated, "deallocated != false")
            disposable.dispose()
        }
        
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
    }
    
    func testActionDisposableNotDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
        }
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertFalse(disposed, "disposed != false")
    }
    
    func testMetaDisposableDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
            
            let metaDisposable = MetaDisposable()
            metaDisposable.set(disposable)
            metaDisposable.dispose()
        }
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
    }
    
    func testMetaDisposableDisposedMultipleTimes() {
        var deallocated1 = false
        var disposed1 = false
        var deallocated2 = false
        var disposed2 = false
        if true {
            var object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                object1.debugDescription
                disposed1 = true
            })
            
            var object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                object2.debugDescription
                disposed2 = true
            })
            
            let metaDisposable = MetaDisposable()
            metaDisposable.set(actionDisposable1)
            metaDisposable.set(actionDisposable2)
            metaDisposable.dispose()
        }
        XCTAssertTrue(deallocated1, "deallocated1 != true")
        XCTAssertTrue(disposed1, "disposed1 != true")
        XCTAssertTrue(deallocated2, "deallocated2 != true")
        XCTAssertTrue(disposed2, "disposed2 != true")
    }
    
    func testMetaDisposableNotDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
            
            let metaDisposable = MetaDisposable()
            metaDisposable.set(disposable)
        }
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertFalse(disposed, "disposed != false")
    }
    
    func testDisposableSetSingleDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
            
            let disposableSet = DisposableSet()
            disposableSet.add(disposable)
            disposableSet.dispose()
        }
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
    }
    
    func testDisposableSetMultipleDisposed() {
        var deallocated1 = false
        var disposed1 = false
        var deallocated2 = false
        var disposed2 = false
        if true {
            var object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                object1.debugDescription
                disposed1 = true
            })
            
            var object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                object2.debugDescription
                disposed2 = true
            })
            
            let disposableSet = DisposableSet()
            disposableSet.add(actionDisposable1)
            disposableSet.add(actionDisposable2)
            disposableSet.dispose()
        }
        XCTAssertTrue(deallocated1, "deallocated1 != true")
        XCTAssertTrue(disposed1, "disposed1 != true")
        XCTAssertTrue(deallocated2, "deallocated2 != true")
        XCTAssertTrue(disposed2, "disposed2 != true")
    }
    
    func testDisposableSetSingleNotDisposed() {
        var deallocated = false
        var disposed = false
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                object.debugDescription
                disposed = true
            })
            
            let disposableSet = DisposableSet()
            disposableSet.add(disposable)
        }
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertFalse(disposed, "disposed != false")
    }
    
    func testDisposableSetMultipleNotDisposed() {
        var deallocated1 = false
        var disposed1 = false
        var deallocated2 = false
        var disposed2 = false
        if true {
            var object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                object1.debugDescription
                disposed1 = true
            })
            
            var object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                object2.debugDescription
                disposed2 = true
            })
            
            let disposableSet = DisposableSet()
            disposableSet.add(actionDisposable1)
            disposableSet.add(actionDisposable2)
        }
        XCTAssertTrue(deallocated1, "deallocated1 != true")
        XCTAssertFalse(disposed1, "disposed1 != false")
        XCTAssertTrue(deallocated2, "deallocated2 != true")
        XCTAssertFalse(disposed2, "disposed2 != false")
    }
    
    func testMetaDisposableAlreadyDisposed() {
        var deallocated1 = false
        var disposed1 = false
        var deallocated2 = false
        var disposed2 = false
        if true {
            var object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                object1.debugDescription
                disposed1 = true
            })
            
            var object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                object2.debugDescription
                disposed2 = true
            })
            
            let metaDisposable = MetaDisposable()
            metaDisposable.set(actionDisposable1)
            metaDisposable.dispose()
            metaDisposable.set(actionDisposable2)
        }
        XCTAssertTrue(deallocated1, "deallocated1 != true")
        XCTAssertTrue(disposed1, "disposed1 != true")
        XCTAssertTrue(deallocated2, "deallocated2 != true")
        XCTAssertTrue(disposed2, "disposed2 != true")
    }
    
    func testDisposableSetAlreadyDisposed() {
        var deallocated1 = false
        var disposed1 = false
        var deallocated2 = false
        var disposed2 = false
        if true {
            var object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                object1.debugDescription
                disposed1 = true
            })
            
            var object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                object2.debugDescription
                disposed2 = true
            })
            
            let disposableSet = DisposableSet()
            disposableSet.add(actionDisposable1)
            disposableSet.dispose()
            disposableSet.add(actionDisposable2)
        }
        XCTAssertTrue(deallocated1, "deallocated1 != true")
        XCTAssertTrue(disposed1, "disposed1 != true")
        XCTAssertTrue(deallocated2, "deallocated2 != true")
        XCTAssertTrue(disposed2, "disposed2 != true")
    }
    
    func testSignalQueue1() {
        let queue = SignalQueue<Int, NoError>()
        
        var disposed1 = false
        let queued1 = queue.enqueued(Signal { subscriber in
            subscriber.putNext(1)
            subscriber.putCompletion()
            
            return ActionDisposable {
                disposed1 = true
            }
        })
        
        var disposed2 = false
        let queued2 = queue.enqueued(Signal { subscriber in
            subscriber.putNext(2)
            subscriber.putCompletion()
            
            return ActionDisposable {
                disposed2 = true
            }
        })
        
        var next1Called = false
        var completed1Called = false
        queued1.start(next: { next in
            XCTAssert(!next1Called)
            next1Called = true
            XCTAssert(next == 1)
        }, error: { _ in
            XCTFail()
        }, completed: {
            XCTAssert(!completed1Called)
            completed1Called = true
        })
        
        var next2Called = false
        var completed2Called = false
        queued2.start(next: { next in
            XCTAssert(!next2Called)
            next2Called = true
            XCTAssert(next == 2)
        }, error: { _ in
            XCTFail()
        }, completed: {
            XCTAssert(!completed2Called)
            completed2Called = true
        })

        XCTAssert(next1Called)
        XCTAssert(completed1Called)
        XCTAssert(disposed1)
        
        XCTAssert(next2Called)
        XCTAssert(completed2Called)
        XCTAssert(disposed2)
    }
    
    func testSignalQueue2() {
        let q = Queue()
        let queue = SignalQueue<Int, NoError>()
        
        var disposed1 = false
        let queued1 = queue.enqueued(Signal { subscriber in
            q.after(0.4, {
                subscriber.putNext(1)
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                disposed1 = true
            }
        })
        
        var disposed2 = false
        let queued2 = queue.enqueued(Signal { subscriber in
            q.after(0.2, {
                subscriber.putNext(2)
                subscriber.putCompletion()
            })
            
            return ActionDisposable {
                disposed2 = true
            }
        })
        
        var next1Called = false
        var completed1Called = false
        queued1.start(next: { next in
            XCTAssert(!next1Called)
            next1Called = true
            XCTAssert(next == 1)
        }, error: { _ in
            XCTFail()
        }, completed: {
            XCTAssert(!completed1Called)
            completed1Called = true
        })
        
        var next2Called = false
        var completed2Called = false
        queued2.start(next: { next in
            XCTAssert(next1Called)
            XCTAssert(!next2Called)
            next2Called = true
            XCTAssert(next == 2)
        }, error: { _ in
            XCTFail()
        }, completed: {
            XCTAssert(completed1Called)
            XCTAssert(!completed2Called)
            completed2Called = true
        })
        
        sleep(1)
        
        XCTAssert(next1Called)
        XCTAssert(completed1Called)
        XCTAssert(disposed1)
        
        XCTAssert(next2Called)
        XCTAssert(completed2Called)
        XCTAssert(disposed2)
    }
}
