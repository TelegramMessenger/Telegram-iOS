import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedMessageHistoryHolesState {
    private struct LocationKey: Equatable {
        var peerId: PeerId
        var threadId: Int64?
        var space: MessageHistoryHoleSpace
        
        init(peerId: PeerId, threadId: Int64?, space: MessageHistoryHoleSpace) {
            self.peerId = peerId
            self.threadId = threadId
            self.space = space
        }
    }
    
    private struct PendingEntry {
        var key: LocationKey
        var entry: MessageHistoryHolesViewEntry
        var disposable: Disposable
        
        init(key: LocationKey, entry: MessageHistoryHolesViewEntry, disposable: Disposable) {
            self.key = key
            self.entry = entry
            self.disposable = disposable
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
    
    private var pendingEntries: [PendingEntry] = []
    private var discardedEntries: [DiscardedEntry] = []
    
    private let performWork: (@escaping (ManagedMessageHistoryHolesState) -> Void) -> Void
    private var oldEntriesTimer: SwiftSignalKit.Timer?
    
    init(performWork: @escaping (@escaping (ManagedMessageHistoryHolesState) -> Void) -> Void) {
        self.performWork = performWork
    }
    
    deinit {
        self.oldEntriesTimer?.invalidate()
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
                let performWork = self.performWork
                self.oldEntriesTimer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: {
                    performWork { impl in
                        let disposables = impl.discardOldEntries()
                        for disposable in disposables {
                            disposable.dispose()
                        }
                    }
                }, queue: .mainQueue())
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
                self.discardedEntries.remove(at: i)
            }
        }
        
        return result
    }
    
    func update(entries: Set<MessageHistoryHolesViewEntry>) -> (removed: [Disposable], added: [MessageHistoryHolesViewEntry: MetaDisposable], hasOldEntries: Bool) {
        let removed: [Disposable] = []
        var added: [MessageHistoryHolesViewEntry: MetaDisposable] = [:]
        
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        for i in (0 ..< self.pendingEntries.count).reversed() {
            if !entries.contains(self.pendingEntries[i].entry) {
                self.discardedEntries.append(DiscardedEntry(entry: self.pendingEntries[i], timestamp: timestamp))
                self.pendingEntries.remove(at: i)
                //removed.append(self.pendingEntries[i].disposable)
            }
        }
        
        for entry in entries {
            switch entry.hole {
            case let .peer(peerHole):
                let key = LocationKey(peerId: peerHole.peerId, threadId: peerHole.threadId, space: entry.space)
                if !self.pendingEntries.contains(where: { $0.key == key }) {
                    if let discardedIndex = self.discardedEntries.firstIndex(where: { $0.entry.entry == entry }) {
                        let discardedEntry = self.discardedEntries.remove(at: discardedIndex)
                        self.pendingEntries.append(discardedEntry.entry)
                    } else {
                        let disposable = MetaDisposable()
                        self.pendingEntries.append(PendingEntry(key: key, entry: entry, disposable: disposable))
                        added[entry] = disposable
                    }
                }
            }
        }
        
        self.updateNeedsTimer()
        
        return (removed, added, !self.discardedEntries.isEmpty)
    }
}

func managedMessageHistoryHoles(accountPeerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return Signal { _ in
        var performWorkImpl: ((@escaping (ManagedMessageHistoryHolesState) -> Void) -> Void)?
        let state = Atomic(value: ManagedMessageHistoryHolesState(performWork: { f in
            performWorkImpl?(f)
        }))
        performWorkImpl = { [weak state] f in
            state?.with { state in
                f(state)
            }
        }
        
        let disposable = postbox.messageHistoryHolesView().start(next: { view in
            let (removed, added, _) = state.with { state in
                return state.update(entries: view.entries)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                switch entry.hole {
                case let .peer(hole):
                    disposable.set(fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(network), postbox: postbox, peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: entry.direction, space: entry.space, count: entry.count).start())
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            for disposable in state.with({ state -> [Disposable] in
                state.clearDisposables()
            }) {
                disposable.dispose()
            }
        }
    }
}
