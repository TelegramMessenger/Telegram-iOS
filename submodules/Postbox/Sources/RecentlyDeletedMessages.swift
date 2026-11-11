import Foundation

/// The messages deleted from this Postbox in the last few minutes. In memory only: never persisted, empty at
/// every launch, one per Postbox and so per process (the app's and an extension's are separate).
///
/// A fetch that was asked before a deletion and answered after it can bring the deleted message back: the
/// server's answer predates the deletion. TelegramCore's history fills therefore store no answer message
/// this record holds (`Transaction.wasMessageDeletedRecently`; owner decision D2, 2026-10-15).
///
/// It holds what a deletion was ASKED to delete, not only what it removed, because the message a fetch is
/// bringing back may never have been stored here:
/// - `deleteMessages`: every requested id;
/// - `deleteMessagesWithGlobalIds`: every requested global id as well, since a message never stored here maps
///   to no `MessageId` (a global id is matched only in the peer and message namespaces that have global ids);
/// - `deleteMessagesInRange`: the range;
/// - `clearHistory` (with or without a timestamp range), `removeAllMessagesWithAuthor`,
///   `removeAllMessagesWithGlobalTag`, `removeAllMessagesWithForwardAuthor`: the ids they removed, as they
///   name no ids of their own.
/// A message whose index moves (`updateMessage`, a timestamp change) is not deleted and is not recorded.
///
/// An entry expires `lifetime` seconds after it was recorded. Past `capacity` ids and global ids together,
/// or past `rangeCapacity` ranges, the oldest are dropped, never merged into something wider: for a dropped
/// entry a fetch behaves as it did before this record existed, while a wider entry would hide messages that
/// still exist. Only the Postbox queue touches it (inside transactions), so it takes no lock.
final class RecentlyDeletedMessages {
    static let defaultLifetime: Double = 5.0 * 60.0
    static let defaultCapacity: Int = 10000
    static let defaultRangeCapacity: Int = 64

    private enum Key {
        case id(MessageId)
        case globalId(Int32)
    }

    private struct Entry {
        let key: Key
        let time: Double
        let sequence: Int
    }

    private struct RangeEntry {
        let peerId: PeerId
        let namespace: MessageId.Namespace
        let range: ClosedRange<MessageId.Id>
        let time: Double
    }

    let lifetime: Double
    let capacity: Int
    let rangeCapacity: Int
    private let now: () -> Double

    private var ids: [MessageId: (time: Double, sequence: Int)] = [:]
    private var globalIds: [Int32: (time: Double, sequence: Int)] = [:]
    private var ranges: [RangeEntry] = []
    /// Every recording of an id or a global id, oldest first, from `orderStart` on. An id recorded again
    /// has a newer entry; dropping the older one leaves it recorded (`sequence` tells them apart).
    private var order: [Entry] = []
    private var orderStart: Int = 0
    private var nextSequence: Int = 0

    /// `now` is a monotonic clock in seconds, the system uptime by default, so a change of the wall clock
    /// neither keeps an entry alive nor drops one early.
    init(lifetime: Double = RecentlyDeletedMessages.defaultLifetime, capacity: Int = RecentlyDeletedMessages.defaultCapacity, rangeCapacity: Int = RecentlyDeletedMessages.defaultRangeCapacity, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.lifetime = lifetime
        self.capacity = max(1, capacity)
        self.rangeCapacity = max(1, rangeCapacity)
        self.now = now
    }

    func add(ids: [MessageId]) {
        if ids.isEmpty {
            return
        }
        let time = self.now()
        self.prune(at: time)
        for id in ids {
            let sequence = self.nextSequence
            self.nextSequence += 1
            self.ids[id] = (time, sequence)
            self.order.append(Entry(key: .id(id), time: time, sequence: sequence))
        }
        self.dropPastCapacity()
    }

    func add(globalIds: [Int32]) {
        if globalIds.isEmpty {
            return
        }
        let time = self.now()
        self.prune(at: time)
        for id in globalIds {
            let sequence = self.nextSequence
            self.nextSequence += 1
            self.globalIds[id] = (time, sequence)
            self.order.append(Entry(key: .globalId(id), time: time, sequence: sequence))
        }
        self.dropPastCapacity()
    }

    func add(peerId: PeerId, namespace: MessageId.Namespace, range: ClosedRange<MessageId.Id>) {
        let time = self.now()
        self.prune(at: time)
        self.ranges.append(RangeEntry(peerId: peerId, namespace: namespace, range: range, time: time))
        if self.ranges.count > self.rangeCapacity {
            self.ranges.removeFirst(self.ranges.count - self.rangeCapacity)
        }
    }

    /// Forgets the ids and ranges recorded for `peerId`, as if they had expired. Global ids name no chat and
    /// stay. For a removal that was local only, whose messages the server still has (a debug reset of a chat's
    /// cached history). Their recordings leave `order` too, so they no longer count toward `capacity`.
    func forget(peerId: PeerId) {
        self.ids = self.ids.filter { $0.key.peerId != peerId }
        self.ranges.removeAll(where: { $0.peerId == peerId })
        self.order = self.order[self.orderStart...].filter { entry in
            if case let .id(id) = entry.key {
                return id.peerId != peerId
            }
            return true
        }
        self.orderStart = 0
    }

    /// Whether `id` was recorded less than `lifetime` seconds ago: by itself, inside a range of its chat and
    /// namespace, or, when `matchesGlobalId` (its peer and message namespaces have global ids), by its
    /// global id `id.id`.
    func contains(_ id: MessageId, matchesGlobalId: Bool) -> Bool {
        let time = self.now()
        if let entry = self.ids[id], time - entry.time < self.lifetime {
            return true
        }
        if matchesGlobalId, let entry = self.globalIds[id.id], time - entry.time < self.lifetime {
            return true
        }
        for entry in self.ranges {
            if entry.peerId == id.peerId && entry.namespace == id.namespace && entry.range.contains(id.id) && time - entry.time < self.lifetime {
                return true
            }
        }
        return false
    }

    private func prune(at time: Double) {
        while self.orderStart < self.order.count && time - self.order[self.orderStart].time >= self.lifetime {
            self.dropOldest()
        }
        let lifetime = self.lifetime
        self.ranges.removeAll(where: { entry in
            return time - entry.time >= lifetime
        })
        self.compact()
    }

    private func dropPastCapacity() {
        while self.order.count - self.orderStart > self.capacity {
            self.dropOldest()
        }
        self.compact()
    }

    private func dropOldest() {
        let entry = self.order[self.orderStart]
        self.orderStart += 1
        switch entry.key {
        case let .id(id):
            if self.ids[id]?.sequence == entry.sequence {
                self.ids.removeValue(forKey: id)
            }
        case let .globalId(id):
            if self.globalIds[id]?.sequence == entry.sequence {
                self.globalIds.removeValue(forKey: id)
            }
        }
    }

    private func compact() {
        if self.orderStart > 0 && self.orderStart * 2 >= self.order.count {
            self.order.removeFirst(self.orderStart)
            self.orderStart = 0
        }
    }
}
