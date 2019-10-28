import Postbox
import SyncCore
import UIKit

public extension TelegramMediaWebFile {
    public var dimensions: CGSize? {
        return dimensionsForFileAttributes(self.attributes)
    }
    
    public var duration: Int32? {
        return durationForFileAttributes(self.attributes)
    }
}
