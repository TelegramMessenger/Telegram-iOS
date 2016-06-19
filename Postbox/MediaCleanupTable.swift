import Foundation

final class MediaCleanupTable: Table {
    var debugMedia: [Media] = []
    
    override init(valueBox: ValueBox, tableId: Int32) {
        super.init(valueBox: valueBox, tableId: tableId)
    }
    
    func add(_ media: Media, sharedEncoder: Encoder = Encoder()) {
        debugMedia.append(media)
    }
    
    func debugList() -> [Media] {
        return self.debugMedia
    }
}
