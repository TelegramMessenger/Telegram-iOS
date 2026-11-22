import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import MessageWidget

/// Where a widget's `local` area is written, and how all of an account's are cleared (SDK v1 §5.4).
public protocol MessageWidgetStorageWriter: AnyObject {
    /// Writes `area` as `message`'s stored area and records the message in the account's index.
    func write(_ area: MessageWidgetStoredArea, to message: EngineMessage.Id)
    /// Empties the stored area of every message the account's index holds, then the index.
    func clearAll() -> Signal<Never, NoError>
}

/// The client's half of SDK v1 §2.8 and §5.4 (V2b plan, Task 6): the latest areas of every widget shown in this process,
/// keyed by (account, message), and their writes. `local` is written `writeDelay` after a widget's last commit and at
/// once on `flush`, `flushAll` and when the app goes to the background or terminates; `session` stays in memory, so it
/// lasts until the app restarts. A widget made before its write lands reads its last commit. Main thread only.
public final class MessageWidgetStorageStore {
    public struct Key: Hashable {
        public let accountPeerId: EnginePeer.Id
        public let message: EngineMessage.Id
        /// False for a widget whose storage stays in memory (a preview, the admin log): its areas are kept apart from
        /// the message's own, because an admin-log id is synthetic and can equal an unrelated real message's.
        public let persists: Bool

        public init(accountPeerId: EnginePeer.Id, message: EngineMessage.Id, persists: Bool) {
            self.accountPeerId = accountPeerId
            self.message = message
            self.persists = persists
        }
    }

    private struct Areas {
        /// nil until a commit (or a clear) sets it: the stored attribute is the area then.
        var local: [MessageWidgetStorage.Entry]?
        var session: [MessageWidgetStorage.Entry] = []
    }

    private struct PendingWrite {
        let writer: MessageWidgetStorageWriter
        let area: MessageWidgetStoredArea
        let cancel: () -> Void
    }

    public static let shared = MessageWidgetStorageStore()
    public static let writeDelay: Double = 1.0

    /// Whether a clear in Storage Usage deletes every widget's storage (§5.4's "Clear cache"): the whole-cache clear,
    /// whatever categories are chosen, and not a chat's own screen or the clear of chats picked from the list.
    public static func clearsWidgetStorage(chatScoped: Bool, clearingCategories: Bool) -> Bool {
        return !chatScoped && clearingCategories
    }

    private let schedule: (Double, @escaping () -> Void) -> () -> Void
    private var areas: [Key: Areas] = [:]
    private var pending: [Key: PendingWrite] = [:]
    private var observers: [NSObjectProtocol] = []

    /// `schedule` runs a body after a delay and returns its cancellation (tests pass a clock of their own).
    public init(schedule: ((Double, @escaping () -> Void) -> () -> Void)? = nil) {
        self.schedule = schedule ?? { delay, body in
            let item = DispatchWorkItem(block: body)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return {
                item.cancel()
            }
        }
        for name in [UIApplication.didEnterBackgroundNotification, UIApplication.willTerminateNotification] {
            self.observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main, using: { [weak self] _ in
                self?.flushAll()
            }))
        }
    }

    deinit {
        for observer in self.observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// What a widget made now for `key` starts with: the last `local` commit, else the area the message's attributes
    /// hold; the last `session` commit, else nothing.
    public func preload(_ key: Key, storedAttributes: [EngineMessage.Attribute]) -> MessageWidgetStorage {
        let areas = self.areas[key]
        return MessageWidgetStorage(local: areas?.local ?? MessageWidgetStoredArea.decode(from: storedAttributes), session: areas?.session ?? [])
    }

    /// Keeps a commit; a `local` one is also written through `writer`, once its widget has made no other commit for
    /// `writeDelay`. No writer (a preview, the admin log): memory only.
    public func commit(_ key: Key, _ commit: MessageWidgetInstance.StorageCommit, writer: MessageWidgetStorageWriter?) {
        var areas = self.areas[key] ?? Areas()
        switch commit.area {
        case .session:
            areas.session = commit.entries
            self.areas[key] = areas
        case .local:
            areas.local = commit.entries
            self.areas[key] = areas
            guard let writer else {
                return
            }
            self.pending[key]?.cancel()
            let cancel = self.schedule(MessageWidgetStorageStore.writeDelay, { [weak self] in
                self?.flush(key)
            })
            self.pending[key] = PendingWrite(writer: writer, area: MessageWidgetStoredArea(commit.entries), cancel: cancel)
        }
    }

    /// The message `old` names is now `new` (a sent message's local id became its cloud id): its areas move, and its
    /// waiting write goes to the new id now.
    public func rekey(from old: Key, to new: Key) {
        guard old != new else {
            return
        }
        if let areas = self.areas.removeValue(forKey: old) {
            self.areas[new] = areas
        }
        if let write = self.pending.removeValue(forKey: old) {
            write.cancel()
            write.writer.write(write.area, to: new.message)
        }
    }

    /// Writes `key`'s pending area now (its widget was hidden or destroyed).
    public func flush(_ key: Key) {
        guard let write = self.pending.removeValue(forKey: key) else {
            return
        }
        write.cancel()
        write.writer.write(write.area, to: key.message)
    }

    public func flushAll() {
        for key in Array(self.pending.keys) {
            self.flush(key)
        }
    }

    /// "Clear cache" (§5.4): every area of the account, in memory (both kept as empty, so a stale attribute read before
    /// the clear lands is not used) and through the writer.
    public func clearAll(accountPeerId: EnginePeer.Id, writer: MessageWidgetStorageWriter) -> Signal<Never, NoError> {
        for key in Array(self.pending.keys) where key.accountPeerId == accountPeerId {
            self.pending.removeValue(forKey: key)?.cancel()
        }
        for key in Array(self.areas.keys) where key.accountPeerId == accountPeerId {
            self.areas[key] = Areas(local: [], session: [])
        }
        return writer.clearAll()
    }
}

/// The writer of a real account: the message's derived data (`engine.messages.updateLocallyDerivedData`, changing only
/// the `"widgetStorage"` key) and the account's index (an application-specific preference).
public final class MessageWidgetEngineStorageWriter: MessageWidgetStorageWriter {
    private let engine: TelegramEngine

    public init(engine: TelegramEngine) {
        self.engine = engine
    }

    public func write(_ area: MessageWidgetStoredArea, to message: EngineMessage.Id) {
        guard let entry = EngineCodableEntry(area) else {
            return
        }
        let _ = self.engine.messages.updateLocallyDerivedData(messageId: message, update: { data in
            var data = data
            data[MessageWidgetStoredArea.derivedDataKey] = entry
            return data
        }).startStandalone()
        let _ = self.engine.preferences.update(id: ApplicationSpecificPreferencesKeys.messageWidgetStorageIndex, { current in
            var index = current?.get(MessageWidgetStorageIndex.self) ?? MessageWidgetStorageIndex(messageIds: [])
            if !index.messageIds.contains(message) {
                index.messageIds.append(message)
            }
            return EnginePreferencesEntry(index)
        }).startStandalone()
    }

    public func clearAll() -> Signal<Never, NoError> {
        let engine = self.engine
        let key = ApplicationSpecificPreferencesKeys.messageWidgetStorageIndex
        return engine.data.get(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: key))
        |> mapToSignal { current -> Signal<Never, NoError> in
            let ids = current?.get(MessageWidgetStorageIndex.self)?.messageIds ?? []
            guard let empty = EngineCodableEntry(MessageWidgetStoredArea(keysAndValues: [])) else {
                return .complete()
            }
            let clears = ids.map { id -> Signal<Never, NoError> in
                return engine.messages.updateLocallyDerivedData(messageId: id, update: { data in
                    var data = data
                    if data[MessageWidgetStoredArea.derivedDataKey] != nil {
                        data[MessageWidgetStoredArea.derivedDataKey] = empty
                    }
                    return data
                })
            }
            return clears.reduce(Signal<Never, NoError>.complete(), { chain, clear in chain |> then(clear) })
            |> then(engine.preferences.update(id: key, { _ in nil }))
        }
    }
}

/// One widget's storage commits, delivered to the store under its message's current key. A message sent from this
/// device first shows under a local id and keeps its stable id when the server's id replaces it, so its widget keeps
/// running and must follow the message (`update`). Made per widget owner, so a recycled bubble's next message never
/// receives a commit of the widget it showed before. Main thread only.
public final class MessageWidgetStorageSink {
    public let owner: AnyHashable
    public private(set) var key: MessageWidgetStorageStore.Key
    private var writer: MessageWidgetStorageWriter?
    private let store: MessageWidgetStorageStore

    public init(owner: AnyHashable, key: MessageWidgetStorageStore.Key, writer: MessageWidgetStorageWriter?, store: MessageWidgetStorageStore = .shared) {
        self.owner = owner
        self.key = key
        self.writer = writer
        self.store = store
    }

    /// The owner's message as the latest pass shows it.
    public func update(key: MessageWidgetStorageStore.Key, writer: MessageWidgetStorageWriter?) {
        if key != self.key {
            self.store.rekey(from: self.key, to: key)
            self.key = key
        }
        self.writer = writer
    }

    public func commit(_ commit: MessageWidgetInstance.StorageCommit) {
        self.store.commit(self.key, commit, writer: self.writer)
    }
}
