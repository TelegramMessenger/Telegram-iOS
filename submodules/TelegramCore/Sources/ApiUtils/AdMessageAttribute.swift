import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public let opaqueId: Data
    public let startParam: String?

    public init(opaqueId: Data, startParam: String?) {
        self.opaqueId = opaqueId
        self.startParam = startParam
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
