import Foundation
import SwiftSignalKit
import sqlcipher

public enum PreloadedMessageHistoryView {
    case Loading
    case Preloaded(MessageHistoryView)
}

public protocol PeerChatState: Coding {
    func equals(other: PeerChatState) -> Bool
}

public final class Modifier {
    private weak var postbox: Postbox?
    
    private init(postbox: Postbox) {
        self.postbox = postbox
    }
    
    public func addMessages(messages: [StoreMessage], location: AddMessagesLocation) {
        self.postbox?.addMessages(messages, location: location)
    }
    
    public func addHole(messageId: MessageId) {
        self.postbox?.addHole(messageId)
    }
    
    public func fillHole(hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        self.postbox?.fillHole(hole, fillType: fillType, tagMask: tagMask, messages: messages)
    }
    
    public func replaceChatListHole(index: MessageIndex, hole: ChatListHole?) {
        self.postbox?.replaceChatListHole(index, hole: hole)
    }
    
    public func deleteMessages(messageIds: [MessageId]) {
        self.postbox?.deleteMessages(messageIds)
    }
    
    public func deleteMessagesWithGlobalIds(ids: [Int32]) {
        if let postbox = self.postbox {
            let messageIds = postbox.messageIdsForGlobalIds(ids)
            postbox.deleteMessages(messageIds)
        }
    }
    
    public func resetIncomingReadStates(states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.postbox?.resetIncomingReadStates(states)
    }
    
    public func confirmSynchronizedIncomingReadState(peerId: PeerId) {
        self.postbox?.confirmSynchronizedIncomingReadState(peerId)
    }
    
    public func applyIncomingReadMaxId(messageId: MessageId) {
        self.postbox?.applyIncomingReadMaxId(messageId)
    }
    
    public func applyOutgoingReadMaxId(messageId: MessageId) {
        self.postbox?.applyOutgoingReadMaxId(messageId)
    }
    
    public func applyInteractiveReadMaxId(messageId: MessageId) {
        self.postbox?.applyInteractiveReadMaxId(messageId)
    }
    
    public func getState() -> Coding? {
        return self.postbox?.getState()
    }
    
    public func setState(state: Coding) {
        self.postbox?.setState(state)
    }
    
    public func getPeerChatState(id: PeerId) -> PeerChatState? {
        return self.postbox?.peerChatStateTable.get(id) as? PeerChatState
    }
    
    public func setPeerChatState(id: PeerId, state: PeerChatState) {
        self.postbox?.peerChatStateTable.set(id, state: state)
    }
    
    public func getPeer(id: PeerId) -> Peer? {
        return self.postbox?.peerTable.get(id)
    }
    
    public func getPeerReadStates(id: PeerId) -> [(MessageId.Namespace, PeerReadState)]? {
        return self.postbox?.readStateTable.getCombinedState(id)?.states
    }
    
    public func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer?) {
        self.postbox?.updatePeers(peers, update: update)
    }
    
    public func updateMessage(index: MessageIndex, update: Message -> StoreMessage) {
        self.postbox?.updateMessage(index, update: update)
    }
    
    public func updateMedia(id: MediaId, update: Media?) {
        self.postbox?.updateMedia(id, update: update)
    }
    
    public func getMessage(id: MessageId) -> Message? {
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
    
    public func filterStoredMessageIds(messageIds: Set<MessageId>) -> Set<MessageId> {
        if let postbox = self.postbox {
            return postbox.filterStoredMessageIds(messageIds)
        }
        return Set()
    }
}

public final class Postbox {
    private let seedConfiguration: SeedConfiguration
    private let basePath: String
    private let globalMessageIdsNamespace: MessageId.Namespace
    
    private let queue = Queue(name: "org.telegram.postbox.Postbox")
    private var valueBox: ValueBox!
    
    private var viewTracker: ViewTracker!
    private var nextViewId = 0
    
    private var peerPipes: [PeerId: Pipe<Peer>] = [:]
    
    private var currentOperationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
    private var currentUnsentOperations: [IntermediateMessageHistoryUnsentOperation] = []
    private var currentUpdatedSynchronizeReadStateOperations: [PeerId: PeerReadStateSynchronizationOperation?] = [:]
    private var currentUpdatedMedia: [MediaId: Media?] = [:]
    
    private var currentRemovedHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentFilledHolesByPeerId: [PeerId: [MessageIndex: HoleFillDirection]] = [:]
    private var currentUpdatedPeers: [PeerId: Peer] = [:]
    private var currentReplaceChatListHoles: [(MessageIndex, ChatListHole?)] = []
    
    private var statePipe: Pipe<Coding> = Pipe()

    private let fetchChatListHoleImpl = Promise<ChatListHole -> Signal<Void, NoError>>()
    public func setFetchChatListHole(fetch: ChatListHole -> Signal<Void, NoError>) {
        self.fetchChatListHoleImpl.set(single(fetch, NoError.self))
    }
    
    private let fetchMessageHistoryHoleImpl = Promise<(MessageHistoryHole, HoleFillDirection, MessageTags?) -> Signal<Void, NoError>>()
    public func setFetchMessageHistoryHole(fetch: (MessageHistoryHole, HoleFillDirection, MessageTags?) -> Signal<Void, NoError>) {
        self.fetchMessageHistoryHoleImpl.set(single(fetch, NoError.self))
    }
    
    private let sendUnsentMessageImpl = Promise<Message -> Signal<Void, NoError>>()
    public func setSendUnsentMessage(sendUnsentMessage: Message -> Signal<Void, NoError>) {
        self.sendUnsentMessageImpl.set(single(sendUnsentMessage, NoError.self))
    }
    
    private let synchronizePeerReadStateImpl = Promise<(PeerId, PeerReadStateSynchronizationOperation) -> Signal<Void, NoError>>()
    public func setSynchronizePeerReadState(synchronizePeerReadState: (PeerId, PeerReadStateSynchronizationOperation) -> Signal<Void, NoError>) {
        self.synchronizePeerReadStateImpl.set(.single(synchronizePeerReadState))
    }
    
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
    
    public init(basePath: String, globalMessageIdsNamespace: MessageId.Namespace, seedConfiguration: SeedConfiguration) {
        self.basePath = basePath
        self.globalMessageIdsNamespace = globalMessageIdsNamespace
        self.seedConfiguration = seedConfiguration
        
        let _ = try? NSFileManager.defaultManager().removeItemAtPath(self.basePath + "/media")
        
        self.mediaBox = MediaBox(basePath: self.basePath + "/media")
        self.openDatabase()
    }
    
    private func debugSaveState(name: String) {
        self.queue.justDispatch({
            let path = self.basePath + name
            let _ = try? NSFileManager.defaultManager().removeItemAtPath(path)
            do {
                try NSFileManager.defaultManager().copyItemAtPath(self.basePath, toPath: path)
            } catch (let e) {
                print("(Postbox debugSaveState: error \(e))")
            }
        })
    }
    
    private func debugRestoreState(name: String) {
        self.queue.justDispatch({
            let path = self.basePath + name
            let _ = try? NSFileManager.defaultManager().removeItemAtPath(self.basePath)
            do {
                try NSFileManager.defaultManager().copyItemAtPath(path, toPath: self.basePath)
            } catch (let e) {
                print("(Postbox debugRestoreState: error \(e))")
            }
        })
    }
    
    private func openDatabase() {
        self.queue.justDispatch({
            let startTime = CFAbsoluteTimeGetCurrent()
            
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(self.basePath, withIntermediateDirectories: true, attributes: nil)
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
            
            //self.debugSaveState("previous")
            //self.debugRestoreState("previous")
            
            //#endif
            
            self.valueBox = SqliteValueBox(basePath: self.basePath + "/db")
            self.metadataTable = MetadataTable(valueBox: self.valueBox, tableId: 0)
            
            let userVersion: Int32? = self.metadataTable.userVersion()
            let currentUserVersion: Int32 = 5
            
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
            
            self.tables.append(self.keychainTable)
            self.tables.append(self.peerTable)
            self.tables.append(self.globalMessageIdsTable)
            self.tables.append(self.messageHistoryMetadataTable)
            self.tables.append(self.messageHistoryIndexTable)
            self.tables.append(self.mediaCleanupTable)
            self.tables.append(self.mediaTable)
            self.tables.append(self.messageHistoryTable)
            self.tables.append(self.chatListIndexTable)
            self.tables.append(self.chatListTable)
            self.tables.append(self.peerChatStateTable)
            self.tables.append(self.readStateTable)
            self.tables.append(self.synchronizeReadStateTable)
            
            self.viewTracker = ViewTracker(queue: self.queue, fetchEarlierHistoryEntries: self.fetchEarlierHistoryEntries, fetchLaterHistoryEntries: self.fetchLaterHistoryEntries, fetchEarlierChatEntries: self.fetchEarlierChatEntries, fetchLaterChatEntries: self.fetchLaterChatEntries, fetchAnchorIndex: self.fetchAnchorIndex, renderMessage: self.renderIntermediateMessage, fetchChatListHole: self.fetchChatListHoleWrapper, fetchMessageHistoryHole: self.fetchMessageHistoryHoleWrapper, sendUnsentMessage: self.sendUnsentMessageWrapper, unsentMessageIndices: self.messageHistoryUnsentTable!.get(), synchronizeReadState: self.synchronizePeerReadStateWrapper, synchronizePeerReadStateOperations: self.synchronizeReadStateTable!.get())
            
            print("(Postbox initialization took \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        })
    }
    
    private func takeNextViewId() -> Int {
        let nextId = self.nextViewId
        self.nextViewId += 1
        return nextId
    }
    
    private var cachedState: Coding?
    
    private func setState(state: Coding) {
        self.queue.justDispatch({
            self.cachedState = state
            
            self.metadataTable.setState(state)
            
            self.statePipe.putNext(state)
        })
    }
    
    private func getState() -> Coding? {
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
    
    public func state() -> Signal<Coding?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.justDispatch({
                subscriber.putNext(self.getState())
                disposable.set(self.statePipe.signal().start(next: { next in
                    subscriber.putNext(next)
                }))
            })
            
            return disposable
        }
    }
    
    public func keychainEntryForKey(key: String) -> NSData? {
        return self.keychainTable.get(key)
    }
    
    public func setKeychainEntryForKey(key: String, value: NSData) {
        self.keychainTable.set(key, value: value)
    }
    
    public func removeKeychainEntryForKey(key: String) {
        self.keychainTable.remove(key)
    }
    
    private func addMessages(messages: [StoreMessage], location: AddMessagesLocation) {
        self.messageHistoryTable.addMessages(messages, location: location, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func addHole(id: MessageId) {
        self.messageHistoryTable.addHoles([id], operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func fillHole(hole: MessageHistoryHole, fillType: HoleFill, tagMask: MessageTags?, messages: [StoreMessage]) {
        var operationsByPeerId: [PeerId: [MessageHistoryOperation]] = [:]
        self.messageHistoryTable.fillHole(hole.id, fillType: fillType, tagMask: tagMask, messages: messages, operationsByPeerId: &operationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        for (peerId, operations) in operationsByPeerId {
            if self.currentOperationsByPeerId[peerId] == nil {
                self.currentOperationsByPeerId[peerId] = operations
            } else {
                self.currentOperationsByPeerId[peerId]!.appendContentsOf(operations)
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
    
    private func replaceChatListHole(index: MessageIndex, hole: ChatListHole?) {
        self.currentReplaceChatListHoles.append((index, hole))
    }
    
    private func deleteMessages(messageIds: [MessageId]) {
        self.messageHistoryTable.removeMessages(messageIds, operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func resetIncomingReadStates(states: [PeerId: [MessageId.Namespace: PeerReadState]]) {
        self.messageHistoryTable.resetIncomingReadStates(states, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func confirmSynchronizedIncomingReadState(peerId: PeerId) {
        self.synchronizeReadStateTable.set(peerId, operation: nil, operations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func applyIncomingReadMaxId(messageId: MessageId) {
        self.messageHistoryTable.applyIncomingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func applyOutgoingReadMaxId(messageId: MessageId) {
        self.messageHistoryTable.applyOutgoingReadMaxId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func applyInteractiveReadMaxId(messageId: MessageId) {
        self.messageHistoryTable.applyInteractiveMaxReadId(messageId, operationsByPeerId: &self.currentOperationsByPeerId, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
    }
    
    private func fetchEarlierHistoryEntries(peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.earlierEntries(tagMask, peerId: peerId, index: index, count: count)
        } else {
            intermediateEntries = self.messageHistoryTable.earlierEntries(peerId, index: index, count: count)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message))
                case let .Hole(index):
                    entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchAroundHistoryEntries(index: MessageIndex, count: Int, tagMask: MessageTags? = nil) -> (entries: [MutableMessageHistoryEntry], lower: MutableMessageHistoryEntry?, upper: MutableMessageHistoryEntry?) {
        
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        let intermediateLower: IntermediateMessageHistoryEntry?
        let intermediateUpper: IntermediateMessageHistoryEntry?
        
        if let tagMask = tagMask {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(tagMask, index: index, count: count)
        } else {
            (intermediateEntries, intermediateLower, intermediateUpper) = self.messageHistoryTable.entriesAround(index, count: count)
        }
        
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
                case let .Message(message):
                    entries.append(.IntermediateMessageEntry(message))
                case let .Hole(index):
                    entries.append(.HoleEntry(index))
            }
        }
        
        var lower: MutableMessageHistoryEntry?
        if let intermediateLower = intermediateLower {
            switch intermediateLower {
                case let .Message(message):
                    lower = .IntermediateMessageEntry(message)
                case let .Hole(index):
                    lower = .HoleEntry(index)
            }
        }
        
        var upper: MutableMessageHistoryEntry?
        if let intermediateUpper = intermediateUpper {
            switch intermediateUpper {
                case let .Message(message):
                    upper = .IntermediateMessageEntry(message)
                case let .Hole(index):
                    upper = .HoleEntry(index)
            }
        }
        
        return (entries: entries, lower: lower, upper: upper)
    }
    
    private func fetchLaterHistoryEntries(peerId: PeerId, index: MessageIndex?, count: Int, tagMask: MessageTags? = nil) -> [MutableMessageHistoryEntry] {
        let intermediateEntries: [IntermediateMessageHistoryEntry]
        if let tagMask = tagMask {
            intermediateEntries = self.messageHistoryTable.laterEntries(tagMask, peerId: peerId, index: index, count: count)
        } else {
            intermediateEntries = self.messageHistoryTable.laterEntries(peerId, index: index, count: count)
        }
        var entries: [MutableMessageHistoryEntry] = []
        for entry in intermediateEntries {
            switch entry {
            case let .Message(message):
                entries.append(.IntermediateMessageEntry(message))
            case let .Hole(index):
                entries.append(.HoleEntry(index))
            }
        }
        return entries
    }
    
    private func fetchAroundChatEntries(index: MessageIndex, count: Int) -> (entries: [MutableChatListEntry], earlier: MutableChatListEntry?, later: MutableChatListEntry?) {
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
    
    private func fetchEarlierChatEntries(index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
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
    
    private func fetchLaterChatEntries(index: MessageIndex?, count: Int) -> [MutableChatListEntry] {
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
    
    private func fetchAnchorIndex(id: MessageId) -> MessageHistoryAnchorIndex? {
        return self.messageHistoryTable.anchorIndex(id)
    }
    
    private func renderIntermediateMessage(message: IntermediateMessage) -> Message {
        return self.messageHistoryTable.renderMessage(message, peerTable: self.peerTable)
    }

    private func fetchChatListHoleWrapper(hole: ChatListHole) -> Disposable {
        return (self.fetchChatListHoleImpl.get() |> mapToSignal { fetch in
            return fetch(hole)
        }).start()
    }
    
    private func fetchMessageHistoryHoleWrapper(hole: MessageHistoryHole, direction: HoleFillDirection, tagMask: MessageTags?) -> Disposable {
        return (self.fetchMessageHistoryHoleImpl.get() |> mapToSignal { fetch in
            return fetch(hole, direction, tagMask)
        }).start()
    }
    
    private func sendUnsentMessageWrapper(index: MessageIndex) -> Disposable {
        return (self.sendUnsentMessageImpl.get() |> deliverOn(self.queue) |> mapToSignal { send -> Signal<Void, NoError> in
            if let intermediateMessage = self.messageHistoryTable.getMessage(index) {
                let message = self.renderIntermediateMessage(intermediateMessage)
                return send(message)
            } else {
                return never(Void.self, NoError.self)
            }
        }).start()
    }
    
    private func synchronizePeerReadStateWrapper(peerId: PeerId, operation: PeerReadStateSynchronizationOperation) -> Disposable {
        return (self.synchronizePeerReadStateImpl.get() |> mapToSignal { validate -> Signal<Void, NoError> in
            return validate(peerId, operation)
        }).start()
    }
    
    private func beforeCommit() {
        var chatListOperations: [ChatListOperation] = []
        self.chatListTable.replay(self.currentOperationsByPeerId, messageHistoryTable: self.messageHistoryTable, operations: &chatListOperations)
        for (index, hole) in self.currentReplaceChatListHoles {
            self.chatListTable.replaceHole(index, hole: hole, operations: &chatListOperations)
        }
        
        self.viewTracker.updateViews(currentOperationsByPeerId: self.currentOperationsByPeerId, peerIdsWithFilledHoles: self.currentFilledHolesByPeerId, removedHolesByPeerId: self.currentRemovedHolesByPeerId, chatListOperations: chatListOperations, currentUpdatedPeers: self.currentUpdatedPeers, unsentMessageOperations: self.currentUnsentOperations, updatedSynchronizePeerReadStateOperations: self.currentUpdatedSynchronizeReadStateOperations, updatedMedia: self.currentUpdatedMedia)
        
        self.currentOperationsByPeerId.removeAll()
        self.currentFilledHolesByPeerId.removeAll()
        self.currentRemovedHolesByPeerId.removeAll()
        self.currentUpdatedPeers.removeAll()
        self.currentReplaceChatListHoles.removeAll()
        self.currentUnsentOperations.removeAll()
        self.currentUpdatedSynchronizeReadStateOperations.removeAll()
        self.currentUpdatedMedia.removeAll()
        
        for table in self.tables {
            table.beforeCommit()
        }
    }
    
    private func messageIdsForGlobalIds(ids: [Int32]) -> [MessageId] {
        var result: [MessageId] = []
        for globalId in ids {
            if let id = self.globalMessageIdsTable.get(globalId) {
                result.append(id)
            }
        }
        return result
    }
    
    private func updatePeers(peers: [Peer], update: (Peer, Peer) -> Peer?) {
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
    
    private func updateMessage(index: MessageIndex, update: Message -> StoreMessage) {
        if let intermediateMessage = self.messageHistoryTable.getMessage(index) {
            let message = self.renderIntermediateMessage(intermediateMessage)
            self.messageHistoryTable.updateMessage(index.id, message: update(message), operationsByPeerId: &self.currentOperationsByPeerId, unsentMessageOperations: &self.currentUnsentOperations, updatedPeerReadStateOperations: &self.currentUpdatedSynchronizeReadStateOperations)
        }
    }
    
    private func updateMedia(id: MediaId, update: Media?) {
        self.messageHistoryTable.updateMedia(id, media: update, operationsByPeerId: &self.currentOperationsByPeerId, updatedMedia: &self.currentUpdatedMedia)
    }
    
    private func filterStoredMessageIds(messageIds: Set<MessageId>) -> Set<MessageId> {
        var filteredIds = Set<MessageId>()
        
        for id in messageIds {
            if self.messageHistoryIndexTable.exists(id) {
                filteredIds.insert(id)
            }
        }
        
        return filteredIds
    }
    
    public func modify<T>(f: Modifier -> T) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.queue.justDispatch({
                //let startTime = CFAbsoluteTimeGetCurrent()
                //self.valueBox.beginStats()
                self.valueBox.begin()
                let result = f(Modifier(postbox: self))
                self.beforeCommit()
                self.valueBox.commit()
                
                subscriber.putNext(result)
                //print("modify \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
    }
    
    public func aroundUnreadMessageHistoryViewForPeerId(peerId: PeerId, count: Int, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.dispatch {
                var index = MessageHistoryAnchorIndex(index: MessageIndex.upperBound(peerId), exact: true)
                if let maxReadIndex = self.messageHistoryTable.maxReadIndex(peerId) {
                    index = maxReadIndex
                }
                disposable.set(self.aroundMessageHistoryViewForPeerId(peerId, index: index.index, count: count, anchorIndex: index, unreadIndex: index.index, fixedCombinedReadState: nil, tagMask: tagMask).start(next: { next in
                    subscriber.putNext(next)
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    subscriber.putCompletion()
                }))
            }
            return disposable
        }
    }
    
    public func aroundMessageHistoryViewForPeerId(peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageIndex, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.aroundMessageHistoryViewForPeerId(peerId, index: index, count: count, anchorIndex: MessageHistoryAnchorIndex(index: anchorIndex, exact: true), unreadIndex: nil, fixedCombinedReadState: fixedCombinedReadState, tagMask: tagMask)
    }
    
    private func aroundMessageHistoryViewForPeerId(peerId: PeerId, index: MessageIndex, count: Int, anchorIndex: MessageHistoryAnchorIndex, unreadIndex: MessageIndex?, fixedCombinedReadState: CombinedPeerReadState?, tagMask: MessageTags? = nil) -> Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            let startTime = CFAbsoluteTimeGetCurrent()
            self.queue.justDispatch({
                //print("+ queue \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                let (entries, earlier, later) = self.fetchAroundHistoryEntries(index, count: count, tagMask: tagMask)
                print("aroundMessageHistoryViewForPeerId fetchAroundHistoryEntries \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                var adjustedAnchorIndex = anchorIndex
                /*if entries.count != 0 {
                    let minIndex = entries[0].index
                    if anchorIndex < minIndex {
                        //adjustedAnchorIndex = minIndex
                    }
                }*/
                
                let mutableView = MutableMessageHistoryView(id: MessageHistoryViewId(peerId: peerId, id: self.takeNextViewId()), anchorIndex: adjustedAnchorIndex, combinedReadState: fixedCombinedReadState ?? self.readStateTable.getCombinedState(peerId), earlier: earlier, entries: entries, later: later, tagMask: tagMask, count: count)
                mutableView.render(self.renderIntermediateMessage)
                //print("+ render \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
                
                let initialUpdateType: ViewUpdateType
                if let unreadIndex = unreadIndex {
                    initialUpdateType = .InitialUnread(unreadIndex)
                } else {
                    initialUpdateType = .Generic
                }
                subscriber.putNext((MessageHistoryView(mutableView), initialUpdateType))
                
                let (index, signal) = self.viewTracker.addMessageHistoryView(peerId, view: mutableView)
                    
                let pipeDisposable = signal.start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            strongSelf.viewTracker.removeMessageHistoryView(peerId, index: index)
                        }
                    }
                    return
                })
            })
            
            return disposable
        }
    }
    
    public func messageIndexAtId(id: MessageId) -> Signal<MessageIndex?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.justDispatch {
                if let entry = self.messageHistoryIndexTable.get(id), case let .Message(index) = entry {
                    subscriber.putNext(index)
                    subscriber.putCompletion()
                } else if let hole = self.messageHistoryIndexTable.holeContainingId(id) {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            }
            
            return disposable
        }
    }
    
    public func tailChatListView(count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return self.aroundChatListView(MessageIndex.absoluteUpperBound(), count: count)
    }
    
    public func aroundChatListView(index: MessageIndex, count: Int) -> Signal<(ChatListView, ViewUpdateType), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            self.queue.justDispatch({
                let (entries, earlier, later) = self.fetchAroundChatEntries(index, count: count)
                
                let mutableView = MutableChatListView(earlier: earlier, entries: entries, later: later, count: count)
                mutableView.render(self.renderIntermediateMessage)
                subscriber.putNext((ChatListView(mutableView), .Generic))
                
                let (index, signal) = self.viewTracker.addChatListView(mutableView)
                
                let pipeDisposable = signal.start(next: { next in
                    subscriber.putNext(next)
                })
                
                disposable.set(ActionDisposable { [weak self] in
                    pipeDisposable.dispose()
                    
                    if let strongSelf = self {
                        strongSelf.queue.dispatch {
                            strongSelf.viewTracker.removeChatListView(index)
                        }
                    }
                    return
                })
            })
            
            return disposable
        }
    }
    
    public func peerWithId(id: PeerId) -> Signal<Peer, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.queue.justDispatch({
                if let peer: Peer = self.peerTable.get(id) {
                    subscriber.putNext(peer)
                }
            })
            return disposable
        }
    }
    
    public func updateMessageHistoryViewVisibleRange(id: MessageHistoryViewId, earliestVisibleIndex: MessageIndex, latestVisibleIndex: MessageIndex) {
        self.queue.justDispatch({
            self.viewTracker.updateMessageHistoryViewVisibleRange(id, earliestVisibleIndex: earliestVisibleIndex, latestVisibleIndex: latestVisibleIndex)
        })
    }
}
