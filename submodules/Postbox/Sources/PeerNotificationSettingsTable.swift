import Foundation

private struct PeerNotificationSettingsTableEntry: Equatable {
    let current: PeerNotificationSettings?
    let pending: PeerNotificationSettings?
    
    static func ==(lhs: PeerNotificationSettingsTableEntry, rhs: PeerNotificationSettingsTableEntry) -> Bool {
        if let lhsCurrent = lhs.current, let rhsCurrent = rhs.current {
            if !lhsCurrent.isEqual(to: rhsCurrent) {
                return false
            }
        } else if (lhs.current != nil) != (rhs.current != nil) {
            return false
        }
        if let lhsPending = lhs.pending, let rhsPending = rhs.pending {
            if !lhsPending.isEqual(to: rhsPending) {
                return false
            }
        } else if (lhs.pending != nil) != (rhs.pending != nil) {
            return false
        }
        return true
    }
    
    var effective: PeerNotificationSettings? {
        if let pending = self.pending {
            return pending
        }
        return self.current
    }
    
    func withUpdatedCurrent(_ current: PeerNotificationSettings?) -> PeerNotificationSettingsTableEntry {
        return PeerNotificationSettingsTableEntry(current: current, pending: self.pending)
    }
    
    func withUpdatedPending(_ pending: PeerNotificationSettings?) -> PeerNotificationSettingsTableEntry {
        return PeerNotificationSettingsTableEntry(current: self.current, pending: pending)
    }
}

private struct PeerNotificationSettingsTableEntryFlags: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let hasCurrent = PeerNotificationSettingsTableEntryFlags(rawValue: 1 << 0)
    static let hasPending = PeerNotificationSettingsTableEntryFlags(rawValue: 1 << 1)
}

final class PeerNotificationSettingsTable: Table {
    static func tableSpec(_ id: Int32) -> ValueBoxTable {
        return ValueBoxTable(id: id, keyType: .int64, compactValuesOnCreation: true)
    }
    
    private let pendingIndexTable: PendingPeerNotificationSettingsIndexTable
    private let behaviorTable: PeerNotificationSettingsBehaviorTable
    
    private let sharedEncoder = PostboxEncoder()
    private let sharedKey = ValueBoxKey(length: 8)
    
    private var cachedSettings: [PeerId: PeerNotificationSettingsTableEntry] = [:]
    private var updatedInitialSettings: [PeerId: PeerNotificationSettingsTableEntry] = [:]
    
    init(valueBox: ValueBox, table: ValueBoxTable, useCaches: Bool, pendingIndexTable: PendingPeerNotificationSettingsIndexTable, behaviorTable: PeerNotificationSettingsBehaviorTable) {
        self.pendingIndexTable = pendingIndexTable
        self.behaviorTable = behaviorTable
        
        super.init(valueBox: valueBox, table: table, useCaches: useCaches)
    }
    
    private func key(_ id: PeerId) -> ValueBoxKey {
        self.sharedKey.setInt64(0, value: id.toInt64())
        return self.sharedKey
    }
    
    private func getEntry(_ id: PeerId, _ value: ReadBuffer? = nil) -> PeerNotificationSettingsTableEntry {
        if let entry = self.cachedSettings[id] {
            return entry
        } else if let value = value ?? self.valueBox.get(self.table, key: self.key(id)) {
            var flagsValue: Int32 = 0
            value.read(&flagsValue, offset: 0, length: 4)
            let flags = PeerNotificationSettingsTableEntryFlags(rawValue: flagsValue)
            
            var current: PeerNotificationSettings?
            if flags.contains(.hasCurrent) {
                var length: Int32 = 0
                value.read(&length, offset: 0, length: 4)
                let object = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(length), length: Int(length), freeWhenDone: false)).decodeRootObject() as? PeerNotificationSettings
                assert(object != nil)
                current = object
                value.skip(Int(length))
            }
            
            var pending: PeerNotificationSettings?
            if flags.contains(.hasPending) {
                var length: Int32 = 0
                value.read(&length, offset: 0, length: 4)
                let object = PostboxDecoder(buffer: MemoryBuffer(memory: value.memory.advanced(by: value.offset), capacity: Int(length), length: Int(length), freeWhenDone: false)).decodeRootObject() as? PeerNotificationSettings
                assert(object != nil)
                pending = object
                value.skip(Int(length))
            }
            let entry = PeerNotificationSettingsTableEntry(current: current, pending: pending)
            self.cachedSettings[id] = entry
            return entry
        } else {
            let entry = PeerNotificationSettingsTableEntry(current: nil, pending: nil)
            self.cachedSettings[id] = entry
            return entry
        }
    }
    
    func setCurrent(id: PeerId, settings: PeerNotificationSettings?, updatedTimestamps: inout [PeerId: PeerNotificationSettingsBehaviorTimestamp]) -> PeerNotificationSettings? {
        let currentEntry = self.getEntry(id)
        var updated = false
        if let current = currentEntry.current, let settings = settings {
            updated = !current.isEqual(to: settings)
        } else if (currentEntry.current != nil) != (settings != nil) {
            updated = true
        }
        if updated {
            var behaviorTimestamp: Int32?
            if let settings = settings {
                switch settings.behavior {
                    case .none:
                        break
                    case let .reset(atTimestamp, _):
                        behaviorTimestamp = atTimestamp
                }
            }
            self.behaviorTable.set(peerId: id, timestamp: behaviorTimestamp, updatedTimestamps: &updatedTimestamps)
            if self.updatedInitialSettings[id] == nil {
               self.updatedInitialSettings[id] = currentEntry
            }
            let updatedEntry = currentEntry.withUpdatedCurrent(settings)
            self.cachedSettings[id] = updatedEntry
            return updatedEntry.effective
        } else {
            return nil
        }
    }
    
    func setPending(id: PeerId, settings: PeerNotificationSettings?, updatedSettings: inout Set<PeerId>) -> PeerNotificationSettings? {
        let currentEntry = self.getEntry(id)
        var updated = false
        if let pending = currentEntry.pending, let settings = settings {
            updated = !pending.isEqual(to: settings)
        } else if (currentEntry.pending != nil) != (settings != nil) {
            updated = true
        }
        if updated {
            if self.updatedInitialSettings[id] == nil {
                self.updatedInitialSettings[id] = currentEntry
            }
            updatedSettings.insert(id)
            let updatedEntry = currentEntry.withUpdatedPending(settings)
            self.cachedSettings[id] = updatedEntry
            self.pendingIndexTable.set(peerId: id, pending: updatedEntry.pending != nil)
            return updatedEntry.effective
        } else {
            return nil
        }
    }
    
    func getCurrent(_ id: PeerId) -> PeerNotificationSettings? {
        return self.getEntry(id).current
    }
    
    func getEffective(_ id: PeerId) -> PeerNotificationSettings? {
        return self.getEntry(id).effective
    }
    
    func getPending(_ id: PeerId) -> PeerNotificationSettings? {
        return self.getEntry(id).pending
    }
    
    func getAll() -> [PeerId: PeerNotificationSettings] {
        var allSettings: [PeerId: PeerNotificationSettings] = [:]
        valueBox.scanInt64(self.table, values: { key, value in
            let peerId = PeerId(key)
            let entry = self.getEntry(peerId, value)
            if let settings = entry.effective {
                allSettings[peerId] = settings
            }
            return true
        })
        
        return allSettings
    }
    
    override func clearMemoryCache() {
        self.cachedSettings.removeAll()
        self.updatedInitialSettings.removeAll()
    }
    
    func transactionParticipationInTotalUnreadCountUpdates(postbox: PostboxImpl, transaction: Transaction) -> (added: Set<PeerId>, removed: Set<PeerId>) {
        var added = Set<PeerId>()
        var removed = Set<PeerId>()
        
        var globalNotificationSettings: PostboxGlobalNotificationSettings?
        
        for (peerId, initialSettings) in self.updatedInitialSettings {
            guard let peer = postbox.peerTable.get(peerId) else {
                continue
            }
            
            let globalNotificationSettingsValue: PostboxGlobalNotificationSettings
            if let current = globalNotificationSettings {
                globalNotificationSettingsValue = current
            } else {
                globalNotificationSettingsValue = postbox.getGlobalNotificationSettings(transaction: transaction)
                globalNotificationSettings = globalNotificationSettingsValue
            }
            
            let wasParticipating = !resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: peer, peerSettings: initialSettings.effective)
            let isParticipating = !resolvedIsRemovedFromTotalUnreadCount(globalSettings: globalNotificationSettingsValue, peer: peer, peerSettings: self.cachedSettings[peerId]?.effective)
            
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
    
    func resetAll(to settings: PeerNotificationSettings, updatedSettings: inout Set<PeerId>, updatedTimestamps: inout [PeerId: PeerNotificationSettingsBehaviorTimestamp]) -> [PeerId: PeerNotificationSettings?] {
        let lowerBound = ValueBoxKey(length: 8)
        lowerBound.setInt64(0, value: 0)
        let upperBound = ValueBoxKey(length: 8)
        upperBound.setInt64(0, value: Int64.max)
        var peerIds: [PeerId] = []
        self.valueBox.range(self.table, start: lowerBound, end: upperBound, keys: { key in
            peerIds.append(PeerId(key.getInt64(0)))
            return true
        }, limit: 0)
        
        var updatedPeers: [PeerId: PeerNotificationSettings?] = [:]
        for peerId in peerIds {
            let entry = self.getEntry(peerId)
            if let current = entry.current, !current.isEqual(to: settings) || entry.pending != nil {
                let _ = self.setCurrent(id: peerId, settings: settings, updatedTimestamps: &updatedTimestamps)
                let _ = self.setPending(id: peerId, settings: nil, updatedSettings: &updatedSettings)
                updatedPeers[peerId] = entry.effective
            }
        }
        
        return updatedPeers
    }
    
    override func beforeCommit() {
        if !self.updatedInitialSettings.isEmpty {
            let buffer = WriteBuffer()
            let encoder = PostboxEncoder()
            for (peerId, _) in self.updatedInitialSettings {
                if let entry = self.cachedSettings[peerId] {
                    buffer.reset()
                    
                    var flags = PeerNotificationSettingsTableEntryFlags()
                    if entry.current != nil {
                        flags.insert(.hasCurrent)
                    }
                    if entry.pending != nil {
                        flags.insert(.hasPending)
                    }
                    
                    var flagsValue: Int32 = flags.rawValue
                    buffer.write(&flagsValue, offset: 0, length: 4)
                    
                    if let current = entry.current {
                        encoder.reset()
                        encoder.encodeRootObject(current)
                        let object = encoder.readBufferNoCopy()
                        withExtendedLifetime(object, {
                            var length: Int32 = Int32(object.length)
                            buffer.write(&length, offset: 0, length: 4)
                            buffer.write(object.memory, offset: 0, length: object.length)
                        })
                    }
                    
                    if let pending = entry.pending {
                        encoder.reset()
                        encoder.encodeRootObject(pending)
                        let object = encoder.readBufferNoCopy()
                        withExtendedLifetime(object, {
                            var length: Int32 = Int32(object.length)
                            buffer.write(&length, offset: 0, length: 4)
                            buffer.write(object.memory, offset: 0, length: object.length)
                        })
                    }
                    
                    self.valueBox.set(self.table, key: self.key(peerId), value: buffer.readBufferNoCopy())
                } else {
                    assertionFailure()
                }
            }
            
            self.updatedInitialSettings.removeAll()

            if !self.useCaches {
                self.cachedSettings.removeAll()
            }
        }
    }
}
