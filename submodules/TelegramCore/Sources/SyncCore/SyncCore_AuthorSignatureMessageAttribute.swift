import Foundation
import Postbox

public class AuthorSignatureMessageAttribute: MessageAttribute {
    public let signature: String
    
    public let associatedPeerIds: [PeerId] = []
    
    public init(signature: String) {
        self.signature = signature
    }
    
    required public init(decoder: PostboxDecoder) {
        self.signature = decoder.decodeStringForKey("s", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.signature, forKey: "s")
    }
}
