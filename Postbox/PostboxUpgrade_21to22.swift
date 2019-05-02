import Foundation

#if os(macOS)
import SwiftSignalKitMac
#else
import SwiftSignalKit
#endif

func postboxUpgrade_21to22(queue: Queue, basePath: String, valueBox: ValueBox, encryptionParameters: ValueBoxEncryptionParameters, progress: (Float) -> Void) -> String? {
    if encryptionParameters.forceEncryptionIfNoSet {
        let exportPath = "\(basePath)/version22"
        let _ = try? FileManager.default.removeItem(atPath: exportPath)
        valueBox.exportEncrypted(to: exportPath, encryptionParameters: encryptionParameters)
        
        let updatedValueBox = SqliteValueBox(basePath: exportPath, queue: queue, encryptionParameters: encryptionParameters, upgradeProgress: progress)
        let metadataTable = MetadataTable(valueBox: updatedValueBox, table: MetadataTable.tableSpec(0))
        updatedValueBox.begin()
        metadataTable.setUserVersion(22)
        updatedValueBox.commit()
        return exportPath
    } else {
        valueBox.begin()
        let metadataTable = MetadataTable(valueBox: valueBox, table: MetadataTable.tableSpec(0))
        metadataTable.setUserVersion(22)
        valueBox.commit()
        return nil
    }
}
