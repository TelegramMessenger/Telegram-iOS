import Foundation

final class PeerNotificationSettingsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64)
    }
    
    private let sharedEncoder = Encoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedSettings: [PeerId: PeerNotificationSettings] = [:]
    private var updatedInitialSettings: [PeerId: PeerNotificationSettings?] = [:]
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    func set(id: PeerId, settings: PeerNotificationSettings) {
        let current = self.get(id)
        if current == nil || !current!.isEqual(to: settings) {
            if self.updatedInitialSettings[id] == nil {
               self.updatedInitialSettings[id] = current
            }
            self.cachedSettings[id] = settings
        }
    }
    
    func get(_ id: PeerId) -> PeerNotificationSettings? {
        if let settings = self.cachedSettings[id] {
            return settings
        }
        if let value = self.valueBox.get(self.table, key: self.key(id)) {
            if let settings = Decoder(buffer: value).decodeRootObject() as? PeerNotificationSettings {
                self.cachedSettings[id] = settings
                return settings
            }
        }
        return nil
    }
    
    override func clearMemoryCache() {
        self.cachedSettings.removeAll()
        self.updatedInitialSettings.removeAll()
    }
    
    func transactionParticipationInTotalUnreadCountUpdates() -> (added: Set<PeerId>, removed: Set<PeerId>) {
        var added = Set<PeerId>()
        var removed = Set<PeerId>()
        
        for (peerId, initialSettings) in self.updatedInitialSettings {
            var wasParticipating = false
            if let initialSettings = initialSettings {
                wasParticipating = !initialSettings.isRemovedFromTotalUnreadCount
            }
            let isParticipating = !self.cachedSettings[peerId]!.isRemovedFromTotalUnreadCount
            if wasParticipating != isParticipating {
                if isParticipating {
                    added.insert(peerId)
                } else {
                    removed.insert(peerId)
                }
            }
        }
        
        return (added, removed)
    }
    
    override func beforeCommit() {
        if !self.updatedInitialSettings.isEmpty {
            for (peerId, _) in self.updatedInitialSettings {
                if let settings = self.cachedSettings[peerId] {
                    self.sharedEncoder.reset()
                    self.sharedEncoder.encodeRootObject(settings)
                    
                    self.valueBox.set(self.table, key: self.key(peerId), value: self.sharedEncoder.readBufferNoCopy())
                }
            }
            
            self.updatedInitialSettings.removeAll()
        }
    }
}
