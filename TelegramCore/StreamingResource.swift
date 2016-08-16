import Foundation
import Postbox

final class StreamingResource: Coding {
    let location: TelegramMediaLocation
    let mimeType: String
    let size: Int
    
    init(location: TelegramMediaLocation, mimeType: String, size: Int) {
        self.location = location
        self.mimeType = mimeType
        self.size = size
    }
    
    init(decoder: Decoder) {
        self.location = decoder.decodeObjectForKey("l") as! TelegramMediaLocation
        self.mimeType = decoder.decodeStringForKey("t")
        self.size = Int(decoder.decodeInt32ForKey("s"))
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeObject(self.location, forKey: "l")
        encoder.encodeString(self.mimeType, forKey: "t")
        encoder.encodeInt32(Int32(self.size), forKey: "s")
    }
}
