import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public enum MessageType {
        case sponsored
        case recommended
    }
    
    public enum MessageTarget {
        case peer(id: EnginePeer.Id, message: EngineMessage.Id?, startParam: String?)
        case join(title: String, joinHash: String)
    }
    
    public let opaqueId: Data
    public let messageType: MessageType
    public let displayAvatar: Bool
    public let target: MessageTarget

    public init(opaqueId: Data, messageType: MessageType, displayAvatar: Bool, target: MessageTarget) {
        self.opaqueId = opaqueId
        self.messageType = messageType
        self.displayAvatar = displayAvatar
        self.target = target
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
