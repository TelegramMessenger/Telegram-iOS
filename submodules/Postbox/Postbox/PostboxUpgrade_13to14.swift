import Foundation

func postboxUpgrade_13to14(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    var peerSettings: [PeerId: Data] = [:]
    
    let peerNotificationSettingsTable = ValueBoxTable(id: 19, keyType: .int64, compactValuesOnCreation: false)
    valueBox.scanInt64(peerNotificationSettingsTable, values: { key, value in
        let peerId = PeerId(key)
        peerSettings[peerId] = value.makeData()
        return true
    })
    
    valueBox.removeAllFromTable(peerNotificationSettingsTable)
    let key = ValueBoxKey(length: 8)
    let buffer = WriteBuffer()
    for (peerId, settings) in peerSettings {
        buffer.reset()
        
        key.setInt64(0, value: peerId.toInt64())
        var flagsValue: Int32 = (1 << 0)
        buffer.write(&flagsValue, offset: 0, length: 4)
        var length: Int32 = Int32(settings.count)
        buffer.write(&length, offset: 0, length: 4)
        buffer.write(settings)
        valueBox.set(peerNotificationSettingsTable, key: key, value: buffer)
    }
    
    metadataTable.setUserVersion(14)
}
