import Foundation
import Postbox
import TelegramApi


extension LocalizationInfo {
    init(apiLanguage: Api.LangPackLanguage) {
        switch apiLanguage {
            case let .langPackLanguage(langPackLanguageData):
                let (flags, name, nativeName, langCode, baseLangCode, pluralCode, stringsCount, translatedCount, translationsUrl) = (langPackLanguageData.flags, langPackLanguageData.name, langPackLanguageData.nativeName, langPackLanguageData.langCode, langPackLanguageData.baseLangCode, langPackLanguageData.pluralCode, langPackLanguageData.stringsCount, langPackLanguageData.translatedCount, langPackLanguageData.translationsUrl)
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
