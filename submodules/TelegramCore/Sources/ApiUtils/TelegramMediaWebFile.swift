import Postbox
import SyncCore

public extension TelegramMediaWebFile {
    var dimensions: PixelDimensions? {
        return dimensionsForFileAttributes(self.attributes)
    }
    
    var duration: Int32? {
        return durationForFileAttributes(self.attributes)
    }
}
