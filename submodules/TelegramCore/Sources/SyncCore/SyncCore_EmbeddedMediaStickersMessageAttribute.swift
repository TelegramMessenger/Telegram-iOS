import Foundation
import Postbox

public class EmbeddedMediaStickersMessageAttribute: MessageAttribute {
    public let files: [TelegramMediaFile]
    
    public init(files: [TelegramMediaFile]) {
        self.files = files
    }
    
    required public init(decoder: PostboxDecoder) {
        self.files = decoder.decodeObjectArrayWithDecoderForKey("files")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.files, forKey: "files")
    }
}
