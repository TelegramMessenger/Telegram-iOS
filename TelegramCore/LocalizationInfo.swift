import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LocalizationInfo: PostboxCoding {
    public let languageCode: String
    public let title: String
    public let localizedTitle: String
    
    public init(languageCode: String, title: String, localizedTitle: String) {
        self.languageCode = languageCode
        self.title = title
        self.localizedTitle = localizedTitle
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.localizedTitle = decoder.decodeStringForKey("lt", orElse: "")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.localizedTitle, forKey: "lt")
    }
}

public final class SuggestedLocalizationInfo {
    public let languageCode: String
    public let extractedEntries: [LocalizationEntry]
    
    public let availableLocalizations: [LocalizationInfo]
    
    init(languageCode: String, extractedEntries: [LocalizationEntry], availableLocalizations: [LocalizationInfo]) {
        self.languageCode = languageCode
        self.extractedEntries = extractedEntries
        self.availableLocalizations = availableLocalizations
    }
}
