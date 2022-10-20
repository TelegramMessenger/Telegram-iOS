import Foundation

final class CachedPeerDataTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: false)
    }
    
    private let sharedEncoder = PostboxEncoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedDatas: [PeerId: CachedPeerData] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool) {
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
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
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            if let data = PostboxDecoder(buffer: value).decodeRootObject() as? CachedPeerData {
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
                
                self.valueBox.set(self.table, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
            }
        }
        
        self.updatedPeerIds.removeAll()
        if !self.useCaches {
            self.cachedDatas.removeAll()
        }
    }
}
