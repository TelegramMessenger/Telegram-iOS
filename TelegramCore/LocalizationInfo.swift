import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class LocalizationInfo: PostboxCoding {
    public let languageCode: String
    public let baseLanguageCode: String?
    public let title: String
    public let localizedTitle: String
    public let isOfficial: Bool
    public let totalStringCount: Int32
    public let translatedStringCount: Int32
    
    public init(languageCode: String, baseLanguageCode: String?, title: String, localizedTitle: String, isOfficial: Bool, totalStringCount: Int32, translatedStringCount: Int32) {
        self.languageCode = languageCode
        self.baseLanguageCode = baseLanguageCode
        self.title = title
        self.localizedTitle = localizedTitle
        self.isOfficial = isOfficial
        self.totalStringCount = totalStringCount
        self.translatedStringCount = translatedStringCount
    }
    
    public init(decoder: PostboxDecoder) {
        self.languageCode = decoder.decodeStringForKey("lc", orElse: "")
        self.baseLanguageCode = decoder.decodeOptionalStringForKey("nlc")
        self.title = decoder.decodeStringForKey("t", orElse: "")
        self.localizedTitle = decoder.decodeStringForKey("lt", orElse: "")
        self.isOfficial = decoder.decodeInt32ForKey("of", orElse: 0) != 0
        self.totalStringCount = decoder.decodeInt32ForKey("tsc", orElse: 0)
        self.translatedStringCount = decoder.decodeInt32ForKey("lsc", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(self.languageCode, forKey: "lc")
        if let baseLanguageCode = self.baseLanguageCode {
            encoder.encodeString(baseLanguageCode, forKey: "nlc")
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
                self.init(languageCode: language.langCode, baseLanguageCode: nil/*language.baseLangCode*/, title: language.name, localizedTitle: language.nativeName, isOfficial: true/*(language.flags & (1 << 0)) != 0*/, totalStringCount: 1/*language.stringsCount*/, translatedStringCount: 1/*language.translatedCount*/)
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
