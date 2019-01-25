import Foundation
import Postbox

final class SolidColorMedia: Media  {
    var id: MediaId? {
        return nil
    }
    let peerIds: [PeerId] = []
    
    let color: UIColor
    
    init(color: UIColor) {
        self.color = color
    }
    
    init(decoder: PostboxDecoder) {
        self.color = UIColor(argb: UInt32(bitPattern: decoder.decodeInt32ForKey("c", orElse: 0)))
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(Int32(bitPattern: self.color.rgb), forKey: "c")
    }
    
    public func isEqual(to other: Media) -> Bool {
        guard let other = other as? SolidColorMedia else {
            return false
        }
        
        if self.color != other.color {
            return false
        }
        
        return true
    }
    
    public func isSemanticallyEqual(to other: Media) -> Bool {
        return self.isEqual(to: other)
    }
}
