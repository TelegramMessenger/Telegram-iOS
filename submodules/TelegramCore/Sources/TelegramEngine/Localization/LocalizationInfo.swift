import Foundation
import Postbox
import TelegramApi


extension LocalizationInfo {
    init(apiLanguage: Api.LangPackLanguage) {
        switch apiLanguage {
            case let .langPackLanguage(flags, name, nativeName, langCode, baseLangCode, pluralCode, stringsCount, translatedCount, translationsUrl):
                self.init(languageCode: langCode, baseLanguageCode: baseLangCode, customPluralizationCode: pluralCode, title: name, localizedTitle: nativeName, isOfficial: (flags & (1 << 0)) != 0, totalStringCount: stringsCount, translatedStringCount: translatedCount, platformUrl: translationsUrl)
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
