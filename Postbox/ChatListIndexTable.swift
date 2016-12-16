import Foundation

final class ChatListIndexTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private let peerNameIndexTable: PeerNameIndexTable
    
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedIndices: [PeerId: MessageIndex?] = [:]
    private var updatedPreviousCachedIndices: [PeerId: MessageIndex?] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, peerNameIndexTable: PeerNameIndexTable) {
        self.peerNameIndexTable = peerNameIndexTable
        
        super.init(valueBox: valueBox, table: table)
    }
    
    private func key(_ peerId: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: peerId.toInt64())
        return self.sharedKey
    }
    
    func set(_ index: MessageIndex) {
        self.updatedPreviousCachedIndices[index.id.peerId] = self.get(index.id.peerId)
        self.cachedIndices[index.id.peerId] = index
    }
    
    func remove(_ peerId: PeerId) {
        self.updatedPreviousCachedIndices[peerId] = self.get(peerId)
        self.cachedIndices[peerId] = nil
    }
    
    func get(_ peerId: PeerId) -> MessageIndex? {
        if let cached = self.cachedIndices[peerId] {
            return cached
        } else {
            if let value = self.valueBox.get(self.table, key: self.key(peerId)) {
                var idNamespace: Int32 = 0
                var idId: Int32 = 0
                var idTimestamp: Int32 = 0
                value.read(&idNamespace, offset: 0, length: 4)
                value.read(&idId, offset: 0, length: 4)
                value.read(&idTimestamp, offset: 0, length: 4)
                let index = MessageIndex(id: MessageId(peerId: peerId, namespace: idNamespace, id: idId), timestamp: idTimestamp)
                self.cachedIndices[peerId] = index
                return index
            } else {
                return nil
            }
        }
    }
    
    override func clearMemoryCache() {
        self.cachedIndices.removeAll()
        assert(self.updatedPreviousCachedIndices.isEmpty)
    }
    
    override func beforeCommit() {
        if !self.updatedPreviousCachedIndices.isEmpty {
            var addedPeerIds = Set<PeerId>()
            var removedPeerIds = Set<PeerId>()
            
            for (peerId, previousIndex) in self.updatedPreviousCachedIndices {
                let index = self.cachedIndices[peerId]!
                if let index = index {
                    if previousIndex == nil {
                        addedPeerIds.insert(peerId)
                    }
                    
                    let writeBuffer = WriteBuffer()
                    var idNamespace: Int32 = index.id.namespace
                    var idId: Int32 = index.id.id
                    var idTimestamp: Int32 = index.timestamp
                    writeBuffer.write(&idNamespace, offset: 0, length: 4)
                    writeBuffer.write(&idId, offset: 0, length: 4)
                    writeBuffer.write(&idTimestamp, offset: 0, length: 4)
                    self.valueBox.set(self.table, key: self.key(index.id.peerId), value: writeBuffer.readBufferNoCopy())
                } else {
                    if previousIndex != nil {
                        removedPeerIds.insert(peerId)
                    }
                    
                    self.valueBox.remove(self.table, key: self.key(peerId))
                }
            }
            self.updatedPreviousCachedIndices.removeAll()
            
            for peerId in addedPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: true)
            }
            
            for peerId in removedPeerIds {
                self.peerNameIndexTable.setPeerCategoryState(peerId: peerId, category: [.chats], includes: false)
            }
        }
    }
}
