import Foundation
import SwiftSignalKit

public enum ViewUpdateType {
    case Generic
    case FillHole
}

final class ViewTracker {
    private let queue: Queue
    private let fetchEarlierHistoryEntries: (PeerId, MessageIndex?, Int) -> [MutableMessageHistoryEntry]
    private let fetchLaterHistoryEntries: (PeerId, MessageIndex?, Int) -> [MutableMessageHistoryEntry]
    private let fetchEarlierChatEntries: (MessageIndex?, Int) -> [MutableChatListEntry]
    private let fetchLaterChatEntries: (MessageIndex?, Int) -> [MutableChatListEntry]
    private let renderMessage: IntermediateMessage -> Message
    private let fetchMessageHistoryHole: MessageHistoryHole -> Disposable
    
    private var messageHistoryViews: [PeerId: Bag<(MutableMessageHistoryView, Pipe<(MessageHistoryView, ViewUpdateType)>)>] = [:]
    private var chatListViews = Bag<(MutableChatListView, Pipe<(ChatListView, ViewUpdateType)>)>()
    
    private var holeDisposablesByPeerId: [PeerId: [(MessageHistoryHole, Disposable)]] = [:]
    
    init(queue: Queue, fetchEarlierHistoryEntries: (PeerId, MessageIndex?, Int) -> [MutableMessageHistoryEntry], fetchLaterHistoryEntries: (PeerId, MessageIndex?, Int) -> [MutableMessageHistoryEntry], fetchEarlierChatEntries: (MessageIndex?, Int) -> [MutableChatListEntry], fetchLaterChatEntries: (MessageIndex?, Int) -> [MutableChatListEntry], renderMessage: IntermediateMessage -> Message, fetchMessageHistoryHole: MessageHistoryHole -> Disposable) {
        self.queue = queue
        self.fetchEarlierHistoryEntries = fetchEarlierHistoryEntries
        self.fetchLaterHistoryEntries = fetchLaterHistoryEntries
        self.fetchEarlierChatEntries = fetchEarlierChatEntries
        self.fetchLaterChatEntries = fetchLaterChatEntries
        self.renderMessage = renderMessage
        self.fetchMessageHistoryHole = fetchMessageHistoryHole
    }
    
    deinit {
        for (_, indexToDisposable) in holeDisposablesByPeerId {
            for (_, disposable) in indexToDisposable {
                disposable.dispose()
            }
        }
    }
    
    func addMessageHistoryView(peerId: PeerId, view: MutableMessageHistoryView) -> (Bag<(MutableMessageHistoryView, Pipe<(MessageHistoryView, ViewUpdateType)>)>.Index, Signal<(MessageHistoryView, ViewUpdateType), NoError>) {
        let record = (view, Pipe<(MessageHistoryView, ViewUpdateType)>())
        
        let index: Bag<(MutableMessageHistoryView, Pipe<(MessageHistoryView, ViewUpdateType)>)>.Index
        if let bag = self.messageHistoryViews[peerId] {
            index = bag.add(record)
        } else {
            let bag = Bag<(MutableMessageHistoryView, Pipe<(MessageHistoryView, ViewUpdateType)>)>()
            index = bag.add(record)
            self.messageHistoryViews[peerId] = bag
        }
        
        self.updateTrackedHoles(peerId)
        
        return (index, record.1.signal())
    }
    
    func removeMessageHistoryView(peerId: PeerId, index: Bag<(MutableMessageHistoryView, Pipe<(MessageHistoryView, ViewUpdateType)>)>.Index) {
        if let bag = self.messageHistoryViews[peerId] {
            bag.remove(index)
            
            self.updateTrackedHoles(peerId)
        }
    }
    
    func addChatListView(view: MutableChatListView) -> (Bag<(MutableChatListView, Pipe<(ChatListView, ViewUpdateType)>)>.Index, Signal<(ChatListView, ViewUpdateType), NoError>) {
        let record = (view, Pipe<(ChatListView, ViewUpdateType)>())
        
        let index = self.chatListViews.add(record)
        return (index, record.1.signal())
    }
    
    func removeChatListView(index: Bag<(MutableChatListView, Pipe<ChatListView>)>.Index) {
        self.chatListViews.remove(index)
    }
    
    func updateViews(currentOperationsByPeerId currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]], peerIdsWithFilledHoles: Set<PeerId>, chatListOperations: [ChatListOperation], currentUpdatedPeers: [PeerId: Peer]) {
        var updateTrackedHolesPeerIds: [PeerId] = []
        
        for (peerId, bag) in self.messageHistoryViews {
            var updateHoles = false
            if let operations = currentOperationsByPeerId[peerId] {
                updateHoles = true
                for (mutableView, pipe) in bag.copyItems() {
                    let context = MutableMessageHistoryViewReplayContext()
                    var updated = false
                    if mutableView.replay(operations, context: context) {
                        mutableView.complete(context, fetchEarlier: { index, count in
                            return self.fetchEarlierHistoryEntries(peerId, index, count)
                        }, fetchLater: { index, count in
                            return self.fetchLaterHistoryEntries(peerId, index, count)
                        })
                        updated = true
                    }
                    
                    if mutableView.updatePeers(currentUpdatedPeers) {
                        updated = true
                    }
                    
                    if updated {
                        mutableView.render(self.renderMessage)
                        pipe.putNext((MessageHistoryView(mutableView), peerIdsWithFilledHoles.contains(peerId) ? .FillHole : .Generic))
                    }
                }
            }
            
            if updateHoles {
                updateTrackedHolesPeerIds.append(peerId)
            }
        }
        
        if chatListOperations.count != 0 {
            for (mutableView, pipe) in self.chatListViews.copyItems() {
                let context = MutableChatListViewReplayContext()
                if mutableView.replay(chatListOperations, context: context) {
                    mutableView.complete(context, fetchEarlier: self.fetchEarlierChatEntries, fetchLater: self.fetchLaterChatEntries)
                    mutableView.render(self.renderMessage)
                    pipe.putNext((ChatListView(mutableView), .Generic))
                }
            }
        }
        
        for peerId in updateTrackedHolesPeerIds {
            self.updateTrackedHoles(peerId)
        }
    }
    
    func updateTrackedHoles(peerId: PeerId) {
        if let bag = self.messageHistoryViews[peerId]  {
            var disposeHoles: [Disposable] = []
            
            var firstHoles: [MessageHistoryHole] = []
            
            for (view, _) in bag.copyItems() {
                if let hole = view.firstHole() {
                    var exists = false
                    for existingHole in firstHoles {
                        if existingHole == hole {
                            exists = true
                            break
                        }
                    }
                    if !exists {
                        firstHoles.append(hole)
                    }
                }
            }
            
            if let holes = self.holeDisposablesByPeerId[peerId] {
                var i = 0
                for (hole, disposable) in holes {
                    var exists = false
                    for firstHole in firstHoles {
                        if hole == firstHole {
                            exists = true
                            break
                        }
                    }
                    if !exists {
                        disposeHoles.append(disposable)
                        self.holeDisposablesByPeerId[peerId]!.removeAtIndex(i)
                    } else {
                        i++
                    }
                }
            }
            
            for disposable in disposeHoles {
                disposable.dispose()
            }
            
            for hole in firstHoles {
                var exists = false
                if let existingHoles = self.holeDisposablesByPeerId[hole.id.peerId] {
                    for (existingHole, _) in existingHoles {
                        if existingHole == hole {
                            exists = true
                            break
                        }
                    }
                }
                
                if !exists {
                    if self.holeDisposablesByPeerId[hole.id.peerId] == nil {
                        self.holeDisposablesByPeerId[hole.id.peerId] = []
                    }
                    
                    self.holeDisposablesByPeerId[hole.id.peerId]!.append((hole, self.fetchMessageHistoryHole(hole)))
                }
            }
        } else if let holes = self.holeDisposablesByPeerId[peerId] {
            self.holeDisposablesByPeerId[peerId]?.removeAll()
            
            for (_, disposable) in holes {
                disposable.dispose()
            }
        }
    }
}
