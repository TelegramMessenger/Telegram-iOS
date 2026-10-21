import XCTest
import SwiftSignalKit
import TelegramCore
import MessageWidget
@testable import MessageWidgetStorage

/// The client's half of SDK v1 §2.8 and §5.4 (V2b plan, Task 6), on a fake writer and a manual clock.
final class MessageWidgetStorageTests: XCTestCase {
    private final class FakeWriter: MessageWidgetStorageWriter {
        var writes: [(EngineMessage.Id, MessageWidgetStoredArea)] = []
        var clears = 0
        func write(_ area: MessageWidgetStoredArea, to message: EngineMessage.Id) {
            self.writes.append((message, area))
        }
        func clearAll() -> Signal<Never, NoError> {
            self.clears += 1
            return .complete()
        }
    }

    /// The store's timers, fired by hand.
    private final class ManualClock {
        var pending: [(id: Int, body: () -> Void)] = []
        private var next = 0
        func schedule(_ delay: Double, _ body: @escaping () -> Void) -> () -> Void {
            self.next += 1
            let id = self.next
            self.pending.append((id, body))
            return { [weak self] in
                self?.pending.removeAll { $0.id == id }
            }
        }
        func fire() {
            let due = self.pending
            self.pending.removeAll()
            due.forEach { $0.body() }
        }
    }

    private let account = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(7))

    private func key(_ id: Int32, namespace: Int32 = Namespaces.Message.Cloud, persists: Bool = true) -> MessageWidgetStorageStore.Key {
        let peer = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(100))
        return MessageWidgetStorageStore.Key(accountPeerId: self.account, message: EngineMessage.Id(peerId: peer, namespace: namespace, id: id), persists: persists)
    }

    private func entries(_ pairs: [(String, String)]) -> [MessageWidgetStorage.Entry] {
        return pairs.map { MessageWidgetStorage.Entry(key: $0.0, value: $0.1) }
    }

    private func attributes(_ area: MessageWidgetStoredArea) -> [EngineMessage.Attribute] {
        var data: [String: EngineCodableEntry] = [:]
        data[MessageWidgetStoredArea.derivedDataKey] = EngineCodableEntry(area)
        data["code"] = EngineCodableEntry(MessageWidgetStoredArea(keysAndValues: ["not", "widget"]))
        return [DerivedDataMessageAttribute(data: data)]
    }

    func testAStoredAreaRoundTrips() {
        let area = MessageWidgetStoredArea(keysAndValues: ["b", "2", "a", "✓ ünï", "", ""])
        XCTAssertEqual(MessageWidgetStoredArea.decode(from: self.attributes(area)), self.entries([("b", "2"), ("a", "✓ ünï"), ("", "")]))
        XCTAssertEqual(MessageWidgetStoredArea.decode(from: []), [])
    }

    /// Review Focus 2: a widget rebuilt before its write lands reads its last commit, not the older stored area.
    func testTheLatestCommitWinsOverTheStoredArea() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        store.commit(self.key(1), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "new")])), writer: writer)
        let older = self.attributes(MessageWidgetStoredArea(keysAndValues: ["k", "old"]))
        XCTAssertEqual(store.preload(self.key(1), storedAttributes: older).local, self.entries([("k", "new")]))
        XCTAssertEqual(store.preload(self.key(2), storedAttributes: older).local, self.entries([("k", "old")]))
    }

    func testWritesAreDebouncedAndFlushed() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        for value in ["1", "2", "3"] {
            store.commit(self.key(1), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("n", value)])), writer: writer)
        }
        XCTAssertEqual(writer.writes.count, 0)
        clock.fire()
        XCTAssertEqual(writer.writes.map(\.1), [MessageWidgetStoredArea(keysAndValues: ["n", "3"])])
        store.commit(self.key(1), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("n", "4")])), writer: writer)
        store.flush(self.key(1))
        XCTAssertEqual(writer.writes.count, 2)
        clock.fire()
        XCTAssertEqual(writer.writes.count, 2)
    }

    /// Review Focus 3: clearing the last key writes an empty area; the attribute's merge would restore a removed one.
    func testAnEmptyAreaIsWrittenNotRemoved() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        store.commit(self.key(1), MessageWidgetInstance.StorageCommit(area: .local, entries: []), writer: writer)
        store.flushAll()
        XCTAssertEqual(writer.writes.map(\.1), [MessageWidgetStoredArea(keysAndValues: [])])
    }

    /// Previews and the admin log keep their widgets' storage in memory only.
    func testNoWriterMeansNoWrite() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        store.commit(self.key(1, persists: false), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "v")])), writer: nil)
        XCTAssertTrue(clock.pending.isEmpty)
        XCTAssertEqual(store.preload(self.key(1, persists: false), storedAttributes: []).local, self.entries([("k", "v")]))
    }

    /// Final review C3: an admin-log widget's id is synthetic and can equal a real message's; what it keeps in memory
    /// never becomes that message's starting state, nor the other way round.
    func testAMemoryOnlyAreaNeverAnswersThePersistingWidget() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        store.commit(self.key(7, persists: false), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "admin")])), writer: nil)
        store.commit(self.key(7, persists: false), MessageWidgetInstance.StorageCommit(area: .session, entries: self.entries([("s", "admin")])), writer: nil)
        let real = self.attributes(MessageWidgetStoredArea(keysAndValues: ["k", "real"]))
        XCTAssertEqual(store.preload(self.key(7), storedAttributes: real), MessageWidgetStorage(local: self.entries([("k", "real")]), session: []))
        store.commit(self.key(7), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "live")])), writer: writer)
        XCTAssertEqual(store.preload(self.key(7, persists: false), storedAttributes: []).local, self.entries([("k", "admin")]))
    }

    /// Final review I3: a pending message's widget keeps running when the message is sent and its id becomes the cloud
    /// one (Postbox keeps the stable id); its areas, its waiting write and its later commits follow the new id.
    func testASinkFollowsItsMessageFromThePendingIdToTheCloudId() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        let pending = self.key(5, namespace: Namespaces.Message.Local)
        let sent = self.key(90)
        let sink = MessageWidgetStorageSink(owner: AnyHashable(1), key: pending, writer: writer, store: store)
        sink.commit(MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "1")])))
        sink.commit(MessageWidgetInstance.StorageCommit(area: .session, entries: self.entries([("s", "1")])))
        sink.update(key: sent, writer: writer)
        XCTAssertEqual(sink.key, sent)
        XCTAssertEqual(store.preload(sent, storedAttributes: []), MessageWidgetStorage(local: self.entries([("k", "1")]), session: self.entries([("s", "1")])))
        sink.commit(MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "2")])))
        clock.fire()
        XCTAssertEqual(writer.writes.map(\.0), [sent.message, sent.message])
        XCTAssertEqual(writer.writes.map(\.1), [MessageWidgetStoredArea(keysAndValues: ["k", "1"]), MessageWidgetStoredArea(keysAndValues: ["k", "2"])])
    }

    /// Final review C2: Storage Usage's whole-cache clear, whatever categories are chosen, deletes every widget's
    /// storage; a chat's own screen and the selected-chats clear leave it.
    func testOnlyTheWholeCacheClearDeletesWidgetStorage() {
        XCTAssertTrue(MessageWidgetStorageStore.clearsWidgetStorage(chatScoped: false, clearingCategories: true))
        XCTAssertFalse(MessageWidgetStorageStore.clearsWidgetStorage(chatScoped: false, clearingCategories: false))
        XCTAssertFalse(MessageWidgetStorageStore.clearsWidgetStorage(chatScoped: true, clearingCategories: true))
        XCTAssertFalse(MessageWidgetStorageStore.clearsWidgetStorage(chatScoped: true, clearingCategories: false))
    }

    /// Final review I4 and Review Focus 3: an empty area survives the attribute's own coding as an empty area, not as
    /// a missing key.
    func testAnEmptyAreaSurvivesTheAttributesCoding() {
        let attribute = DerivedDataMessageAttribute(data: [MessageWidgetStoredArea.derivedDataKey: EngineCodableEntry(MessageWidgetStoredArea(keysAndValues: []))!])
        let encoder = EnginePostboxEncoder()
        attribute.encode(encoder)
        let decoded = DerivedDataMessageAttribute(decoder: EnginePostboxDecoder(buffer: EngineMemoryBuffer(data: encoder.makeData())))
        XCTAssertNotNil(decoded.data[MessageWidgetStoredArea.derivedDataKey])
        XCTAssertEqual(decoded.data[MessageWidgetStoredArea.derivedDataKey]?.get(MessageWidgetStoredArea.self), MessageWidgetStoredArea(keysAndValues: []))
        XCTAssertEqual(MessageWidgetStoredArea.decode(from: [decoded]), [])
    }

    /// Final review I4: the account's index of written messages round-trips through its preferences entry.
    func testTheIndexRoundTrips() {
        let index = MessageWidgetStorageIndex(messageIds: [self.key(1).message, self.key(2, namespace: Namespaces.Message.Local).message])
        XCTAssertEqual(EnginePreferencesEntry(index)?.get(MessageWidgetStorageIndex.self), index)
        XCTAssertEqual(EnginePreferencesEntry(MessageWidgetStorageIndex(messageIds: []))?.get(MessageWidgetStorageIndex.self), MessageWidgetStorageIndex(messageIds: []))
    }

    func testSessionIsInMemoryOnly() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        store.commit(self.key(1), MessageWidgetInstance.StorageCommit(area: .session, entries: self.entries([("s", "1")])), writer: writer)
        store.flushAll()
        clock.fire()
        XCTAssertEqual(writer.writes.count, 0)
        XCTAssertEqual(store.preload(self.key(1), storedAttributes: []).session, self.entries([("s", "1")]))
        XCTAssertEqual(MessageWidgetStorageStore(schedule: clock.schedule).preload(self.key(1), storedAttributes: []).session, [])
    }

    /// §5.4's "Clear cache": every area of the account goes, in memory and through the writer, and a stale attribute
    /// read before the writer's update lands is not used.
    func testClearAllEmptiesEveryArea() {
        let clock = ManualClock()
        let store = MessageWidgetStorageStore(schedule: clock.schedule)
        let writer = FakeWriter()
        for id: Int32 in [1, 2] {
            store.commit(self.key(id), MessageWidgetInstance.StorageCommit(area: .local, entries: self.entries([("k", "\(id)")])), writer: writer)
            store.commit(self.key(id), MessageWidgetInstance.StorageCommit(area: .session, entries: self.entries([("s", "\(id)")])), writer: writer)
        }
        store.flushAll()
        let _ = store.clearAll(accountPeerId: self.account, writer: writer).start()
        XCTAssertEqual(writer.clears, 1)
        let stale = self.attributes(MessageWidgetStoredArea(keysAndValues: ["k", "1"]))
        for id: Int32 in [1, 2] {
            XCTAssertEqual(store.preload(self.key(id), storedAttributes: stale), MessageWidgetStorage.empty)
        }
    }
}
