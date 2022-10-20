import Foundation

import SwiftSignalKit

func postboxUpgrade_21to22(queue: Queue, basePath: String, valueBox: ValueBox, encryptionParameters: ValueBoxEncryptionParameters, progress: (Float) -> Void) -> String? {
    postboxLog("Upgrade 21->22 started")
    valueBox.begin()
    let metadataTable = MetadataTable(valueBox: valueBox, table: MetadataTable.tableSpec(0), useCaches: false)
    metadataTable.setUserVersion(22)
    valueBox.commit()
    return nil
}
