import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public class AutoremoveTimeoutMessageAttribute: MessageAttribute {
    public let timeout: Int32
    public let countdownBeginTime: Int32?
    
    public var associatedMessageIds: [MessageId] = []
    
    init(timeout: Int32, countdownBeginTime: Int32?) {
        self.timeout = timeout
        self.countdownBeginTime = countdownBeginTime
    }
    
    required public init(decoder: Decoder) {
        self.timeout = decoder.decodeInt32ForKey("t")
        self.countdownBeginTime = decoder.decodeInt32ForKey("c")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt32(self.timeout, forKey: "t")
        if let countdownBeginTime = self.countdownBeginTime {
            encoder.encodeInt32(countdownBeginTime, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
    }
}
