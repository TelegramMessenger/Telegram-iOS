import Foundation

final class PeerNotificationSettingsTable: Table {
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedSettings: [PeerId: PeerNotificationSettings] = [:]
    private var updatedPeerIds = Set<PeerId>()
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(id: PeerId, settings: PeerNotificationSettings) {
        self.cachedSettings[id] = settings
        self.updatedPeerIds.insert(id)
    }
    
    func get(_ id: PeerId) -> PeerNotificationSettings? {
        if let settings = self.cachedSettings[id] {
            return settings
        }
        if let value = self.valueBox.get(self.tableId, key: self.key(id)) {
            if let settings = Decoder(buffer: value).decodeRootObject() as? PeerNotificationSettings {
                self.cachedSettings[id] = settings
                return settings
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedSettings.removeAll()
        self.updatedPeerIds.removeAll()
    }
    
    override func beforeCommit() {
        for peerId in self.updatedPeerIds {
            if let settings = self.cachedSettings[peerId] {
                self.sharedEncoder.reset()
                self.sharedEncoder.encodeRootObject(settings)
                
                self.valueBox.set(self.tableId, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
            }
        }
        
        self.updatedPeerIds.removeAll()
    }
}
