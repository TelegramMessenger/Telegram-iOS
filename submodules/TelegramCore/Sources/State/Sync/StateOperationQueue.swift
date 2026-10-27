import Foundation
import Postbox
import SwiftSignalKit

/// An operation of `AccountStateManager`'s queue, by the kind names of the state-sync refactor (spec section 3.1).
/// `AccountStateManager.Impl.startFirstOperation()` runs the head; `StateOperationQueue` decides where each
/// operation goes.
enum StateOperation {
    /// A getDifference attempt of the main app's poll cycle, with the events its chain has gathered so far.
    case fetchDifference(Int32, AccountFinalStateEvents)
    /// Pushed update groups, which become one `processBatch` at the head when a zero-delay timer fires; groups pushed
    /// meanwhile join them (`StateOperationQueue.absorbUpdateGroups`).
    case batchUpdates([UpdateGroup])
    /// The wait after a pushed batch with a common pts, qts or seq hole: once `AccountStateManager.Impl`'s
    /// `gapWaitTimeout` has passed, a getDifference replaces the queue. It holds nothing: groups pushed while it is
    /// the last entry are absorbed and dropped, so of what they carried only what the getDifference returns arrives
    /// (Q5).
    case gapWait
    /// A batch of pushed update groups, interpreted and replayed.
    case processBatch([UpdateGroup])
    /// `addCustomOperation`'s signal, run in its turn.
    case custom(Int32, Signal<Void, NoError>)
    /// The barrier behind `pollStateUpdateCompletion()`: the incoming message ids delivered while it waits, and its
    /// subscribers, called once a `help.test` round trip ends with nothing queued behind it.
    case stateBarrier(Int32, [MessageId], [(Int32, ([MessageId]) -> Void)])
    /// The events of replayed states, delivered.
    case dispatchEvents(Int32, AccountFinalStateEvents)
    /// A final state built outside the queue (`addReplayAsynchronouslyBuiltFinalState`), replayed in its turn.
    case replayPrebuilt(AccountFinalState, () -> Void)
}

/// The operations `AccountStateManager.Impl` runs one at a time, in order, and the rules that place them. Only the
/// head runs (`startHead()`), and an operation that finishes pops the head (the `pop…` methods). Everything else
/// here is placement.
///
/// A value with no reference to the manager, so it cannot start anything: a method after which the head may need
/// starting returns whether the caller must start it (`AccountStateManager.Impl.startFirstOperation()`), and after
/// the others the caller starts the head where it always did. `Impl` reaches it only on its queue, through the
/// asserting `operations` accessor.
struct StateOperationQueue {
    /// Where `add(_:at:)` puts an operation.
    enum Position {
        /// At the head, or right behind it while it runs.
        case first
        /// At the end.
        case last
    }

    struct Entry {
        /// Set by `startHead()`; an entry replaced by an updated copy keeps it. Only the head ever runs.
        var isRunning: Bool = false
        let content: StateOperation
    }

    private(set) var entries: [Entry] = []

    var first: Entry? {
        return self.entries.first
    }

    var isEmpty: Bool {
        return self.entries.isEmpty
    }

    // MARK: - The head

    /// Marks the head running and returns it; nil when the queue is empty or the head already runs.
    mutating func startHead() -> Entry? {
        guard !self.entries.isEmpty, !self.entries[0].isRunning else {
            return nil
        }
        self.entries[0].isRunning = true
        return self.entries[0]
    }

    // MARK: - Placement

    /// `.first` puts the operation at the head, or right behind the head while it runs; `.last` at the end. Returns
    /// whether the caller must start the head: after `.first` at the head, or after `.last` into an empty queue.
    mutating func add(_ content: StateOperation, at position: Position) -> Bool {
        let operation = Entry(content: content)
        switch position {
        case .first:
            if self.entries.isEmpty || !self.entries[0].isRunning {
                self.entries.insert(operation, at: 0)
                return true
            } else {
                self.entries.insert(operation, at: 1)
                return false
            }
        case .last:
            let begin = self.entries.isEmpty
            self.entries.append(operation)
            return begin
        }
    }

    /// Pushed groups join a `batchUpdates` that is the last entry, running or not: they are appended to its groups, and
    /// the entry is replaced by an updated copy that keeps `isRunning`. A `gapWait` that is the last entry absorbs them
    /// and drops them, since it holds nothing (Q5). Returns false, changing nothing, when the queue is empty or its
    /// last entry is of another kind: the caller then queues a `batchUpdates` of its own.
    mutating func absorbUpdateGroups(_ groups: [UpdateGroup]) -> Bool {
        guard let last = self.entries.last else {
            return false
        }
        switch last.content {
        case .fetchDifference, .processBatch, .custom, .stateBarrier, .dispatchEvents, .replayPrebuilt:
            return false
        case let .batchUpdates(currentGroups):
            self.entries[self.entries.count - 1] = Entry(isRunning: last.isRunning, content: .batchUpdates(currentGroups + groups))
            return true
        case .gapWait:
            return true
        }
    }

    /// A getDifference (`content`) replaces what is queued. Running entries stay, in their order (only the head ever
    /// runs). Behind them come, each group in queue order: the queued `processBatch` entries; `content`; one barrier
    /// holding every queued barrier's message ids and subscribers, under a new id from `nextId()`, called only when
    /// there is one of either; the queued replays; the queued event deliveries; the queued custom operations. Queued
    /// `fetchDifference`, `batchUpdates` and `gapWait` entries are dropped, a `batchUpdates`' groups with it. Starts
    /// nothing. `nextId` runs while the caller holds the queue's value, so it must not read or write the operation
    /// queue.
    mutating func replace(with content: StateOperation, nextId: () -> Int32) {
        var collectedBatches: [StateOperation] = []
        var collectedMessageIds: [MessageId] = []
        var collectedSubscribers: [(Int32, ([MessageId]) -> Void)] = []
        var collectedReplays: [(AccountFinalState, () -> Void)] = []
        var collectedEvents: [(Int32, AccountFinalStateEvents)] = []
        var customOperations: [(Int32, Signal<Void, NoError>)] = []

        var replacedOperations: [Entry] = []

        for i in 0 ..< self.entries.count {
            if self.entries[i].isRunning {
                replacedOperations.append(self.entries[i])
            } else {
                switch self.entries[i].content {
                case .processBatch:
                    collectedBatches.append(self.entries[i].content)
                case let .stateBarrier(_, messageIds, subscribers):
                    collectedMessageIds.append(contentsOf: messageIds)
                    collectedSubscribers.append(contentsOf: subscribers)
                case let .replayPrebuilt(finalState, completion):
                    collectedReplays.append((finalState, completion))
                case let .dispatchEvents(operationId, events):
                    collectedEvents.append((operationId, events))
                case let .custom(operationId, customSignal):
                    customOperations.append((operationId, customSignal))
                case .fetchDifference, .batchUpdates, .gapWait:
                    // Dropped, a `batchUpdates`' groups with it.
                    break
                }
            }
        }

        replacedOperations.append(contentsOf: collectedBatches.map { Entry(content: $0) })

        replacedOperations.append(Entry(content: content))

        if !collectedSubscribers.isEmpty || !collectedMessageIds.isEmpty {
            replacedOperations.append(Entry(content: .stateBarrier(nextId(), collectedMessageIds, collectedSubscribers)))
        }

        for (finalState, completion) in collectedReplays {
            replacedOperations.append(Entry(content: .replayPrebuilt(finalState, completion)))
        }

        for (operationId, events) in collectedEvents {
            replacedOperations.append(Entry(content: .dispatchEvents(operationId, events)))
        }

        for (operationId, customSignal) in customOperations {
            replacedOperations.append(Entry(content: .custom(operationId, customSignal)))
        }

        self.entries.removeAll()
        self.entries.append(contentsOf: replacedOperations)
    }

    /// An event delivery goes in front of the first entry that is neither running nor an event delivery: behind the
    /// running head and the deliveries already queued at the front, ahead of everything else. With no such entry, at
    /// the end. Starts nothing.
    mutating func insertEvents(id: Int32, events: AccountFinalStateEvents) {
        let operation = Entry(content: .dispatchEvents(id, events))
        var inserted = false
        for i in 0 ..< self.entries.count {
            if self.entries[i].isRunning {
                continue
            }
            if case .dispatchEvents = self.entries[i].content {
                continue
            }
            self.entries.insert(operation, at: i)
            inserted = true
            break
        }
        if !inserted {
            self.entries.append(operation)
        }
    }

    // MARK: - The barrier (`.stateBarrier`)

    /// A barrier that starts with entries behind it does not run: it leaves the head, and the caller queues it again
    /// at the end under a new id (`postponeStateBarrier`). Returns false, changing nothing, when it is the
    /// only entry; then it runs.
    mutating func barrierStepsAside() -> Bool {
        if self.entries.count > 1 {
            self.entries.removeFirst()
            return true
        } else {
            return false
        }
    }

    /// What `postponeStateBarrier` checks once it has queued its barrier at the end: no barrier is queued
    /// before the last entry. Debug builds only; a failure changes nothing.
    func assertBarrierIsLast() {
        for i in 0 ..< self.entries.count {
            if case .stateBarrier = self.entries[i].content {
                if i != self.entries.count - 1 {
                    assertionFailure()
                }
            }
        }
    }

    /// A `pollStateUpdateCompletion()` subscriber `(id, f)` joins the first queued barrier, running or not. Returns
    /// false, changing nothing, when none is queued: the caller then queues a barrier of its own at the end.
    mutating func addBarrierSubscriber(id: Int32, _ f: @escaping ([MessageId]) -> Void) -> Bool {
        for i in 0 ..< self.entries.count {
            if case let .stateBarrier(pollId, messageIds, subscribers) = self.entries[i].content {
                var subscribers = subscribers
                subscribers.append((id, f))
                self.entries[i] = Entry(isRunning: self.entries[i].isRunning, content: .stateBarrier(pollId, messageIds, subscribers))
                return true
            }
        }
        return false
    }

    /// A cancelled subscriber leaves every queued barrier: in each, the first subscriber with its id is removed.
    mutating func removeBarrierSubscriber(id: Int32) {
        for i in 0 ..< self.entries.count {
            if case let .stateBarrier(pollId, messages, subscribers) = self.entries[i].content {
                for j in 0 ..< subscribers.count {
                    if subscribers[j].0 == id {
                        var subscribers = subscribers
                        subscribers.remove(at: j)
                        self.entries[i] = Entry(isRunning: self.entries[i].isRunning, content: .stateBarrier(pollId, messages, subscribers))
                        break
                    }
                }
            }
        }
    }

    /// A finished event delivery appends its incoming message ids to every queued barrier, which hands them to its
    /// subscribers. At most one barrier is queued then (asserted in debug builds).
    mutating func addIncomingMessageIdsToBarriers(_ addedIncomingMessageIds: [MessageId]) {
        var pollCount = 0
        for i in 0 ..< self.entries.count {
            if case let .stateBarrier(pollId, messageIds, subscribers) = self.entries[i].content {
                pollCount += 1
                var updatedMessageIds = messageIds
                updatedMessageIds.append(contentsOf: addedIncomingMessageIds)
                self.entries[i] = Entry(isRunning: self.entries[i].isRunning, content: .stateBarrier(pollId, updatedMessageIds, subscribers))
            }
        }
        assert(pollCount <= 1)
    }

    // MARK: - Completion: pop the head, then check it

    // An operation that finishes pops the head, which is the operation it started, and acts only if the popped entry
    // is that operation: of its kind and, for a custom operation or an event delivery, with its id (a barrier's id is
    // only asserted). A mismatch is a state no path produces: the pop asserts in debug builds and returns nil or
    // false, and the caller acts on nothing it popped; the head is gone all the same and nothing is started. The
    // poll's pop does not assert: its completions never did.

    /// The poll's completions (`AccountStateManager.Impl.removeFinishedPoll()`, the differenceTooLong reset's
    /// completion): pops the head and returns whether it was a poll. Not asserted.
    mutating func popFetchDifference() -> Bool {
        if case .fetchDifference = self.entries.removeFirst().content {
            return true
        } else {
            return false
        }
    }

    /// A `batchUpdates`' timer: pops the head and returns its groups, every group absorbed while it waited included.
    mutating func popBatchUpdates() -> [UpdateGroup]? {
        if case let .batchUpdates(groups) = self.entries.removeFirst().content {
            return groups
        } else {
            assertionFailure()
            return nil
        }
    }

    /// A `gapWait`'s timer.
    mutating func popGapWait() -> Bool {
        if case .gapWait = self.entries.removeFirst().content {
            return true
        } else {
            assertionFailure()
            return false
        }
    }

    mutating func popProcessBatch() -> Bool {
        if case .processBatch = self.entries.removeFirst().content {
            return true
        } else {
            assertionFailure()
            return false
        }
    }

    mutating func popCustom(id: Int32) -> Bool {
        if case .custom(id, _) = self.entries.removeFirst().content {
            return true
        } else {
            assertionFailure()
            return false
        }
    }

    mutating func popDispatchEvents(id: Int32) -> Bool {
        if case .dispatchEvents(id, _) = self.entries.removeFirst().content {
            return true
        } else {
            assertionFailure()
            return false
        }
    }

    /// A barrier's `help.test` round trip: pops the head and returns the message ids and subscribers it holds now,
    /// those that joined while it ran included.
    mutating func popStateBarrier(id: Int32) -> ([MessageId], [(Int32, ([MessageId]) -> Void)])? {
        if case let .stateBarrier(topPollId, messageIds, subscribers) = self.entries.removeFirst().content {
            assert(topPollId == id)
            return (messageIds, subscribers)
        } else {
            assertionFailure()
            return nil
        }
    }

    mutating func popReplayPrebuilt() -> Bool {
        if case .replayPrebuilt = self.entries.removeFirst().content {
            return true
        } else {
            assertionFailure()
            return false
        }
    }
}
