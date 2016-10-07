import Foundation

final class CachedPeerDataTable: Table {
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedDatas: [PeerId: CachedPeerData] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(id: PeerId, data: CachedPeerData) {
        self.cachedDatas[id] = data
        self.updatedPeerIds.insert(id)
    }
    
    func get(_ id: PeerId) -> CachedPeerData? {
        if let status = self.cachedDatas[id] {
            return status
        }
        if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
            if let data = Decoder(buffer: value).decodeRootObject() as? CachedPeerData {
                self.cachedDatas[id] = data
                return data
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedDatas.removeAll()
        self.updatedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        for peerId in self.updatedPeerIds {
            if let data = self.cachedDatas[peerId] {
                self.sharedEncoder.reset()
                self.sharedEncoder.encodeRootObject(data)
                
                self.valueBox.set(self.tableId, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
            }
        }
        
        self.updatedPeerIds.removeAll()
        self.cachedDatas.removeAll()
    }
}
