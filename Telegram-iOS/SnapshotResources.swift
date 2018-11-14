#if DEBUG
    
import Foundation
import Postbox
import SwiftSignalKit
import TelegramCore
    
private var dataPath: String?

func setupSnapshotData(_ path: String) {
    dataPath = path
}
    
func snapshotAvatar(_ postbox: Postbox, _ id: Int32) -> [TelegramMediaImageRepresentation] {
    guard let path = dataPath else {
        return []
    }
    
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: path + "/Bitmap\(id).png")) else {
        return []
    }
    if let image = UIImage(data: data) {
        let resource = LocalFileMediaResource(fileId: arc4random64(), size: data.count)
        
        postbox.mediaBox.storeResourceData(resource.id, data: data)
        return [TelegramMediaImageRepresentation(dimensions: image.size, resource: resource)]
    } else {
        return []
    }
}

#endif
