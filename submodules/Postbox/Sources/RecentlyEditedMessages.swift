import Foundation

/// The edits the update replay received in the last few minutes. In memory only: never persisted, empty at every
/// launch, one per Postbox and so per process (the app's and an extension's are separate).
///
/// A fetch that was asked before an edit and answered after it brings the message with its old content: the server's
/// answer predates the edit. Storing it would undo the edit, which the replay applied to the stored message or, with
/// none stored, had nothing to apply to. TelegramCore's fetches therefore store the recorded edit in place of an answer
/// message edited since their request went out (`Transaction.recentMessageEdit`; the edit counterpart of
/// RecentlyDeletedMessages, owner decision 2026-10-25).
///
/// It keeps each message's latest edit, as the edit carried it. An entry expires `lifetime` seconds after it was
/// recorded, by default the deletion record's: a fetch stores no answer older than that (TelegramCore's
/// `FetchedAnswerAge`), so it finds every edit its answer can predate. Past `capacity` messages the oldest are
/// dropped: for a dropped entry a fetch stores its answer, as before this record existed. Only the Postbox queue
/// touches it (inside transactions), so it takes no lock.
final class RecentlyEditedMessages {
    static let defaultCapacity: Int = 1000

    private struct Entry {
        let message: StoreMessage
        let time: Double
        let sequence: Int
    }

    let lifetime: Double
    let capacity: Int
    private let now: () -> Double

    private var entries: [MessageId: Entry] = [:]
    /// Every recording, oldest first, from `orderStart` on. A message edited again has a newer recording; dropping
    /// the older one leaves it recorded (`sequence` tells them apart).
    private var order: [(id: MessageId, time: Double, sequence: Int)] = []
    private var orderStart: Int = 0
    private var nextSequence: Int = 0

    /// `now` is a monotonic clock in seconds, the system uptime by default, so a change of the wall clock neither
    /// keeps an entry alive nor drops one early.
    init(lifetime: Double = RecentlyDeletedMessages.defaultLifetime, capacity: Int = RecentlyEditedMessages.defaultCapacity, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }) {
        self.lifetime = lifetime
        self.capacity = max(1, capacity)
        self.now = now
    }

    /// Records `message`, an edited message as its edit carried it, replacing an earlier edit of it. A message without
    /// an id (`.Partial`) is not recorded.
    func add(_ message: StoreMessage) {
        guard case let .Id(id) = message.id else {
            return
        }
        let time = self.now()
        self.prune(at: time)
        let sequence = self.nextSequence
        self.nextSequence += 1
        self.entries[id] = Entry(message: message, time: time, sequence: sequence)
        self.order.append((id: id, time: time, sequence: sequence))
        while self.order.count - self.orderStart > self.capacity {
            self.dropOldest()
        }
        self.compact()
    }

    /// The latest edit of `id`, when it was recorded at or after `since` (on this record's clock) and less than
    /// `lifetime` seconds ago. An edit recorded before a fetch went out is in the fetch's answer.
    func edit(of id: MessageId, since: Double) -> StoreMessage? {
        guard let entry = self.entries[id] else {
            return nil
        }
        if self.now() - entry.time >= self.lifetime || entry.time < since {
            return nil
        }
        return entry.message
    }

    private func prune(at time: Double) {
        while self.orderStart < self.order.count && time - self.order[self.orderStart].time >= self.lifetime {
            self.dropOldest()
        }
        self.compact()
    }

    private func dropOldest() {
        let recording = self.order[self.orderStart]
        self.orderStart += 1
        if self.entries[recording.id]?.sequence == recording.sequence {
            self.entries.removeValue(forKey: recording.id)
        }
    }

    private func compact() {
        if self.orderStart > 0 && self.orderStart * 2 >= self.order.count {
            self.order.removeFirst(self.orderStart)
            self.orderStart = 0
        }
    }
}
