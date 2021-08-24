import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public let opaqueId: Data

    public init(opaqueId: Data) {
        self.opaqueId = opaqueId
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
