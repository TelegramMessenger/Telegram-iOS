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
                let _ = object.debugDescription
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
            let object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let _ = ActionDisposable(action: { [object] () -> Void in
                let _ = object.debugDescription
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
            let object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                let _ = object.debugDescription
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
            let object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                let _ = object1.debugDescription
                disposed1 = true
            })
            
            let object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                let _ = object2.debugDescription
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
            let object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                let _ = object.debugDescription
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
            let object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                let _ = object.debugDescription
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
            let object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                let _ = object1.debugDescription
                disposed1 = true
            })
            
            let object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                let _ = object2.debugDescription
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
            let object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let disposable = ActionDisposable(action: { [object] () -> Void in
                let _ = object.debugDescription
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
            let object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                let _ = object1.debugDescription
                disposed1 = true
            })
            
            let object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                let _ = object2.debugDescription
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
            let object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                let _ = object1.debugDescription
                disposed1 = true
            })
            
            let object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                let _ = object2.debugDescription
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
            let object1: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated1)
            let actionDisposable1 = ActionDisposable(action: { [object1] () -> Void in
                let _ = object1.debugDescription
                disposed1 = true
            })
            
            let object2: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated2)
            let actionDisposable2 = ActionDisposable(action: { [object2] () -> Void in
                let _ = object2.debugDescription
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
    
    func testDelayed1() {
        var flag = false
        let signal = Signal<Signal<Void, NoError>, NoError> { subscriber in
            Queue.concurrentDefaultQueue().after(0.1, {
                subscriber.putNext(Signal { susbcriber2 in
                    return ActionDisposable {
                        flag = true
                    }
                })
            })
            
            return EmptyDisposable
        } |> switchToLatest
        
        let disposable = signal.start()
        disposable.dispose()
        
        usleep(1000000 * 20)
        
        XCTAssert(flag == true)
    }
    
    func testSingleDeallocation() {
        do {
            let signal: Signal<(Bool, WrapData?, Int), NoError> = .single((true, WrapData(data: Data(count: 1000)), 123))
            let _ = signal.start()
        }
    }
}

final class WrapData {
    let data: Data?
    
    init(data: Data?) {
        self.data = data
    }
    
    deinit {
        print("deinit")
    }
}
