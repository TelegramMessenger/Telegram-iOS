import Foundation
import Postbox

public final class AdMessageAttribute: MessageAttribute {
    public enum MessageType {
        case sponsored
        case recommended
    }
    
    public let opaqueId: Data
    public let messageType: MessageType
    public let url: String
    public let buttonText: String
    public let sponsorInfo: String?
    public let additionalInfo: String?
    public let canReport: Bool
    public let hasContentMedia: Bool
    public let minDisplayDuration: Int32?
    public let maxDisplayDuration: Int32?

    public init(opaqueId: Data, messageType: MessageType, url: String, buttonText: String, sponsorInfo: String?, additionalInfo: String?, canReport: Bool, hasContentMedia: Bool, minDisplayDuration: Int32?, maxDisplayDuration: Int32?) {
        self.opaqueId = opaqueId
        self.messageType = messageType
        self.url = url
        self.buttonText = buttonText
        self.sponsorInfo = sponsorInfo
        self.additionalInfo = additionalInfo
        self.canReport = canReport
        self.hasContentMedia = hasContentMedia
        self.minDisplayDuration = minDisplayDuration
        self.maxDisplayDuration = maxDisplayDuration
    }

    public init(decoder: PostboxDecoder) {
        preconditionFailure()
    }

    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
}
