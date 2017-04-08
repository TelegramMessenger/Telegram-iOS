import Foundation

func postboxUpgrade_12to13(metadataTable: MetadataTable, valueBox: ValueBox) {
    // drop PeerMergedOperationLogIndexTable
    valueBox.dropTable(ValueBoxTable(id: 30, keyType: .binary))
    
    // drop PeerOperationLogTable
    valueBox.dropTable(ValueBoxTable(id: 31, keyType: .binary))
    
    metadataTable.setUserVersion(13)
}
