import Postbox

public final class SynchronizeEmojiKeywordsOperation: PostboxCoding {
    public let inputLanguageCode: String
    public let languageCode: String?
    public let fromVersion: Int32?
    
    public init(inputLanguageCode: String, languageCode: String?, fromVersion: Int32?) {
        self.inputLanguageCode = inputLanguageCode
        self.languageCode = languageCode
        self.fromVersion = fromVersion
    }
    
    public init(decoder: PostboxDecoder) {
        self.inputLanguageCode = decoder.decodeStringForKey("ilc", orElse: "")
        self.languageCode = decoder.decodeOptionalStringForKey("lc")
        self.fromVersion = decoder.decodeOptionalInt32ForKey("v")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.inputLanguageCode, forKey: "ilc")
        if let languageCode = self.languageCode {
            encoder.encodeString(languageCode, forKey: "lc")
        } else {
            encoder.encodeNil(forKey: "lc")
        }
        if let fromVersion = self.fromVersion {
            encoder.encodeInt32(fromVersion, forKey: "v")
        } else {
            encoder.encodeNil(forKey: "v")
        }
    }
}
