import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreDisposableTests: XCTestCase {
    func testEmptyDisposableIsSharedAndDisposeIsNoop() {
        XCTAssertTrue(EmptyDisposable === EmptyDisposable)
        EmptyDisposable.dispose()
        EmptyDisposable.dispose()
    }

    func testActionDisposableRunsActionOnce() {
        let counter = CoreCounter()
        let disposable = ActionDisposable {
            counter.increment()
        }
        XCTAssertEqual(counter.value, 0)
        disposable.dispose()
        XCTAssertEqual(counter.value, 1)
        disposable.dispose()
        XCTAssertEqual(counter.value, 1)
    }

    func testActionDisposableRunsActionOnceUnderConcurrentDispose() {
        for _ in 0 ..< 100 {
            let counter = CoreCounter()
            let disposable = ActionDisposable {
                counter.increment()
            }
            DispatchQueue.concurrentPerform(iterations: 32) { _ in
                disposable.dispose()
            }
            XCTAssertEqual(counter.value, 1)
        }
    }

    func testActionDisposableDeinitWithoutDisposeDoesNotRunActionAndReleasesIt() {
        let counter = CoreCounter()
        weak var weakCaptured: CoreObject?
        do {
            let captured = CoreObject()
            weakCaptured = captured
            let disposable = ActionDisposable {
                withExtendedLifetime(captured) {}
                counter.increment()
            }
            withExtendedLifetime(disposable) {}
        }
        XCTAssertNil(weakCaptured)
        XCTAssertEqual(counter.value, 0)
    }

    func testActionDisposableReleasesActionAfterDispose() {
        weak var weakCaptured: CoreObject?
        let disposable: ActionDisposable
        do {
            let captured = CoreObject()
            weakCaptured = captured
            disposable = ActionDisposable {
                withExtendedLifetime(captured) {}
            }
        }
        XCTAssertNotNil(weakCaptured)
        disposable.dispose()
        XCTAssertNil(weakCaptured)
    }

    func testActionDisposableReentrantDisposeFromActionRunsOnce() {
        let counter = CoreCounter()
        var disposable: ActionDisposable?
        disposable = ActionDisposable {
            counter.increment()
            disposable?.dispose()
        }
        disposable?.dispose()
        XCTAssertEqual(counter.value, 1)
        disposable = nil
    }

    func testMetaDisposableSetDisposesPrevious() {
        let log = CoreEventLog()
        let meta = MetaDisposable()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        meta.set(a)
        XCTAssertEqual(log.events, [])
        meta.set(b)
        XCTAssertEqual(log.events, ["a"])
        meta.dispose()
        XCTAssertEqual(log.events, ["a", "b"])
        XCTAssertEqual(a.disposeCount, 1)
        XCTAssertEqual(b.disposeCount, 1)
    }

    func testMetaDisposableSetNilDisposesPrevious() {
        let log = CoreEventLog()
        let meta = MetaDisposable()
        let a = CoreCountingDisposable("a", log: log)
        meta.set(a)
        meta.set(nil)
        XCTAssertEqual(log.events, ["a"])
        meta.set(nil)
        meta.dispose()
        XCTAssertEqual(log.events, ["a"])
    }

    func testMetaDisposableSetSameDisposableTwiceDisposesItAndKeepsItCurrent() {
        let meta = MetaDisposable()
        let a = CoreCountingDisposable()
        meta.set(a)
        meta.set(a)
        XCTAssertEqual(a.disposeCount, 1)
        meta.dispose()
        XCTAssertEqual(a.disposeCount, 2)
    }

    func testMetaDisposableSetAfterDisposeDisposesNewImmediately() {
        let log = CoreEventLog()
        let meta = MetaDisposable()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        meta.set(a)
        meta.dispose()
        XCTAssertEqual(log.events, ["a"])
        meta.set(b)
        XCTAssertEqual(log.events, ["a", "b"])
        meta.set(nil)
        meta.dispose()
        XCTAssertEqual(a.disposeCount, 1)
        XCTAssertEqual(b.disposeCount, 1)
    }

    func testMetaDisposableDisposeTwiceDisposesCurrentOnce() {
        let meta = MetaDisposable()
        let a = CoreCountingDisposable()
        meta.set(a)
        meta.dispose()
        meta.dispose()
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testMetaDisposableDisposeWithoutCurrentThenSetDisposesImmediately() {
        let meta = MetaDisposable()
        meta.dispose()
        let a = CoreCountingDisposable()
        meta.set(a)
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testMetaDisposableDeinitDoesNotDisposeCurrentButReleasesIt() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        do {
            let meta = MetaDisposable()
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            meta.set(inner)
        }
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, [])
    }

    func testMetaDisposableReleasesPreviousAfterSet() {
        weak var weakFirst: CoreCountingDisposable?
        let meta = MetaDisposable()
        do {
            let first = CoreCountingDisposable()
            weakFirst = first
            meta.set(first)
        }
        XCTAssertNotNil(weakFirst)
        meta.set(CoreCountingDisposable())
        XCTAssertNil(weakFirst)
        meta.dispose()
    }

    func testMetaDisposableReentrantSetFromPreviousDispose() {
        let log = CoreEventLog()
        let meta = MetaDisposable()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        let c = CoreCountingDisposable("c", log: log)
        a.onDispose = {
            meta.set(c)
        }
        meta.set(a)
        meta.set(b)
        XCTAssertEqual(log.events, ["a", "b"])
        meta.dispose()
        XCTAssertEqual(log.events, ["a", "b", "c"])
        a.onDispose = nil
    }

    func testMetaDisposableConcurrentDisposeDisposesCurrentOnce() {
        for _ in 0 ..< 50 {
            let meta = MetaDisposable()
            let a = CoreCountingDisposable()
            meta.set(a)
            DispatchQueue.concurrentPerform(iterations: 16) { _ in
                meta.dispose()
            }
            XCTAssertEqual(a.disposeCount, 1)
        }
    }

    func testMetaDisposableConcurrentSetsAndDisposeDisposeEachExactlyOnce() {
        let meta = MetaDisposable()
        let disposables = (0 ..< 300).map { _ in CoreCountingDisposable() }
        DispatchQueue.concurrentPerform(iterations: disposables.count) { index in
            meta.set(disposables[index])
            if index == 150 {
                meta.dispose()
            }
        }
        meta.dispose()
        XCTAssertEqual(disposables.map { $0.disposeCount }, Array(repeating: 1, count: 300))
    }

    func testDisposableSetDisposesAllInInsertionOrderOnce() {
        let log = CoreEventLog()
        let set = DisposableSet()
        set.add(CoreCountingDisposable("a", log: log))
        set.add(CoreCountingDisposable("b", log: log))
        set.add(CoreCountingDisposable("c", log: log))
        XCTAssertEqual(log.events, [])
        set.dispose()
        XCTAssertEqual(log.events, ["a", "b", "c"])
        set.dispose()
        XCTAssertEqual(log.events, ["a", "b", "c"])
    }

    func testDisposableSetAddAfterDisposeDisposesImmediately() {
        let log = CoreEventLog()
        let set = DisposableSet()
        set.dispose()
        let a = CoreCountingDisposable("a", log: log)
        set.add(a)
        XCTAssertEqual(log.events, ["a"])
        set.dispose()
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testDisposableSetRemoveDoesNotDispose() {
        let log = CoreEventLog()
        let set = DisposableSet()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        set.add(a)
        set.add(b)
        set.remove(a)
        XCTAssertEqual(log.events, [])
        set.dispose()
        XCTAssertEqual(log.events, ["b"])
        XCTAssertEqual(a.disposeCount, 0)
    }

    func testDisposableSetRemoveUnknownIsNoop() {
        let log = CoreEventLog()
        let set = DisposableSet()
        let a = CoreCountingDisposable("a", log: log)
        set.add(a)
        set.remove(CoreCountingDisposable("unknown", log: log))
        set.dispose()
        XCTAssertEqual(log.events, ["a"])
    }

    func testDisposableSetRemoveAfterDisposeIsNoop() {
        let set = DisposableSet()
        let a = CoreCountingDisposable()
        set.add(a)
        set.dispose()
        set.remove(a)
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testDisposableSetSameDisposableAddedTwiceIsDisposedTwiceAndRemoveRemovesOneOccurrence() {
        let set = DisposableSet()
        let a = CoreCountingDisposable()
        set.add(a)
        set.add(a)
        set.dispose()
        XCTAssertEqual(a.disposeCount, 2)

        let other = DisposableSet()
        let b = CoreCountingDisposable()
        other.add(b)
        other.add(b)
        other.remove(b)
        other.dispose()
        XCTAssertEqual(b.disposeCount, 1)
    }

    func testDisposableSetRemoveLastOnNonEmptySetRemovesLastAddedWithoutDisposing() {
        let log = CoreEventLog()
        let set = DisposableSet()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        let c = CoreCountingDisposable("c", log: log)
        set.add(a)
        set.add(b)
        set.add(c)
        set.removeLast()
        XCTAssertEqual(log.events, [])
        set.removeLast()
        XCTAssertEqual(log.events, [])
        set.dispose()
        XCTAssertEqual(log.events, ["a"])
        XCTAssertEqual(b.disposeCount, 0)
        XCTAssertEqual(c.disposeCount, 0)
    }

    func testDisposableSetRemoveReleasesRemovedDisposable() {
        let set = DisposableSet()
        var inner: CoreCountingDisposable? = CoreCountingDisposable()
        weak var weakInner: CoreCountingDisposable?
        weakInner = inner
        set.add(inner!)
        inner = nil
        XCTAssertNotNil(weakInner)
        set.remove(weakInner!)
        XCTAssertNil(weakInner)
        set.dispose()
    }

    func testDisposableSetDeinitDoesNotDisposeButReleases() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        do {
            let set = DisposableSet()
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            set.add(inner)
        }
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, [])
    }

    func testDisposableSetConcurrentAddThenDisposeDisposesEachOnce() {
        let set = DisposableSet()
        let disposables = (0 ..< 200).map { _ in CoreCountingDisposable() }
        DispatchQueue.concurrentPerform(iterations: disposables.count) { index in
            set.add(disposables[index])
        }
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            set.dispose()
        }
        XCTAssertEqual(disposables.map { $0.disposeCount }, Array(repeating: 1, count: 200))
    }

    func testDisposableDictSetReplacesAndDisposesPrevious() {
        let log = CoreEventLog()
        let dict = DisposableDict<String>()
        let a = CoreCountingDisposable("a", log: log)
        let b = CoreCountingDisposable("b", log: log)
        let c = CoreCountingDisposable("c", log: log)
        dict.set(a, forKey: "k")
        dict.set(c, forKey: "other")
        XCTAssertEqual(log.events, [])
        dict.set(b, forKey: "k")
        XCTAssertEqual(log.events, ["a"])
        dict.dispose()
        XCTAssertEqual(Set(log.events), Set(["a", "b", "c"]))
        XCTAssertEqual(log.events.count, 3)
        XCTAssertEqual(a.disposeCount, 1)
        XCTAssertEqual(b.disposeCount, 1)
        XCTAssertEqual(c.disposeCount, 1)
    }

    func testDisposableDictSetSameDisposableForSameKeyDisposesItAndKeepsIt() {
        let dict = DisposableDict<Int>()
        let a = CoreCountingDisposable()
        dict.set(a, forKey: 1)
        dict.set(a, forKey: 1)
        XCTAssertEqual(a.disposeCount, 1)
        dict.dispose()
        XCTAssertEqual(a.disposeCount, 2)
    }

    func testDisposableDictSetAfterDisposeDisposesImmediately() {
        let dict = DisposableDict<Int>()
        let a = CoreCountingDisposable()
        let b = CoreCountingDisposable()
        dict.set(a, forKey: 1)
        dict.dispose()
        XCTAssertEqual(a.disposeCount, 1)
        dict.set(b, forKey: 1)
        XCTAssertEqual(b.disposeCount, 1)
        XCTAssertEqual(a.disposeCount, 1)
        dict.set(nil, forKey: 1)
        dict.dispose()
        XCTAssertEqual(a.disposeCount, 1)
        XCTAssertEqual(b.disposeCount, 1)
    }

    func testDisposableDictDisposeTwiceDisposesAllOnce() {
        let dict = DisposableDict<Int>()
        let items = (0 ..< 10).map { _ in CoreCountingDisposable() }
        for (index, item) in items.enumerated() {
            dict.set(item, forKey: index)
        }
        dict.dispose()
        dict.dispose()
        XCTAssertEqual(items.map { $0.disposeCount }, Array(repeating: 1, count: 10))
    }

    func testDisposableDictConcurrentSetsThenDisposeDisposeEachExactlyOnce() {
        let dict = DisposableDict<Int>()
        let first = (0 ..< 200).map { _ in CoreCountingDisposable() }
        let second = (0 ..< 200).map { _ in CoreCountingDisposable() }
        DispatchQueue.concurrentPerform(iterations: first.count) { index in
            dict.set(first[index], forKey: index)
            dict.set(second[index], forKey: index)
        }
        XCTAssertEqual(first.map { $0.disposeCount }, Array(repeating: 1, count: 200))
        XCTAssertEqual(second.map { $0.disposeCount }, Array(repeating: 0, count: 200))
        dict.dispose()
        XCTAssertEqual(second.map { $0.disposeCount }, Array(repeating: 1, count: 200))
    }

    func testDisposableDictSetNilDisposesPreviousImmediately() {
        let dict = DisposableDict<String>()
        let a = CoreCountingDisposable()
        dict.set(a, forKey: "k")
        dict.set(nil, forKey: "k")
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testDisposableDictSetNilForUnknownKeyIsNoop() {
        let dict = DisposableDict<String>()
        let a = CoreCountingDisposable()
        dict.set(a, forKey: "k")
        dict.set(nil, forKey: "missing")
        XCTAssertEqual(a.disposeCount, 0)
        dict.dispose()
        XCTAssertEqual(a.disposeCount, 1)
    }

    func testDisposableDictSetNilThenDisposeDiffersBetweenImplementations() {
        let dict = DisposableDict<String>()
        let a = CoreCountingDisposable()
        dict.set(a, forKey: "k")
        dict.set(nil, forKey: "k")
        XCTAssertEqual(a.disposeCount, 1)
        dict.dispose()
        #if SSK_LEGACY
        XCTAssertEqual(a.disposeCount, 2)
        #else
        XCTAssertEqual(a.disposeCount, 1)
        #endif
    }

    func testDisposableDictSetNilTwiceDiffersBetweenImplementations() {
        let dict = DisposableDict<String>()
        let a = CoreCountingDisposable()
        dict.set(a, forKey: "k")
        dict.set(nil, forKey: "k")
        dict.set(nil, forKey: "k")
        #if SSK_LEGACY
        XCTAssertEqual(a.disposeCount, 2)
        #else
        XCTAssertEqual(a.disposeCount, 1)
        #endif
        dict.dispose()
    }

    func testDisposableDictDeinitDoesNotDisposeButReleases() {
        let log = CoreEventLog()
        weak var weakInner: CoreCountingDisposable?
        do {
            let dict = DisposableDict<Int>()
            let inner = CoreCountingDisposable(log: log)
            weakInner = inner
            dict.set(inner, forKey: 0)
        }
        XCTAssertNil(weakInner)
        XCTAssertEqual(log.events, [])
    }

    func testStrictDisposableForwardsEveryDispose() {
        let inner = CoreCountingDisposable()
        let strict = StrictDisposable(inner, file: #file, line: #line)
        strict.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
        strict.dispose()
        XCTAssertEqual(inner.disposeCount, 2)
    }

    func testStrictExtensionWrapsInStrictDisposable() {
        let inner = CoreCountingDisposable()
        let strict = inner.strict()
        XCTAssertTrue(strict is StrictDisposable)
        XCTAssertFalse(strict === inner)
        XCTAssertEqual(inner.disposeCount, 0)
        strict.dispose()
        XCTAssertEqual(inner.disposeCount, 1)
    }

    func testStrictDisposableRetainsInnerUntilItDeallocates() {
        weak var weakInner: CoreCountingDisposable?
        var strict: Disposable?
        do {
            let inner = CoreCountingDisposable()
            weakInner = inner
            strict = inner.strict()
        }
        XCTAssertNotNil(weakInner)
        strict?.dispose()
        XCTAssertNotNil(weakInner)
        strict = nil
        XCTAssertNil(weakInner)
    }
}
