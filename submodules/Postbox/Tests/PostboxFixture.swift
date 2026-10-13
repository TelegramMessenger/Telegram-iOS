import Foundation
import XCTest
import SwiftSignalKit
@testable import Postbox

/// A whole `Postbox` over an in-memory value box, for tests that need the transaction
/// API and the view tracker rather than a single table.
final class PostboxFixture {
    let queue: Queue
    let basePath: String
    private(set) var postbox: Postbox!
    static let messageNamespace: MessageId.Namespace = MessageHistoryTableFixture.messageNamespace

    /// Holds the value box so it can be released on its queue (`SqliteValueBox.deinit`
    /// preconditions that); the Postbox implementation drops its own reference there too.
    private final class Storage {
        let valueBox: SqliteValueBox
        init(valueBox: SqliteValueBox) {
            self.valueBox = valueBox
        }
    }
    private var storage: Storage?
    private var disposables: [Disposable] = []

    init(name: String) {
        let _ = FixtureMedia.register
        let _ = FixturePeer.register
        self.queue = Queue(name: name)
        self.basePath = NSTemporaryDirectory() + name + "-" + UUID().uuidString
        let queue = self.queue
        let basePath = self.basePath
        var valueBox: SqliteValueBox?
        queue.sync {
            valueBox = SqliteValueBox(basePath: basePath + "/db", queue: queue, isTemporary: true, isReadOnly: false, useCaches: true, removeDatabaseOnError: true, encryptionParameters: nil, upgradeProgress: { _ in }, inMemory: true)
        }
        self.storage = Storage(valueBox: valueBox!)
        self.postbox = Postbox(
            queue: queue,
            basePath: basePath,
            seedConfiguration: MessageHistoryTableFixture.makeSeedConfiguration(),
            valueBox: valueBox!,
            timestampForAbsoluteTimeBasedOperations: Int32(Date().timeIntervalSince1970),
            isMainProcess: true,
            isTemporary: true,
            tempDir: nil,
            useCaches: true
        )
    }

    func close() {
        for disposable in self.disposables {
            disposable.dispose()
        }
        self.disposables = []
        // The media box opens its storage database on its own queue, lazily; deleting
        // the directory while that open is in flight trips an assertion inside SQLite
        // setup. A round trip through that queue makes sure the open has finished.
        let storageReady = DispatchSemaphore(value: 0)
        let disposable = self.postbox.mediaBox.storageBox.totalSize().start(next: { _ in
            storageReady.signal()
        })
        let _ = storageReady.wait(timeout: .now() + 10.0)
        disposable.dispose()
        // Release the Postbox first: its implementation is dropped on the queue, ahead of
        // the block below, so the value box outlives everything that uses it.
        self.postbox = nil
        self.queue.sync {
            self.storage = nil
        }
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
    }

    // MARK: - Transactions

    /// Runs `f` as a Postbox transaction and waits for it to finish. Nil, with the test
    /// failed, if it did not finish in time (a hung queue must not take the process down).
    @discardableResult
    func transaction<T>(_ f: @escaping (Transaction) -> T, file: StaticString = #file, line: UInt = #line) -> T? {
        let semaphore = DispatchSemaphore(value: 0)
        var result: T?
        let disposable = self.postbox.transaction(f).start(next: { value in
            result = value
            semaphore.signal()
        })
        if semaphore.wait(timeout: .now() + 10.0) == .timedOut {
            XCTFail("transaction did not complete", file: file, line: line)
        }
        disposable.dispose()
        return result
    }

    // MARK: - Views

    /// Every value a signal has produced so far, oldest first.
    final class Recorder<Value> {
        private let lock = NSLock()
        private var recorded: [Value] = []
        private let semaphore = DispatchSemaphore(value: 0)

        fileprivate func record(_ value: Value) {
            self.lock.lock()
            self.recorded.append(value)
            self.lock.unlock()
            self.semaphore.signal()
        }

        var values: [Value] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.recorded
        }

        /// Blocks until at least `count` values have arrived (or fails the test).
        @discardableResult
        func waitForValues(count: Int, file: StaticString = #file, line: UInt = #line) -> [Value] {
            let deadline = DispatchTime.now() + 10.0
            while self.values.count < count {
                if self.semaphore.wait(timeout: deadline) == .timedOut {
                    XCTFail("expected \(count) values, got \(self.values.count)", file: file, line: line)
                    break
                }
            }
            return self.values
        }
    }

    /// Records every value of `signal` for the rest of the fixture's life.
    func observe<Value>(_ signal: Signal<Value, NoError>) -> Recorder<Value> {
        let recorder = Recorder<Value>()
        self.disposables.append(signal.start(next: { value in
            recorder.record(value)
        }))
        return recorder
    }

    func observe<View: PostboxView>(_ key: PostboxViewKey, as type: View.Type) -> Recorder<View> {
        return self.observe(self.postbox.combinedView(keys: [key]) |> mapToSignal { combined -> Signal<View, NoError> in
            if let view = combined.views[key] as? View {
                return .single(view)
            } else {
                XCTFail("combined view has no \(View.self) for \(key)")
                return .complete()
            }
        })
    }

    /// The single-message view for `id`.
    func observeMessage(_ id: MessageId) -> Recorder<MessageView> {
        return self.observe(self.postbox.messageView(id))
    }

    /// The message history around the top of `peerId`'s chat, with `additionalData`.
    func observeHistory(peerId: PeerId, additionalData: [AdditionalMessageHistoryViewData]) -> Recorder<MessageHistoryView> {
        return self.observe(self.postbox.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), anchor: .upperBound, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: [], count: 10, fixedCombinedReadStates: nil, topTaggedMessageIdNamespaces: [], tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, orderStatistics: [], additionalData: additionalData) |> map { $0.0 })
    }
}
