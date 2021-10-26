import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public let opaqueId: Data
    public let startParam: String?
    public let messageId: MessageId?

    public init(opaqueId: Data, startParam: String?, messageId: MessageId?) {
        self.opaqueId = opaqueId
        self.startParam = startParam
        self.messageId = messageId
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
