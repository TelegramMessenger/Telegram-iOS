import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreAtomicLockBagTests: XCTestCase {
    private enum CoreTestError: Error, Equatable {
        case failed(Int)
    }

    func testAtomicWithReadsWithoutModifying() {
        let atomic = Atomic<Int>(value: 5)
        let result = atomic.with { value -> String in
            return "value \(value)"
        }
        XCTAssertEqual(result, "value 5")
        XCTAssertEqual(atomic.with { $0 }, 5)
    }

    func testAtomicModifyStoresAndReturnsNewValue() {
        let atomic = Atomic<Int>(value: 1)
        let result = atomic.modify { $0 + 10 }
        XCTAssertEqual(result, 11)
        XCTAssertEqual(atomic.with { $0 }, 11)
    }

    func testAtomicSwapReturnsPreviousValue() {
        let atomic = Atomic<String>(value: "a")
        XCTAssertEqual(atomic.swap("b"), "a")
        XCTAssertEqual(atomic.swap("c"), "b")
        XCTAssertEqual(atomic.with { $0 }, "c")
    }

    func testAtomicTryWithSucceedsWhenUnlocked() throws {
        let atomic = Atomic<Int>(value: 3)
        let result = try atomic.tryWith { $0 * 2 }
        XCTAssertEqual(result, 6)
    }

    func testAtomicTryWithThrowsIsLockedWhileLockedFromAnotherThread() {
        let atomic = Atomic<Int>(value: 0)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = self.expectation(description: "holder finished")
        DispatchQueue.global().async {
            atomic.with { _ in
                entered.signal()
                _ = release.wait(timeout: .now() + 5.0)
            }
            finished.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 5.0), .success)
        var thrown: Error?
        do {
            _ = try atomic.tryWith { $0 }
        } catch let error {
            thrown = error
        }
        release.signal()
        self.wait(for: [finished], timeout: 5.0)
        if let thrown = thrown as? AtomicLockError {
            XCTAssertEqual(thrown, .isLocked)
        } else {
            XCTFail("expected AtomicLockError.isLocked, got \(String(describing: thrown))")
        }
        XCTAssertEqual(try? atomic.tryWith { $0 }, 0)
    }

    func testAtomicTryWithThrowsIsLockedWhenCalledInsideWithOnSameThread() {
        let atomic = Atomic<Int>(value: 0)
        let thrown = atomic.with { _ -> Bool in
            do {
                _ = try atomic.tryWith { $0 }
                return false
            } catch AtomicLockError.isLocked {
                return true
            } catch {
                return false
            }
        }
        XCTAssertTrue(thrown)
    }

    func testAtomicConcurrentModifyIsSerialized() {
        let atomic = Atomic<Int>(value: 0)
        DispatchQueue.concurrentPerform(iterations: 4000) { _ in
            _ = atomic.modify { $0 + 1 }
        }
        XCTAssertEqual(atomic.with { $0 }, 4000)
    }

    func testAtomicSwapReleasesPreviousValueOnceCallerDropsIt() {
        weak var weakFirst: CoreObject?
        let atomic: Atomic<CoreObject>
        do {
            let first = CoreObject(1)
            weakFirst = first
            atomic = Atomic(value: first)
        }
        XCTAssertNotNil(weakFirst)
        _ = atomic.swap(CoreObject(2))
        XCTAssertNil(weakFirst)
        XCTAssertEqual(atomic.with { $0.value }, 2)
    }

    func testAtomicModifyReleasesPreviousValue() {
        weak var weakFirst: CoreObject?
        let atomic: Atomic<CoreObject>
        do {
            let first = CoreObject(1)
            weakFirst = first
            atomic = Atomic(value: first)
        }
        _ = atomic.modify { _ in CoreObject(2) }
        XCTAssertNil(weakFirst)
    }

    func testAtomicModifyReleasesPreviousValueBeforeReturning() {
        let log = CoreEventLog()
        let atomic = Atomic<CoreDeinitProbe>(value: CoreDeinitProbe {
            log.append("first released")
        })
        let _ = atomic.modify { _ in
            log.append("modify")
            return CoreDeinitProbe {
                log.append("second released")
            }
        }
        log.append("returned")
        XCTAssertEqual(log.events, ["modify", "first released", "returned"])
    }

    func testAtomicSwapHandsPreviousValueToCaller() {
        let log = CoreEventLog()
        let atomic = Atomic<CoreDeinitProbe>(value: CoreDeinitProbe {
            log.append("first released")
        })
        do {
            let previous = atomic.swap(CoreDeinitProbe {
                log.append("second released")
            })
            log.append("swapped")
            withExtendedLifetime(previous) {}
        }
        log.append("scope ended")
        XCTAssertEqual(log.events, ["swapped", "first released", "scope ended"])
    }

    func testLockLockedRunsClosure() {
        let lock = Lock()
        var value = 0
        lock.locked {
            value = 1
        }
        XCTAssertEqual(value, 1)
    }

    func testLockThrowingLockedRethrowsAndUnlocks() {
        let lock = Lock()
        var caught: CoreTestError?
        do {
            try lock.throwingLocked {
                throw CoreTestError.failed(7)
            }
        } catch let error as CoreTestError {
            caught = error
        } catch {
        }
        XCTAssertEqual(caught, .failed(7))
        var ranAfterwards = false
        lock.locked {
            ranAfterwards = true
        }
        XCTAssertTrue(ranAfterwards)
        XCTAssertNoThrow(try lock.throwingLocked {})
    }

    func testLockProvidesMutualExclusion() {
        let lock = Lock()
        var value = 0
        DispatchQueue.concurrentPerform(iterations: 4000) { _ in
            lock.locked {
                value += 1
            }
        }
        XCTAssertEqual(value, 4000)
    }

    func testBagKeysStartAtZeroAndIncrease() {
        let bag = Bag<String>()
        XCTAssertTrue(bag.isEmpty)
        XCTAssertNil(bag.first)
        XCTAssertEqual(bag.add("a"), 0)
        XCTAssertEqual(bag.add("b"), 1)
        XCTAssertEqual(bag.add("c"), 2)
        XCTAssertFalse(bag.isEmpty)
        XCTAssertEqual(bag.copyItems(), ["a", "b", "c"])
    }

    func testBagKeysKeepCountingAfterRemoveAndRemoveAll() {
        let bag = Bag<String>()
        let a = bag.add("a")
        let b = bag.add("b")
        bag.remove(b)
        XCTAssertEqual(bag.add("c"), 2)
        bag.remove(a)
        bag.removeAll()
        XCTAssertTrue(bag.isEmpty)
        XCTAssertEqual(bag.add("d"), 3)
        XCTAssertEqual(bag.copyItems(), ["d"])
    }

    func testBagGet() {
        let bag = Bag<String>()
        let a = bag.add("a")
        let b = bag.add("b")
        XCTAssertEqual(bag.get(a), "a")
        XCTAssertEqual(bag.get(b), "b")
        XCTAssertNil(bag.get(2))
        XCTAssertNil(bag.get(-1))
        bag.remove(a)
        XCTAssertNil(bag.get(a))
        XCTAssertEqual(bag.get(b), "b")
    }

    func testBagRemovePreservesOrderOfRemainingItems() {
        let bag = Bag<Int>()
        let keys = (0 ..< 6).map { bag.add($0 * 10) }
        bag.remove(keys[1])
        bag.remove(keys[4])
        XCTAssertEqual(bag.copyItems(), [0, 20, 30, 50])
        let withIndices = bag.copyItemsWithIndices()
        XCTAssertEqual(withIndices.map { $0.0 }, [0, 2, 3, 5])
        XCTAssertEqual(withIndices.map { $0.1 }, [0, 20, 30, 50])
    }

    func testBagRemovingUnknownOrAlreadyRemovedIndexIsNoop() {
        let bag = Bag<Int>()
        let a = bag.add(1)
        _ = bag.add(2)
        bag.remove(100)
        bag.remove(-5)
        bag.remove(a)
        bag.remove(a)
        XCTAssertEqual(bag.copyItems(), [2])
    }

    func testBagFirstReturnsEarliestRemainingEntry() {
        let bag = Bag<String>()
        let a = bag.add("a")
        _ = bag.add("b")
        XCTAssertEqual(bag.first?.0, 0)
        XCTAssertEqual(bag.first?.1, "a")
        bag.remove(a)
        XCTAssertEqual(bag.first?.0, 1)
        XCTAssertEqual(bag.first?.1, "b")
        bag.removeAll()
        XCTAssertNil(bag.first)
    }

    func testBagCopyItemsIsSnapshot() {
        let bag = Bag<Int>()
        _ = bag.add(1)
        let snapshot = bag.copyItems()
        _ = bag.add(2)
        XCTAssertEqual(snapshot, [1])
        XCTAssertEqual(bag.copyItems(), [1, 2])
    }

    func testBagCopyItemsWithIndicesEmpty() {
        let bag = Bag<Int>()
        XCTAssertTrue(bag.copyItemsWithIndices().isEmpty)
    }

    func testBagManyAddsAndRemovesKeepConsistentMapping() {
        let bag = Bag<Int>()
        var expected: [(Int, Int)] = []
        for i in 0 ..< 200 {
            let key = bag.add(i)
            XCTAssertEqual(key, i)
            expected.append((key, i))
        }
        for key in stride(from: 0, to: 200, by: 3) {
            bag.remove(key)
            expected.removeAll(where: { $0.0 == key })
        }
        let actual = bag.copyItemsWithIndices()
        XCTAssertEqual(actual.map { $0.0 }, expected.map { $0.0 })
        XCTAssertEqual(actual.map { $0.1 }, expected.map { $0.1 })
        for (key, value) in expected {
            XCTAssertEqual(bag.get(key), value)
        }
        XCTAssertEqual(bag.add(-1), 200)
    }

    func testBagRemoveReleasesItem() {
        let bag = Bag<CoreObject>()
        weak var weakItem: CoreObject?
        let key: Int
        do {
            let item = CoreObject()
            weakItem = item
            key = bag.add(item)
        }
        XCTAssertNotNil(weakItem)
        bag.remove(key)
        XCTAssertNil(weakItem)
    }

    func testSparseBagContentsAndKeys() {
        let bag = SparseBag<String>()
        XCTAssertTrue(bag.isEmpty)
        XCTAssertEqual(bag.add("a"), 0)
        XCTAssertEqual(bag.add("b"), 1)
        XCTAssertEqual(bag.add("c"), 2)
        XCTAssertFalse(bag.isEmpty)
        XCTAssertEqual(Set(bag), Set(["a", "b", "c"]))
        XCTAssertEqual(bag.get(1), "b")
        bag.remove(1)
        XCTAssertNil(bag.get(1))
        bag.remove(1)
        bag.remove(42)
        XCTAssertEqual(Set(bag), Set(["a", "c"]))
        XCTAssertEqual(Array(bag).count, 2)
        bag.removeAll()
        XCTAssertTrue(bag.isEmpty)
        XCTAssertEqual(Array(bag).count, 0)
        XCTAssertEqual(bag.add("d"), 3)
        XCTAssertEqual(Array(bag), ["d"])
    }

    func testCounterBagStartsAtOne() {
        let bag = CounterBag()
        XCTAssertTrue(bag.isEmpty)
        let a = bag.add()
        let b = bag.add()
        XCTAssertEqual(a, 1)
        XCTAssertEqual(b, 2)
        XCTAssertFalse(bag.isEmpty)
        bag.remove(a)
        XCTAssertFalse(bag.isEmpty)
        bag.remove(99)
        bag.remove(b)
        XCTAssertTrue(bag.isEmpty)
        XCTAssertEqual(bag.add(), 3)
        bag.remove(3)
        bag.remove(3)
        XCTAssertTrue(bag.isEmpty)
    }

    func testWeakValueTracksObjectLifetime() {
        let reference: Weak<CoreObject>
        do {
            let object = CoreObject(4)
            reference = Weak(object)
            XCTAssertTrue(reference.value === object)
            XCTAssertEqual(reference.value?.value, 4)
        }
        XCTAssertNil(reference.value)
    }

    func testWeakDoesNotRetain() {
        var object: CoreObject? = CoreObject()
        let reference = Weak(object!)
        XCTAssertNotNil(reference.value)
        object = nil
        XCTAssertNil(reference.value)
    }

    func testMulticastPromiseHoldsState() {
        let promise = MulticastPromise<Int>()
        XCTAssertNil(promise.value)
        XCTAssertTrue(promise.subscribers.isEmpty)
        promise.value = 3
        XCTAssertEqual(promise.value, 3)
        var received: [Int] = []
        var key: Int = -1
        promise.lock.locked {
            key = promise.subscribers.add { value in
                received.append(value)
            }
        }
        XCTAssertEqual(key, 0)
        for subscriber in promise.subscribers.copyItems() {
            subscriber(5)
        }
        XCTAssertEqual(received, [5])
        promise.subscribers.remove(key)
        XCTAssertTrue(promise.subscribers.isEmpty)
    }
}
