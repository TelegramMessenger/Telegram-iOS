import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LocalizationInfo: PostboxCoding {
    public let languageCode: String
    public let nativeLanguageCode: String?
    public let title: String
    public let localizedTitle: String
    public let isOfficial: Bool
    public let totalStringCount: Int32
    public let translatedStringCount: Int32
    
    public init(languageCode: String, nativeLanguageCode: String?, title: String, localizedTitle: String, isOfficial: Bool, totalStringCount: Int32, translatedStringCount: Int32) {
        self.languageCode = languageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.title = title
        self.localizedTitle = localizedTitle
        self.isOfficial = isOfficial
        self.totalStringCount = totalStringCount
        self.translatedStringCount = translatedStringCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.nativeLanguageCode = decoder.decodeOptionalStringForKey("nlc")
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.localizedTitle = decoder.decodeStringForKey("lt", orElse: "")
        self.isOfficial = decoder.decodeInt32ForKey("of", orElse: 0) != 0
        self.totalStringCount = decoder.decodeInt32ForKey("tsc", orElse: 0)
        self.translatedStringCount = decoder.decodeInt32ForKey("lsc", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        if let nativeLanguageCode = self.nativeLanguageCode {
            encoder.encodeString(nativeLanguageCode, forKey: "nlc")
        } else {
            encoder.encodeNil(forKey: "nlc")
        }
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeString(self.localizedTitle, forKey: "lt")
        encoder.encodeInt32(self.isOfficial ? 1 : 0, forKey: "of")
        encoder.encodeInt32(self.totalStringCount, forKey: "tsc")
        encoder.encodeInt32(self.translatedStringCount, forKey: "lsc")
    }
}

extension LocalizationInfo {
    convenience init(apiLanguage: Api.LangPackLanguage) {
        switch apiLanguage {
            case let .langPackLanguage(language):
                self.init(languageCode: language.langCode, nativeLanguageCode: language.baseLangCode, title: language.name, localizedTitle: language.nativeName, isOfficial: (language.flags & (1 << 0)) != 0, totalStringCount: language.stringsCount, translatedStringCount: language.translatedCount)
        }
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
