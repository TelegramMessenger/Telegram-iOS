import UIKit
import XCTest
import SwiftSignalKit

func singleSignalInt(value: Signal<Int, Void>) -> Signal<Signal<Int, Void>, Void> {
    return Signal { subscriber in
        subscriber.putNext(value)
        subscriber.putCompletion()
        return EmptyDisposable
    }
}

class SwiftSignalKitFunctionsTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testSignalGenerated() {
        var deallocated = false
        var disposed = false
        var generated = false
        
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let signal = Signal<Int, Void> { [object] subscriber in
                subscriber.putNext(1)
                return ActionDisposable {
                    object?.description
                    disposed = true
                }
            }
            
            let disposable = signal.start(next: { [object] next in
                generated = true
                object?.description
            })
            
            object = nil
            
            XCTAssertFalse(deallocated, "deallocated != false")
            
            disposable.dispose()
        }
        
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
        XCTAssertTrue(generated, "generated != true")
    }
    
    func testSignalGeneratedCompleted() {
        var deallocated = false
        var disposed = false
        var generated = false
        var completed = false
        
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let signal = Signal<Int, Void> { [object] subscriber in
                subscriber.putNext(1)
                subscriber.putCompletion()
                
                return ActionDisposable {
                    object?.description
                    disposed = true
                }
            }
            
            let disposable = signal.start(next: { [object] next in
                generated = true
                object?.description
            }, completed: { [object]
                completed = true
                object?.description
            })
            
            object = nil
            
            XCTAssertFalse(deallocated, "deallocated != false")
            
            disposable.dispose()
        }
        
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
        XCTAssertTrue(generated, "generated != true")
        XCTAssertTrue(completed, "completed != true")
    }
    
    func testSignalGeneratedError() {
        var deallocated = false
        var disposed = false
        var generated = false
        var completed = false
        var error = false
        
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            let signal = Signal<Int, Void> { [object] subscriber in
                subscriber.putError()
                subscriber.putNext(1)
                
                return ActionDisposable {
                    object?.description
                    disposed = true
                }
            }
            
            let disposable = signal.start(next: { [object] next in
                generated = true
                object?.description
            }, error: { [object] _ in
                error = true
                object?.description
            },
             completed: { [object]
                completed = true
                object?.description
            })
            
            object = nil
            
            XCTAssertFalse(deallocated, "deallocated != false")
            
            disposable.dispose()
        }
        
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
        XCTAssertFalse(generated, "generated != false")
        XCTAssertFalse(completed, "completed != false")
        XCTAssertTrue(error, "error != true")
    }
    
    func testMap() {
        var deallocated = false
        var disposed = false
        var generated = false
        
        if true {
            var object: DeallocatingObject? = DeallocatingObject(deallocated: &deallocated)
            var signal = Signal<Int, Void> { [object] subscriber in
                subscriber.putNext(1)
                
                return ActionDisposable {
                    object?.description
                    disposed = true
                }
            }
            signal = signal |> map { $0 * 2}
            
            let disposable = signal.start(next: { [object] next in
                generated = next == 2
                object?.description
            })
            
            object = nil
            
            XCTAssertFalse(deallocated, "deallocated != false")
            
            disposable.dispose()
        }
        
        XCTAssertTrue(deallocated, "deallocated != true")
        XCTAssertTrue(disposed, "disposed != true")
        XCTAssertTrue(generated, "generated != true")
    }
    
    func testCatch() {
        let failingSignal = Signal<Int, Int> { subscriber in
            subscriber.putNext(1)
            subscriber.putError(1)
            return EmptyDisposable
        }
        
        let catchSignal = failingSignal |> `catch` { error in
            return Signal<Int, Int> { subscriber in
                subscriber.putNext(error * 2)
                return EmptyDisposable
            }
        }
        
        var result = 0
        catchSignal.start(next: { next in
            result += next
        })
        
        XCTAssertTrue(result == 3, "result != 2")
    }
    
    func testSubscriberDisposal() {
        var disposed = false
        var generated = false
        var queue = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL);
        
        if true {
            let signal = Signal<Int, Void> { subscriber in
                dispatch_async(queue, {
                    usleep(200)
                    subscriber.putNext(1)
                })
                return ActionDisposable {
                    disposed = true
                }
            }
            
            let disposable = signal.start(next: { next in
                generated = true
            })
            disposable.dispose()
            
            dispatch_barrier_sync(queue, {})
            
            XCTAssertTrue(disposed, "disposed != true")
            XCTAssertFalse(generated, "generated != false")
        }
    }
    
    func testThen() {
        var generatedFirst = false
        var disposedFirst = false
        var generatedSecond = false
        var disposedSecond = false
        var result = 0
        
        var signal = Signal<Int, Void> { subscriber in
            generatedFirst = true
            subscriber.putNext(1)
            subscriber.putCompletion()
            return ActionDisposable {
                disposedFirst = true
            }
        }
        
        signal = signal |> then (Signal<Int, Void> { subscriber in
            generatedSecond = true
            subscriber.putNext(2)
            subscriber.putCompletion()
            return ActionDisposable {
                disposedSecond = true
            }
        })
        
        signal.start(next: { next in
            result += next
        })
        
        XCTAssertTrue(generatedFirst, "generatedFirst != true");
        XCTAssertTrue(disposedFirst, "disposedFirst != true");
        XCTAssertTrue(generatedSecond, "generatedSecond !+ true");
        XCTAssertTrue(disposedSecond, "disposedSecond != true");
        XCTAssertTrue(result == 3, "result != 3");
    }
    
    func testCombineLatest2() {
        let s1 = Signal<Int, Void> { subscriber in
            subscriber.putNext(1)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let s2 = Signal<Int, Void> { subscriber in
            subscriber.putNext(2)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let signal = combineLatest(s1, s2)
        
        var completed = false
        signal.start(next: { next in
            XCTAssert(next.0 == 1 && next.1 == 2, "next != (1, 2)")
            return
        }, completed: {
            completed = true
        })
        XCTAssert(completed == true, "completed != true")
    }
    
    func testCombineLatest3() {
        let s1 = Signal<Int, Void> { subscriber in
            subscriber.putNext(1)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let s2 = Signal<Int, Void> { subscriber in
            subscriber.putNext(2)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let s3 = Signal<Int, Void> { subscriber in
            subscriber.putNext(3)
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let signal = combineLatest(s1, s2, s3)
        
        var completed = false
        signal.start(next: { next in
            XCTAssert(next.0 == 1 && next.1 == 2 && next.2 == 3, "next != (1, 2, 3)")
            return
        }, completed: {
                completed = true
        })
        XCTAssert(completed == true, "completed != true")
    }
    
    func testSingle() {
        let s1 = single(1, Void.self)
        let s2 = fail(Int.self, Void())
        let s3 = complete(Int.self, Void.self)
        
        var singleEmitted = false
        s1.start(next: { next in
            singleEmitted = next == 1
        })
        XCTAssert(singleEmitted == true, "singleEmitted != true")
        
        var errorEmitted = false
        s2.start(error: { error in
            errorEmitted = true
        })
        XCTAssert(errorEmitted == true, "errorEmitted != true")
        
        var completedEmitted = false
        s3.start(completed: {
            completedEmitted = true
        })
        XCTAssert(completedEmitted == true, "errorEmitted != true")
    }
    
    func testSwitchToLatest() {
        var result: [Int] = []
        var disposedOne = false
        var disposedTwo = false
        var disposedThree = false
        var completedAll = false
        
        var deallocatedOne = false
        var deallocatedTwo = false
        var deallocatedThree = false
        
        if true {
            var objectOne: DeallocatingObject? = DeallocatingObject(deallocated: &deallocatedOne)
            var objectTwo: DeallocatingObject? = DeallocatingObject(deallocated: &deallocatedTwo)
            var objectThree: DeallocatingObject? = DeallocatingObject(deallocated: &deallocatedThree)
            
            let one = Signal<Int, Void> { subscriber in
                subscriber.putNext(1)
                subscriber.putCompletion()
                return ActionDisposable { [objectOne] in
                    objectOne?.description
                    disposedOne = true
                }
            }
            
            let two = Signal<Int, Void> { subscriber in
                subscriber.putNext(2)
                subscriber.putCompletion()
                return ActionDisposable { [objectTwo] in
                    objectTwo?.description
                    disposedTwo = true
                }
            }
            
            let three = Signal<Int, Void> { subscriber in
                subscriber.putNext(3)
                subscriber.putCompletion()
                return ActionDisposable { [objectThree] in
                    objectThree?.description
                    disposedThree = true
                }
            }
            
            let signal = singleSignalInt(one) |> then(singleSignalInt(two)) |> then(singleSignalInt(three)) |> switchToLatest
            
            signal.start(next: { next in
                result.append(next)
            }, completed: {
                completedAll = true
            })
        }
        
        XCTAssert(result.count == 3 && result[0] == 1 && result[1] == 2 && result[2] == 3, "result != [1, 2, 3]");
        XCTAssert(disposedOne == true, "disposedOne != true");
        XCTAssert(disposedTwo == true, "disposedTwo != true");
        XCTAssert(disposedThree == true, "disposedThree != true");
        XCTAssert(deallocatedOne == true, "deallocatedOne != true");
        XCTAssert(deallocatedTwo == true, "deallocatedTwo != true");
        XCTAssert(deallocatedThree == true, "deallocatedThree != true");
        XCTAssert(completedAll == true, "completedAll != true");
    }
    
    func testSwitchToLatestError() {
        var errorGenerated = false
        
        let one = Signal<Int, Void> { subscriber in
            subscriber.putError(Void())
            return EmptyDisposable
        }
        
        let signal = singleSignalInt(one) |> switchToLatest
        
        signal.start(error: { error in
            errorGenerated = true
        })
        
        XCTAssert(errorGenerated == true, "errorGenerated != true")
    }
    
    func testQueue() {
        let q = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
        
        var disposedOne = false
        var disposedTwo = false
        var disposedThree = false
        var completedAll = false
        var result: [Int] = []
        
        let one = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(1)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposedOne = true
            }
        }
        
        let two = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(2)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposedTwo = true
            }
        }
        
        let three = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(3)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposedThree = true
            }
        }
        
        let signal = singleSignalInt(one) |> then(singleSignalInt(two)) |> then(singleSignalInt(three)) |> queue
        
        signal.start(next: { next in
            print("next: \(next)")
            result.append(next)
        }, completed: {
            completedAll = true
        })
        
        usleep(1000 * 200)
        
        XCTAssert(result.count == 3 && result[0] == 1 && result[1] == 2 && result[2] == 3, "result != [1, 2, 3]");
        XCTAssert(disposedOne == true, "disposedOne != true");
        XCTAssert(disposedTwo == true, "disposedTwo != true");
        XCTAssert(disposedThree == true, "disposedThree != true");
        XCTAssert(completedAll == true, "completedAll != true");
    }
    
    func testQueueInterrupted() {
        let q = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
        
        var disposedOne = false
        var disposedTwo = false
        var disposedThree = false
        var startedThird = false
        var completedAll = false
        var result: [Int] = []
        
        let one = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(1)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposedOne = true
            }
        }
        
        let two = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(2)
                subscriber.putError(Void())
            })
            return ActionDisposable {
                disposedTwo = true
            }
        }
        
        let three = Signal<Int, Void> { subscriber in
            startedThird = true
            dispatch_async(q, {
                subscriber.putNext(3)
                subscriber.putCompletion()
            })
            return ActionDisposable {
                disposedThree = true
            }
        }
        
        let signal = singleSignalInt(one) |> then(singleSignalInt(two)) |> then(singleSignalInt(three)) |> queue
        
        signal.start(next: { next in
            result.append(next)
        }, completed: {
            completedAll = true
        })
        
        usleep(1000 * 200)
        
        XCTAssert(result.count == 2 && result[0] == 1 && result[1] == 2, "result != [1, 2]");
        XCTAssert(disposedOne == true, "disposedOne != true");
        XCTAssert(disposedTwo == true, "disposedTwo != true");
        XCTAssert(disposedThree == false, "disposedThree != false");
        XCTAssert(startedThird == false, "startedThird != false");
        XCTAssert(completedAll == false, "completedAll != false");
    }
    
    func testQueueDisposed() {
        let q = dispatch_queue_create(nil, DISPATCH_QUEUE_SERIAL)
        
        var disposedOne = false
        var disposedTwo = false
        var disposedThree = false
        var startedFirst = false
        var startedSecond = false
        var startedThird = false
        var result: [Int] = []
        
        let one = Signal<Int, Void> { subscriber in
            startedFirst = true
            var cancelled = false
            dispatch_async(q, {
                if !cancelled {
                    usleep(100 * 1000)
                    subscriber.putNext(1)
                    subscriber.putCompletion()
                }
            })
            return ActionDisposable {
                cancelled = true
                disposedOne = true
            }
        }
        
        let two = Signal<Int, Void> { subscriber in
            startedSecond = true
            var cancelled = false
            dispatch_async(q, {
                if !cancelled {
                    usleep(100 * 1000)
                    subscriber.putNext(2)
                    subscriber.putError(Void())
                }
            })
            return ActionDisposable {
                cancelled = true
                disposedTwo = true
            }
        }
        
        let three = Signal<Int, Void> { subscriber in
            startedThird = true
            var cancelled = false
            dispatch_async(q, {
                if !cancelled {
                    usleep(100 * 1000)
                    subscriber.putNext(3)
                    subscriber.putCompletion()
                }
            })
            return ActionDisposable {
                cancelled = true
                disposedThree = true
            }
        }
        
        let signal = singleSignalInt(one) |> then(singleSignalInt(two)) |> then(singleSignalInt(three)) |> queue
        
        signal.start(next: { next in
            result.append(next)
        }).dispose()
        
        usleep(1000 * 200)
        
        XCTAssert(result.count == 0, "result != []");
        XCTAssert(disposedOne == true, "disposedOne != true");
        XCTAssert(disposedTwo == false, "disposedTwo != false");
        XCTAssert(disposedThree == false, "disposedThree != false");
        XCTAssert(startedFirst == true, "startedFirst != false");
        XCTAssert(startedSecond == false, "startedSecond != false");
        XCTAssert(startedThird == false, "startedThird != false");
    }
    
    func testRestart() {
        let q = dispatch_queue_create(nil, DISPATCH_QUEUE_CONCURRENT)
        let signal = Signal<Int, Void> { subscriber in
            dispatch_async(q, {
                subscriber.putNext(1)
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
        
        var result = 0
        
        (signal |> restart |> take(3)).start(next: { next in
            result += next
        })
        
        usleep(100 * 1000)
        
        XCTAssert(result == 3, "result != 3")
    }
    
    func testPipe() {
        let pipe = Pipe<Int>()
        
        var result1 = 0
        let disposable1 = pipe.signal().start(next: { next in
            result1 += next
        })
        
        var result2 = 0
        let disposable2 = pipe.signal().start(next: { next in
            result2 += next
        })
        
        pipe.putNext(1)
        
        XCTAssert(result1 == 1, "result1 != 1")
        XCTAssert(result2 == 1, "result2 != 1")
        
        disposable1.dispose()
        
        pipe.putNext(1)
        
        XCTAssert(result1 == 1, "result1 != 1")
        XCTAssert(result2 == 2, "result2 != 2")
        
        disposable2.dispose()
        
        pipe.putNext(1)
        
        XCTAssert(result1 == 1, "result1 != 1")
        XCTAssert(result2 == 2, "result2 != 2")
    }
    
    func testQueueRecursive() {
        let q = Queue()
        
        let signal = Signal<Int, NoError> { subscriber in
            for _ in 0 ..< 1000 {
                subscriber.putNext(1)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let queued = signal
            |> mapToQueue { _ -> Signal<Void, NoError> in
                return complete(Void.self, NoError.self) |> deliverOn(q)
            }
        
        queued.start()
    }
    
    func testReduceSignal() {
        let q = Queue()
        
        let signal = Signal<Int, NoError> { subscriber in
            for i in 0 ..< 1000 {
                subscriber.putNext(i)
            }
            subscriber.putCompletion()
            return EmptyDisposable
        }
        
        let reduced = signal
            |> reduceLeft(0, generator: { current, next -> Signal<(Int, Passthrough<Int>), NoError> in
                return Signal { subscriber in
                    subscriber.putNext((current + next, Passthrough.Some(current + next)))
                    subscriber.putCompletion()
                    return EmptyDisposable
                } |> deliverOn(q)
            })
        
        var values: [Int] = []
        reduced.start(next: { next in
            values.append(next)
        })
        
        q.sync { }
        
        XCTAssert(values.count == 1001, "count \(values.count) != 1001")
        var previous = 0
        for i in 0 ..< 1001 {
            let value: Int
            if i >= 1000 {
                value = previous
            } else {
                value = previous + i
                previous = value
            }
            previous = value
            XCTAssert(values[i] == value, "at \(i): \(values[i]) != \(value)")
        }
    }
}
