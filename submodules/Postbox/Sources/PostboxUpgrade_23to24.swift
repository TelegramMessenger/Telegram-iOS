import Foundation

func postboxUpgrade_23to24(metadataTable: MetadataTable, valueBox: ValueBox, progress: (Float) -> Void) {
    postboxLog("Upgrade 23->24 started")
    let messageHistoryMetadataTable = ValueBoxTable(id: 10, keyType: .binary, compactValuesOnCreation: true)
    let shouldReindexUnreadCountsKey = ValueBoxKey(length: 1)
    shouldReindexUnreadCountsKey.setInt8(0, value: 8)
    valueBox.set(messageHistoryMetadataTable, key: shouldReindexUnreadCountsKey, value: MemoryBuffer())
    
    metadataTable.setUserVersion(24)
}
