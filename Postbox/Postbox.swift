import Foundation
import sqlcipher

#if os(macOS)
    import SwiftSignalKitMac
#else
    import SwiftSignalKit
#endif

public enum PreloadedMessageHistoryView {
    case Loading
    case Preloaded(MessageHistoryView)
}

public protocol PeerChatState: Coding {
    func equals(_ other: PeerChatState) -> Bool
}

public final class Modifier {
    private weak var postbox: Postbox?
    
    fileprivate init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    public func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) {
        self.postbox?.addMessages(messages, location: location)
    }
    
    public func addHole(_ messageId: MessageId) {
        self.postbox?.addHole(messageId)
    }
    
    public func fillHole(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        self.postbox?.fillHole(hole, fillType: fillType, tagMask: tagMask, messages: messages)
    }
    
    public func replaceChatListHole(_ index: MessageIndex, hole: ChatListHole?) {
        self.postbox?.replaceChatListHole(index, hole: hole)
    }
    
    public func deleteMessages(_ messageIds: [MessageId]) {
        self.postbox?.deleteMessages(messageIds)
    }
    
    public func deleteMessagesWithGlobalIds(_ ids: [Int32]) {
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForGlobalIds(ids)
            postbox.deleteMessages(messageIds)
        }
    }
    
    public func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.postbox?.resetIncomingReadStates(states)
    }
    
    public func confirmSynchronizedIncomingReadState(_ peerId: PeerId) {
        self.postbox?.confirmSynchronizedIncomingReadState(peerId)
    }
    
    public func applyIncomingReadMaxId(_ messageId: MessageId) {
        self.postbox?.applyIncomingReadMaxId(messageId)
    }
    
    public func applyOutgoingReadMaxId(_ messageId: MessageId) {
        self.postbox?.applyOutgoingReadMaxId(messageId)
    }
    
    public func applyInteractiveReadMaxId(_ messageId: MessageId) {
        self.postbox?.applyInteractiveReadMaxId(messageId)
    }
    
    public func getState() -> Coding? {
        return self.postbox?.getState()
    }
    
    public func setState(_ state: Coding) {
        self.postbox?.setState(state)
    }
    
    public func getPeerChatState(_ id: PeerId) -> PeerChatState? {
        return self.postbox?.peerChatStateTable.get(id) as? PeerChatState
    }
    
    public func setPeerChatState(_ id: PeerId, state: PeerChatState) {
        self.postbox?.peerChatStateTable.set(id, state: state)
    }
    
    public func getPeer(_ id: PeerId) -> Peer? {
        return self.postbox?.peerTable.get(id)
    }
    
    public func getPeerReadStates(_ id: PeerId) -> [(MessageId.Namespace, PeerReadState)]? {
        return self.postbox?.readStateTable.getCombinedState(id)?.states
    }
    
    public func updatePeers(_ peers: [Peer], update: (Peer, Peer) -> Peer?) {
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        self.postbox?.replaceContactPeerIds(peerIds)
    }
    
    public func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        self.postbox?.replaceRecentPeerIds(peerIds)
    }
    
    public func updateMessage(_ index: MessageIndex, update: (Message) -> StoreMessage) {
        self.postbox?.updateMessage(index, update: update)
    }
    
    public func updateMedia(_ id: MediaId, update: Media?) {
        self.postbox?.updateMedia(id, update: update)
    }
    
    public func getMessage(_ id: MessageId) -> Message? {
        if let postbox = self.postbox {
            if let entry = postbox.messageHistoryIndexTable.get(id) {
                if case let .Message(index) = entry {
                    if let message = postbox.messageHistoryTable.getMessage(index) {
                        return postbox.renderIntermediateMessage(message)
                    }
                }
            }
        }
        return nil
    }
    
    public func filterStoredMessageIds(_ messageIds: Set<MessageId>) -> Set<MessageId> {
        if let postbox = self.postbox {
            return postbox.filterStoredMessageIds(messageIds)
        }
        return Set()
    }
}

fileprivate class PipeNotifier: NSObject {
    let notifier: RLMNotifier
    let thread: Thread
    
    fileprivate init(basePath: String, notify: @escaping () -> Void) {
        self.notifier = RLMNotifier(basePath: basePath, notify: notify)
        self.thread = Thread(target: PipeNotifier.self, selector: #selector(PipeNotifier.threadEntry(_:)), object: self.notifier)
        self.thread.start()
    }
    
    @objc static func threadEntry(_ notifier: RLMNotifier!) {
        notifier.listen()
    }
    
    func notify() {
        notifier.notifyOtherRealms()
    }
}

public final class Postbox {
    private let seedConfiguration: SeedConfiguration
    private let basePath: String
    private let globalMessageIdsNamespace: MessageId.Namespace
    
    private let ipcNotificationsDisposable = MetaDisposable()
    private var pipeNotifier: PipeNotifier!
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var transactionStateVersion: Int64 = 0
    
    private var viewTracker: ViewTracker!
    private var nextViewId = 0
    
    private var peerPipes: [PeerId: ValuePipe<Peer>] = [:]
    
    private var currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
    private var currentUnsentOperations: [IntermediateMessageHistoryUnsentOperation] = []
    private var currentUpdatedSynchronizeReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    private var currentUpdatedMedia: [MediaId: Media?] = [:]
    
    private var currentRemovedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentFilledHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentUpdatedPeers: [PeerId: Peer] = [:]
    private var currentReplaceChatListHoles: [(MessageIndex, ChatListHole?)] = []
    private var currentReplacedContactPeerIds: Set<PeerId>?
    private var currentUpdatedMasterClientId: Int64?
    
    private var statePipe: ValuePipe<Coding> = ValuePipe()
    private var masterClientId = Promise<Int64>()
    
    private var sessionClientId: Int64 = {
        var value: Int64 = 0
        arc4random_buf(&value, 8)
        return value
    }()
    
    public let mediaBox: MediaBox
    
    var tables: [Table] = []
    
    var metadataTable: MetadataTable!
    var keychainTable: KeychainTable!
    var peerTable: PeerTable!
    var globalMessageIdsTable: GlobalMessageIdsTable!
    var messageHistoryIndexTable: MessageHistoryIndexTable!
    var messageHistoryTable: MessageHistoryTable!
    var mediaTable: MessageMediaTable!
    var mediaCleanupTable: MediaCleanupTable!
    var chatListIndexTable: ChatListIndexTable!
    var chatListTable: ChatListTable!
    var messageHistoryMetadataTable: MessageHistoryMetadataTable!
    var messageHistoryUnsentTable: MessageHistoryUnsentTable!
    var messageHistoryTagsTable: MessageHistoryTagsTable!
    var peerChatStateTable: PeerChatStateTable!
    var readStateTable: MessageHistoryReadStateTable!
    var synchronizeReadStateTable: MessageHistorySynchronizeReadStateTable!
    var contactsTable: ContactTable!
    
    //temporary
    var peerRatingTable: RatingTable<PeerId>!
    
    
    public init(basePath: String, globalMessageIdsNamespace: MessageId.Namespace, seedConfiguration: SeedConfiguration) {
        self.basePath = basePath
        self.globalMessageIdsNamespace = globalMessageIdsNamespace
        self.seedConfiguration = seedConfiguration
        
        print("MediaBox path: \(self.basePath + "/media")")
        
        //let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        
        self.mediaBox = MediaBox(basePath: self.basePath + "/media")
        
        self.pipeNotifier = PipeNotifier(basePath: basePath, notify: { [weak self] in
            if let strongSelf = self {
                strongSelf.queue.async {
                    if strongSelf.valueBox != nil {
                        let _ = strongSelf.modify({ _ -> Void in
                        }).start()
                    }
                }
            }
        })
        
        self.openDatabase()
    }
    
    private func debugSaveState(name: String) {
        let path = self.basePath + name
        let _ = try? FileManager.default.removeItem(atPath: path)
        do {
            try FileManager.default.copyItem(atPath: self.basePath, toPath: path)
        } catch (let e) {
            print("(Postbox debugSaveState: error \(e))")
        }
    }
    
    private func debugRestoreState(name: String) {
        let path = self.basePath + name
        let _ = try? FileManager.default.removeItem(atPath: self.basePath)
        do {
            try FileManager.default.copyItem(atPath: path, toPath: self.basePath)
        } catch (let e) {
            print("(Postbox debugRestoreState: error \(e))")
        }
    }
    
    private func openDatabase() {
        self.queue.justDispatch({
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
            } catch _ {
            }
            
            //let _ = try? NSFileManager.defaultManager().removeItemAtPath(self.basePath + "/media")
            
            //#if TARGET_IPHONE_SIMULATOR
            
            //self.debugRestoreState("_empty")
            
            // debugging large amount of updates
            //self.debugSaveState("beforeHoles")
            //self.debugRestoreState("beforeHoles")
            
            // debugging unread counters
            //self.debugRestoreState("afterLogin")
            
            //self.debugSaveState(name: "previous")
            //self.debugRestoreState(name: "previous")
            
            //#endif
            
            self.valueBox = SqliteValueBox(basePath: self.basePath + "/db", queue: self.queue)
            
            self.metadataTable = MetadataTable(valueBox: self.valueBox, tableId: 0)
            
            let userVersion: Int32? = self.metadataTable.userVersion()
            let currentUserVersion: Int32 = 8
            
            if userVersion != currentUserVersion {
                self.valueBox.drop()
                self.metadataTable.setUserVersion(currentUserVersion)
            }
            
            self.keychainTable = KeychainTable(valueBox: self.valueBox, tableId: 1)
            self.peerTable = PeerTable(valueBox: self.valueBox, tableId: 2)
            self.globalMessageIdsTable = GlobalMessageIdsTable(valueBox: self.valueBox, tableId: 3, namespace: self.globalMessageIdsNamespace)
            self.messageHistoryMetadataTable = MessageHistoryMetadataTable(valueBox: self.valueBox, tableId: 10)
            self.messageHistoryUnsentTable = MessageHistoryUnsentTable(valueBox: self.valueBox, tableId: 11)
            self.messageHistoryTagsTable = MessageHistoryTagsTable(valueBox: self.valueBox, tableId: 12)
            self.messageHistoryIndexTable = MessageHistoryIndexTable(valueBox: self.valueBox, tableId: 4, globalMessageIdsTable: self.globalMessageIdsTable, metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
            self.mediaCleanupTable = MediaCleanupTable(valueBox: self.valueBox, tableId: 5)
            self.mediaTable = MessageMediaTable(valueBox: self.valueBox, tableId: 6, mediaCleanupTable: self.mediaCleanupTable)
            self.readStateTable = MessageHistoryReadStateTable(valueBox: self.valueBox, tableId: 14)
            self.synchronizeReadStateTable = MessageHistorySynchronizeReadStateTable(valueBox: self.valueBox, tableId: 15)
            self.messageHistoryTable = MessageHistoryTable(valueBox: self.valueBox, tableId: 7, messageHistoryIndexTable: self.messageHistoryIndexTable, messageMediaTable: self.mediaTable, historyMetadataTable: self.messageHistoryMetadataTable, unsentTable: self.messageHistoryUnsentTable!, tagsTable: self.messageHistoryTagsTable, readStateTable: self.readStateTable, synchronizeReadStateTable: self.synchronizeReadStateTable!)
            self.chatListIndexTable = ChatListIndexTable(valueBox: self.valueBox, tableId: 8)
            self.chatListTable = ChatListTable(valueBox: self.valueBox, tableId: 9, indexTable: self.chatListIndexTable, metadataTable: self.messageHistoryMetadataTable, seedConfiguration: self.seedConfiguration)
            self.peerChatStateTable = PeerChatStateTable(valueBox: self.valueBox, tableId: 13)
            self.contactsTable = ContactTable(valueBox: self.valueBox, tableId: 16)
            self.peerRatingTable = RatingTable<PeerId>(valueBox: self.valueBox, tableId: 17)
            
            self.tables.append(self.keychainTable)
            self.tables.append(self.peerTable)
            self.tables.append(self.globalMessageIdsTable)
            self.tables.append(self.messageHistoryMetadataTable)
            self.tables.append(self.messageHistoryUnsentTable)
            self.tables.append(self.messageHistoryTagsTable)
            self.tables.append(self.messageHistoryIndexTable)
            self.tables.append(self.mediaCleanupTable)
            self.tables.append(self.mediaTable)
            self.tables.append(self.readStateTable)
            self.tables.append(self.synchronizeReadStateTable)
            self.tables.append(self.messageHistoryTable)
            self.tables.append(self.chatListIndexTable)
            self.tables.append(self.chatListTable)
            self.tables.append(self.peerChatStateTable)
            self.tables.append(self.contactsTable)
            self.tables.append(self.peerRatingTable)
            
            self.transactionStateVersion = self.metadataTable.transactionStateVersion()
            
            self.viewTracker = ViewTracker(queue: self.queue, fetchEarlierHistoryEntries: self.fetchEarlierHistoryEntries, fetchLaterHistoryEntries: self.fetchLaterHistoryEntries, fetchEarlierChatEntries: self.fetchEarlierChatEntries, fetchLaterChatEntries: self.fetchLaterChatEntries, fetchAnchorIndex: self.fetchAnchorIndex, renderMessage: self.renderIntermediateMessage, getPeer: { peerId in
                return self.peerTable.get(peerId)
            }, unsentMessageIndices: self.messageHistoryUnsentTable!.get(), synchronizePeerReadStateOperations: self.synchronizeReadStateTable!.get())
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        })
    }
    
    private func takeNextViewId() -> Int {
        let nextId = self.nextViewId
        self.nextViewId += 1
        return nextId
    }
    
    private var cachedState: Coding?
    
    fileprivate func setState(_ state: Coding) {
        self.cachedState = state
        
        self.metadataTable.setState(state)
        
        self.statePipe.putNext(state)
    }
    
    fileprivate func getState() -> Coding? {
        if let cachedState = self.cachedState {
            return cachedState
        } else {
            if let state = self.metadataTable.state() {
                self.cachedState = state
                return state
            }
            
            return nil
        }
    }
    
    @available(*, deprecated: 1.0)
    public func state() -> Signal<Coding?, NoError> {
        return self.modify { modifier -> Signal<Coding?, NoError> in
            return Signal<Coding?, NoError>.single(self.getState())
                |> then(self.statePipe.signal() |> map { $0 })
        } |> switchToLatest
    }
    
    public func keychainEntryForKey(_ key: String) -> Data? {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var entry: Data? = nil
        let disposable = (self.modify({ modifier -> Data? in
            return self.keychainTable.get(key)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start(next: { data in
            entry = data
            semaphore.signal()
        })
        metaDisposable.set(disposable)
        
        semaphore.wait()
        return entry
    }
    
    private var keychainOperationsDisposable = DisposableSet()
    
    public func setKeychainEntryForKey(_ key: String, value: Data) {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let disposable = (self.modify({ modifier -> Void in
            self.keychainTable.set(key, value: value)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start()
        metaDisposable.set(disposable)
    }
    
    public func removeKeychainEntryForKey(_ key: String) {
        let metaDisposable = MetaDisposable()
        self.keychainOperationsDisposable.add(metaDisposable)
        
        let disposable = (self.modify({ modifier -> Void in
            self.keychainTable.remove(key)
        }) |> afterDisposed { [weak self, weak metaDisposable] in
            if let strongSelf = self, let metaDisposable = metaDisposable {
                strongSelf.keychainOperationsDisposable.remove(metaDisposable)
            }
        }).start()
        metaDisposable.set(disposable)
    }
    
    fileprivate func addMessages(_ messages: [StoreMessage], location: AddMessagesLocation) {
        self.messageHistoryTable.addMessages(messages, location: location, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func addHole(_ id: MessageId) {
        self.messageHistoryTable.addHoles([id], operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func fillHole(_ hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.messageHistoryTable.fillHole(hole.id, fillType: fillType, tagMask: tagMask, messages: messages, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        for (peerId, operations) in operationsByPeerId {
            if self.currentOperationsByPeerId[peerId] == nil {
                self.currentOperationsByPeerId[peerId] = operations
            } else {
                self.currentOperationsByPeerId[peerId]!.append(contentsOf: operations)
            }
            
            var filledMessageIndices: [MessageIndex: HoleFillDirection] = [:]
            for operation in operations {
                switch operation {
                    case let .InsertHole(hole):
                        filledMessageIndices[hole.maxIndex] = fillType.direction
                    case let .InsertMessage(message):
                        filledMessageIndices[MessageIndex(message)] = fillType.direction
                    default:
                        break
                }
            }
            
            if !filledMessageIndices.isEmpty {
                if self.currentFilledHolesByPeerId[peerId] == nil {
                    self.currentFilledHolesByPeerId[peerId] = filledMessageIndices
                } else {
                    for (messageIndex, direction) in filledMessageIndices {
                        self.currentFilledHolesByPeerId[peerId]![messageIndex] = direction
                    }
                }
            }
            
            if self.currentRemovedHolesByPeerId[peerId] == nil {
                self.currentRemovedHolesByPeerId[peerId] = [hole.maxIndex: fillType.direction]
            } else {
                self.currentRemovedHolesByPeerId[peerId]![hole.maxIndex] = fillType.direction
            }
        }
    }
    
    fileprivate func replaceChatListHole(_ index: MessageIndex, hole: ChatListHole?) {
        self.currentReplaceChatListHoles.append((index, hole))
    }
    
    fileprivate func deleteMessages(_ messageIds: [MessageId]) {
        self.messageHistoryTable.removeMessages(messageIds, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func resetIncomingReadStates(_ states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.messageHistoryTable.resetIncomingReadStates(states, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func confirmSynchronizedIncomingReadState(_ peerId: PeerId) {
        self.synchronizeReadStateTable.set(peerId, operation: nil, operations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyIncomingReadMaxId(_ messageId: MessageId) {
        self.messageHistoryTable.applyIncomingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyOutgoingReadMaxId(_ messageId: MessageId) {
        self.messageHistoryTable.applyOutgoingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    fileprivate func applyInteractiveReadMaxId(_ messageId: MessageId) {
        self.messageHistoryTable.applyInteractiveMaxReadId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func fetchEarlierHistoryEntries(_ peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.earlierEntries(tagMask, peerId: peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            intermediateEntries = self.messageHistoryTable.earlierEntries(peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, nil))
                case let .Hole(index):
                    entries.append(.HoleEntry(index, nil))
            }
        }
        return entries
    }
    
    private func fetchAroundHistoryEntries(_ index: MessageIndex, count: Int, tagMask: MessageTags? = nil) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?) {
        
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        let intermediateLower: IntermediateMessageHistoryEntry?
        let intermediateUpper: IntermediateMessageHistoryEntry?
        
        if let tagMask = tagMask {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(tagMask, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, nil))
                case let .Hole(index):
                    entries.append(.HoleEntry(index, nil))
            }
        }
        
        var lower: MutableMessageHistoryEntry?
        if let intermediateLower = intermediateLower {
            switch intermediateLower {
                case let .Message(message):
                    lower = .IntermediateMessageEntry(message, nil)
                case let .Hole(index):
                    lower = .HoleEntry(index, nil)
            }
        }
        
        var upper: MutableMessageHistoryEntry?
        if let intermediateUpper = intermediateUpper {
            switch intermediateUpper {
                case let .Message(message):
                    upper = .IntermediateMessageEntry(message, nil)
                case let .Hole(index):
                    upper = .HoleEntry(index, nil)
            }
        }
        
        if let tagMask = tagMask {
            return addLocationsToMessageHistoryViewEntries(tagMask: tagMask, earlier: lower, later: upper, entries: entries)
        } else {
            return (entries: entries, lower: lower, upper: upper)
        }
    }
    
    private func fetchLaterHistoryEntries(_ peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.laterEntries(tagMask, peerId: peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        } else {
            intermediateEntries = self.messageHistoryTable.laterEntries(peerId, index: index, count: count, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message, nil))
            case let .Hole(index):
                entries.append(.HoleEntry(index, nil))
            }
        }
        return entries
    }
    
    private func fetchAroundChatEntries(_ index: MessageIndex, count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?) {
        let (intermediateEntries, intermediateLower, intermediateUpper) = self.chatListTable.entriesAround(index, messageHistoryTable: self.messageHistoryTable, count: count)
        var entries: [MutableChatListEntry] = []
        var lower: MutableChatListEntry?
        var upper: MutableChatListEntry?
        
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, self.readStateTable.getCombinedState(message.id.peerId)))
                case let .Hole(hole):
                    entries.append(.HoleEntry(hole))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
            }
        }
        
        if let intermediateLower = intermediateLower {
            switch intermediateLower {
                case let .Message(message):
                    lower = .IntermediateMessageEntry(message, self.readStateTable.getCombinedState(message.id.peerId))
                case let .Hole(hole):
                    lower = .HoleEntry(hole)
                case let .Nothing(index):
                    lower = .Nothing(index)
            }
        }
        
        if let intermediateUpper = intermediateUpper {
            switch intermediateUpper {
                case let .Message(message):
                    upper = .IntermediateMessageEntry(message, self.readStateTable.getCombinedState(message.id.peerId))
                case let .Hole(hole):
                    upper = .HoleEntry(hole)
                case let .Nothing(index):
                    upper = .Nothing(index)
            }
        }
        
        return (entries, lower, upper)
    }
    
    private func fetchEarlierChatEntries(_ index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.earlierEntries(index, messageHistoryTable: self.messageHistoryTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, self.readStateTable.getCombinedState(message.id.peerId)))
                case let .Hole(hole):
                    entries.append(.HoleEntry(hole))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
            }
        }
        return entries
    }
    
    private func fetchLaterChatEntries(_ index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
        let intermediateEntries = self.chatListTable.laterEntries(index, messageHistoryTable: self.messageHistoryTable, count: count)
        var entries: [MutableChatListEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message, self.readStateTable.getCombinedState(message.id.peerId)))
                case let .Nothing(index):
                    entries.append(.Nothing(index))
                case let .Hole(index):
                    entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchAnchorIndex(_ id: MessageId) -> MessageHistoryAnchorIndex? {
        return self.messageHistoryTable.anchorIndex(id)
    }
    
    fileprivate func renderIntermediateMessage(_ message: IntermediateMessage) -> Message {
        return self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable)
    }
    
    private func afterBegin() {
        let currentTransactionStateVersion = self.metadataTable.transactionStateVersion()
        if currentTransactionStateVersion != self.transactionStateVersion {
            for table in self.tables {
                table.clearMemoryCache()
            }
            self.viewTracker.refreshViewsDueToExternalTransaction(fetchAroundChatEntries: self.fetchAroundChatEntries, fetchAroundHistoryEntries: self.fetchAroundHistoryEntries, fetchUnsendMessageIndices: {
                return self.messageHistoryUnsentTable!.get()
            }, fetchSynchronizePeerReadStateOperations: {
                return self.synchronizeReadStateTable!.get()
            })
            self.transactionStateVersion = currentTransactionStateVersion
            
            self.masterClientId.set(.single(self.metadataTable.masterClientId()))
        }
    }
    
    private func beforeCommit() -> (updatedTransactionStateVersion: Int64?, updatedMasterClientId: Int64?) {
        var chatListOperations: [ChatListOperation] = []
        self.chatListTable.replay(self.currentOperationsByPeerId, messageHistoryTable: self.messageHistoryTable, operations: &chatListOperations)
        for (index, hole) in self.currentReplaceChatListHoles {
            self.chatListTable.replaceHole(index, hole: hole, operations: &chatListOperations)
        }
        
        let transaction = PostboxTransaction(currentOperationsByPeerId: self.currentOperationsByPeerId, peerIdsWithFilledHoles: self.currentFilledHolesByPeerId, removedHolesByPeerId: self.currentRemovedHolesByPeerId, chatListOperations: chatListOperations, currentUpdatedPeers: self.currentUpdatedPeers, unsentMessageOperations: self.currentUnsentOperations, updatedSynchronizePeerReadStateOperations: self.currentUpdatedSynchronizeReadStateOperations, updatedMedia: self.currentUpdatedMedia, replaceContactPeerIds: self.currentReplacedContactPeerIds, currentUpdatedMasterClientId: currentUpdatedMasterClientId)
        var updatedTransactionState: Int64?
        var updatedMasterClientId: Int64?
        if !transaction.isEmpty {
            self.viewTracker.updateViews(transaction: transaction)
            self.transactionStateVersion = self.metadataTable.incrementTransactionStateVersion()
            updatedTransactionState = self.transactionStateVersion
            
            if let currentUpdatedMasterClientId = self.currentUpdatedMasterClientId {
                self.metadataTable.setMasterClientId(currentUpdatedMasterClientId)
                updatedMasterClientId = currentUpdatedMasterClientId
            }
        }
        
        self.currentOperationsByPeerId.removeAll()
        self.currentFilledHolesByPeerId.removeAll()
        self.currentRemovedHolesByPeerId.removeAll()
        self.currentUpdatedPeers.removeAll()
        self.currentReplaceChatListHoles.removeAll()
        self.currentUnsentOperations.removeAll()
        self.currentUpdatedSynchronizeReadStateOperations.removeAll()
        self.currentUpdatedMedia.removeAll()
        self.currentReplacedContactPeerIds = nil
        self.currentUpdatedMasterClientId = nil
        
        for table in self.tables {
            table.beforeCommit()
        }
        
        return (updatedTransactionState, updatedMasterClientId)
    }
    
    fileprivate func messageIdsForGlobalIds(_ ids: [Int32]) -> [MessageId] {
        var result: [MessageId] = []
        for globalId in ids {
            if let id = self.globalMessageIdsTable.get(globalId) {
                result.append(id)
            }
        }
        return result
    }
    
    fileprivate func updatePeers(_ peers: [Peer], update: (Peer, Peer) -> Peer?) {
        for peer in peers {
            if let currentPeer = self.peerTable.get(peer.id) {
                if let updatedPeer = update(currentPeer, peer) {
                    self.peerTable.set(updatedPeer)
                    self.currentUpdatedPeers[updatedPeer.id] = updatedPeer
                }
            } else {
                self.peerTable.set(peer)
            }
        }
    }
    
    fileprivate func replaceContactPeerIds(_ peerIds: Set<PeerId>) {
        self.contactsTable.replace(peerIds)
        
        self.currentReplacedContactPeerIds = peerIds
    }
    
    fileprivate func replaceRecentPeerIds(_ peerIds: [PeerId]) {
        self.peerRatingTable.replace(items: peerIds)
    }
    
    fileprivate func updateMessage(_ index: MessageIndex, update: (Message) -> StoreMessage) {
        if let intermediateMessage = self.messageHistoryTable.getMessage(index) {
            let message = self.renderIntermediateMessage(intermediateMessage)
            self.messageHistoryTable.updateMessage(index.id, message: update(message), operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
    }
    
    fileprivate func updateMedia(_ id: MediaId, update: Media?) {
        self.messageHistoryTable.updateMedia(id, media: update, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia)
    }
    
    fileprivate func filterStoredMessageIds(_ messageIds: Set<MessageId>) -> Set<MessageId> {
        var filteredIds = Set<MessageId>()
        
        for id in messageIds {
            if self.messageHistoryIndexTable.exists(id) {
                filteredIds.insert(id)
            }
        }
        
        return filteredIds
    }
    
    public func modify<T>(_ f: @escaping(Modifier) -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch {
                self.valueBox.begin()
                self.afterBegin()
                let result = f(Modifier(postbox: self))
                let (updatedTransactionState, updatedMasterClientId) = self.beforeCommit()
                self.valueBox.commit()
                
                subscriber.putNext(result)
                subscriber.putCompletion()
                
                if updatedTransactionState != nil || updatedMasterClientId != nil {
                    self.pipeNotifier.notify()
                }
                
                if let updatedMasterClientId = updatedMasterClientId {
                    self.masterClientId.set(.single(updatedMasterClientId))
                }
            }
            return EmptyDisposable
        }
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.modify { modifier -> Signal<(MessageHistoryView, ViewUpdateType), NoError> in
            var index = MessageHistoryAnchorIndex(index: MessageIndex.upperBound(peerId: peerId), exact: true)
            if let maxReadIndex = self.messageHistoryTable.maxReadIndex(peerId) {
                index = maxReadIndex
            }
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index.index, count: count, anchorIndex: index, unreadIndex: index.index, fixedCombinedReadState: nil, tagMask: tagMask)
        } |> switchToLatest
    }
    
    public func aroundIdMessageHistoryViewForPeerId(_ peerId: PeerId, count: Int, messageId: MessageId, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.modify { modifier -> Signal<(MessageHistoryView, ViewUpdateType), NoError> in
            var index = MessageHistoryAnchorIndex(index: MessageIndex.upperBound(peerId: peerId), exact: true)
            if let anchorIndex = self.messageHistoryTable.anchorIndex(messageId) {
                index = anchorIndex
            }
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index.index, count: count, anchorIndex: index, unreadIndex: index.index, fixedCombinedReadState: nil, tagMask: tagMask)
        } |> switchToLatest
    }
    
    public func aroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.modify { modifier -> Signal<(MessageHistoryView, ViewUpdateType), NoError> in
            return self.syncAroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: MessageHistoryAnchorIndex(index: anchorIndex, exact: true), unreadIndex: nil, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask)
        } |> switchToLatest
    }
    
    private func addLocationsToMessageHistoryViewEntries(tagMask: MessageTags, earlier: MutableMessageHistoryEntry?, later: MutableMessageHistoryEntry?, entries: [MutableMessageHistoryEntry]) -> ([MutableMessageHistoryEntry], MutableMessageHistoryEntry?, MutableMessageHistoryEntry?) {
        if let firstEntry = entries.first {
            if let location = self.messageHistoryTagsTable.entryLocation(at: firstEntry.index, tagMask: tagMask) {
                var mappedEarlier = earlier?.updatedLocation(location.predecessor)
                var mappedEntries: [MutableMessageHistoryEntry] = []
                var previousLocation: MessageHistoryEntryLocation?
                for i in 0 ..< entries.count {
                    if i == 0 {
                        mappedEntries.append(entries[i].updatedLocation(location))
                        previousLocation = location
                    } else {
                        previousLocation = previousLocation?.successor
                        mappedEntries.append(entries[i].updatedLocation(previousLocation))
                    }
                }
                previousLocation = previousLocation?.successor
                var mappedLater = later?.updatedLocation(previousLocation)
                return (mappedEntries, mappedEarlier, mappedLater)
            } else {
                return (entries, earlier, later)
            }
        } else {
            return (entries, earlier, later)
        }
    }
    
    private func syncAroundMessageHistoryViewForPeerId(_ peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageHistoryAnchorIndex, unreadIndex: MessageIndex?, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        let startTime = CFAbsoluteTimeGetCurrent()
        let (entries, earlier, later) = self.fetchAroundHistoryEntries(index, count: count, tagMask: tagMask)
        print("aroundMessageHistoryViewForPeerId fetchAroundHistoryEntries \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        
        let mutableView = MutableMessageHistoryView(id: MessageHistoryViewId(peerId: peerId, id: self.takeNextViewId()), anchorIndex: anchorIndex, combinedReadState: fixedCombinedReadState ?? self.readStateTable.getCombinedState(peerId), earlier: earlier, entries: entries, later: later, tagMask: tagMask, count: count)
        mutableView.render(self.renderIntermediateMessage)
        
        let initialUpdateType: ViewUpdateType
        if let unreadIndex = unreadIndex {
            initialUpdateType = .InitialUnread(unreadIndex)
        } else {
            initialUpdateType = .Generic
        }
        
        let (index, signal) = self.viewTracker.addMessageHistoryView(peerId, view: mutableView)
        
        return (.single((MessageHistoryView(mutableView), initialUpdateType))
            |> then(signal))
            |> afterDisposed { [weak self] in
                if let strongSelf = self {
                    strongSelf.queue.async {
                        strongSelf.viewTracker.removeMessageHistoryView(peerId, index: index)
                    }
                }
            }
    }
    
    public func messageIndexAtId(_ id: MessageId) -> Signal<MessageIndex?, NoError> {
        return self.modify { modifier -> Signal<MessageIndex?, NoError> in
            if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                return .single(index)
            } else if let _ = self.messageHistoryIndexTable.holeContainingId(id) {
                return .single(nil)
            } else {
                return .single(nil)
            }
        } |> switchToLatest
    }
    
    public func messageAtId(_ id: MessageId) -> Signal<Message?, NoError> {
        return self.modify { modifier -> Signal<Message?, NoError> in
            if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                if let message = self.messageHistoryTable.getMessage(index) {
                    return .single(self.renderIntermediateMessage(message))
                } else {
                    return .single(nil)
                }
            } else if let _ = self.messageHistoryIndexTable.holeContainingId(id) {
                return .single(nil)
            } else {
                return .single(nil)
            }
        } |> switchToLatest
    }
    
    public func tailChatListView(_ count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.aroundChatListView(MessageIndex.absoluteUpperBound(), count: count)
    }
    
    public func aroundChatListView(_ index: MessageIndex, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.modify { modifier -> Signal<(ChatListView, ViewUpdateType), NoError> in
            let (entries, earlier, later) = self.fetchAroundChatEntries(index, count: count)
            
            let mutableView = MutableChatListView(earlier: earlier, entries: entries, later: later, count: count)
            mutableView.render(self.renderIntermediateMessage)
            
            let (index, signal) = self.viewTracker.addChatListView(mutableView)
            
            return (.single((ChatListView(mutableView), .Generic))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeChatListView(index)
                        }
                    }
                }
        } |> switchToLatest
    }
    
    public func contactPeerIdsView() -> Signal<ContactPeerIdsView, NoError> {
        return self.modify { modifier -> Signal<ContactPeerIdsView, NoError> in
            let view = MutableContactPeerIdsView(peerIds: self.contactsTable.get())
            let (index, signal) = self.viewTracker.addContactPeerIdsView(view)
            
            return (.single(ContactPeerIdsView(view))
                |> then(signal))
                |> afterDisposed { [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeContactPeerIdsView(index)
                        }
                    }
            }
        } |> switchToLatest
    }
    
    public func contactPeersView(index: PeerNameIndex, accountPeerId: PeerId) -> Signal<ContactPeersView, NoError> {
        return self.modify { modifier -> Signal<ContactPeersView, NoError> in
            var peers: [PeerId: Peer] = [:]
            
            for peerId in self.contactsTable.get() {
                if let peer = self.peerTable.get(peerId) {
                    peers[peerId] = peer
                }
            }
            
            let view = MutableContactPeersView(peers: peers, index: index, accountPeer: self.peerTable.get(accountPeerId))
            let (index, signal) = self.viewTracker.addContactPeersView(view)
            
            return (.single(ContactPeersView(view))
                |> then(signal))
                |> afterDisposed {
                    [weak self] in
                    if let strongSelf = self {
                        strongSelf.queue.async {
                            strongSelf.viewTracker.removeContactPeersView(index)
                        }
                    }
                }
        } |> switchToLatest
    }
    
    public func searchContacts(query: String) -> Signal<[Peer], NoError> {
        return self.modify { modifier -> Signal<[Peer], NoError> in
            var peers: [Peer] = []
            for peerId in self.contactsTable.get() {
                if let peer = self.peerTable.get(peerId) {
                    if peer.indexName.match(query: query) {
                        peers.append(peer)
                    }
                }
            }
            
            peers.sort(by: { $0.indexName.indexName(.lastNameFirst) < $1.indexName.indexName(.lastNameFirst) })
            return .single(peers)
        } |> switchToLatest
    }
    
    public func peerWithId(_ id: PeerId) -> Signal<Peer, NoError> {
        return self.modify { modifier -> Signal<Peer, NoError> in
            if let peer = self.peerTable.get(id) {
                return .single(peer)
            } else {
                return .never()
            }
        } |> switchToLatest
    }
    
    public func updateMessageHistoryViewVisibleRange(_ id: MessageHistoryViewId, earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex) {
        self.modify({ modifier -> Void in
            self.viewTracker.updateMessageHistoryViewVisibleRange(id, earliestVisibleIndex: earliestVisibleIndex, latestVisibleIndex: latestVisibleIndex)
        }).start()
    }
    
    public func recentPeers() -> Signal<[Peer], NoError> {
        return self.modify { modifier -> Signal<[Peer], NoError> in
            let peerIds = self.peerRatingTable.get()
            var peers: [Peer] = []
            for peerId in peerIds {
                if let peer: Peer = self.peerTable.get(peerId) {
                    peers.append(peer)
                }
            }
            return .single(peers)
        } |> switchToLatest
    }
    
    public func messageHistoryHolesView() -> Signal<MessageHistoryHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.messageHistoryHolesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func chatListHolesView() -> Signal<ChatListHolesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.chatListHolesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func unsentMessageIndicesView() -> Signal<UnsentMessageIndicesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.unsentMessageIndicesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func synchronizePeerReadStatesView() -> Signal<SynchronizePeerReadStatesView, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.async {
                disposable.set(self.viewTracker.synchronizePeerReadStatesViewSignal().start(next: { view in
                    subscriber.putNext(view)
                }))
            }
            return disposable
        }
    }
    
    public func isMasterClient() -> Signal<Bool, NoError> {
        return self.modify { modifier -> Signal<Bool, NoError> in
            let sessionClientId = self.sessionClientId
            return self.masterClientId.get()
                |> distinctUntilChanged
                |> map({ $0 == sessionClientId })
        } |> switchToLatest
    }
    
    public func becomeMasterClient() {
        self.modify({ modifier in
            if self.metadataTable.masterClientId() != self.sessionClientId {
                self.currentUpdatedMasterClientId = self.sessionClientId
            }
        }).start()
    }
}
