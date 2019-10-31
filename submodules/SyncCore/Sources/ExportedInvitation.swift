import Postbox

public struct ExportedInvitation: PostboxCoding, Equatable {
    public let link: String
    
    public init(link: String) {
        self.link = link
    }
    
    public init(decoder: PostboxDecoder) {
        self.link = decoder.decodeStringForKey("l", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.link, forKey: "l")
    }
    
    public static func ==(lhs: ExportedInvitation, rhs: ExportedInvitation) -> Bool {
        return lhs.link == rhs.link
    }
}
