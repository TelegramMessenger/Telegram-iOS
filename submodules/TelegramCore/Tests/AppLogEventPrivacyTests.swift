import Foundation
import XCTest
import Postbox
import SwiftSignalKit
@testable import TelegramApi
@testable import TelegramCore

final class AppLogEventPrivacyTests: XCTestCase {
    private var postbox: Postbox!
    private var directory: URL!

    override func setUpWithError() throws {
        initializeAccountManagement()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("app-log-tests-" + UUID().uuidString)
        let encryption = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: try XCTUnwrap(.init(data: Data(count: 32))), salt: try XCTUnwrap(.init(data: Data(count: 16))))
        let opened = try value(openPostbox(basePath: directory.path, seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryption, timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970), isMainProcess: true, isTemporary: false, isReadOnly: false, useCopy: false, useCaches: true, removeDatabaseOnError: false)
            |> filter { result in
                if case .upgrading = result { return false }
                return true
            })
        guard case let .postbox(postbox) = opened else {
            throw NSError(domain: "AppLogEventPrivacyTests", code: 1)
        }
        self.postbox = postbox
    }

    override func tearDownWithError() throws {
        if let postbox = postbox {
            let _ = try value(postbox.transaction { _ in })
            let _ = try value(postbox.mediaBox.storageBox.all())
            let _ = try value(postbox.mediaBox.cacheStorageBox.all())
            postbox.mediaBox.dataQueue.sync {}
        }
        postbox = nil
        Postbox.sharedQueue.sync {}
        if let directory = directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private func value<T>(_ signal: Signal<T, NoError>, file: StaticString = #filePath, line: UInt = #line) throws -> T {
        let completed = expectation(description: "signal completed")
        let result = Atomic<T?>(value: nil)
        let disposable = (signal |> take(1)).start(next: { value in
            let _ = result.swap(value)
        }, completed: { completed.fulfill() })
        defer { disposable.dispose() }
        wait(for: [completed], timeout: 15)
        return try XCTUnwrap(result.with { $0 }, file: file, line: line)
    }

    private func entries() throws -> [PeerMergedOperationLogEntry] {
        return try value(postbox.transaction { transaction in
            var result: [PeerMergedOperationLogEntry] = []
            transaction.operationLogEnumerateEntries(peerId: PeerId(0), tag: OperationLogTags.SynchronizeAppLogEvents) { entry in
                if let entry = entry.mergedEntry { result.append(entry) }
                return true
            }
            return result
        })
    }

    private func enqueue(_ context: AppLogEventContext, time: Double = Date().timeIntervalSince1970, data: JSON = .dictionary([:])) {
        _internal_addAppLogEvent(postbox: postbox, time: time, type: "app.foreground", data: data, context: context)
    }

    private func seed(_ operations: [SynchronizeAppLogEventsOperation]) throws {
        let _ = try value(postbox.transaction { transaction in
            for operation in operations {
                transaction.operationLogAddEntry(peerId: PeerId(0), tag: OperationLogTags.SynchronizeAppLogEvents, tagLocalIndex: .automatic, tagMergedIndex: .automatic, contents: operation)
            }
        })
    }

    // Unscoped ("legacy") events are denied on macOS only: iOS keeps them for its network telemetry and split tests
    // (`AppLogEventCollection.allowsLegacyEvents`).
    func testUnscopedLegacyAndTransactionalEnqueueAreDeniedOnlyWithoutLegacyEvents() throws {
        _internal_addAppLogEvent(postbox: postbox, type: "legacy")
        invokeAppLogEventsSynchronization(postbox: postbox)
        let _ = try value(postbox.transaction { transaction in
            _internal_addAppLogEvent(transaction: transaction, time: Date().timeIntervalSince1970, type: "legacy", data: .dictionary([:]))
        })
        if AppLogEventCollection.allowsLegacyEvents {
            // The two events and the flush marker.
            XCTAssertEqual(try entries().count, 3)
        } else {
            XCTAssertTrue(try entries().isEmpty)
        }
    }

    func testScopedEventPreservesOccurrenceTimeAndLocalAuthorization() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        let time = Date().timeIntervalSince1970 - 10
        enqueue(context, time: time)
        let queued = try entries()
        let operation = try XCTUnwrap(queued.first?.contents as? SynchronizeAppLogEventsOperation)
        XCTAssertEqual(operation.collectionId, context.identifier)
        guard case let .add(storedTime, _, peerId, _) = operation.content else { return XCTFail() }
        XCTAssertEqual(storedTime, time)
        XCTAssertEqual(peerId, PeerId(0))
        let copied = try JSONDecoder().decode(SynchronizeAppLogEventsOperation.self, from: JSONEncoder().encode(operation))
        XCTAssertEqual(copied.collectionId, context.identifier)
        withExtendedLifetime(context) {}
    }

    func testOldPersistedEntriesArePurgedWithoutARequestOnlyWithoutLegacyEvents() throws {
        let operation = SynchronizeAppLogEventsOperation(content: .add(time: Date().timeIntervalSince1970, type: "legacy", peerId: nil, data: .dictionary([:])))
        let decoded = try JSONDecoder().decode(SynchronizeAppLogEventsOperation.self, from: JSONEncoder().encode(operation))
        XCTAssertNil(decoded.collectionId)
        try seed([decoded])
        let prepared = try entries()
        var requests = 0
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: prepared, send: { _ in
            requests += 1
            return .complete()
        }))
        // With legacy events allowed the entry is sent, and removed once it is.
        XCTAssertEqual(requests, AppLogEventCollection.allowsLegacyEvents ? 1 : 0)
        XCTAssertTrue(try entries().isEmpty)
    }

    func testRevocationPurgesQueueAndDoesNotEraseNewContextEvents() throws {
        let first = makeAppLogEventContext(postbox: postbox)
        enqueue(first)
        XCTAssertEqual(try entries().count, 1)
        first.invalidate()
        let second = makeAppLogEventContext(postbox: postbox)
        enqueue(second)
        let queued = try entries()
        XCTAssertEqual(queued.count, 1)
        XCTAssertEqual((queued.first?.contents as? SynchronizeAppLogEventsOperation)?.collectionId, second.identifier)
        enqueue(first)
        XCTAssertEqual(try entries().count, 1)
        withExtendedLifetime(second) {}
    }

    func testContextCannotAuthorizeAnotherAccountStore() throws {
        let otherOwner = NSObject()
        let context = AppLogEventCollection.makeContext(owner: otherOwner, purge: {})
        enqueue(context)
        XCTAssertTrue(try entries().isEmpty)
        XCTAssertFalse(AppLogEventCollection.allows(owner: postbox, identifier: context.identifier))
    }

    func testRevocationBeforePostboxTransactionPreventsPersistence() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let blocker = postbox.transaction { _ in
            entered.signal()
            XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
        }.start()
        defer { blocker.dispose() }
        XCTAssertEqual(entered.wait(timeout: .now() + 10), .success)
        enqueue(context)
        context.invalidate()
        release.signal()
        XCTAssertTrue(try entries().isEmpty)
    }

    func testPreparedBatchRechecksAuthorizationAtSubscription() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        var requests = 0
        let batch = synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), send: { _ in
            requests += 1
            return .complete()
        })
        context.invalidate()
        let replacement = makeAppLogEventContext(postbox: postbox)
        let _ = try value(batch)
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(try entries().isEmpty)
        withExtendedLifetime(replacement) {}
    }

    func testValidBatchHasZeroPeerAndNoLocalAuthorizationOnWire() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        let time = Date().timeIntervalSince1970
        enqueue(context, time: time)
        var captured: [Api.InputAppEvent] = []
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), send: { events in
            captured = events
            return .complete()
        }))
        XCTAssertEqual(captured.count, 1)
        if case let .inputAppEvent(event)? = captured.first {
            XCTAssertEqual(event.time, time)
            XCTAssertEqual(event.peer, 0)
            XCTAssertFalse(String(describing: event.data).contains(context.identifier))
        } else {
            XCTFail()
        }
        XCTAssertTrue(try entries().isEmpty)
        withExtendedLifetime(context) {}
    }

    func testRevocationCancelsPendingRequestAndFinishesBatch() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        let started = expectation(description: "request started")
        let cancelled = expectation(description: "request cancelled")
        let finished = expectation(description: "batch finished")
        let batch = synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), send: { _ in
            Signal { _ in
                started.fulfill()
                return ActionDisposable { cancelled.fulfill() }
            }
        }).start(completed: { finished.fulfill() })
        defer { batch.dispose() }
        wait(for: [started], timeout: 5)
        context.invalidate()
        wait(for: [cancelled, finished], timeout: 5)
        XCTAssertTrue(try entries().isEmpty)
    }

    func testRevocationFromRequestFactoryPreventsRequestStart() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        var started = false
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), send: { _ in
            context.invalidate()
            return Signal { subscriber in
                started = true
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }))
        XCTAssertFalse(started)
    }

    func testStalledRequestTimesOutAndCannotRetainTheBatch() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        let cancelled = expectation(description: "stalled request cancelled")
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), requestTimeout: 0.02, send: { _ in
            Signal { _ in
                ActionDisposable { cancelled.fulfill() }
            }
        }))
        wait(for: [cancelled], timeout: 3)
        XCTAssertTrue(try entries().isEmpty)
        withExtendedLifetime(context) {}
    }

    func testEventSizeAndTimestampBoundsRejectInvalidEvents() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context, time: .nan)
        enqueue(context, time: .infinity)
        enqueue(context, time: Date().timeIntervalSince1970 - AppLogEventLimits.lifetime - 1)
        enqueue(context, time: Date().timeIntervalSince1970 + AppLogEventLimits.futureTolerance + 100)
        enqueue(context, data: .dictionary(["large": .string(String(repeating: "a", count: AppLogEventLimits.eventBytes))]))
        XCTAssertTrue(try entries().isEmpty)
        enqueue(context)
        XCTAssertEqual(try entries().count, 1)
        withExtendedLifetime(context) {}
    }

    func testPreparedBatchExpiresBeforeSubscription() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        var now = Date().timeIntervalSince1970
        enqueue(context, time: now)
        var requests = 0
        let batch = synchronizeAppLogEventsBatch(postbox: postbox, entries: try entries(), clock: { now }, send: { _ in
            requests += 1
            return .complete()
        })
        now += AppLogEventLimits.lifetime + 1
        let _ = try value(batch)
        XCTAssertEqual(requests, 0)
        XCTAssertTrue(try entries().isEmpty)
        withExtendedLifetime(context) {}
    }

    func testQueueCountBoundDropsOldestAndKeepsNewest() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        let now = Date().timeIntervalSince1970
        try seed((0 ..< AppLogEventLimits.queueCount + 10).map { index in
            SynchronizeAppLogEventsOperation(content: .add(time: now, type: "app.foreground", peerId: nil, data: .dictionary(["index": .number(Double(index))])), collectionId: context.identifier)
        })
        enqueue(context, data: .dictionary(["newest": .bool(true)]))
        let queued = try entries()
        XCTAssertEqual(queued.count, AppLogEventLimits.queueCount)
        let last = try XCTUnwrap(queued.last?.contents as? SynchronizeAppLogEventsOperation)
        guard case let .add(_, _, _, data) = last.content else { return XCTFail() }
        XCTAssertEqual(data, .dictionary(["newest": .bool(true)]))
        withExtendedLifetime(context) {}
    }

    func testQueueByteBoundAndBatchByteLimit() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        let data = JSON.dictionary(["large": .string(String(repeating: "a", count: 15000))])
        let operation = SynchronizeAppLogEventsOperation(content: .add(time: Date().timeIntervalSince1970, type: "app.foreground", peerId: nil, data: data), collectionId: context.identifier)
        try seed(Array(repeating: operation, count: 100))
        enqueue(context, data: data)
        let queued = try entries()
        let sizes = queued.compactMap { ($0.contents as? SynchronizeAppLogEventsOperation).flatMap(appLogEventSize) }
        XCTAssertLessThanOrEqual(sizes.reduce(0, +), AppLogEventLimits.queueBytes)
        var count = 0
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: queued, send: { events in
            count = events.count
            return .complete()
        }))
        XCTAssertGreaterThan(count, 0)
        XCTAssertLessThan(count, queued.count)
        XCTAssertLessThanOrEqual(sizes.prefix(count).reduce(0, +), 256 * 1024)
        XCTAssertEqual(try entries().count, queued.count - count)
        withExtendedLifetime(context) {}
    }

    func testBatchCountLimitAndFlushMarkerCoalescing() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        for _ in 0 ..< 60 { enqueue(context) }
        invokeAppLogEventsSynchronization(postbox: postbox)
        invokeAppLogEventsSynchronization(postbox: postbox)
        let queued = try entries()
        XCTAssertEqual(queued.count, 61)
        var count = 0
        let _ = try value(synchronizeAppLogEventsBatch(postbox: postbox, entries: queued, send: { events in
            count = events.count
            return .complete()
        }))
        XCTAssertEqual(count, 50)
        XCTAssertEqual(try entries().count, 11)
        withExtendedLifetime(context) {}
    }

    func testContextDestructionPurgesPendingEvents() throws {
        var context: AppLogEventContext? = makeAppLogEventContext(postbox: postbox)
        enqueue(try XCTUnwrap(context))
        XCTAssertEqual(try entries().count, 1)
        context = nil
        XCTAssertTrue(try entries().isEmpty)
    }

    func testFlushMarkerWakesAnAlreadyWaitingBatch() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        let updates = Promise(try entries())
        var emitted = false
        let subscription = readyAppLogEventsBatch(updates.get(), batchDelay: 60).start(next: { _ in emitted = true })
        defer { subscription.dispose() }
        XCTAssertFalse(emitted)
        invokeAppLogEventsSynchronization(postbox: postbox)
        updates.set(.single(try entries()))
        XCTAssertTrue(emitted)
        withExtendedLifetime(context) {}
    }

    func testNewEventPreservesPendingFlush() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        invokeAppLogEventsSynchronization(postbox: postbox)
        enqueue(context)
        let queued = try entries()
        XCTAssertEqual(queued.count, 3)
        var emitted = false
        let subscription = readyAppLogEventsBatch(.single(queued), batchDelay: 60).start(next: { _ in emitted = true })
        defer { subscription.dispose() }
        XCTAssertTrue(emitted)
        withExtendedLifetime(context) {}
    }

    func testNewArrivalsDoNotRestartTheBatchDeadline() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        let updates = Promise(try entries())
        var now: TimeInterval = 0
        var emitted = false
        let subscription = readyAppLogEventsBatch(updates.get(), batchDelay: 60, clock: { now }).start(next: { _ in emitted = true })
        defer { subscription.dispose() }
        XCTAssertFalse(emitted)
        now = 61
        enqueue(context)
        updates.set(.single(try entries()))
        XCTAssertTrue(emitted)
        withExtendedLifetime(context) {}
    }

    func testEmptyQueueResetsTheBatchDeadline() throws {
        let context = makeAppLogEventContext(postbox: postbox)
        enqueue(context)
        let snapshot = try entries()
        let updates = Promise(snapshot)
        var now: TimeInterval = 0
        var emitted = false
        let subscription = readyAppLogEventsBatch(updates.get(), batchDelay: 60, clock: { now }).start(next: { _ in emitted = true })
        defer { subscription.dispose() }
        updates.set(.single([]))
        now = 61
        updates.set(.single(snapshot))
        XCTAssertFalse(emitted)
        invokeAppLogEventsSynchronization(postbox: postbox)
        updates.set(.single(try entries()))
        XCTAssertTrue(emitted)
        withExtendedLifetime(context) {}
    }
}
