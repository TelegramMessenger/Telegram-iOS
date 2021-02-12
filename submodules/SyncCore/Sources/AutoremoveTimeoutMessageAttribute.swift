import Foundation
import Postbox

public class AutoremoveTimeoutMessageAttribute: MessageAttribute {
    public let timeout: Int32
    public let countdownBeginTime: Int32?
    
    public var associatedMessageIds: [MessageId] = []
    
    public let automaticTimestampBasedAttribute: (UInt16, Int32)?
    
    public init(timeout: Int32, countdownBeginTime: Int32?) {
        self.timeout = timeout
        self.countdownBeginTime = countdownBeginTime
        
        if let countdownBeginTime = countdownBeginTime {
            self.automaticTimestampBasedAttribute = (0, countdownBeginTime + timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
    }
    
    required public init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeInt32ForKey("t", orElse: 0)
        self.countdownBeginTime = decoder.decodeOptionalInt32ForKey("c")
        
        if let countdownBeginTime = self.countdownBeginTime {
            self.automaticTimestampBasedAttribute = (0, countdownBeginTime + self.timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timeout, forKey: "t")
        if let countdownBeginTime = self.countdownBeginTime {
            encoder.encodeInt32(countdownBeginTime, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
    }
}

public class AutoclearTimeoutMessageAttribute: MessageAttribute {
    public let timeout: Int32
    public let countdownBeginTime: Int32?
    
    public var associatedMessageIds: [MessageId] = []
    
    public let automaticTimestampBasedAttribute: (UInt16, Int32)?
    
    public init(timeout: Int32, countdownBeginTime: Int32?) {
        self.timeout = timeout
        self.countdownBeginTime = countdownBeginTime
        
        if let countdownBeginTime = countdownBeginTime {
            self.automaticTimestampBasedAttribute = (1, countdownBeginTime + timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
    }
    
    required public init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeInt32ForKey("t", orElse: 0)
        self.countdownBeginTime = decoder.decodeOptionalInt32ForKey("c")
        
        if let countdownBeginTime = self.countdownBeginTime {
            self.automaticTimestampBasedAttribute = (1, countdownBeginTime + self.timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timeout, forKey: "t")
        if let countdownBeginTime = self.countdownBeginTime {
            encoder.encodeInt32(countdownBeginTime, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
    }
}

public extension Message {
    var autoremoveAttribute: AutoremoveTimeoutMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var autoclearAttribute: AutoclearTimeoutMessageAttribute? {
        for attribute in self.attributes {
            if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                return attribute
            }
        }
        return nil
    }
    
    var minAutoremoveOrClearTimeout: Int32? {
        var timeout: Int32?
        for attribute in self.attributes {
            if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                if let timeoutValue = timeout {
                    timeout = min(timeoutValue, attribute.timeout)
                } else {
                    timeout = attribute.timeout
                }
            } else if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
                if let timeoutValue = timeout {
                    timeout = min(timeoutValue, attribute.timeout)
                } else {
                    timeout = attribute.timeout
                }
            }
        }
        return timeout
    }
    
    var containsSecretMedia: Bool {
        guard let timeout = self.minAutoremoveOrClearTimeout else {
            return false
        }
        if timeout > 1 * 60 {
            return false
        }
        
        for media in self.media {
            switch media {
                case _ as TelegramMediaImage:
                    return true
                case let file as TelegramMediaFile:
                    if file.isVideo || file.isAnimated || file.isVoice || file.isMusic {
                        return true
                    }
                default:
                    break
            }
        }
        
        return false
    }
    
    var isSelfExpiring: Bool {
        return self.minAutoremoveOrClearTimeout != nil
    }
}

