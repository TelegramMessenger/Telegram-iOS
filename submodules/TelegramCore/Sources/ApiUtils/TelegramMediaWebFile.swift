import Postbox

public extension TelegramMediaWebFile {
    var dimensions: PixelDimensions? {
        return dimensionsForFileAttributes(self.attributes)
    }
    
    var duration: Double? {
        return durationForFileAttributes(self.attributes)
    }
}
