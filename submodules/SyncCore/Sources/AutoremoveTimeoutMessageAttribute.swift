import Foundation
import Postbox

public class AutoremoveTimeoutMessageAttribute: MessageAttribute {
    public enum Action: Int32 {
        case remove = 0
        case clear = 1
    }
    
    public let timeout: Int32
    public let countdownBeginTime: Int32?
    public let action: Action
    
    public var associatedMessageIds: [MessageId] = []
    
    public let automaticTimestampBasedAttribute: (UInt16, Int32)?
    
    public init(timeout: Int32, countdownBeginTime: Int32?, action: Action = .remove) {
        self.timeout = timeout
        self.countdownBeginTime = countdownBeginTime
        
        if let countdownBeginTime = countdownBeginTime {
            self.automaticTimestampBasedAttribute = (0, countdownBeginTime + timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
        
        self.action = action
    }
    
    required public init(decoder: PostboxDecoder) {
        self.timeout = decoder.decodeInt32ForKey("t", orElse: 0)
        self.countdownBeginTime = decoder.decodeOptionalInt32ForKey("c")
        
        if let countdownBeginTime = self.countdownBeginTime {
            self.automaticTimestampBasedAttribute = (0, countdownBeginTime + self.timeout)
        } else {
            self.automaticTimestampBasedAttribute = nil
        }
        
        self.action = Action(rawValue: decoder.decodeInt32ForKey("a", orElse: 0)) ?? .remove
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.timeout, forKey: "t")
        if let countdownBeginTime = self.countdownBeginTime {
            encoder.encodeInt32(countdownBeginTime, forKey: "c")
        } else {
            encoder.encodeNil(forKey: "c")
        }
        encoder.encodeInt32(self.action.rawValue, forKey: "a")
    }
}

public extension Message {
    var containsSecretMedia: Bool {
        var found = false
        for attribute in self.attributes {
            if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
                if attribute.timeout > 1 * 60 {
                    return false
                }
                found = true
                break
            }
        }
        
        if !found {
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
        for attribute in self.attributes {
            if let _ = attribute as? AutoremoveTimeoutMessageAttribute {
                return true
            }
        }
        return false
    }
}
