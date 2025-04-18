import Foundation

struct PeerNameIndexCategories: OptionSet {
    var rawValue: Int32
    
    init() {
        self.rawValue = 0
    }
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let chats = PeerNameIndexCategories(rawValue: 1 << 0)
    static let contacts = PeerNameIndexCategories(rawValue: 1 << 1)
}

private final class PeerNameIndexCategoriesEntry {
    let categories: PeerNameIndexCategories
    let tokens: [ValueBoxKey]
    
    init(categories: PeerNameIndexCategories, tokens: [ValueBoxKey]) {
        self.categories = categories
        self.tokens = tokens
    }
    
    init(buffer: MemoryBuffer) {
        assert(buffer.length >= 8)
        
        self.categories = PeerNameIndexCategories(rawValue: buffer.memory.load(fromByteOffset: 0, as: Int32.self))
        let tokenCount = buffer.memory.load(fromByteOffset: 4, as: Int32.self)
        var offset = 8
        var tokens: [ValueBoxKey] = []
        for _ in 0 ..< tokenCount {
            let length = buffer.memory.load(fromByteOffset: offset, as: Int32.self)
            offset += 4
            tokens.append(ValueBoxKey(MemoryBuffer(memory: buffer.memory.advanced(by: offset), capacity: Int(length), length: Int(length), freeWhenDone: false)))
            offset += Int(length)
            let paddingLength = length % 4
            offset += Int(paddingLength)
        }
        self.tokens = tokens
    }
    
    func write(to buffer: WriteBuffer) {
        var rawValue: Int32 = self.categories.rawValue
        buffer.write(&rawValue, offset: 0, length: 4)
        var count: Int32 = Int32(self.tokens.count)
        buffer.write(&count, offset: 0, length: 4)
        for token in self.tokens {
            var length = Int32(token.length)
            buffer.write(&length, offset: 0, length: 4)
            buffer.write(token.memory, offset: 0, length: token.length)
            var paddingLength = token.length % 4
            var zero: Int8 = 0
            while paddingLength > 0 {
                buffer.write(&zero, offset: 0, length: 1)
                paddingLength -= 1
            }
        }
    }
}

private final class PeerNameIndexCategoriesEntryUpdate {
    let initialCategories: PeerNameIndexCategories
    let initialTokens: [ValueBoxKey]
    
    private(set) var updatedCategories: PeerNameIndexCategories?
    private(set) var updatedName: PeerIndexNameRepresentation?
    
    init(initialCategories: PeerNameIndexCategories, initialTokens: [ValueBoxKey]) {
        self.initialCategories = initialCategories
        self.initialTokens = initialTokens
    }
    
    func updateCategory(_ category: PeerNameIndexCategories, includes: Bool) {
        var currentCategories: PeerNameIndexCategories
        if let updatedCategories = self.updatedCategories {
            currentCategories = updatedCategories
        } else {
            currentCategories = self.initialCategories
        }
        if includes {
            currentCategories.insert(category)
            self.updatedCategories = currentCategories
        } else {
            currentCategories.remove(category)
            self.updatedCategories = currentCategories
        }
    }
    
    func updateName(_ name: PeerIndexNameRepresentation) {
        self.updatedName = name
    }
}

struct PeerIdReverseIndexReference: Equatable, Hashable, ReverseIndexReference {
    let value: Int64
    
    static func <(lhs: PeerIdReverseIndexReference, rhs: PeerIdReverseIndexReference) -> Bool {
        return lhs.value < rhs.value
    }
    
    static func decodeArray(_ buffer: MemoryBuffer) -> [PeerIdReverseIndexReference] {
        assert(buffer.length % 8 == 0)
        var sortedPeerIds: [PeerIdReverseIndexReference] = []
        sortedPeerIds.reserveCapacity(buffer.length % 8)
        withExtendedLifetime(buffer, {
            let memory = buffer.memory.assumingMemoryBound(to: Int64.self)
            for i in 0 ..< buffer.length / 8 {
                sortedPeerIds.append(PeerIdReverseIndexReference(value: memory[i]))
            }
        })
        return sortedPeerIds
    }
    
    static func encodeArray(_ array: [PeerIdReverseIndexReference]) -> MemoryBuffer {
        let buffer = MemoryBuffer(memory: malloc(array.count * 8), capacity: array.count * 8, length: array.count * 8, freeWhenDone: true)
        let memory = buffer.memory.assumingMemoryBound(to: Int64.self)
        var index = 0
        for peerId in array {
            memory[index] = peerId.value
            index += 1
        }
        return buffer
    }
}

private let reverseIndexNamespace = ReverseIndexNamespace(nil)

final class PeerNameIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let peerTable: PeerTable
    private let peerNameTokenIndexTable: ReverseIndexReferenceTable<PeerIdReverseIndexReference>
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var entryUpdates: [PeerId: PeerNameIndexCategoriesEntryUpdate] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, peerTable: PeerTable, peerNameTokenIndexTable: ReverseIndexReferenceTable<PeerIdReverseIndexReference>) {
        self.peerTable = peerTable
        self.peerNameTokenIndexTable = peerNameTokenIndexTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    private func updateEntry(_ peerId: PeerId, _ f: (PeerNameIndexCategoriesEntryUpdate) -> Void) {
        let entryUpdate: PeerNameIndexCategoriesEntryUpdate
        if let current = self.entryUpdates[peerId] {
            entryUpdate = current
        } else {
            let entry: PeerNameIndexCategoriesEntry
            if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
                entry = PeerNameIndexCategoriesEntry(buffer: value)
            } else {
                entry = PeerNameIndexCategoriesEntry(categories: [], tokens: [])
            }
            entryUpdate = PeerNameIndexCategoriesEntryUpdate(initialCategories: entry.categories, initialTokens: entry.tokens)
            self.entryUpdates[peerId] = entryUpdate
        }
        f(entryUpdate)
    }
    
    func setPeerCategoryState(peerId: PeerId, category: PeerNameIndexCategories, includes: Bool) {
        self.updateEntry(peerId, { entryUpdate in
            entryUpdate.updateCategory(category, includes: includes)
        })
    }
    
    func markPeerNameUpdated(peerId: PeerId, name: PeerIndexNameRepresentation) {
        self.updateEntry(peerId, { entryUpdate in
            entryUpdate.updateName(name)
        })
    }
    
    override func clearMemoryCache() {
        assert(self.entryUpdates.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.entryUpdates.isEmpty {
            let sharedBuffer = WriteBuffer()
            for (peerId, entryUpdate) in self.entryUpdates {
                if let updatedCategories = entryUpdate.updatedCategories {
                    let wasEmpty = entryUpdate.initialCategories.isEmpty
                    if updatedCategories.isEmpty != wasEmpty {
                        if updatedCategories.isEmpty {
                            if !entryUpdate.initialTokens.isEmpty {
                                self.peerNameTokenIndexTable.remove(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: entryUpdate.initialTokens)
                            }
                            if !entryUpdate.initialCategories.isEmpty {
                                self.valueBox.remove(self.table, key: self.key(peerId), secure: false)
                            }
                        } else {
                            let updatedTokens: [ValueBoxKey]
                            if let updatedName = entryUpdate.updatedName {
                                updatedTokens = updatedName.indexTokens
                            } else {
                                if let peer = self.peerTable.get(peerId) {
                                    if let associatedPeerId = peer.associatedPeerId {
                                        if let associatedPeer = self.peerTable.get(associatedPeerId) {
                                            updatedTokens = associatedPeer.indexName.indexTokens
                                        } else {
                                            updatedTokens = []
                                        }
                                    } else {
                                        updatedTokens = peer.indexName.indexTokens
                                    }
                                } else {
                                    //assertionFailure()
                                    updatedTokens = []
                                }
                            }
                            self.peerNameTokenIndexTable.add(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: updatedTokens)
                            sharedBuffer.reset()
                            PeerNameIndexCategoriesEntry(categories: updatedCategories, tokens: updatedTokens).write(to: sharedBuffer)
                            self.valueBox.set(self.table, key: self.key(peerId), value: sharedBuffer)
                        }
                    } else {
                        if let updatedName = entryUpdate.updatedName {
                            if !entryUpdate.initialTokens.isEmpty {
                                self.peerNameTokenIndexTable.remove(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: entryUpdate.initialTokens)
                            }
                            let updatedTokens = updatedName.indexTokens
                            self.peerNameTokenIndexTable.add(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: updatedTokens)
                            sharedBuffer.reset()
                            PeerNameIndexCategoriesEntry(categories: updatedCategories, tokens: updatedTokens).write(to: sharedBuffer)
                            self.valueBox.set(self.table, key: self.key(peerId), value: sharedBuffer)
                        } else {
                            sharedBuffer.reset()
                            PeerNameIndexCategoriesEntry(categories: updatedCategories, tokens: entryUpdate.initialTokens).write(to: sharedBuffer)
                            self.valueBox.set(self.table, key: self.key(peerId), value: sharedBuffer)
                        }
                    }
                } else if let updatedName = entryUpdate.updatedName {
                    if !entryUpdate.initialCategories.isEmpty {
                        if !entryUpdate.initialTokens.isEmpty {
                            self.peerNameTokenIndexTable.remove(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: entryUpdate.initialTokens)
                        }
                        let updatedTokens = updatedName.indexTokens
                        self.peerNameTokenIndexTable.add(namespace: reverseIndexNamespace, reference: PeerIdReverseIndexReference(value: peerId.toInt64()), tokens: updatedTokens)
                        sharedBuffer.reset()
                        PeerNameIndexCategoriesEntry(categories: entryUpdate.initialCategories, tokens: updatedTokens).write(to: sharedBuffer)
                        self.valueBox.set(self.table, key: self.key(peerId), value: sharedBuffer)
                    }
                }
            }
            self.entryUpdates.removeAll()
        }
    }
    
    func matchingPeerIds(tokens: (regular: [ValueBoxKey], transliterated: [ValueBoxKey]?), categories: PeerNameIndexCategories, chatListIndexTable: ChatListIndexTable, contactTable: ContactTable) -> (chats: [PeerId], contacts: [PeerId]) {
        if categories.isEmpty {
            return ([], [])
        } else {
            var contacts: [PeerId] = []
            var chatIndices: [PeerId: ChatListIndex] = [:]
            var peerIds = self.peerNameTokenIndexTable.matchingReferences(namespace: reverseIndexNamespace, tokens: tokens.regular)
            if let transliterated = tokens.transliterated, tokens.regular != transliterated {
                let transliteratedPeerIds = self.peerNameTokenIndexTable.matchingReferences(namespace: reverseIndexNamespace, tokens: transliterated)
                peerIds.formUnion(transliteratedPeerIds)
            }
            for peerIdReference in peerIds {
                let peerId = PeerId(peerIdReference.value)
                var foundInChats = false
                if categories.contains(.chats) {
                    if let (_, index) = chatListIndexTable.get(peerId: peerId).includedIndex(peerId: peerId) {
                        foundInChats = true
                        chatIndices[peerId] = index
                    }
                }
                if !foundInChats {
                    if categories.contains(.contacts) {
                        if contactTable.isContact(peerId: peerId) {
                            contacts.append(peerId)
                        }
                    }
                }
            }
            
            let chats = chatIndices.keys.sorted(by: { lhs, rhs -> Bool in
                return chatIndices[lhs]! > chatIndices[rhs]!
            })
            return (chats, contacts)
        }
    }
}
