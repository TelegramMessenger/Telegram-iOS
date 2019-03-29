import Foundation

#if os(macOS)
import SwiftSignalKitMac
#else
import SwiftSignalKit
#endif

func postboxUpgrade_21to22(queue: Queue, basePath: String, valueBox: ValueBox, encryptionKey: Data, progress: (Float) -> Void) -> String {
    let exportPath = "\(basePath)/version22"
    let _ = try? FileManager.default.removeItem(atPath: exportPath)
    valueBox.exportEncrypted(to: exportPath, encryptionKey: encryptionKey)
    
    let updatedValueBox = SqliteValueBox(basePath: exportPath, queue: queue, encryptionKey: encryptionKey)
    let metadataTable = MetadataTable(valueBox: updatedValueBox, table: MetadataTable.tableSpec(0))
    updatedValueBox.begin()
    metadataTable.setUserVersion(22)
    updatedValueBox.commit()
    
    return exportPath
}
