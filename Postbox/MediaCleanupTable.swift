import Foundation

final class MediaCleanupTable {
    let valueBox: ValueBox
    let tableId: Int32
    
    var debugMedia: [Media] = []
    
    init(valueBox: ValueBox, tableId: Int32) {
        self.valueBox = valueBox
        self.tableId = tableId
    }
    
    func add(media: Media, sharedEncoder: Encoder = Encoder()) {
        debugMedia.append(media)
    }
    
    func debugList() -> [Media] {
        return self.debugMedia
    }
}