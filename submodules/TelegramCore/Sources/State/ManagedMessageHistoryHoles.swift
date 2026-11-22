import Foundation
import Postbox
import SwiftSignalKit

/// How long a fill's entry is not started again once the fill has completed (`completedEntries`).
enum ManagedMessageHistoryHolesPause {
    static let defaultDuration: Double = 20.0

    /// Tests shorten it (and restore it); nothing else writes it.
    static var duration: Double = ManagedMessageHistoryHolesPause.defaultDuration
}

private final class ManagedMessageHistoryHolesContext {
    private struct LocationKey: Equatable {
        var peerId: PeerId
        var threadId: Int64?
        var space: MessageHistoryHoleOperationSpace
        
        init(peerId: PeerId, threadId: Int64?, space: MessageHistoryHoleOperationSpace) {
            self.peerId = peerId
            self.threadId = threadId
            self.space = space
        }
    }
    
    private struct PendingEntry: CustomStringConvertible {
        var id: Int
        var key: LocationKey
        var entry: MessageHistoryHolesViewEntry
        var disposable: MetaDisposable
        
        init(id: Int, key: LocationKey, entry: MessageHistoryHolesViewEntry, disposable: MetaDisposable) {
            self.id = id
            self.key = key
            self.entry = entry
            self.disposable = disposable
        }
        
        var description: String {
            return "entry: \(self.entry)"
        }
    }
    
    private struct DiscardedEntry {
        var entry: PendingEntry
        var timestamp: Double
        
        init(entry: PendingEntry, timestamp: Double) {
            self.entry = entry
            self.timestamp = timestamp
        }
    }
    
    private let queue: Queue
    private let accountPeerId: PeerId
    private let postbox: Postbox
    private let network: Network
    private let pendingReferences: PendingMessageReferences
    
    private var nextEntryId: Int = 0
    private var pendingEntries: [PendingEntry] = []
    private var discardedEntries: [DiscardedEntry] = []
    
    private var oldEntriesTimer: SwiftSignalKit.Timer?
    
    private var currentEntries: Set<MessageHistoryHolesViewEntry> = Set()
    private var currentEntriesDisposable: Disposable?
    
    private var completedEntries: [MessageHistoryHolesViewEntry: Double] = [:]
    
    /// Fires when the earliest pause of a current entry ends (`pauseEnd`), to re-evaluate `currentEntries`.
    private var pauseTimer: SwiftSignalKit.Timer?
    private var pauseEnd: Double?
    
    init(
        queue: Queue,
        accountPeerId: PeerId,
        postbox: Postbox,
        network: Network,
        pendingReferences: PendingMessageReferences,
        entries: Signal<Set<MessageHistoryHolesViewEntry>, NoError>
    ) {
        self.queue = queue
        self.accountPeerId = accountPeerId
        self.postbox = postbox
        self.network = network
        self.pendingReferences = pendingReferences
        
        self.currentEntriesDisposable = (entries |> deliverOn(self.queue)).start(next: { [weak self] entries in
            guard let self = self else {
                return
            }
            // Kept for a fill's completion: the transaction that closes a hole also emits the view's next
            // hole, while the fill is still pending under the same peer, thread and space, so `update`
            // passes it over here and the completion's `update(entries: self.currentEntries)` starts it.
            // Because this is live, a completion re-evaluates the whole current set: it also restarts any
            // entry whose "recently finished" pause (`completedEntries`, `ManagedMessageHistoryHolesPause`) has
            // ended, for any chat (channels and threads too), without waiting for the view's next emission. Before
            // this assignment existed `currentEntries` stayed empty and that call did nothing. The end of a pause
            // re-evaluates it too (`pauseTimer`). `completedEntries` is never pruned by time (as before);
            // `resetPeer` drops a peer's entries.
            self.currentEntries = entries
            self.update(entries: entries)
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.oldEntriesTimer?.invalidate()
        self.pauseTimer?.invalidate()
        self.currentEntriesDisposable?.dispose()
        // The pending fills go with the manager (the account is torn down or resigns master); teardown is not
        // giving up. A fill retries a transient error until it succeeds (HistoryFillRequestRetry.swift), so a
        // fill whose MetaDisposable is merely released keeps retrying for good, holding the Postbox and the
        // network, beside the fill the next manager starts for the same hole.
        for disposable in self.clearDisposables() {
            disposable.dispose()
        }
    }
    
    func resetPeer(peerId: PeerId) {
        for entry in Array(self.completedEntries.keys) {
            switch entry.hole {
            case let .peer(peer):
                if peer.peerId == peerId {
                    self.completedEntries.removeValue(forKey: entry)
                }
            }
        }
    }
    
    func clearDisposables() -> [Disposable] {
        var disposables = Array(self.pendingEntries.map(\.disposable))
        disposables.append(contentsOf: self.discardedEntries.map(\.entry.disposable))
        self.pendingEntries.removeAll()
        self.discardedEntries.removeAll()
        return disposables
    }
    
    private func updateNeedsTimer() {
        let needsTimer = !self.discardedEntries.isEmpty
        if needsTimer {
            if self.oldEntriesTimer == nil {
                self.oldEntriesTimer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                    guard let self = self else {
                        return
                    }
                    let disposables = self.discardOldEntries()
                    for disposable in disposables {
                        disposable.dispose()
                    }
                }, queue: self.queue)
                self.oldEntriesTimer?.start()
            }
        } else if let oldEntriesTimer = self.oldEntriesTimer {
            self.oldEntriesTimer = nil
            oldEntriesTimer.invalidate()
        }
    }
    
    private func discardOldEntries() -> [Disposable] {
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        var result: [Disposable] = []
        for i in (0 ..< self.discardedEntries.count).reversed() {
            if self.discardedEntries[i].timestamp < timestamp - 0.5 {
                result.append(self.discardedEntries[i].entry.disposable)
                Logger.shared.log("ManagedMessageHistoryHoles", "Removing discarded entry \(self.discardedEntries[i].entry)")
                self.discardedEntries.remove(at: i)
            }
        }
        
        return result
    }
    
    /// Re-evaluates `currentEntries` once `end`, the end of the earliest pause of an entry they hold, has passed, so
    /// a fill that closed nothing (a definite answer, or an answer too old to store) starts again while a view still
    /// shows its hole, though no other fill completes and the view does not emit again: history loading never gives
    /// up. A timer already set for an earlier end is kept; that one re-evaluates and sets the next.
    private func updatePauseTimer(earliestPauseEnd end: Double) {
        if let pauseEnd = self.pauseEnd, pauseEnd <= end {
            return
        }
        self.pauseTimer?.invalidate()
        self.pauseEnd = end
        // Just past the end: `update` keeps an entry paused while its pause has not passed.
        let timeout = max(0.0, end - CFAbsoluteTimeGetCurrent()) + 0.05
        let timer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
            guard let self = self else {
                return
            }
            self.pauseTimer = nil
            self.pauseEnd = nil
            self.update(entries: self.currentEntries)
        }, queue: self.queue)
        self.pauseTimer = timer
        timer.start()
    }
    
    func update(entries: Set<MessageHistoryHolesViewEntry>) {
        //let removed: [Disposable] = []
        var added: [PendingEntry] = []
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        let _ = timestamp
        var earliestPauseEnd: Double?
        
        /*for i in (0 ..< self.pendingEntries.count).reversed() {
         if !entries.contains(self.pendingEntries[i].entry) {
         Logger.shared.log("ManagedMessageHistoryHoles", "Stashing entry \(self.pendingEntries[i])")
         self.discardedEntries.append(DiscardedEntry(entry: self.pendingEntries[i], timestamp: timestamp))
         self.pendingEntries.remove(at: i)
         }
         }*/
        
        for entry in entries {
            if let previousTimestamp = self.completedEntries[entry] {
                if previousTimestamp >= CFAbsoluteTimeGetCurrent() - ManagedMessageHistoryHolesPause.duration {
                    Logger.shared.log("ManagedMessageHistoryHoles", "Not adding recently finished entry \(entry)")
                    let pauseEnd = previousTimestamp + ManagedMessageHistoryHolesPause.duration
                    earliestPauseEnd = min(earliestPauseEnd ?? pauseEnd, pauseEnd)
                    continue
                }
            }
            
            switch entry.hole {
            case let .peer(peerHole):
                let key = LocationKey(peerId: peerHole.peerId, threadId: peerHole.threadId, space: entry.space)
                if !self.pendingEntries.contains(where: { $0.key == key }) {
                    if let discardedIndex = self.discardedEntries.firstIndex(where: { $0.entry.entry == entry }) {
                        let discardedEntry = self.discardedEntries.remove(at: discardedIndex)
                        Logger.shared.log("ManagedMessageHistoryHoles", "Taking discarded entry \(discardedEntry.entry)")
                        self.pendingEntries.append(discardedEntry.entry)
                    } else {
                        let disposable = MetaDisposable()
                        let id = self.nextEntryId
                        self.nextEntryId += 1
                        let pendingEntry = PendingEntry(id: id, key: key, entry: entry, disposable: disposable)
                        self.pendingEntries.append(pendingEntry)
                        Logger.shared.log("ManagedMessageHistoryHoles", "Adding pending entry \(pendingEntry), discarded entries: \(self.discardedEntries.map(\.entry))")
                        added.append(pendingEntry)
                    }
                }
            }
        }
        
        self.updateNeedsTimer()
        if let earliestPauseEnd = earliestPauseEnd {
            self.updatePauseTimer(earliestPauseEnd: earliestPauseEnd)
        }
        
        for pendingEntry in added {
            let id = pendingEntry.id
            let entry = pendingEntry.entry
            switch pendingEntry.entry.hole {
            case let .peer(hole):
                pendingEntry.disposable.set((fetchMessageHistoryHole(
                    accountPeerId: self.accountPeerId,
                    source: .network(self.network),
                    postbox: self.postbox,
                    peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: pendingEntry.entry.direction, space: pendingEntry.entry.space, count: pendingEntry.entry.count, pendingReferences: self.pendingReferences)
                |> deliverOn(self.queue)).start(completed: { [weak self] in
                    guard let self = self else {
                        return
                    }
                    self.pendingEntries.removeAll(where: { $0.id == id })
                    self.completedEntries[entry] = CFAbsoluteTimeGetCurrent()
                    self.update(entries: self.currentEntries)
                }))
            }
        }
    }
}

func managedMessageHistoryHoles(accountPeerId: PeerId, network: Network, postbox: Postbox, pendingReferences: PendingMessageReferences) -> ((PeerId) -> Void, Disposable) {
    let sharedQueue = Queue()
    
    var context: QueueLocalObject<ManagedMessageHistoryHolesContext>? = QueueLocalObject<ManagedMessageHistoryHolesContext>(queue: sharedQueue, generate: {
        return ManagedMessageHistoryHolesContext(
            queue: sharedQueue,
            accountPeerId: accountPeerId,
            postbox: postbox,
            network: network,
            pendingReferences: pendingReferences,
            entries: postbox.messageHistoryHolesView() |> map { view in
                return view.entries
            }
        )
    })
    
    return ({ [weak context] peerId in
        context?.with { context in
            context.resetPeer(peerId: peerId)
        }
    }, ActionDisposable {
        if context != nil {
            context = nil
        }
    })
}
