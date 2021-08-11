import Foundation
import Postbox

public struct DoubleBottomHideTimestamp: PreferencesEntry, Equatable {
    public var timestamp: Int64
    
    public static var defaultValue: DoubleBottomHideTimestamp {
        return DoubleBottomHideTimestamp(timestamp: 0)
    }
    
    init(timestamp: Int64) {
        self.timestamp = timestamp
    }
    
    public init(decoder: PostboxDecoder) {
        self.timestamp = decoder.decodeInt64ForKey("t", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.timestamp, forKey: "t")
    }
    
    public func isEqual(to: PreferencesEntry) -> Bool {
        guard let to = to as? DoubleBottomHideTimestamp else {
            return false
        }
        return self == to
    }
}
