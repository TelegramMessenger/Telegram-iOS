import Foundation
import Postbox

class ViewCountMessageAttribute: MessageAttribute {
    let count: Int
    
    var associatedMessageIds: [MessageId] = []
    
    init(count: Int) {
        self.count = count
    }
    
    required init(decoder: Decoder) {
        self.count = Int(decoder.decodeInt32ForKey("c"))
    }
    
    func encode(_ encoder: Encoder) {
        encoder.encodeInt32(Int32(self.count), forKey: "c")
    }
}
