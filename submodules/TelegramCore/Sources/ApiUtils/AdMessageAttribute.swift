import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public enum MessageTarget {
        case peer(id: EnginePeer.Id, message: EngineMessage.Id?, startParam: String?)
        case join(title: String, joinHash: String)
    }
    
    public let opaqueId: Data
    public let target: MessageTarget

    public init(opaqueId: Data, target: MessageTarget) {
        self.opaqueId = opaqueId
        self.target = target
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
